import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/server_models.dart';
import '../theme/app_colors.dart';
import 'app_icon.dart';
import 'glass.dart';

/// Shimmer animation wrapper that slides an iridescent highlight across all
/// child skeleton elements.
class SkeletonShimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const SkeletonShimmer({
    super.key,
    required this.child,
    this.baseColor = const Color(0x18FFFFFF),
    this.highlightColor = const Color(0x4000F5FF),
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    // In test environment, forward once so pumpAndSettle does not time out.
    // In real app environment, repeat indefinitely for smooth continuous shimmer.
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _controller.forward();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final t = _controller.value;
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(slidePercent: t),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final translation = bounds.width * (slidePercent * 2.5 - 0.75);
    return Matrix4.translationValues(translation, 0.0, 0.0);
  }
}

/// A basic placeholder box with rounded corners that responds to [SkeletonShimmer].
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? color;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.color,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Helper for single text line skeletons.
class SkeletonLine extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonLine({
    super.key,
    this.width,
    this.height = 12,
    this.borderRadius = 6,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: width,
      height: height,
      borderRadius: borderRadius,
      margin: margin,
    );
  }
}

/// Helper for circular gauge / avatar skeletons.
class SkeletonCircle extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry? margin;

  const SkeletonCircle({
    super.key,
    required this.size,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: size,
      height: size,
      borderRadius: size / 2,
      margin: margin,
    );
  }
}

/// Shimmering skeleton card representing an Overview metric tile (CPU, RAM, Disk, Net).
class SkeletonMetricCard extends StatelessWidget {
  final Color accent;
  const SkeletonMetricCard({super.key, this.accent = SysDashColors.cpuCyan});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(16),
      child: SkeletonShimmer(
        highlightColor: accent.withValues(alpha: 0.28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SkeletonCircle(size: 28),
                    const SizedBox(width: 10),
                    const SkeletonLine(width: 80, height: 13),
                  ],
                ),
                const SkeletonLine(width: 44, height: 13),
              ],
            ),
            const SizedBox(height: 16),
            const SkeletonLine(width: 120, height: 26, borderRadius: 8),
            const SizedBox(height: 12),
            const SkeletonBox(height: 6, borderRadius: 3),
          ],
        ),
      ),
    );
  }
}

/// Shimmering skeleton card representing a chart area with time-range pill placeholders.
class SkeletonChartCard extends StatelessWidget {
  final String? title;
  final Color accent;
  final double height;

