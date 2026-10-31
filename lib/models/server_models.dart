import 'dart:convert';

/// Authenticated user information returned by SysDashServer `/auth/login` and `/auth/me`.
class UserInfo {
  final int id;
  final String username;
  final String fullName;
  final String role; // 'admin' | 'viewer'

  const UserInfo({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
        id: (json['id'] as num?)?.toInt() ?? 0,
        username: (json['username'] as String?) ?? '',
        fullName: (json['full_name'] as String?) ?? '',
        role: (json['role'] as String?) ?? 'viewer',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'full_name': fullName,
        'role': role,
      };
}

/// Server connection profile for SysDashServer (Golang API + WebSocket).
/// Persisted only through the encrypted [SecureCredentialStore].
class ServerProfile {
  final String id;
  final String alias;
  final String serverUrl;
  final String username;
  final String password;
  final String token;
  final String role;
  final String fullName;

  const ServerProfile({
    required this.id,
    required this.alias,
    required this.serverUrl,
    required this.username,
    required this.password,
    this.token = '',
    this.role = 'viewer',
    this.fullName = '',
  });

  String get displayName => alias.trim().isEmpty ? cleanUrl : alias.trim();
  String get cleanUrl => serverUrl
      .replaceAll('http://', '')
      .replaceAll('https://', '')
      .replaceAll('/api/v1', '')
      .replaceAll(RegExp(r'/+$'), '');

  ServerProfile copyWith({
    String? alias,
    String? serverUrl,
    String? username,
    String? password,
    String? token,
    String? role,
    String? fullName,
  }) {
    return ServerProfile(
      id: id,
      alias: alias ?? this.alias,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      token: token ?? this.token,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'alias': alias,
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
        'token': token,
        'role': role,
        'fullName': fullName,
      };

  factory ServerProfile.fromJson(Map<String, dynamic> json) => ServerProfile(
        id: json['id'] as String,
        alias: (json['alias'] as String?) ?? '',
        serverUrl: (json['serverUrl'] as String?) ??
            (json['host'] != null
                ? 'http://${json['host']}:${json['port'] ?? 8080}'
                : 'http://10.0.2.2:8080'),
        username: (json['username'] as String?) ?? 'admin',
        password: (json['password'] as String?) ?? '',
        token: (json['token'] as String?) ?? '',
        role: (json['role'] as String?) ?? 'viewer',
        fullName: (json['fullName'] as String?) ?? '',
      );

  String encode() => jsonEncode(toJson());
}

// Backward compatibility alias for SshProfile.
typedef SshProfile = ServerProfile;

/// Time ranges matching SysDashServer `/metrics/history?range=...` parameters.
enum TimeRange {
  live(apiParam: 'live', points: 45, step: Duration(seconds: 2)),
  hour1(apiParam: '1h', points: 60, step: Duration(minutes: 1)),
  hour12(apiParam: '12h', points: 72, step: Duration(minutes: 10)),
  hour24(apiParam: '24h', points: 96, step: Duration(minutes: 15)),
  week1(apiParam: '7d', points: 84, step: Duration(hours: 2)),
  day30(apiParam: '30d', points: 90, step: Duration(hours: 8));

  const TimeRange({
    required this.apiParam,
    required this.points,
    required this.step,
  });

  final String apiParam;
  final int points;
  final Duration step;
}

/// A single timestamped value.
class TimedSample {
  final DateTime time;
  final double value;
  const TimedSample(this.time, this.value);
}

/// Metric keys displayed in charts.
enum MetricKey {
  cpu,
  cpuTemp,
  memory,
  swap,
  disk,
  diskRead,
  diskWrite,
  netRx,
  netTx,
  dockerCpu,
  dockerMem,
}

/// Metric specifications for bounds.
class MetricSpec {
  final double min;
  final double max;
  final double volatility;
  final double dailyAmplitude;
  final bool spiky;

  const MetricSpec({
    required this.min,
    required this.max,
    required this.volatility,
    this.dailyAmplitude = 0,
    this.spiky = false,
  });

