import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/server_models.dart';
import 'api_client.dart';

/// Telemetry service connected to SysDashServer (Golang backend) via WebSocket
/// (`/api/v1/ws/metrics?token=...`) and REST API (`/api/v1/metrics/...`),
/// with automatic polling and real-time streaming.
class TelemetryService extends ChangeNotifier {
  final ServerProfile profile;
  final SysDashApiClient? client;
  final List<ServerNode> nodes;
  final Map<String, List<TimedSample>> _historyCache = {};

  Timer? _localTimer;
  Timer? _restPollTimer;
  Timer? _dockerPollTimer;
  Timer? _processPollTimer;
  WebSocket? _ws;
  StreamSubscription? _wsSub;
  bool _isLive = true;
  bool _isConnectedToServer = false;
  bool _isLoaded = false;
  bool _isDockerLoaded = false;
  bool _isFetchingDocker = false;
  bool _isDisposed = false;
  int _processLimit = 15;

  bool get isLive => _isLive;
  bool get isConnectedToServer => _isConnectedToServer;
  bool get isLoaded => _isLoaded;
  bool get isDockerLoaded => _isDockerLoaded;
  bool get isFetchingDocker => _isFetchingDocker;
  int get processLimit => _processLimit;

  void setProcessLimit(int limit) {
    if (_processLimit == limit) return;
    _processLimit = limit;
    _fetchTopProcesses();
    if (_isConnectedToServer && _ws != null) {
      try {
        _ws!.add(jsonEncode({'limit': limit}));
      } catch (_) {
        _reconnectWebSocketWithLimit();
      }
    }
    notifyListeners();
  }

  Future<void> _reconnectWebSocketWithLimit() async {
    _wsSub?.cancel();
    _wsSub = null;
    _ws?.close();
    _ws = null;
    await _connectWebSocket();
  }

  TelemetryService({
    required this.profile,
    this.client,
    ServerNode? initialNode,
    bool isLoaded = false,
    bool? isDockerLoaded,
  })  : _isLoaded = isLoaded || initialNode != null,
        _isDockerLoaded = isDockerLoaded ?? (initialNode != null || client == null),
        nodes = [initialNode ?? ServerNode.createEmpty(profile)] {
    _seedInitialLiveBuffers();
    _initConnection();
  }

  void _seedInitialLiveBuffers() {
    final now = DateTime.now();
    for (final node in nodes) {
      if ((node.current[MetricKey.disk] == null || node.current[MetricKey.disk] == 0.0) && node.diskTotalGb > 0) {
        node.current[MetricKey.disk] = (node.diskUsedGb / node.diskTotalGb * 100);
      }
      for (final key in MetricKey.values) {
        final buf = node.live[key];
        if (buf != null && buf.isEmpty) {
          final val = node.current[key] ?? node.baseline[key] ?? 0.0;
          buf.add(TimedSample(now.subtract(const Duration(seconds: 2)), val));
          buf.add(TimedSample(now, val));
        }
      }
    }
  }

  void toggleLive() {
    _isLive = !_isLive;
    notifyListeners();
  }

  /// Returns metric series over [range]. Historical ranges query the server
  /// `/metrics/history?range=...` when available and cache the result.
  List<TimedSample> series(ServerNode node, MetricKey key, TimeRange range) {
    if (range == TimeRange.live) return node.live[key] ?? [];

    final cacheKey = '${node.id}|${key.name}|${range.apiParam}';
    if (_historyCache.containsKey(cacheKey)) {
      return _historyCache[cacheKey]!;
    }

    if (client != null && node.id == nodes.first.id) {
      _fetchServerHistory(node, key, range, cacheKey);
    }

    return const [];
  }