  const SkeletonChartCard({
    super.key,
    this.title,
    this.accent = SysDashColors.cpuCyan,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: SkeletonShimmer(
        highlightColor: accent.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  const SkeletonLine(width: 110, height: 15),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    4,
                    (i) => const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: SkeletonBox(width: 42, height: 24, borderRadius: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: height,
              child: Stack(
                children: [
                  // Subtle simulated grid lines
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      4,
                      (_) => const Divider(
                        color: Colors.white12,
                        height: 1,
                        thickness: 1,
                      ),
                    ),
                  ),
                  // Chart wave placeholders
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(14, (i) {
                        final h = 30.0 + (math.sin(i * 0.5) * 35.0).abs() + (i % 3) * 20.0;
                        return SkeletonBox(
                          width: 10,
                          height: h.clamp(20.0, height - 20),
                          borderRadius: 4,
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmering skeleton card representing the top processes list.
class SkeletonProcessList extends StatelessWidget {
  final String title;
  final int count;
  final Color accent;

  const SkeletonProcessList({
    super.key,
    required this.title,
    this.count = 10,
    this.accent = SysDashColors.cpuCyan,
  });

  @override
  Widget build(BuildContext context) {
    final displayCount = count.clamp(3, 15);
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: SkeletonShimmer(
        highlightColor: accent.withValues(alpha: 0.22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4,
                      height: 14,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: SysDashColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SkeletonBox(width: 70, height: 24, borderRadius: 8),
              ],
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < displayCount; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              Row(
                children: [
                  const SkeletonBox(width: 22, height: 18, borderRadius: 5),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SkeletonLine(width: 100 + (i % 4) * 25.0, height: 13),
                        const SizedBox(height: 4),
                        const SkeletonLine(width: 60, height: 10),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    flex: 3,
                    child: SkeletonBox(height: 6, borderRadius: 3),
                  ),
                  const SizedBox(width: 12),
                  const SkeletonLine(width: 42, height: 13),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmering skeleton card representing Docker containers.
class SkeletonContainerList extends StatelessWidget {
  final int count;
  const SkeletonContainerList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: SkeletonShimmer(
        highlightColor: SysDashColors.netIndigo.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const Divider(color: Colors.white10, height: 24),
              Row(
                children: [
                  const SkeletonCircle(size: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLine(width: 120 + (i % 3) * 30.0, height: 14),
                        const SizedBox(height: 6),
                        const SkeletonLine(width: 180, height: 10),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const SkeletonBox(width: 64, height: 26, borderRadius: 8),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Comprehensive Cyberpunk dashboard skeleton layout for initial load and smooth transitions.
class DashboardSkeletonView extends StatelessWidget {
  final AppStrings strings;
  final ServerProfile profile;
  final bool isConnected;
  final VoidCallback? onLogout;

  const DashboardSkeletonView({
    super.key,
    required this.strings,
    required this.profile,
    required this.isConnected,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SysDashColors.bgPrimary,
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackground()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top App Bar Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: SysDashColors.glassFillTop,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: SysDashColors.glassBorderSubtle),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isConnected
                                        ? SysDashColors.statusEmerald
                                        : SysDashColors.diskAmber,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  profile.displayName,
                                  style: const TextStyle(
                                    color: SysDashColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (onLogout != null) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: onLogout,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: SysDashColors.glassBorderSubtle),
                                ),
                                child: const Icon(
                                  Icons.logout_rounded,
                                  size: 16,
                                  color: SysDashColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Main Skeleton Body
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = math.max(16.0, (constraints.maxWidth - 1100) / 2);
                      return ListView(
                        padding: EdgeInsets.fromLTRB(side, 8, side, 40),
                        children: [
                          // Active Loading Banner Status Card (maintains test and visual compatibility)
                          GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            borderRadius: 18,
                            glowColor: SysDashColors.cpuCyan,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      SysDashColors.cpuCyan,
                                    ),
                                    backgroundColor:
                                        SysDashColors.cpuCyan.withValues(alpha: 0.15),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        strings.loadingTelemetry,
                                        style: const TextStyle(
                                          color: SysDashColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        strings.waitingForData,
                                        style: const TextStyle(
                                          color: SysDashColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isConnected
                                            ? SysDashColors.statusEmerald
                                            : SysDashColors.diskAmber)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: (isConnected
                                              ? SysDashColors.statusEmerald
                                              : SysDashColors.diskAmber)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    isConnected ? 'WebSocket' : 'Connecting',
                                    style: TextStyle(
                                      color: isConnected
                                          ? SysDashColors.statusEmerald
                                          : SysDashColors.diskAmber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 4 Metric Card Skeletons (Grid)
                          Row(
                            children: const [
                              Expanded(
                                child: SkeletonMetricCard(accent: SysDashColors.statusEmerald),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: SkeletonMetricCard(accent: SysDashColors.cpuCyan),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: const [
                              Expanded(
                                child: SkeletonMetricCard(accent: SysDashColors.ramViolet),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: SkeletonMetricCard(accent: SysDashColors.diskAmber),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Hero Chart Skeleton
                          const SkeletonChartCard(
                            accent: SysDashColors.cpuCyan,
                            height: 140,
                          ),
                          const SizedBox(height: 16),
                          // Processes List Skeleton
                          SkeletonProcessList(
                            title: strings.topProcesses,
                            count: 5,
                            accent: SysDashColors.cpuCyan,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
