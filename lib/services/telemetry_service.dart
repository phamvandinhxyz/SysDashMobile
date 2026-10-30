import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/server_models.dart';
import 'api_client.dart';

/// Telemetry service connected to SysDashServer (Golang backend) via WebSocket
/// (`/api/v1/ws/metrics?token=...`) and REST API (`/api/v1/metrics/...`),
/// with automatic polling and smooth offline fallback.
class TelemetryService extends ChangeNotifier {
  final ServerProfile profile;
  final SysDashApiClient? client;
  final List<ServerNode> nodes;
  final math.Random _rng = math.Random();
  final Map<String, List<TimedSample>> _historyCache = {};

  Timer? _localTimer;
  Timer? _restPollTimer;
  Timer? _dockerPollTimer;
  WebSocket? _ws;
  StreamSubscription? _wsSub;
  bool _isLive = true;
  bool _isConnectedToServer = false;
  bool _isDisposed = false;

  bool get isLive => _isLive;
  bool get isConnectedToServer => _isConnectedToServer;

  TelemetryService({
    required this.profile,
    this.client,
  }) : nodes = _MockFleet.build(profile) {
    for (final node in nodes) {
      _seedLiveBuffers(node);
    }
    _initConnection();
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

    // Generate immediate fallback and trigger background server fetch
    final fallback = _generateHistory(node, key, range);
    _historyCache[cacheKey] = fallback;

    if (client != null && node.id == nodes.first.id) {
      _fetchServerHistory(node, key, range, cacheKey);
    }

    return fallback;
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
    if (client != null && profile.token.isNotEmpty) {
      _fetchInitialServerData();
      _connectWebSocket();
    } else {
      _startLocalTicker();
    }
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

      // 3. Fetch Docker containers
      try {
        final containers = await client!.getDockerContainers();
        if (!_isDisposed) {
          nodes[0].containers
            ..clear()
            ..addAll(containers);
        }
      } catch (_) {}

      // 4. Fetch Docker images
      try {
        final images = await client!.getDockerImages();
        if (!_isDisposed) {
          nodes[0].dockerImages
            ..clear()
            ..addAll(images);
        }
      } catch (_) {}

      if (!_isDisposed) notifyListeners();
    } catch (_) {}
  }

  Future<void> _connectWebSocket() async {
    try {
      final ws = await client!.connectWebSocket();
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

  void _startRestPollingTicker() {
    if (_isDisposed) return;
    if (client == null) {
      _startLocalTicker();
      return;
    }
    _localTimer?.cancel();
    _restPollTimer?.cancel();
    _dockerPollTimer?.cancel();

    // 1. Poll metrics every 2 seconds via REST
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

    // 2. Poll Docker every 10 seconds
    _dockerPollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_isDisposed || !_isLive) return;
      try {
        final containers = await client!.getDockerContainers();
        final images = await client!.getDockerImages();
        if (!_isDisposed) {
          nodes[0].containers
            ..clear()
            ..addAll(containers);
          nodes[0].dockerImages
            ..clear()
            ..addAll(images);
          notifyListeners();
        }
      } catch (_) {}
    });

    // 3. Retry WebSocket connection after 8 seconds
    Timer(const Duration(seconds: 8), () {
      if (!_isDisposed && !_isConnectedToServer) {
        _connectWebSocket();
      }
    });
  }

  void _handleServerSnapshot(Map<String, dynamic> json) {
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
    primaryNode.current[MetricKey.cpu] = cpu;
    primaryNode.current[MetricKey.cpuTemp] = 40.0 + cpu * 0.45;
    primaryNode.current[MetricKey.memory] = memPercent;
    primaryNode.current[MetricKey.swap] = swapPercent;
    primaryNode.current[MetricKey.netRx] = netRxMbps;
    primaryNode.current[MetricKey.netTx] = netTxMbps;

    // Push into rolling live buffers
    void pushLive(MetricKey key, double val) {
      final buf = primaryNode.live[key];
      if (buf != null) {
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

    // Update top processes
    final topProc = json['top_processes'] as List<dynamic>?;
    if (topProc != null) {
      final procs = topProc
          .map((e) => SystemProcessItem.fromJson(e as Map<String, dynamic>))
          .toList();
      primaryNode.topProcesses
        ..clear()
        ..addAll(procs);
    }

    notifyListeners();
  }

  @visibleForTesting
  void handleSnapshotForTest(Map<String, dynamic> json) => _handleServerSnapshot(json);

  void _startLocalTicker() {
    if (_isDisposed) return;
    _localTimer?.cancel();
    _localTimer = Timer.periodic(TimeRange.live.step, (_) => _tickLocal());
  }

  void _tickLocal() {
    if (!_isLive) return;
    final now = DateTime.now();
    for (final node in nodes) {
      for (final key in MetricKey.values) {
        final next = _step(node.value(key), node.baseline[key] ?? 30.0, MetricSpec.of(key));
        node.current[key] = next;
        final buffer = node.live[key]!..add(TimedSample(now, next));
        if (buffer.length > TimeRange.live.points) buffer.removeAt(0);
      }

      final cpu = node.value(MetricKey.cpu);
      for (var i = 0; i < node.coreLoads.length; i++) {
        final target = cpu + (_rng.nextDouble() * 2 - 1) * 18;
        node.coreLoads[i] = (node.coreLoads[i] * 0.4 + target * 0.6).clamp(0, 100);
      }

      for (final c in node.containers.where((c) => c.isRunning)) {
        c.cpuPercent = (c.cpuPercent + (_rng.nextDouble() * 2 - 1) * 1.5).clamp(0.1, 95);
        c.memMb = (c.memMb + (_rng.nextDouble() * 2 - 1) * c.memLimitMb * 0.004)
            .clamp(4, c.memLimitMb);
      }
    }
    notifyListeners();
  }

  void _seedLiveBuffers(ServerNode node) {
    final now = DateTime.now();
    const r = TimeRange.live;
    for (final key in MetricKey.values) {
      final spec = MetricSpec.of(key);
      var v = node.baseline[key] ?? 30.0;
      node.live[key] = List.generate(r.points, (i) {
        v = _step(v, node.baseline[key] ?? 30.0, spec);
        return TimedSample(now.subtract(r.step * (r.points - 1 - i)), v);
      });
      node.current[key] = v;
    }
  }

  double _step(double v, double baseline, MetricSpec spec) {
    final noise = (_rng.nextDouble() * 2 - 1) * spec.volatility;
    final spike = spec.spiky && _rng.nextDouble() < 0.05
        ? spec.volatility * (3 + _rng.nextDouble() * 4)
        : 0.0;
    final reverted = v + (baseline - v) * 0.12 + noise + spike;
    return reverted.clamp(spec.min, spec.max).toDouble();
  }

  List<TimedSample> _generateHistory(ServerNode node, MetricKey key, TimeRange range) {
    final spec = MetricSpec.of(key);
    final rng = math.Random(Object.hash(node.id, key.index, range.index));
    final now = DateTime.now();
    final base = node.baseline[key] ?? 30.0;
    var walk = 0.0;

    return List.generate(range.points, (i) {
      final t = now.subtract(range.step * (range.points - 1 - i));
      final hour = t.hour + t.minute / 60.0;
      final daily = math.sin((hour - 8) / 24 * 2 * math.pi);
      walk = walk * 0.8 + (rng.nextDouble() * 2 - 1) * spec.volatility;

      double v;
      if (key == MetricKey.disk) {
        final progress = i / (range.points - 1);
        final growth = switch (range) {
          TimeRange.day30 => 6.0,
          TimeRange.week1 => 1.8,
          _ => 0.3,
        };
        v = base - growth * (1 - progress) + walk;
      } else {
        v = base + daily * spec.dailyAmplitude + walk;
        if (spec.spiky && rng.nextDouble() < 0.04) {
          v += spec.volatility * (3 + rng.nextDouble() * 5);
        }
      }
      return TimedSample(t, v.clamp(spec.min, spec.max).toDouble());
    });
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

class _MockFleet {
  static List<ServerNode> build(ServerProfile profile) => [
        ServerNode(
          id: 'node-${profile.id}',
          name: profile.displayName,
          sshAddress: profile.cleanUrl,
          osKernel: 'Microsoft Windows 11 Pro • 25H2',
          cpuModel: 'Intel(R) Core(TM) i7-14700K',
          cpuCores: 28,
          cpuPhysicalCores: 20,
          cpuLogicalCores: 28,
          cpuMhz: 3400.0,
          cpuSpeedGhz: 3.4,
          ramTotalGb: 32,
          swapTotalGb: 4,
          sshPingMs: 6,
          uptime: const Duration(days: 42, hours: 18, minutes: 12),
          baseline: const {
            MetricKey.cpu: 18,
            MetricKey.cpuTemp: 52,
            MetricKey.memory: 75,
            MetricKey.swap: 25,
            MetricKey.disk: 55,
            MetricKey.diskRead: 48,
            MetricKey.diskWrite: 32,
            MetricKey.netRx: 125,
            MetricKey.netTx: 84,
            MetricKey.dockerCpu: 24,
            MetricKey.dockerMem: 38,
          },
          mounts: [
            DiskMount(mountPoint: 'C:', device: 'C:', fileSystem: 'NTFS', totalGb: 512, usedGb: 285),
            DiskMount(mountPoint: 'E:', device: 'E:', fileSystem: 'NTFS', totalGb: 1024, usedGb: 420),
          ],
          interfaces: [
            NetInterface(name: 'Ethernet', ipv4: '192.168.1.100', mac: '52:54:00:a3:1f:09', rxTotalGb: 1824.6, txTotalGb: 942.1),
          ],
          containers: [
            ContainerInfo(name: 'sysdash-server', image: 'sysdash-server', tag: 'latest', imageId: 'sha256:9f4a81c2', imageSize: '34.2 MB', isRunning: true, ports: '8080/tcp', uptime: '12d', memLimitMb: 512, cpuPercent: 0.8, memMb: 28),
            ContainerInfo(name: 'nginx-proxy', image: 'nginx', tag: 'alpine', imageId: 'sha256:4c1b30e9', imageSize: '23.6 MB', isRunning: true, ports: '80, 443', uptime: '12d', memLimitMb: 256, cpuPercent: 3.2, memMb: 42),
            ContainerInfo(name: 'postgres-db', image: 'postgres', tag: '16-alpine', imageId: 'sha256:7d2e19a0', imageSize: '185.4 MB', isRunning: true, ports: '5432', uptime: '30d', memLimitMb: 4096, cpuPercent: 12.4, memMb: 1240),
          ],
        ),
      ];
}