  Future<void> _fetchServerHistory(
    ServerNode node,
    MetricKey key,
    TimeRange range,
    String cacheKey,
  ) async {
    try {
      final rows = await client!.getHistory(range: range.apiParam);
      if (_isDisposed || rows.isEmpty) return;

      final samples = <TimedSample>[];
      for (final r in rows) {
        final rawTs = r['timestamp'] as String?;
        if (rawTs == null) continue;
        final ts = DateTime.tryParse(rawTs) ?? DateTime.now();
        double val = 0.0;

        switch (key) {
          case MetricKey.cpu:
            val = (r['cpu_percent'] as num?)?.toDouble() ?? 0.0;
            break;
          case MetricKey.memory:
            val = (r['mem_used_percent'] as num?)?.toDouble() ?? 0.0;
            break;
          case MetricKey.disk:
            val = (r['disk_percent'] as num?)?.toDouble() ?? 0.0;
            break;
          case MetricKey.diskRead:
            val = ((r['disk_read_rate'] as num?)?.toDouble() ??
                    (r['disk_read_bytes_sec'] as num?)?.toDouble() ??
                    (r['disk_read'] as num?)?.toDouble() ??
                    0.0) /
                (1024 * 1024);
            break;
          case MetricKey.diskWrite:
            val = ((r['disk_write_rate'] as num?)?.toDouble() ??
                    (r['disk_write_bytes_sec'] as num?)?.toDouble() ??
                    (r['disk_write'] as num?)?.toDouble() ??
                    0.0) /
                (1024 * 1024);
            break;
          case MetricKey.netRx:
            val = ((r['net_download_rate'] as num?)?.toDouble() ?? 0.0) / (1024 * 1024 / 8);
            break;
          case MetricKey.netTx:
            val = ((r['net_upload_rate'] as num?)?.toDouble() ?? 0.0) / (1024 * 1024 / 8);
            break;
          default:
            val = (r['cpu_percent'] as num?)?.toDouble() ?? 0.0;
        }
        samples.add(TimedSample(ts, val));
      }

      if (!_isDisposed && samples.length >= 2) {
        _historyCache[cacheKey] = samples;
        notifyListeners();
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Real-Time Connection (WebSocket & REST API)
  // ---------------------------------------------------------------------------

  void _initConnection() {
    _startUptimeTicker();
    if (client != null && profile.token.isNotEmpty) {
      _fetchInitialServerData();
      _connectWebSocket();
      _startPeriodicPollers();
    }
  }

  void _startUptimeTicker() {
    _localTimer?.cancel();
    _localTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isLive || !_isLoaded) return;
      for (final node in nodes) {
        node.uptime += const Duration(seconds: 1);
      }
      notifyListeners();
    });
  }

  void _applyHostInfo(Map<String, dynamic> sysInfo) {
    if (_isDisposed) return;
    final node = nodes.first;
    final info = HostInfo.fromJson(sysInfo);
    node.hostInfo = info;

    if (info.hostname.isNotEmpty) {
      node.name = profile.alias.isNotEmpty ? profile.alias : info.hostname;
    }
    final pretty = info.prettyOs;
    if (pretty.isNotEmpty) {
      node.osKernel = pretty;
    }
    if (info.cpuModel.isNotEmpty) {
      node.cpuModel = info.cpuModel;
    }
    if (info.cpuLogicalCores > 0) {
      node.cpuCores = info.cpuLogicalCores;
      node.cpuLogicalCores = info.cpuLogicalCores;
    }
    if (info.cpuPhysicalCores > 0) {
      node.cpuPhysicalCores = info.cpuPhysicalCores;
    }
    if (info.cpuMhz > 0) {
      node.cpuMhz = info.cpuMhz;
    }
    if (info.cpuSpeedGhz > 0) {
      node.cpuSpeedGhz = info.cpuSpeedGhz;
    }
    if (info.uptime > 0) {
      node.uptime = Duration(seconds: info.uptime);
    }
  }

  Future<void> _fetchInitialServerData() async {
    try {
      // 1. Fetch static system hardware info (CPU, OS, Host)
      final sysInfo = await client!.getSystemInfo();
      if (_isDisposed) return;
      _applyHostInfo(sysInfo);

      // 2. Fetch current metrics (RAM bytes, Disks, per-core CPU, Network)
      final currentMetrics = await client!.getCurrentMetrics();
      if (_isDisposed) return;
      if (currentMetrics.isNotEmpty) {
        _handleServerSnapshot(currentMetrics);
      }

      // 3. Fetch top system & memory processes
      _fetchTopProcesses();

      if (!_isDisposed) notifyListeners();

      // 4. Fetch Docker data (Containers & Images) asynchronously in background
      // without blocking main metrics, CPU, Memory, Disks, and Network tabs
      fetchDockerData();
    } catch (_) {
      _isDockerLoaded = true;
    }
  }

