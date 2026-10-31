import 'package:flutter/widgets.dart';

import '../models/server_models.dart';

enum AppLanguage { vi, en }

/// Holds the current app language and notifies listeners on change.
class LanguageController extends ValueNotifier<AppLanguage> {
  LanguageController([super.value = AppLanguage.vi]);

  void toggle() {
    value = value == AppLanguage.vi ? AppLanguage.en : AppLanguage.vi;
  }

  void setLanguage(AppLanguage lang) {
    if (value != lang) {
      value = lang;
    }
  }
}

/// Exposes [LanguageController] to the widget tree.
class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static LanguageController controllerOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LanguageScope>();
    assert(scope != null, 'LanguageScope not found in widget tree');
    return scope!.notifier!;
  }

  static AppStrings of(BuildContext context) =>
      AppStrings(controllerOf(context).value);
}

/// Bilingual (Vietnamese / English) string table.
class AppStrings {
  final AppLanguage lang;
  const AppStrings(this.lang);

  bool get isVi => lang == AppLanguage.vi;
  String _t(String vi, String en) => isVi ? vi : en;

  // ---------------------------------------------------------------- General
  String get appSubtitle =>
      _t('Giám sát máy chủ Golang & Docker', 'Golang & Docker Server Monitor');
  String get live => _t('Trực tiếp', 'Live');
  String get paused => _t('Tạm dừng', 'Paused');
  String get logout => _t('Đăng xuất', 'Sign out');
  String get selectNode => _t('Chọn máy chủ', 'Select server');
  String get serverSettings => _t('Cài đặt & Máy chủ', 'Server & Settings');
  String get liveStream => _t('Truyền dữ liệu trực tiếp', 'Live data streaming');
  String get liveStreamDesc => _t('WebSocket thời gian thực (2s)', 'Real-time WebSocket (2s)');
  String get language => _t('Ngôn ngữ', 'Language');
  String get theme => _t('Giao diện', 'Theme');
  String get themeDark => _t('Tối', 'Dark');
  String get themeLight => _t('Sáng', 'Light');
  String get themeSystem => _t('Hệ thống', 'System');
  String get themeDesc => _t('Chế độ sáng / tối', 'Light / Dark mode');
  String get now => _t('Hiện tại', 'Now');
  String get avg => _t('TB', 'Avg');
  String get peak => _t('Đỉnh', 'Peak');
  String get cores => _t('nhân', 'cores');
  String get threads => _t('luồng', 'threads');
  String get running => _t('Đang chạy', 'Running');
  String get stopped => _t('Đã dừng', 'Stopped');
  String get sshConnected => _t('Đã kết nối API', 'API Connected');
  String get nodes => _t('Máy chủ', 'Nodes');
  String get loadingTelemetry => _t('Đang tải dữ liệu máy chủ…', 'Loading server telemetry…');
  String get waitingForData => _t('Đang chờ phản hồi số liệu từ máy chủ…', 'Waiting for initial metrics from server…');

