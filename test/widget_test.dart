import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_dash/main.dart';
import 'package:system_dash/models/server_models.dart';
import 'package:system_dash/screens/dashboard_tabs.dart';
import 'package:system_dash/screens/login_screen.dart';
import 'package:system_dash/services/api_client.dart';
import 'package:system_dash/services/telemetry_service.dart';
import 'package:system_dash/widgets/charts.dart';
import 'package:system_dash/widgets/glass_nav_bar.dart';
import 'package:system_dash/widgets/language_toggle.dart';

class _FakeConnector extends SshConnector {
  const _FakeConnector();

  @override
  Future<LoginResult?> authenticate(ServerProfile profile) async {
    return const LoginResult(
      token: 'fake-jwt-token-123',
      expiresAt: 1730380800,
      user: UserInfo(
        id: 1,
        username: 'admin',
        fullName: 'Administrator',
        role: 'admin',
      ),
    );
  }

  @override
  Future<bool> connect(ServerProfile profile) async => true;
}

class _FailingConnector extends SshConnector {
  final Exception error;
  const _FailingConnector(this.error);

  @override
  Future<LoginResult?> authenticate(ServerProfile profile) async {
    throw error;
  }

  @override
  Future<bool> connect(ServerProfile profile) async => false;
}

void main() {
  testWidgets('Renders SysDashServer LoginScreen and toggles language', (tester) async {
    await tester.pumpWidget(const SysDashApp(connector: _FakeConnector()));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Đăng nhập SysDash Server'), findsOneWidget);

    // Open multiple choice menu and select English
    await tester.tap(find.byType(LanguageToggleButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(find.text('SysDash Server Login'), findsOneWidget);
  });

  testWidgets('Signs in and navigates through the 6 glass tabs with time range filters', (
    tester,
  ) async {
    const profile = ServerProfile(
      id: 'test-node-1',
      alias: 'Production Server',
      serverUrl: 'http://10.0.2.2:8080',
      username: 'admin',
      password: 'admin123',
      token: 'fake-jwt-token-123',
      role: 'admin',
      fullName: 'Administrator',
    );

    await tester.pumpWidget(
      const SysDashApp(
        initialProfile: profile,
        connector: _FakeConnector(),
      ),
    );
    await tester.pumpAndSettle();

    // In DashboardShell
    expect(find.byType(DashboardShell), findsOneWidget);
    expect(find.byType(OverviewTab), findsOneWidget);
    expect(find.byType(GlassNavBar), findsOneWidget);

    // Verify time range selector exists in Overview tab
    expect(find.byType(TimeRangeSelector), findsWidgets);

    // Switch to CPU tab using GlassNavBar item
    final navFinder = find.byType(GlassNavBar);
    expect(navFinder, findsOneWidget);

    await tester.tap(find.descendant(of: navFinder, matching: find.text('CPU')));
    await tester.pumpAndSettle();
    expect(find.byType(CpuTab), findsOneWidget);
    expect(find.text('20 nhân'), findsWidgets);
    expect(find.text('28 luồng'), findsWidgets);
    expect(find.text('3.4 GHz'), findsWidgets);

    // Tap on '1 giờ' / '1 hour' filter on the CPU chart
    final hourFilter = find.text('1 giờ');
    expect(hourFilter, findsWidgets);
    await tester.tap(hourFilter.first);
    await tester.pumpAndSettle();

    // Switch to Memory tab (index 2)
    await tester.tap(find.descendant(of: navFinder, matching: find.text('Bộ nhớ')));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryTab), findsOneWidget);

    // Switch to Disks tab (index 3)
    await tester.tap(find.descendant(of: navFinder, matching: find.text('Ổ đĩa')));
    await tester.pumpAndSettle();
    expect(find.byType(DisksTab), findsOneWidget);

    // Switch to Network tab (index 4)
    await tester.tap(find.descendant(of: navFinder, matching: find.text('Mạng')));
    await tester.pumpAndSettle();
    expect(find.byType(NetworkTab), findsOneWidget);

    // Switch to Docker Containers tab (index 5)
    await tester.tap(find.descendant(of: navFinder, matching: find.text('Docker')));
    await tester.pumpAndSettle();
    expect(find.byType(ContainersTab), findsOneWidget);

    // Test full-screen horizontal swipe page transition (PageView): swipe right from Docker tab (5) to Network tab (4)
    await tester.flingFrom(const Offset(400, 80), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(NetworkTab), findsOneWidget);

    // Test drag-and-slide gesture on nav bar
    await tester.drag(navFinder, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.byType(GlassNavBar), findsOneWidget);

    // Open Server Control & Settings sheet via the floating Server Dynamic Pill at top
    final serverPill = find.text('Production Server').first;
    expect(serverPill, findsOneWidget);
    await tester.tap(serverPill);
    await tester.pumpAndSettle();

    // Verify Server Control Sheet is open
    expect(find.text('Truyền dữ liệu trực tiếp'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);

    // Tap Logout to test signing out
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();

    // Should return to LoginScreen
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Long press and drag on GlassNavBar triggers haptic feedback', (tester) async {
    final List<String> hapticCalls = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'HapticFeedback.vibrate') {
          hapticCalls.add(methodCall.arguments.toString());
        }
        return null;
      },
    );

    const profile = ServerProfile(
      id: 'test-node-1',
      alias: 'Production Server',
      serverUrl: 'http://10.0.2.2:8080',
      username: 'admin',
      password: 'admin123',
      token: 'fake-jwt-token-123',
    );

    await tester.pumpWidget(
      const SysDashApp(
        initialProfile: profile,
        connector: _FakeConnector(),
      ),
    );
    await tester.pumpAndSettle();

    final navFinder = find.byType(GlassNavBar);
    expect(navFinder, findsOneWidget);

    // Perform long-press gesture on nav bar
    final gesture = await tester.startGesture(tester.getCenter(navFinder));
    await tester.pump(const Duration(milliseconds: 600));

    // Verify medium impact haptic was triggered on long press start
    expect(hapticCalls, contains('HapticFeedbackType.mediumImpact'));

    // Move along nav bar across tabs
    await gesture.moveBy(const Offset(150, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(hapticCalls, contains('HapticFeedbackType.selectionClick'));

    // Release gesture
    await gesture.up();
    await tester.pumpAndSettle();
    expect(hapticCalls, contains('HapticFeedbackType.lightImpact'));
  });

  testWidgets('Displays error banner when login connection fails', (tester) async {
    const failingConnector = _FailingConnector(
      ApiException(statusCode: 401, message: 'Unauthorized'),
    );
    await tester.pumpWidget(const SysDashApp(connector: failingConnector));
    await tester.pumpAndSettle();

    // Fill in credentials and submit
    await tester.enterText(find.byType(TextFormField).at(0), 'http://192.168.1.100:8080');
    await tester.enterText(find.byType(TextFormField).at(1), 'admin');
    await tester.enterText(find.byType(TextFormField).at(2), 'wrongpassword');
    await tester.ensureVisible(find.text('Kết nối'));
    await tester.tap(find.text('Kết nối'));
    await tester.pumpAndSettle();

    // Verify error banner is visible
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.text('Tài khoản hoặc mật khẩu không chính xác.'), findsOneWidget);
  });

  test('Parses updated GET /api/v1/metrics/current & WS snapshot correctly', () {
    const rawSnapshot = {
      "timestamp": "2026-10-31T03:00:00.123456Z",
      "host_info": {
        "hostname": "ubuntu-vps",
        "os": "linux",
        "platform": "ubuntu",
        "platform_family": "debian",
        "platform_version": "22.04",
        "kernel_version": "5.15.0-105-generic",
        "kernel_arch": "x86_64",
        "uptime": 158310,
        "boot_time": 1793357861,
        "cpu_model": "Intel(R) Xeon(R) Gold 6148 CPU @ 2.40GHz",
        "cpu_physical_cores": 2,
        "cpu_logical_cores": 4,
        "cpu_cores": 4,
        "cpu_mhz": 2400.0,
        "cpu_speed_ghz": 2.4
      },
      "cpu_percent": 14.85,
      "cpu_cores_percent": [12.5, 8.3, 25.0, 10.1],
      "mem_total": 4108169216,
      "mem_used": 1888161792,
      "mem_free": 2220007424,
      "mem_available": 2220007424,
      "mem_buff_cache": 1748004864,
      "mem_used_percent": 45.96,
      "mem_total_formatted": "3.83 GiB",
      "mem_used_formatted": "1.76 GiB",
      "swap_total": 2147483648,
      "swap_used": 536870912,
      "swap_percent": 25.0,
      "partitions": [
        {
          "device": "/dev/vda1",
          "mountpoint": "/",
          "fstype": "ext4",
          "total": 83057483776,
          "used": 30582882304,
          "free": 52474601472,
          "used_percent": 36.82,
          "total_formatted": "77.35 GiB",
          "used_formatted": "28.48 GiB",
          "free_formatted": "48.87 GiB"
        }
      ],
      "net_bytes_sent": 1450239044,
      "net_bytes_recv": 9823485023,
      "net_upload_rate": 125430.5,
      "net_download_rate": 845210.2,
      "top_processes": []
    };

    const profile = ServerProfile(
      id: 'test-node-1',
      alias: '',
      serverUrl: 'http://192.168.1.100:8080',
      username: 'admin',
      password: 'pwd',
    );
    final service = TelemetryService(profile: profile);
    service.handleSnapshotForTest(rawSnapshot);

    final node = service.nodes.first;
    expect(node.name, 'ubuntu-vps');
    expect(node.osKernel, 'Ubuntu 22.04 (5.15.0-105-generic)');
    expect(node.cpuModel, 'Intel(R) Xeon(R) Gold 6148 CPU @ 2.40GHz');
    expect(node.physicalCores, 2);
    expect(node.logicalCores, 4);
    expect(node.formattedSpeed, '2.4 GHz');
    expect(node.ramTotalFormatted, '3.83 GiB');
    expect(node.ramUsedFormatted, '1.76 GiB');
    expect(node.ramAvailableGb, closeTo(2.067, 0.01));
    expect(node.ramBuffCacheGb, closeTo(1.627, 0.01));
    expect(node.mounts.length, 1);
    expect(node.mounts.first.totalFormatted, '77.35 GiB');
    expect(node.mounts.first.usedFormatted, '28.48 GiB');
    expect(node.mounts.first.percent, 36.82);
    expect(node.interfaces.length, 1);
    expect(node.interfaces.first.name, 'eth0 / WAN');
    expect(node.interfaces.first.rxTotalGb, closeTo(9.148, 0.01));
    expect(node.interfaces.first.txTotalGb, closeTo(1.350, 0.01));
    service.dispose();
  });
}