  /// Fetches Docker containers & images in parallel asynchronously.
  Future<void> fetchDockerData() async {
    if (client == null || _isDisposed || nodes.isEmpty || _isFetchingDocker) return;
    _isFetchingDocker = true;
    try {
      final results = await Future.wait([
        client!.getDockerContainers(),
        client!.getDockerImages(),
      ]);
      if (!_isDisposed && nodes.isNotEmpty) {
        nodes[0].containers
          ..clear()
          ..addAll(results[0] as List<ContainerInfo>);
        nodes[0].dockerImages
          ..clear()
          ..addAll(results[1] as List<DockerImageItem>);
        _updateDockerLiveBuffers(nodes[0]);
      }
    } catch (_) {
    } finally {
      _isFetchingDocker = false;
      _isDockerLoaded = true;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> _fetchTopProcesses() async {
    if (client == null || _isDisposed) return;
    try {
      final results = await Future.wait([
        client!.getProcesses(sort: 'cpu', order: 'desc', limit: _processLimit),
        client!.getProcesses(sort: 'memory', order: 'desc', limit: _processLimit),
      ]);
      if (_isDisposed || nodes.isEmpty) return;
      final cpuProcs = results[0];
      final memProcs = results[1];
      final node = nodes.first;

      if (cpuProcs.isNotEmpty) {
        node.topProcesses
          ..clear()
          ..addAll(cpuProcs);
      }
      if (memProcs.isNotEmpty) {
        node.topMemoryProcesses
          ..clear()
          ..addAll(memProcs);
      }
      if (cpuProcs.isNotEmpty || memProcs.isNotEmpty) {
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _connectWebSocket() async {
    if (client == null) return;
    try {
      final ws = await client!.connectWebSocket(
        limit: _processLimit,
        sort: 'cpu',
        order: 'desc',
      );
      if (_isDisposed) {
        ws.close();
        return;
      }
      _ws = ws;
      _isConnectedToServer = true;
      _restPollTimer?.cancel();
      notifyListeners();

      _wsSub = _ws!.listen(
        (data) {
          if (_isDisposed || !_isLive) return;
          try {
            final json = jsonDecode(data.toString()) as Map<String, dynamic>;
            _handleServerSnapshot(json);
          } catch (_) {}
        },
        onError: (err) {
          if (!_isDisposed) _reconnectOrFallback();
        },
        onDone: () {
          if (!_isDisposed) _reconnectOrFallback();
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (!_isDisposed) _reconnectOrFallback();
    }
  }

  void _reconnectOrFallback() {
    if (_isDisposed) return;
    _isConnectedToServer = false;
    _wsSub?.cancel();
    _ws = null;
    _startRestPollingTicker();
  }

  void _startPeriodicPollers() {
    if (_isDisposed || client == null) return;

    _dockerPollTimer?.cancel();
    _dockerPollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_isDisposed || !_isLive || client == null) return;
      await fetchDockerData();
    });

    _processPollTimer?.cancel();
    _processPollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_isDisposed || !_isLive || client == null || nodes.isEmpty) return;
      if (!_isConnectedToServer ||
          nodes.first.topProcesses.length < _processLimit ||
          nodes.first.topMemoryProcesses.length < _processLimit) {
        await _fetchTopProcesses();
      }
    });
  }

  void _startRestPollingTicker() {
    if (_isDisposed || client == null) return;
    _restPollTimer?.cancel();

    _restPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_isDisposed || !_isLive) return;
      if (_isConnectedToServer) {
        _restPollTimer?.cancel();
        return;
      }
      try {
        final current = await client!.getCurrentMetrics();
        if (!_isDisposed && current.isNotEmpty) {
          _handleServerSnapshot(current);
        }
      } catch (_) {}
    });

    _startPeriodicPollers();

    Timer(const Duration(seconds: 8), () {
      if (!_isDisposed && !_isConnectedToServer) {
        _connectWebSocket();
      }
    });
  }

  void _handleServerSnapshot(Map<String, dynamic> json) {
    _isLoaded = true;
    DateTime now = DateTime.now();
    final rawTs = json['timestamp'] as String?;
    if (rawTs != null && rawTs.isNotEmpty) {
      try {
        now = DateTime.parse(rawTs).toLocal();
      } catch (_) {}
    }
    final primaryNode = nodes.first;

    // Apply host_info if provided in snapshot
    final hostInfo = json['host_info'];
    if (hostInfo is Map<String, dynamic>) {
      _applyHostInfo(hostInfo);
    }

    final cpu = (json['cpu_percent'] as num?)?.toDouble() ?? primaryNode.value(MetricKey.cpu);
    final memPercent = (json['mem_used_percent'] as num?)?.toDouble() ?? primaryNode.value(MetricKey.memory);
    final swapPercent = (json['swap_percent'] as num?)?.toDouble() ?? primaryNode.value(MetricKey.swap);
    final uploadBytesSec = (json['net_upload_rate'] as num?)?.toDouble() ?? 0.0;
    final downloadBytesSec = (json['net_download_rate'] as num?)?.toDouble() ?? 0.0;

    primaryNode.netUploadRate = uploadBytesSec;
    primaryNode.netDownloadRate = downloadBytesSec;

    // Update RAM & Swap in exact GB (from raw bytes if provided)
    final memTotalFormatted = json['mem_total_formatted'] as String?;
    final memUsedFormatted = json['mem_used_formatted'] as String?;
    if (memTotalFormatted != null && memTotalFormatted.isNotEmpty) {
      primaryNode.ramTotalFormatted = memTotalFormatted;
    }
    if (memUsedFormatted != null && memUsedFormatted.isNotEmpty) {
      primaryNode.ramUsedFormatted = memUsedFormatted;
    }

    final memTotalBytes = (json['mem_total'] as num?)?.toDouble();
    if (memTotalBytes != null && memTotalBytes > 0) {
      primaryNode.ramTotalGb = memTotalBytes > 1024 * 1024
          ? memTotalBytes / (1024 * 1024 * 1024)
          : memTotalBytes;
    }
    final memUsedBytes = (json['mem_used'] as num?)?.toDouble();
    if (memUsedBytes != null && memUsedBytes > 0) {
      primaryNode.ramUsedGb = memUsedBytes > 1024 * 1024
          ? memUsedBytes / (1024 * 1024 * 1024)
          : memUsedBytes;
    }
    final memFreeBytes = (json['mem_free'] as num?)?.toDouble();
    if (memFreeBytes != null && memFreeBytes >= 0) {
      primaryNode.ramFreeGb = memFreeBytes / (1024 * 1024 * 1024);
    }
    final memAvailableBytes = (json['mem_available'] as num?)?.toDouble();
    if (memAvailableBytes != null && memAvailableBytes >= 0) {
      primaryNode.ramAvailableGb = memAvailableBytes / (1024 * 1024 * 1024);
    }
    final memBuffCacheBytes = (json['mem_buff_cache'] as num?)?.toDouble();
    if (memBuffCacheBytes != null && memBuffCacheBytes >= 0) {
      primaryNode.ramBuffCacheGb = memBuffCacheBytes / (1024 * 1024 * 1024);
    }

    final swapTotalBytes = (json['swap_total'] as num?)?.toDouble();
    if (swapTotalBytes != null && swapTotalBytes > 0) {
      primaryNode.swapTotalGb = swapTotalBytes > 1024 * 1024
          ? swapTotalBytes / (1024 * 1024 * 1024)
          : swapTotalBytes;
    }
    final swapUsedBytes = (json['swap_used'] as num?)?.toDouble();
    if (swapUsedBytes != null && swapUsedBytes > 0) {
      primaryNode.swapUsedGb = swapUsedBytes > 1024 * 1024
          ? swapUsedBytes / (1024 * 1024 * 1024)
          : swapUsedBytes;
    }

    // Convert B/s to Mbps
    final netRxMbps = downloadBytesSec * 8 / (1024 * 1024);
    final netTxMbps = uploadBytesSec * 8 / (1024 * 1024);

    // Update current snapshot map
    final dockerCpu = primaryNode.totalDockerCpuPercent;
    final dockerMem = primaryNode.totalDockerMemPercent;
    primaryNode.current[MetricKey.cpu] = cpu;
    primaryNode.current[MetricKey.cpuTemp] = 40.0 + cpu * 0.45;
    primaryNode.current[MetricKey.memory] = memPercent;
    primaryNode.current[MetricKey.swap] = swapPercent;
    primaryNode.current[MetricKey.netRx] = netRxMbps;
    primaryNode.current[MetricKey.netTx] = netTxMbps;
    primaryNode.current[MetricKey.dockerCpu] = dockerCpu;
    primaryNode.current[MetricKey.dockerMem] = dockerMem;

    // Push into rolling live buffers
    void pushLive(MetricKey key, double val) {
      final buf = primaryNode.live[key];
      if (buf != null) {
        if (buf.isEmpty) {
          buf.add(TimedSample(now.subtract(const Duration(seconds: 2)), val));
        }
        buf.add(TimedSample(now, val));
        if (buf.length > TimeRange.live.points) buf.removeAt(0);
      }
    }

    pushLive(MetricKey.cpu, cpu);
    pushLive(MetricKey.cpuTemp, 40.0 + cpu * 0.45);
    pushLive(MetricKey.memory, memPercent);
    pushLive(MetricKey.swap, swapPercent);
    pushLive(MetricKey.netRx, netRxMbps);
    pushLive(MetricKey.netTx, netTxMbps);
    pushLive(MetricKey.dockerCpu, dockerCpu);
    pushLive(MetricKey.dockerMem, dockerMem);

    // Update per-core loads from `cpu_cores_percent` and resize if needed
    final cores = json['cpu_cores_percent'] as List<dynamic>?;
    if (cores != null && cores.isNotEmpty) {
      if (primaryNode.coreLoads.length != cores.length) {
        primaryNode.coreLoads
          ..clear()
          ..addAll(cores.map((c) => (c as num).toDouble()));
        primaryNode.cpuCores = cores.length;
      } else {
        for (var i = 0; i < cores.length; i++) {
          primaryNode.coreLoads[i] = (cores[i] as num).toDouble();
        }
      }
    }

    // Update partitions from `partitions`
    final partitions = json['partitions'] as List<dynamic>?;
    if (partitions != null && partitions.isNotEmpty) {
      primaryNode.mounts.clear();
      for (final p in partitions) {
        final part = DiskPartitionInfo.fromJson(p as Map<String, dynamic>);
        primaryNode.mounts.add(
          DiskMount(
            mountPoint: part.mountPoint,
            device: part.device,
            fileSystem: part.fstype,
            totalGb: part.totalGb,
            usedGb: part.usedGb,
            freeGb: part.freeGb,
            usedPercent: part.usedPercent,
            totalFormatted: part.totalFormatted,
            usedFormatted: part.usedFormatted,
            freeFormatted: part.freeFormatted,
          ),
        );
      }
    }

    // Disk usage percentage & I/O
    final diskPercent = (json['disk_percent'] as num?)?.toDouble() ??
        (json['disk_used_percent'] as num?)?.toDouble() ??
        (primaryNode.diskTotalGb > 0
            ? (primaryNode.diskUsedGb / primaryNode.diskTotalGb * 100)
            : (primaryNode.mounts.isNotEmpty ? primaryNode.mounts.first.percent : 0.0));

    final diskReadBytes = (json['disk_read_rate'] as num?)?.toDouble() ??
        (json['disk_read_bytes_sec'] as num?)?.toDouble() ??
        (json['disk_read'] as num?)?.toDouble() ??
        0.0;
    final diskWriteBytes = (json['disk_write_rate'] as num?)?.toDouble() ??
        (json['disk_write_bytes_sec'] as num?)?.toDouble() ??
        (json['disk_write'] as num?)?.toDouble() ??
        0.0;
    final diskReadMbps = diskReadBytes / (1024 * 1024);
    final diskWriteMbps = diskWriteBytes / (1024 * 1024);

    primaryNode.current[MetricKey.disk] = diskPercent;
    primaryNode.current[MetricKey.diskRead] = diskReadMbps;
    primaryNode.current[MetricKey.diskWrite] = diskWriteMbps;

    pushLive(MetricKey.disk, diskPercent);
    pushLive(MetricKey.diskRead, diskReadMbps);
    pushLive(MetricKey.diskWrite, diskWriteMbps);

    // Update network interfaces from `net_bytes_recv` & `net_bytes_sent`
    final netBytesRecv = (json['net_bytes_recv'] as num?)?.toDouble();
    final netBytesSent = (json['net_bytes_sent'] as num?)?.toDouble();
    if (netBytesRecv != null && netBytesSent != null) {
      primaryNode.netBytesRecv = netBytesRecv;
      primaryNode.netBytesSent = netBytesSent;
      final rxGb = netBytesRecv / (1024 * 1024 * 1024);
      final txGb = netBytesSent / (1024 * 1024 * 1024);
      final hostIp = profile.cleanUrl.split(':').first.replaceAll(RegExp(r'^https?://'), '');
      final isLinux = !primaryNode.osKernel.toLowerCase().contains('windows');
      final ifaceName = isLinux ? 'eth0 / WAN' : 'Ethernet';
      primaryNode.interfaces
        ..clear()
        ..add(
          NetInterface(
            name: ifaceName,
            ipv4: hostIp.isNotEmpty ? hostIp : '10.0.0.1',
            mac: 'Primary Network',
            rxTotalGb: rxGb,
            txTotalGb: txGb,
          ),
        );
    }

    // Update top CPU processes
    final topProc = json['top_processes'] as List<dynamic>?;
    if (topProc != null) {
      final procs = topProc
          .map((e) => SystemProcessItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (procs.length >= primaryNode.topProcesses.length ||
          procs.length >= _processLimit ||
          primaryNode.topProcesses.isEmpty) {
        primaryNode.topProcesses
          ..clear()
          ..addAll(procs);
      } else {
        final procMap = {for (final p in procs) p.pid: p};
        for (var i = 0; i < primaryNode.topProcesses.length; i++) {
          final curr = primaryNode.topProcesses[i];
          if (procMap.containsKey(curr.pid)) {
            primaryNode.topProcesses[i] = procMap[curr.pid]!;
          }
        }
      }
    }

    // Update top memory processes
    final topMemProc = json['top_memory_processes'] as List<dynamic>?;
    if (topMemProc != null) {
      final memProcs = topMemProc
          .map((e) => SystemProcessItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (memProcs.length >= primaryNode.topMemoryProcesses.length ||
          memProcs.length >= _processLimit ||
          primaryNode.topMemoryProcesses.isEmpty) {
        primaryNode.topMemoryProcesses
          ..clear()
          ..addAll(memProcs);
      } else {
        final memMap = {for (final p in memProcs) p.pid: p};
        for (var i = 0; i < primaryNode.topMemoryProcesses.length; i++) {
          final curr = primaryNode.topMemoryProcesses[i];
          if (memMap.containsKey(curr.pid)) {
            primaryNode.topMemoryProcesses[i] = memMap[curr.pid]!;
          }
        }
      }
    }

    notifyListeners();
  }

  @visibleForTesting
  void handleSnapshotForTest(Map<String, dynamic> json) => _handleServerSnapshot(json);

  void _updateDockerLiveBuffers(ServerNode node) {
    final now = DateTime.now();
    final cpuVal = node.totalDockerCpuPercent;
    final memVal = node.totalDockerMemPercent;

    node.current[MetricKey.dockerCpu] = cpuVal;
    node.current[MetricKey.dockerMem] = memVal;

    void pushDocker(MetricKey key, double val) {
      final buf = node.live[key] ??= [];
      if (buf.isEmpty) {
        buf.add(TimedSample(now.subtract(const Duration(seconds: 2)), val));
      }
      buf.add(TimedSample(now, val));
      if (buf.length > TimeRange.live.points) buf.removeAt(0);
    }

    pushDocker(MetricKey.dockerCpu, cpuVal);
    pushDocker(MetricKey.dockerMem, memVal);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _localTimer?.cancel();
    _restPollTimer?.cancel();
    _dockerPollTimer?.cancel();
    _wsSub?.cancel();
    _ws?.close();
    super.dispose();
  }
}

/// Connector adapter handling real HTTP authentication against SysDashServer.
class SshConnector {
  const SshConnector();

  Future<LoginResult?> authenticate(ServerProfile profile) async {
    final client = SysDashApiClient(rawUrl: profile.serverUrl);
    try {
      final result = await client.login(
        username: profile.username,
        password: profile.password,
      );
      return result;
    } finally {
      client.dispose();
    }
  }

  Future<bool> connect(ServerProfile profile) async {
    try {
      final res = await authenticate(profile);
      return res != null;
    } catch (_) {
      return false;
    }
  }
}