  static MetricSpec of(MetricKey key) => switch (key) {
        MetricKey.cpu => const MetricSpec(min: 1, max: 100, volatility: 6, dailyAmplitude: 12),
        MetricKey.cpuTemp => const MetricSpec(min: 30, max: 95, volatility: 1.6, dailyAmplitude: 6),
        MetricKey.memory => const MetricSpec(min: 5, max: 99, volatility: 1.2, dailyAmplitude: 5),
        MetricKey.swap => const MetricSpec(min: 0, max: 100, volatility: 0.6, dailyAmplitude: 2),
        MetricKey.disk => const MetricSpec(min: 1, max: 99, volatility: 0.05),
        MetricKey.diskRead => const MetricSpec(min: 0, max: 900, volatility: 22, dailyAmplitude: 18, spiky: true),
        MetricKey.diskWrite => const MetricSpec(min: 0, max: 900, volatility: 16, dailyAmplitude: 14, spiky: true),
        MetricKey.netRx => const MetricSpec(min: 0, max: 1000, volatility: 28, dailyAmplitude: 60, spiky: true),
        MetricKey.netTx => const MetricSpec(min: 0, max: 1000, volatility: 20, dailyAmplitude: 40, spiky: true),
        MetricKey.dockerCpu => const MetricSpec(min: 0, max: 100, volatility: 4, dailyAmplitude: 8),
        MetricKey.dockerMem => const MetricSpec(min: 0, max: 100, volatility: 0.8, dailyAmplitude: 3),
      };
}

/// Top system process item from `/metrics/current` or `/system/processes`.
class SystemProcessItem {
  final int pid;
  final String name;
  final double cpuPercent;
  final double memoryPercent;
  final int memoryRss;
  final String status;

  const SystemProcessItem({
    required this.pid,
    required this.name,
    required this.cpuPercent,
    required this.memoryPercent,
    required this.memoryRss,
    required this.status,
  });

  factory SystemProcessItem.fromJson(Map<String, dynamic> json) => SystemProcessItem(
        pid: (json['pid'] as num?)?.toInt() ?? 0,
        name: (json['name'] as String?) ?? 'unknown',
        cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 0.0,
        memoryPercent: (json['memory_percent'] as num?)?.toDouble() ?? 0.0,
        memoryRss: (json['memory_rss'] as num?)?.toInt() ?? 0,
        status: (json['status'] as String?) ?? 'running',
      );
}

/// Host system information from SysDash `/metrics/current` or `/system/info`.
class HostInfo {
  final String hostname;
  final String os;
  final String platform;
  final String platformFamily;
  final String platformVersion;
  final String kernelVersion;
  final String kernelArch;
  final int uptime;
  final int bootTime;
  final String cpuModel;
  final int cpuPhysicalCores;
  final int cpuLogicalCores;
  final int cpuCores;
  final double cpuMhz;
  final double cpuSpeedGhz;

  const HostInfo({
    required this.hostname,
    required this.os,
    required this.platform,
    required this.platformFamily,
    required this.platformVersion,
    required this.kernelVersion,
    required this.kernelArch,
    required this.uptime,
    required this.bootTime,
    required this.cpuModel,
    required this.cpuPhysicalCores,
    required this.cpuLogicalCores,
    required this.cpuCores,
    required this.cpuMhz,
    required this.cpuSpeedGhz,
  });

  String get prettyOs {
    var p = platform.isNotEmpty ? platform : os;
    if (p.toLowerCase() == 'ubuntu') p = 'Ubuntu';
    if (p.toLowerCase() == 'debian') p = 'Debian';
    if (p.toLowerCase() == 'centos') p = 'CentOS';
    if (p.toLowerCase() == 'fedora') p = 'Fedora';
    if (p.toLowerCase() == 'arch') p = 'Arch Linux';

    if (platformVersion.isNotEmpty && !p.contains(platformVersion)) {
      p = '$p $platformVersion';
    }
    if (kernelVersion.isNotEmpty) {
      final shortKernel = kernelVersion.length > 22 && kernelVersion.contains('Build')
          ? kernelVersion.split(' ').first
          : kernelVersion;
      p = '$p ($shortKernel)';
    }
    return p;
  }