  // ------------------------------------------------------------------ Login
  String get loginTitle => _t('Đăng nhập SysDash Server', 'SysDash Server Login');
  String get loginSubtitle => _t(
    'Kết nối REST API & WebSocket thời gian thực',
    'Connect with REST API & Real-time WebSocket',
  );
  String get serverUrl => _t('Địa chỉ Server API (URL / IP)', 'Server API URL / IP');
  String get serverUrlRequired => _t(
    'Vui lòng nhập địa chỉ máy chủ (vd: http://10.0.2.2:8080)',
    'Please enter server URL (e.g. http://10.0.2.2:8080)',
  );
  String get alias => _t('Tên hiển thị (tuỳ chọn)', 'Display name (optional)');
  String get host => _t('Địa chỉ máy chủ (Host / IP)', 'Host / IP address');
  String get port => _t('Cổng', 'Port');
  String get username => _t('Tài khoản', 'Username');
  String get password => _t('Mật khẩu', 'Password');
  String get showPassword => _t('Hiện mật khẩu', 'Show password');
  String get hidePassword => _t('Ẩn mật khẩu', 'Hide password');
  String get rememberMe =>
      _t('Lưu thông tin đăng nhập (mã hoá)', 'Remember credentials (encrypted)');
  String get connect => _t('Kết nối', 'Connect');
  String get connecting => _t('Đang kết nối API…', 'Connecting to API…');
  String get savedServers => _t('Máy chủ đã lưu', 'Saved servers');
  String get deleteProfile => _t('Xoá hồ sơ đã lưu', 'Delete saved profile');
  String get profileDeleted => _t('Đã xoá hồ sơ', 'Profile removed');
  String get defaultCredentials => _t('Mặc định: admin / admin123', 'Default: admin / admin123');
  String get quickPresets => _t('Mẫu URL nhanh', 'Quick URL presets');
  String get hostRequired =>
      _t('Vui lòng nhập địa chỉ máy chủ', 'Please enter a host');
  String get portInvalid =>
      _t('Cổng phải từ 1 đến 65535', 'Port must be between 1 and 65535');
  String get usernameRequired =>
      _t('Vui lòng nhập tài khoản', 'Please enter a username');
  String get passwordRequired =>
      _t('Vui lòng nhập mật khẩu', 'Please enter a password');
  String get connectFailed => _t(
    'Không thể kết nối. Kiểm tra URL máy chủ và tài khoản / mật khẩu.',
    'Unable to connect. Check server URL and credentials.',
  );
  String get invalidCredentials => _t(
    'Tài khoản hoặc mật khẩu không chính xác.',
    'Incorrect username or password.',
  );
  String get connectionTimeout => _t(
    'Quá thời gian kết nối tới máy chủ (Timeout).',
    'Connection to server timed out.',
  );
  String get serverUnreachable => _t(
    'Không thể kết nối tới máy chủ. Vui lòng kiểm tra địa chỉ URL và mạng.',
    'Cannot reach server. Please check URL and network connection.',
  );
  String get storageError => _t(
    'Không thể truy cập kho lưu trữ bảo mật trên thiết bị.',
    'Unable to access secure storage on this device.',
  );

  // --------------------------------------------------------------- Nav tabs
  String get tabOverview => _t('Tổng quan', 'Overview');
  String get tabCpu => 'CPU';
  String get tabMemory => _t('Bộ nhớ', 'Memory');
  String get tabDisks => _t('Ổ đĩa', 'Disks');
  String get tabNetwork => _t('Mạng', 'Network');
  String get tabContainers => 'Containers';

  // ------------------------------------------------------------ Time ranges
  String timeRange(TimeRange r) => switch (r) {
    TimeRange.live => _t('Trực tiếp', 'Live'),
    TimeRange.hour1 => _t('1 giờ', '1 hour'),
    TimeRange.hour12 => _t('12 giờ', '12 hours'),
    TimeRange.hour24 => _t('24 giờ', '24 hours'),
    TimeRange.week1 => _t('1 tuần', '1 week'),
    TimeRange.day30 => _t('30 ngày', '30 days'),
  };

  // --------------------------------------------------------------- Overview
  String get uptime => _t('Thời gian hoạt động', 'Uptime');
  String get nodesOnline => _t('Nodes trực tuyến', 'Nodes online');
  String get sshLatency => _t('Độ trễ API', 'API latency');
  String get containers => 'Containers';
  String get fleet => _t('Cụm máy chủ', 'Server fleet');
  String get resources => _t('Tài nguyên hệ thống', 'System resources');

  // -------------------------------------------------------------------- CPU
  String get cpuUsage => _t('Mức sử dụng CPU', 'CPU usage');
  String get cpuTemp => _t('Nhiệt độ CPU', 'CPU temperature');
  String get loadAverage => _t('Tải trung bình (1/5/15m)', 'Load average (1/5/15m)');
  String get perCore => _t('Mức tải từng luồng', 'Per-thread load');
  String get physicalCores => _t('Số nhân', 'Physical cores');
  String get logicalCores => _t('Số luồng', 'Logical cores / Threads');
  String get cpuSpeed => _t('Tốc độ xử lý', 'Clock speed');

