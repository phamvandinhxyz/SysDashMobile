import 'package:flutter/material.dart';

import 'l10n/app_strings.dart';
import 'models/server_models.dart';
import 'screens/dashboard_tabs.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/secure_credential_store.dart';
import 'services/telemetry_service.dart';
import 'theme/app_colors.dart';
import 'utils/formatters.dart';
import 'widgets/app_icon.dart';
import 'widgets/glass.dart';
import 'widgets/glass_nav_bar.dart';
import 'widgets/language_toggle.dart';
import 'widgets/skeleton.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SysDashApp());
}

// Retain alias for test compatibility.
typedef MyApp = SysDashApp;

class SysDashApp extends StatefulWidget {
  final SecureCredentialStore? store;
  final SshConnector? connector;
  final ServerProfile? initialProfile;
  final SysDashApiClient? client;
  final ServerNode? initialNode;
  final bool initialLoaded;

  const SysDashApp({
    super.key,
    this.store,
    this.connector,
    this.initialProfile,
    this.client,
    this.initialNode,
    this.initialLoaded = false,
  });

  @override
  State<SysDashApp> createState() => _SysDashAppState();
}

class _SysDashAppState extends State<SysDashApp> {
  final _langController = LanguageController(AppLanguage.vi);
  late final SecureCredentialStore _store;
  late final SshConnector _connector;

  ServerProfile? _activeProfile;
  TelemetryService? _telemetry;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? SecureCredentialStore();
    _connector = widget.connector ?? const SshConnector();
    if (widget.initialProfile != null) {
      _onConnected(widget.initialProfile!);
    }
  }

  @override
  void dispose() {
    _telemetry?.dispose();
    _langController.dispose();
    super.dispose();
  }

  void _onConnected(ServerProfile profile) {
    _telemetry?.dispose();
    final client = widget.client ??
        (profile.token.isNotEmpty && !profile.token.startsWith('fake-')
            ? SysDashApiClient(rawUrl: profile.serverUrl, token: profile.token)
            : null);
    setState(() {
      _activeProfile = profile;
      _telemetry = TelemetryService(
        profile: profile,
        client: client,
        initialNode: widget.initialNode,
        isLoaded: widget.initialLoaded,
      );
    });
  }

  void _onLogout() {
    _telemetry?.dispose();
    setState(() {
      _activeProfile = null;
      _telemetry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LanguageScope(
      controller: _langController,
      child: MaterialApp(
        title: 'SysDash - Server Monitor',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: SysDashColors.bgPrimary,
          colorScheme: const ColorScheme.dark(
            primary: SysDashColors.cpuCyan,
            secondary: SysDashColors.ramViolet,
            surface: SysDashColors.bgSecondary,
          ),
          fontFamily: null,
          useMaterial3: true,
        ),
        home: _activeProfile == null || _telemetry == null
            ? LoginScreen(
                store: _store,
                connector: _connector,
                onConnected: _onConnected,
              )
            : DashboardShell(
                service: _telemetry!,
                profile: _activeProfile!,
                onLogout: _onLogout,
              ),
      ),
    );
  }
}

/// Shell hosting the top glass AppBar, 6-tab body and floating bottom nav bar.
class DashboardShell extends StatefulWidget {
  final TelemetryService service;
  final ServerProfile profile;
  final VoidCallback onLogout;