  factory HostInfo.fromJson(Map<String, dynamic> json) => HostInfo(
        hostname: (json['hostname'] as String?) ?? '',
        os: (json['os'] as String?) ?? '',
        platform: (json['platform'] as String?) ?? '',
        platformFamily: (json['platform_family'] as String?) ?? '',
        platformVersion: (json['platform_version'] as String?) ?? '',
        kernelVersion: (json['kernel_version'] as String?) ?? '',
        kernelArch: (json['kernel_arch'] as String?) ?? '',
        uptime: (json['uptime'] as num?)?.toInt() ?? 0,
        bootTime: (json['boot_time'] as num?)?.toInt() ?? 0,
        cpuModel: (json['cpu_model'] as String?) ?? '',
        cpuPhysicalCores: (json['cpu_physical_cores'] as num?)?.toInt() ??
            (json['cpu_cores'] as num?)?.toInt() ?? 0,
        cpuLogicalCores: (json['cpu_logical_cores'] as num?)?.toInt() ??
            (json['cpu_cores'] as num?)?.toInt() ?? 0,
        cpuCores: (json['cpu_cores'] as num?)?.toInt() ?? 0,
        cpuMhz: (json['cpu_mhz'] as num?)?.toDouble() ?? 0.0,
        cpuSpeedGhz: (json['cpu_speed_ghz'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Partition from `/metrics/current`.
class DiskPartitionInfo {
  final String device;
  final String mountPoint;
  final String fstype;
  final double totalBytes;
  final double usedBytes;
  final double freeBytes;
  final double usedPercent;
  final String totalFormatted;
  final String usedFormatted;
  final String freeFormatted;

  const DiskPartitionInfo({
    required this.device,
    required this.mountPoint,
    required this.fstype,
    required this.totalBytes,
    required this.usedBytes,
    required this.freeBytes,
    required this.usedPercent,
    this.totalFormatted = '',
    this.usedFormatted = '',
    this.freeFormatted = '',
  });

  double get totalGb => totalBytes / (1024 * 1024 * 1024);
  double get usedGb => usedBytes / (1024 * 1024 * 1024);
  double get freeGb => freeBytes / (1024 * 1024 * 1024);

  factory DiskPartitionInfo.fromJson(Map<String, dynamic> json) {
    final rawTotal = (json['total'] as num?)?.toDouble() ??
        (json['total_bytes'] as num?)?.toDouble() ??
        0.0;
    final rawUsed = (json['used'] as num?)?.toDouble() ??
        (json['used_bytes'] as num?)?.toDouble() ??
        0.0;
    final rawFree = (json['free'] as num?)?.toDouble() ??
        (json['free_bytes'] as num?)?.toDouble() ??
        0.0;

    // Detect if already in GB (< 100,000) or in bytes (>= 1MB)
    final totalBytes = rawTotal > 1024 * 1024 ? rawTotal : rawTotal * 1024 * 1024 * 1024;
    final usedBytes = rawUsed > 1024 * 1024 ? rawUsed : rawUsed * 1024 * 1024 * 1024;
    final freeBytes = rawFree > 1024 * 1024 ? rawFree : rawFree * 1024 * 1024 * 1024;

    return DiskPartitionInfo(
      device: (json['device'] as String?) ?? '',
      mountPoint: (json['mountpoint'] as String?) ??
          (json['mount_point'] as String?) ??
          '/',
      fstype: (json['fstype'] as String?) ??
          (json['fs_type'] as String?) ??
          'ext4',
      totalBytes: totalBytes,
      usedBytes: usedBytes,
      freeBytes: freeBytes,
      usedPercent: (json['used_percent'] as num?)?.toDouble() ?? 0.0,
      totalFormatted: (json['total_formatted'] as String?) ?? '',
      usedFormatted: (json['used_formatted'] as String?) ?? '',
      freeFormatted: (json['free_formatted'] as String?) ?? '',
    );
  }
}

/// Docker Image item from `/docker/images`.
class DockerImageItem {
  final String id;
  final List<String> repoTags;
  final int sizeBytes;
  final String sizeFormatted;
  final int createdTimestamp;
  final int containersCount;
  final int runningContainersCount;
  final int memUsageBytes;
  final String memFormatted;

  const DockerImageItem({
    required this.id,
    required this.repoTags,
    required this.sizeBytes,
    this.sizeFormatted = '',
    required this.createdTimestamp,
    required this.containersCount,
    this.runningContainersCount = 0,
    this.memUsageBytes = 0,
    this.memFormatted = '',
  });

  String get primaryTag {
    for (final tag in repoTags) {
      if (tag.isNotEmpty && tag != '<none>:<none>') return tag;
    }
    return id.length > 12 ? id.substring(0, 12) : (id.isNotEmpty ? id : 'image');
  }

  // docker images uses SI base 1000 (MB / GB)
  double get sizeMb => sizeBytes / (1000 * 1000);
  double get sizeGb => sizeBytes / (1000 * 1000 * 1000);
  String get formattedSize => sizeFormatted.isNotEmpty
      ? sizeFormatted
      : (sizeGb >= 1.0 ? '${sizeGb.toStringAsFixed(2)} GB' : '${sizeMb.toStringAsFixed(1)} MB');

  // docker stats and mem usage uses binary base 1024 (MiB / GiB)
  double get memMb => memUsageBytes / (1024 * 1024);
  String get formattedMem => memFormatted.isNotEmpty
      ? memFormatted
      : (memMb > 0 ? '${memMb.toStringAsFixed(1)} MB' : '0 MB');

  factory DockerImageItem.fromJson(Map<String, dynamic> json) => DockerImageItem(
        id: (json['id'] as String?) ?? '',
        repoTags: (json['repo_tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
        sizeFormatted: (json['size_formatted'] as String?) ?? '',
        createdTimestamp: (json['created'] as num?)?.toInt() ?? 0,
        containersCount: (json['containers'] as num?)?.toInt() ?? 0,
        runningContainersCount: (json['running_containers'] as num?)?.toInt() ?? 0,
        memUsageBytes: (json['mem_usage'] as num?)?.toInt() ?? 0,
        memFormatted: (json['mem_formatted'] as String?) ?? '',
      );
}

/// System diagnostics info from `GET /system/diagnostics` (Admin only).
class SystemDiagnostics {
  final bool runningInDocker;
  final String hostRoot;
  final String hostMountinfoReadable;
  final Map<String, int> meminfoRawBytes;
  final MemoryComputed memoryComputed;
  final List<PartitionScanItem> partitionsScan;

  const SystemDiagnostics({
    required this.runningInDocker,
    required this.hostRoot,
    required this.hostMountinfoReadable,
    required this.meminfoRawBytes,
    required this.memoryComputed,
    required this.partitionsScan,
  });

  factory SystemDiagnostics.fromJson(Map<String, dynamic> json) {
    final memRaw = (json['meminfo_raw_bytes'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ) ??
        {};
    final memComp = MemoryComputed.fromJson(
      (json['memory_computed'] as Map<String, dynamic>?) ?? {},
    );
    final partScan = ((json['partitions_scan'] as List<dynamic>?) ?? [])
        .map((e) => PartitionScanItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return SystemDiagnostics(
      runningInDocker: (json['running_in_docker'] as bool?) ?? false,
      hostRoot: (json['host_root'] as String?) ?? '/',
      hostMountinfoReadable: (json['host_mountinfo_readable'] as String?) ?? 'no',
      meminfoRawBytes: memRaw,
      memoryComputed: memComp,
      partitionsScan: partScan,
    );
  }
}

class MemoryComputed {
  final int total;
  final int usedLikeFreeHtop;
  final String usedFormatted;
  final String totalFormatted;

  const MemoryComputed({
    required this.total,
    required this.usedLikeFreeHtop,
    required this.usedFormatted,
    required this.totalFormatted,
  });

  factory MemoryComputed.fromJson(Map<String, dynamic> json) => MemoryComputed(
        total: (json['total'] as num?)?.toInt() ?? 0,
        usedLikeFreeHtop: (json['used_like_free_htop'] as num?)?.toInt() ?? 0,
        usedFormatted: (json['used_formatted'] as String?) ?? '',
        totalFormatted: (json['total_formatted'] as String?) ?? '',
      );
}

class PartitionScanItem {
  final String device;
  final String mountpoint;
  final String statPath;
  final String display;
  final String decision;

  const PartitionScanItem({
    required this.device,
    required this.mountpoint,
    required this.statPath,
    required this.display,
    required this.decision,
  });

  bool get isAccepted => decision.toLowerCase().startsWith('accept');

  factory PartitionScanItem.fromJson(Map<String, dynamic> json) => PartitionScanItem(
        device: (json['device'] as String?) ?? '',
        mountpoint: (json['mountpoint'] as String?) ?? '',
        statPath: (json['stat_path'] as String?) ?? '',
        display: (json['display'] as String?) ?? '',
        decision: (json['decision'] as String?) ?? '',
      );
}

/// Docker Container item from `/docker/containers`.
class ContainerInfo {
  final String id;
  final String name;
  final String image;
  final String tag;
  final String imageId;
  final String imageSize;
  final bool isRunning;
  final String ports;
  final String uptime;
  final double memLimitMb;
  double cpuPercent;
  double memMb;
  final double memPercent;
  final String memUsageFormatted;

  ContainerInfo({
    required this.name,
    required this.image,
    required this.tag,
    required this.imageId,
    required this.imageSize,
    required this.isRunning,
    required this.ports,
    required this.uptime,
    required this.memLimitMb,
    required this.cpuPercent,
    required this.memMb,
    this.memPercent = 0.0,
    this.memUsageFormatted = '',
    this.id = '',
  });

  factory ContainerInfo.fromSysDashJson(Map<String, dynamic> json) {
    final names = (json['names'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final rawName = names.isNotEmpty ? names.first.replaceAll(RegExp(r'^/'), '') : 'container';
    final rawImage = (json['image'] as String?) ?? 'image';
    final parts = rawImage.split(':');
    final imgName = parts.first;
    final imgTag = parts.length > 1 ? parts[1] : 'latest';
    final state = (json['state'] as String?) ?? 'stopped';
    final isRun = state.toLowerCase() == 'running';
    final id = (json['id'] as String?) ?? '';
    final shortId = id.length > 12 ? id.substring(0, 12) : id;
    final imageId = (json['image_id'] as String?) ?? '';
    final shortImgId = imageId.startsWith('sha256:') && imageId.length > 19
        ? imageId.substring(7, 19)
        : (imageId.length > 12 ? imageId.substring(0, 12) : imageId);

    // RAM usage & limit in MB from response format
    final directMemMb = (json['mem_mb'] as num?)?.toDouble();
    final memUsageBytes = (json['mem_usage'] as num?)?.toDouble() ??
        (json['memory_usage'] as num?)?.toDouble() ??
        (json['mem_bytes'] as num?)?.toDouble() ??
        0.0;
    final memMb = directMemMb ?? (memUsageBytes > 0 ? (memUsageBytes / (1024 * 1024)) : 0.0);

    final directMemLimitMb = (json['mem_limit_mb'] as num?)?.toDouble();
    final memLimitBytes = (json['mem_limit'] as num?)?.toDouble() ??
        (json['memory_limit'] as num?)?.toDouble() ??
        0.0;
    final memLimitMb = directMemLimitMb ?? (memLimitBytes > 0 ? (memLimitBytes / (1024 * 1024)) : 0.0);

    final directMemPercent = (json['mem_percent'] as num?)?.toDouble() ??
        (json['memory_percent'] as num?)?.toDouble();
    final memPercent = directMemPercent ??
        (memLimitMb > 0 ? (memMb / memLimitMb * 100).clamp(0.0, 100.0) : 0.0);

    final cpuPercent = (json['cpu_percent'] as num?)?.toDouble() ??
        (json['cpu_usage'] as num?)?.toDouble() ??
        0.0;

    final memFormatted = (json['mem_usage_formatted'] as String?) ??
        (json['mem_formatted'] as String?) ??
        (json['memory_formatted'] as String?) ??
        '';

    return ContainerInfo(
      id: id,
      name: rawName,
      image: imgName,
      tag: imgTag,
      imageId: shortImgId.isNotEmpty ? shortImgId : shortId,
      imageSize: memFormatted,
      isRunning: isRun,
      ports: (json['command'] as String?) ?? '—',
      uptime: (json['status'] as String?) ?? state,
      memLimitMb: memLimitMb,
      cpuPercent: cpuPercent,
      memMb: memMb,
      memPercent: memPercent,
      memUsageFormatted: memFormatted,
    );
  }
}

/// Disk mount representation for UI.
class DiskMount {
  final String mountPoint;
  final String device;
  final String fileSystem;
  final double totalGb;
  double usedGb;
  double freeGb;
  final double? usedPercent;
  String totalFormatted;
  String usedFormatted;
  String freeFormatted;

  DiskMount({
    required this.mountPoint,
    required this.device,
    required this.fileSystem,
    required this.totalGb,
    required this.usedGb,
    this.freeGb = 0.0,
    this.usedPercent,
    this.totalFormatted = '',
    this.usedFormatted = '',
    this.freeFormatted = '',
  });

  double get percent => usedPercent ?? (totalGb > 0 ? (usedGb / totalGb * 100) : 0);
}

/// Network interface representation.
class NetInterface {
  final String name;
  final String ipv4;
  final String mac;
  double rxTotalGb;
  double txTotalGb;

  NetInterface({
    required this.name,
    required this.ipv4,
    required this.mac,
    required this.rxTotalGb,
    required this.txTotalGb,
  });
}

/// ServerNode representation for Dashboard and UI telemetry.
class ServerNode {
  final String id;
  String name;
  final String sshAddress;
  String osKernel;
  String cpuModel;
  int cpuCores;
  int? cpuPhysicalCores;
  int? cpuLogicalCores;
  double? cpuMhz;
  double? cpuSpeedGhz;
  double ramTotalGb;
  double swapTotalGb;
  double ramUsedGb;
  double swapUsedGb;
  double? ramFreeGb;
  double? ramAvailableGb;
  double? ramBuffCacheGb;
  String ramTotalFormatted;
  String ramUsedFormatted;
  double? netBytesSent;
  double? netBytesRecv;
  double? netUploadRate;
  double? netDownloadRate;
  HostInfo? hostInfo;
  int sshPingMs;
  Duration uptime;
  final List<DiskMount> mounts;
  final List<NetInterface> interfaces;
  final List<ContainerInfo> containers;
  final List<DockerImageItem> dockerImages;
  final List<SystemProcessItem> topProcesses;
  final List<SystemProcessItem> topMemoryProcesses;

  /// Baseline means.
  final Map<MetricKey, double> baseline;

  /// Most recent metric values.
  final Map<MetricKey, double> current;

  /// Rolling live buffer per metric.
  final Map<MetricKey, List<TimedSample>> live = {};

  /// Per-core CPU loads.
  final List<double> coreLoads;

  ServerNode({
    required this.id,
    required this.name,
    required this.sshAddress,
    required this.osKernel,
    required this.cpuModel,
    required this.cpuCores,
    this.cpuPhysicalCores,
    this.cpuLogicalCores,
    this.cpuMhz,
    this.cpuSpeedGhz,
    required this.ramTotalGb,
    required this.swapTotalGb,
    this.ramUsedGb = 0.0,
    this.swapUsedGb = 0.0,
    this.ramFreeGb,
    this.ramAvailableGb,
    this.ramBuffCacheGb,
    this.ramTotalFormatted = '',
    this.ramUsedFormatted = '',
    this.netBytesSent,
    this.netBytesRecv,
    this.netUploadRate,
    this.netDownloadRate,
    this.hostInfo,
    required this.sshPingMs,
    required this.uptime,
    required this.mounts,
    required this.interfaces,
    required this.containers,
    List<DockerImageItem>? dockerImages,
    required this.baseline,
    List<SystemProcessItem>? topProcesses,
    List<SystemProcessItem>? topMemoryProcesses,
  })  : dockerImages = dockerImages != null ? List.of(dockerImages) : [],
        topProcesses = topProcesses != null ? List.of(topProcesses) : [],
        topMemoryProcesses = topMemoryProcesses != null ? List.of(topMemoryProcesses) : [],
        current = Map.of(baseline),
        coreLoads = List.filled(
          cpuLogicalCores ?? (cpuCores > 0 ? cpuCores : 1),
          baseline[MetricKey.cpu] ?? 0,
          growable: true,
        ) {
    for (final key in MetricKey.values) {
      live[key] = [];
    }
  }

  factory ServerNode.createEmpty(ServerProfile profile) => ServerNode(
        id: 'node-${profile.id}',
        name: profile.displayName.isNotEmpty ? profile.displayName : 'Server',
        sshAddress: profile.cleanUrl,
        osKernel: '—',
        cpuModel: '—',
        cpuCores: 1,
        cpuPhysicalCores: 1,
        cpuLogicalCores: 1,
        cpuMhz: 0,
        cpuSpeedGhz: 0,
        ramTotalGb: 0,
        swapTotalGb: 0,
        ramUsedGb: 0,
        swapUsedGb: 0,
        sshPingMs: 0,
        uptime: Duration.zero,
        baseline: const {
          MetricKey.cpu: 0,
          MetricKey.cpuTemp: 0,
          MetricKey.memory: 0,
          MetricKey.swap: 0,
          MetricKey.disk: 0,
          MetricKey.diskRead: 0,
          MetricKey.diskWrite: 0,
          MetricKey.netRx: 0,
          MetricKey.netTx: 0,
          MetricKey.dockerCpu: 0,
          MetricKey.dockerMem: 0,
        },
        mounts: [],
        interfaces: [],
        containers: [],
        dockerImages: [],
        topProcesses: [],
        topMemoryProcesses: [],
      );

  int get physicalCores => cpuPhysicalCores ?? (cpuLogicalCores != null ? (cpuLogicalCores! * 0.7).round() : cpuCores);
  int get logicalCores => cpuLogicalCores ?? cpuCores;
  double? get speedGhz => cpuSpeedGhz ?? (cpuMhz != null ? cpuMhz! / 1000.0 : null);
  String get formattedSpeed => speedGhz != null
      ? '${speedGhz!.toStringAsFixed(1)} GHz'
      : (cpuMhz != null ? '${cpuMhz!.round()} MHz' : 'N/A');

  double value(MetricKey key) => current[key] ?? 0;

  double get diskTotalGb => mounts.fold(0, (s, m) => s + m.totalGb);
  double get diskUsedGb => mounts.fold(0, (s, m) => s + m.usedGb);
  int get runningContainers => containers.where((c) => c.isRunning).length;

  double get totalDockerImageSizeGb =>
      dockerImages.fold(0.0, (sum, img) => sum + img.sizeGb);
  double get totalDockerMemUsageMb =>
      containers.where((c) => c.isRunning).fold(0.0, (sum, c) => sum + c.memMb);
  double get totalDockerCpuPercent =>
      containers.where((c) => c.isRunning).fold(0.0, (sum, c) => sum + c.cpuPercent);
  double get totalDockerMemPercent {
    final running = containers.where((c) => c.isRunning);
    if (running.isEmpty) return 0.0;
    final sumPct = running.fold<double>(0.0, (sum, c) {
      if (c.memPercent > 0) return sum + c.memPercent;
      if (c.memLimitMb > 0) return sum + (c.memMb / c.memLimitMb * 100);
      if (ramTotalGb > 0) return sum + (c.memMb / (ramTotalGb * 1024) * 100);
      return sum;
    });
    return sumPct.clamp(0.0, 100.0);
  }

  String get uptimeLabel {
    final d = uptime.inDays;
    final h = uptime.inHours % 24;
    final m = uptime.inMinutes % 60;
    return '${d}d ${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m';
  }

  String get loadAverage {
    final cores = cpuCores > 0 ? cpuCores : 1;
    final l1 = value(MetricKey.cpu) / 100 * cores;
    final base = baseline[MetricKey.cpu] ?? value(MetricKey.cpu);
    final l5 = base / 100 * cores * 1.05;
    final l15 = base / 100 * cores * 0.92;
    return '${l1.toStringAsFixed(2)}  ${l5.toStringAsFixed(2)}  ${l15.toStringAsFixed(2)}';
  }
}