  // ----------------------------------------------------------------- Memory
  String get ramUsage => _t('Sử dụng RAM', 'RAM usage');
  String get swapUsage => _t('Bộ nhớ Swap', 'Swap usage');
  String get memBreakdown => _t('Phân bổ bộ nhớ', 'Memory breakdown');
  String get used => _t('Đã dùng', 'Used');
  String get cached => _t('Bộ đệm', 'Cached');
  String get buffers => 'Buffers';
  String get buffCache => _t('Bộ đệm (Buff/Cache)', 'Buff/Cache');
  String get available => _t('Khả dụng', 'Available');
  String get free => _t('Trống', 'Free');

  // ------------------------------------------------------------------ Disks
  String get diskUsage => _t('Dung lượng sử dụng', 'Disk usage');
  String get diskIo => _t('Tốc độ đọc / ghi', 'Disk I/O');
  String get read => _t('Đọc', 'Read');
  String get write => _t('Ghi', 'Write');
  String get mountPoints => _t('Phân vùng', 'Mount points');

  // ---------------------------------------------------------------- Network
  String get bandwidth => _t('Băng thông', 'Bandwidth');
  String get download => _t('Tải xuống', 'Download');
  String get upload => _t('Tải lên', 'Upload');
  String get interfaces => _t('Giao diện mạng', 'Interfaces');

  // ------------------------------------------------------------- Containers
  String get containersCpu => _t('CPU của Containers', 'Containers CPU');
  String get containersMem => _t('RAM của Containers', 'Containers memory');
  String get containerList => _t('Danh sách Containers', 'Container list');
  String get dockerImages => _t('Docker Images', 'Docker Images');
  String get noContainers => _t('Không có container nào đang chạy', 'No containers running');
  String get noImages => _t('Không có Docker image nào', 'No Docker images found');

  // -------------------------------------------------------------- Processes
  String get topProcesses => _t('Top tiến trình hệ thống', 'Top system processes');
  String get topMemoryProcesses => _t('Top tiến trình chiếm RAM', 'Top memory processes');
  String get pid => 'PID';
  String get processName => _t('Tên tiến trình', 'Process name');

  // ------------------------------------------------------------ Diagnostics
  String get systemDiagnostics => _t('Chẩn đoán hệ thống', 'System Diagnostics');
  String get diagnosticsDesc => _t(
    'Kiểm tra /proc/meminfo và quét phân vùng ổ đĩa host',
    'Inspect /proc/meminfo & host disk partition scans',
  );
  String get memoryHtopMatch => _t('Đối chiếu RAM (Chuẩn htop & free)', 'RAM Match (htop & free standard)');
  String get diskScanDecisions => _t('Quét phân vùng ổ đĩa', 'Disk partition scan');
  String get close => _t('Đóng', 'Close');

  // -------------------------------------------------------- User Management
  String get userManagement => _t('Quản lý tài khoản', 'User Management');
  String get userManagementDesc => _t(
    'Cập nhật thông tin, thay đổi mật khẩu hoặc đổi quyền',
    'Update info, change password, or modify role',
  );
  String get changePassword => _t('Đổi mật khẩu', 'Change password');
  String get editUser => _t('Cập nhật người dùng', 'Update user');
  String get newPassword => _t('Mật khẩu mới', 'New password');
  String get newPasswordOptional => _t('Mật khẩu mới (bỏ trống nếu không đổi)', 'New password (optional)');
  String get fullNameOptional => _t('Họ và tên (tuỳ chọn)', 'Full name (optional)');
  String get usernameOptional => _t('Tên người dùng (tuỳ chọn)', 'Username (optional)');
  String get roleSelect => _t('Quyền hạn', 'Role');
  String get updateSuccess => _t('Cập nhật người dùng thành công', 'User updated successfully');
  String get updatingUser => _t('Đang cập nhật…', 'Updating…');
  String get targetUserId => _t('Mã ID người dùng', 'User ID');
  String get saveChanges => _t('Lưu thay đổi', 'Save changes');
}