  const DashboardShell({
    super.key,
    required this.service,
    required this.profile,
    required this.onLogout,
  });

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _currentTab = 0;
  int _selectedNodeIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentTab);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (_currentTab == index) return;
    final distance = (index - _currentTab).abs();
    setState(() => _currentTab = index);
    if (_pageController.hasClients) {
      if (distance == 1) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        // When skipping across multiple tabs (e.g. > 1 tab or dragging across nav bar),
        // jump directly so the screen does not scroll through all intermediate pages.
        _pageController.jumpToPage(index);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = LanguageScope.of(context);

    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        if (!widget.service.isLoaded) {
          return _buildLoading(context, s);
        }

        final nodes = widget.service.nodes;
        if (_selectedNodeIndex >= nodes.length) _selectedNodeIndex = 0;
        final activeNode = nodes[_selectedNodeIndex];

        final navItems = [
          GlassNavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            label: s.tabOverview,
            accent: SysDashColors.statusEmerald,
          ),
          const GlassNavItem(
            icon: Icons.memory_outlined,
            activeIcon: Icons.memory_rounded,
            label: 'CPU',
            accent: SysDashColors.cpuCyan,
          ),
          GlassNavItem(
            icon: Icons.developer_board_outlined,
            activeIcon: Icons.developer_board_rounded,
            label: s.tabMemory,
            accent: SysDashColors.ramViolet,
          ),
          GlassNavItem(
            icon: Icons.storage_outlined,
            activeIcon: Icons.storage_rounded,
            label: s.tabDisks,
            accent: SysDashColors.diskAmber,
          ),
          GlassNavItem(
            icon: Icons.swap_vert_outlined,
            activeIcon: Icons.swap_vert_rounded,
            label: s.tabNetwork,
            accent: SysDashColors.netIndigo,
          ),
          const GlassNavItem(
            icon: Icons.layers_outlined,
            activeIcon: Icons.layers_rounded,
            label: 'Docker',
            accent: SysDashColors.netIndigo,
          ),
        ];

        return Scaffold(
          backgroundColor: SysDashColors.bgPrimary,
          body: Stack(
            children: [
              const Positioned.fill(child: AmbientBackground()),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Floating Dynamic Island Server Pill at Top
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SysDashAppIcon(size: 20, borderRadius: 5),
                              SizedBox(width: 8),
                              Text(
                                'SysDash',
                                style: TextStyle(
                                  color: SysDashColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          _ServerDynamicPill(
                            activeNode: activeNode,
                            profile: widget.profile,
                            service: widget.service,
                            onTap: () => _openServerControlSheet(context),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() => _currentTab = index);
                        },
                        children: [
                          OverviewTab(
                            service: widget.service,
                            selectedIndex: _selectedNodeIndex,
                            onSelectNode: (i) => setState(() => _selectedNodeIndex = i),
                            onOpenTab: _onTabSelected,
                          ),
                          CpuTab(service: widget.service, node: activeNode),
                          MemoryTab(service: widget.service, node: activeNode),
                          DisksTab(service: widget.service, node: activeNode),
                          NetworkTab(service: widget.service, node: activeNode),
                          ContainersTab(service: widget.service, node: activeNode),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: GlassNavBar(
                        items: navItems,
                        currentIndex: _currentTab,
                        pageController: _pageController,
                        onTap: _onTabSelected,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoading(BuildContext context, AppStrings s) {
    return DashboardSkeletonView(
      strings: s,
      profile: widget.profile,
      isConnected: widget.service.isConnectedToServer,
      onLogout: widget.onLogout,
    );
  }

  void _openServerControlSheet(BuildContext context) {
    final nodes = widget.service.nodes;
    if (_selectedNodeIndex >= nodes.length) _selectedNodeIndex = 0;
    final activeNode = nodes[_selectedNodeIndex];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ServerControlSheet(
        service: widget.service,
        profile: widget.profile,
        activeNode: activeNode,
        nodes: nodes,
        selectedIndex: _selectedNodeIndex,
        onSelectNode: (i) {
          setState(() => _selectedNodeIndex = i);
          Navigator.pop(ctx);
        },
        onLogout: () {
          Navigator.pop(ctx);
          widget.onLogout();
        },
      ),
    );
  }
}

/// Floating Dynamic Island Pill displaying live server status, latency and dropdown.
class _ServerDynamicPill extends StatelessWidget {
  final ServerNode activeNode;
  final ServerProfile profile;
  final TelemetryService service;
  final VoidCallback onTap;

  const _ServerDynamicPill({
    required this.activeNode,
    required this.profile,
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final isLive = service.isLive;
        final isWs = service.isConnectedToServer;
        final statusColor = isLive
            ? (isWs ? SysDashColors.statusEmerald : SysDashColors.cpuCyan)
            : SysDashColors.diskAmber;

        return Semantics(
          button: true,
          label: 'Server status and control: ${activeNode.name}',
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(99),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.45),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.20),
                      blurRadius: 10,
                      spreadRadius: -1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pulsing status LED
                    Container(
                      width: 7.5,
                      height: 7.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.8),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                    // Server Name
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Text(
                        activeNode.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SysDashColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '•',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 5),
                    // Ping
                    Text(
                      '${activeNode.sshPingMs}ms',
                      style: const TextStyle(
                        color: SysDashColors.cpuCyan,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.arrow_drop_down_rounded,
                      color: SysDashColors.textSecondary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ServerControlSheet extends StatelessWidget {
  final TelemetryService service;
  final ServerProfile profile;
  final ServerNode activeNode;
  final List<ServerNode> nodes;
  final int selectedIndex;
  final ValueChanged<int> onSelectNode;
  final VoidCallback onLogout;

  const _ServerControlSheet({
    required this.service,
    required this.profile,
    required this.activeNode,
    required this.nodes,
    required this.selectedIndex,
    required this.onSelectNode,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final s = LanguageScope.of(context);
    final roleColor = profile.role == 'admin' ? SysDashColors.cpuCyan : SysDashColors.ramViolet;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Color(0xF20B1222),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: SysDashColors.glassBorderHighlight, width: 1.2),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: kGlassBlur,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header: Server Profile Info
                  Row(
                    children: [
                      const SysDashAppIcon(size: 44, borderRadius: 14),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    activeNode.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: SysDashColors.textPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: roleColor.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: roleColor.withValues(alpha: 0.45)),
                                  ),
                                  child: Text(
                                    profile.role.toUpperCase(),
                                    style: TextStyle(
                                      color: roleColor,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${activeNode.sshAddress} • ${activeNode.sshPingMs}ms',
                              style: const TextStyle(
                                color: SysDashColors.cpuCyan,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đóng',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: SysDashColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Node Selector Section (if multiple nodes)
                  if (nodes.length > 1) ...[
                    Text(
                      s.selectNode,
                      style: const TextStyle(
                        color: SysDashColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: SysDashColors.glassBorderSubtle),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < nodes.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ListTile(
                              onTap: () => onSelectNode(i),
                              dense: true,
                              leading: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == selectedIndex
                                      ? SysDashColors.statusEmerald
                                      : SysDashColors.textMuted,
                                ),
                              ),
                              title: Text(
                                nodes[i].name,
                                style: TextStyle(
                                  color: i == selectedIndex
                                      ? SysDashColors.cpuCyan
                                      : SysDashColors.textPrimary,
                                  fontWeight: i == selectedIndex
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                nodes[i].sshAddress,
                                style: const TextStyle(
                                  color: SysDashColors.textMuted,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              trailing: i == selectedIndex
                                  ? const Icon(Icons.check_rounded, color: SysDashColors.cpuCyan, size: 18)
                                  : Text(
                                      '${nodes[i].sshPingMs}ms',
                                      style: const TextStyle(color: SysDashColors.textMuted, fontSize: 11),
                                    ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Settings Card (Live Stream & Language)
                  GlassCard(
                    borderRadius: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      children: [
                        // Live Stream toggle row
                        Row(
                          children: [
                            const IconBadge(
                              icon: Icons.sensors_rounded,
                              color: SysDashColors.statusEmerald,
                              size: 34,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.liveStream,
                                    style: const TextStyle(
                                      color: SysDashColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    s.liveStreamDesc,
                                    style: const TextStyle(
                                      color: SysDashColors.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _LiveStreamButton(service: service),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        // Language selection row
                        Row(
                          children: [
                            const IconBadge(
                              icon: Icons.translate_rounded,
                              color: SysDashColors.cpuCyan,
                              size: 34,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                s.language,
                                style: const TextStyle(
                                  color: SysDashColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const LanguageSelector(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Diagnostics Button (Admin)
                  if (service.client != null) ...[
                    GlassCard(
                      borderRadius: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: InkWell(
                        onTap: () {
                          _openDiagnosticsSheet(context, service.client!);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          children: [
                            const IconBadge(
                              icon: Icons.troubleshoot_rounded,
                              color: SysDashColors.cpuCyan,
                              size: 34,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        s.systemDiagnostics,
                                        style: const TextStyle(
                                          color: SysDashColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const GlassPill(
                                        text: 'Admin',
                                        color: SysDashColors.cpuCyan,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    s.diagnosticsDesc,
                                    style: const TextStyle(
                                      color: SysDashColors.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: SysDashColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Logout Button
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: onLogout,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.logout_rounded,
                              color: Color(0xFFEF4444),
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              s.logout,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveStreamButton extends StatelessWidget {
  final TelemetryService service;
  const _LiveStreamButton({required this.service});

  @override
  Widget build(BuildContext context) {
    final s = LanguageScope.of(context);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final live = service.isLive;
        final isWs = service.isConnectedToServer;
        final color = live
            ? (isWs ? SysDashColors.statusEmerald : SysDashColors.cpuCyan)
            : SysDashColors.diskAmber;
        final label = live ? (isWs ? 'WS Live' : s.live) : s.paused;

        return Semantics(
          button: true,
          label: label,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: service.toggleLive,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        boxShadow: [
                          BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        color: SysDashColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

void _openDiagnosticsSheet(BuildContext context, SysDashApiClient client) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _SystemDiagnosticsSheet(client: client),
  );
}

class _SystemDiagnosticsSheet extends StatefulWidget {
  final SysDashApiClient client;
  const _SystemDiagnosticsSheet({required this.client});

  @override
  State<_SystemDiagnosticsSheet> createState() => _SystemDiagnosticsSheetState();
}

class _SystemDiagnosticsSheetState extends State<_SystemDiagnosticsSheet> {
  late Future<SystemDiagnostics> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.client.getDiagnostics();
  }

  void _reload() {
    setState(() {
      _future = widget.client.getDiagnostics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = LanguageScope.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xF20B1222),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: SysDashColors.glassBorderHighlight, width: 1.2),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: kGlassBlur,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
                  child: Row(
                    children: [
                      const IconBadge(
                        icon: Icons.troubleshoot_rounded,
                        color: SysDashColors.cpuCyan,
                        size: 38,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  s.systemDiagnostics,
                                  style: const TextStyle(
                                    color: SysDashColors.textPrimary,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const GlassPill(text: 'Admin', color: SysDashColors.cpuCyan),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'GET /system/diagnostics',
                              style: TextStyle(
                                color: SysDashColors.textSecondary,
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tải lại',
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded, color: SysDashColors.cpuCyan),
                      ),
                      IconButton(
                        tooltip: 'Đóng',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: SysDashColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: SysDashColors.glassBorderSubtle),
                Expanded(
                  child: FutureBuilder<SystemDiagnostics>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: SysDashColors.cpuCyan),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 40),
                                const SizedBox(height: 12),
                                Text(
                                  '${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: SysDashColors.textPrimary, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: _reload,
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final diag = snapshot.data!;
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        children: [
                          // 1. Host / Container Environment
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              GlassPill(
                                text: diag.runningInDocker ? 'Docker: YES' : 'Docker: NO (Bare Metal/VPS)',
                                color: diag.runningInDocker ? SysDashColors.cpuCyan : SysDashColors.statusEmerald,
                              ),
                              GlassPill(
                                text: 'Host Root: ${diag.hostRoot}',
                                color: SysDashColors.textSecondary,
                              ),
                              GlassPill(
                                text: 'Mountinfo: ${diag.hostMountinfoReadable}',
                                color: diag.hostMountinfoReadable == 'yes'
                                    ? SysDashColors.statusEmerald
                                    : SysDashColors.diskAmber,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // 2. Memory Computed (htop & free -h match)
                          GlassCard(
                            glowColor: SysDashColors.ramViolet,
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SectionHeader(
                                  title: s.memoryHtopMatch,
                                  badge: diag.memoryComputed.usedFormatted.isNotEmpty
                                      ? '${diag.memoryComputed.usedFormatted} / ${diag.memoryComputed.totalFormatted}'
                                      : 'free -b',
                                  accent: SysDashColors.ramViolet,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Công thức: MemTotal - MemFree - Buffers - Cached - SReclaimable (Hệ 1024)',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (diag.meminfoRawBytes.isNotEmpty)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Column(
                                      children: [
                                        for (final entry in diag.meminfoRawBytes.entries) ...[
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  entry.key,
                                                  style: const TextStyle(
                                                    color: SysDashColors.textSecondary,
                                                    fontSize: 12,
                                                    fontFamily: 'monospace',
                                                  ),
                                                ),
                                                Text(
                                                  '${formatGb(entry.value / (1024 * 1024 * 1024))} (${entry.value} B)',
                                                  style: const TextStyle(
                                                    color: SysDashColors.textPrimary,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    fontFamily: 'monospace',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // 3. Disk Partitions Scan
                          GlassCard(
                            glowColor: SysDashColors.diskAmber,
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SectionHeader(
                                  title: s.diskScanDecisions,
                                  badge: '${diag.partitionsScan.length} mounts',
                                  accent: SysDashColors.diskAmber,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lý do chấp nhận hoặc bỏ qua các phân vùng ảo/tmpfs/snap',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                for (var i = 0; i < diag.partitionsScan.length; i++) ...[
                                  if (i > 0)
                                    Divider(height: 16, color: Colors.white.withValues(alpha: 0.08)),
                                  _PartitionScanRow(item: diag.partitionsScan[i]),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PartitionScanRow extends StatelessWidget {
  final PartitionScanItem item;
  const _PartitionScanRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final accepted = item.isAccepted;
    final badgeColor = accepted ? SysDashColors.statusEmerald : SysDashColors.textSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          accepted ? Icons.check_circle_outline_rounded : Icons.filter_alt_off_rounded,
          color: badgeColor,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.device} → ${item.mountpoint}',
                style: TextStyle(
                  color: accepted ? SysDashColors.textPrimary : SysDashColors.textSecondary,
                  fontWeight: accepted ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12.5,
                  fontFamily: 'monospace',
                ),
              ),
              if (item.statPath.isNotEmpty && item.statPath != item.mountpoint)
                Text(
                  'stat_path: ${item.statPath}',
                  style: const TextStyle(color: SysDashColors.textMuted, fontSize: 11),
                ),
              const SizedBox(height: 2),
              Text(
                item.decision,
                style: TextStyle(
                  color: accepted ? SysDashColors.statusEmerald : SysDashColors.diskAmber,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
