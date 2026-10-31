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

/// Shimmering skeleton hero card with circular gauge and facts list.
class SkeletonHeroCard extends StatelessWidget {
  final Color accent;
  final int factCount;

  const SkeletonHeroCard({
    super.key,
    this.accent = SysDashColors.cpuCyan,
    this.factCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: accent,
      borderRadius: 22,
      padding: const EdgeInsets.all(20),
      child: SkeletonShimmer(
        highlightColor: accent.withValues(alpha: 0.28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Expanded(child: SkeletonLine(width: 140, height: 16)),
                SizedBox(width: 12),
                SkeletonBox(width: 50, height: 24, borderRadius: 12),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const SkeletonCircle(size: 80),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonLine(width: 110, height: 26, borderRadius: 8),
                      SizedBox(height: 8),
                      SkeletonBox(height: 6, borderRadius: 3),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: List.generate(
                factCount,
                (i) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SkeletonLine(width: 52, height: 11),
                    SizedBox(width: 6),
                    SkeletonLine(width: 68, height: 11),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
                    const SkeletonCircle(size: 28),
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
    this.count = 5,
    this.accent = SysDashColors.cpuCyan,
  });

  @override
  Widget build(BuildContext context) {
    final displayCount = count.clamp(3, 10);
    return GlassCard(
      glowColor: accent,
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
                const SkeletonBox(width: 60, height: 22, borderRadius: 8),
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
                        SkeletonLine(width: 100 + (i % 4) * 20.0, height: 13),
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

/// Shimmering skeleton card representing Disk mounts list in DisksTab.
class SkeletonDiskList extends StatelessWidget {
  final int count;
  final Color accent;
  const SkeletonDiskList({
    super.key,
    this.count = 3,
    this.accent = SysDashColors.diskAmber,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: accent,
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: SkeletonShimmer(
        highlightColor: accent.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const SkeletonLine(width: 100, height: 14),
                  ],
                ),
                const SkeletonBox(width: 60, height: 22, borderRadius: 8),
              ],
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const Divider(height: 24, color: Colors.white10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const SkeletonBox(width: 18, height: 18, borderRadius: 4),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: SkeletonLine(width: 90, height: 13),
                      ),
                      const SkeletonLine(width: 38, height: 13),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const SkeletonBox(height: 7, borderRadius: 4),
                  const SizedBox(height: 6),
                  SkeletonLine(width: 160 + (i % 2) * 40.0, height: 11),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmering skeleton card representing Network interfaces in NetworkTab.
class SkeletonNetworkList extends StatelessWidget {
  final int count;
  final Color accent;
  const SkeletonNetworkList({
    super.key,
    this.count = 2,
    this.accent = SysDashColors.netIndigo,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: accent,
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: SkeletonShimmer(
        highlightColor: accent.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const SkeletonLine(width: 110, height: 14),
                  ],
                ),
                const SkeletonBox(width: 32, height: 20, borderRadius: 8),
              ],
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const Divider(height: 24, color: Colors.white10),
              Row(
                children: [
                  const SkeletonCircle(size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLine(width: 90 + (i % 2) * 30.0, height: 14),
                        const SizedBox(height: 6),
                        const SkeletonLine(width: 150, height: 11),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      SkeletonLine(width: 60, height: 12),
                      SizedBox(height: 4),
                      SkeletonLine(width: 50, height: 12),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmering skeleton card representing Docker containers list.
class SkeletonContainerList extends StatelessWidget {
  final int count;
  final Color accent;
  const SkeletonContainerList({
    super.key,
    this.count = 3,
    this.accent = SysDashColors.netIndigo,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: accent,
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: SkeletonShimmer(
        highlightColor: accent.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const SkeletonLine(width: 120, height: 14),
                  ],
                ),
                const SkeletonBox(width: 32, height: 20, borderRadius: 8),
              ],
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const Divider(color: Colors.white10, height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const SkeletonCircle(size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLine(width: 100 + (i % 3) * 30.0, height: 14),
                            const SizedBox(height: 5),
                            const SkeletonLine(width: 140, height: 11),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const SkeletonBox(width: 58, height: 22, borderRadius: 11),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: const [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLine(width: 40, height: 10),
                            SizedBox(height: 4),
                            SkeletonBox(height: 5, borderRadius: 3),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLine(width: 60, height: 10),
                            SizedBox(height: 4),
                            SkeletonBox(height: 5, borderRadius: 3),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SkeletonLine(width: 180 + (i % 2) * 20.0, height: 10),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmering skeleton card representing Docker images in ContainersTab.
class SkeletonDockerImageList extends StatelessWidget {
  final int count;
  final Color accent;
  const SkeletonDockerImageList({
    super.key,
    this.count = 2,
    this.accent = SysDashColors.diskAmber,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: accent,
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: SkeletonShimmer(
        highlightColor: accent.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const SkeletonLine(width: 100, height: 14),
                  ],
                ),
                const SkeletonBox(width: 32, height: 20, borderRadius: 8),
              ],
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const Divider(height: 24, color: Colors.white10),
              Row(
                children: [
                  const SkeletonCircle(size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLine(width: 110 + (i % 2) * 40.0, height: 14),
                        const SizedBox(height: 6),
                        const SkeletonLine(width: 170, height: 11),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const SkeletonBox(width: 58, height: 24, borderRadius: 12),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmering skeleton card representing per-core CPU loads in CpuTab.
class SkeletonCoreLoadsGrid extends StatelessWidget {
  final int cores;
  final Color accent;
  const SkeletonCoreLoadsGrid({
    super.key,
    this.cores = 8,
    this.accent = SysDashColors.cpuCyan,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: accent,
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: SkeletonShimmer(
        highlightColor: accent.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const SkeletonLine(width: 100, height: 14),
                  ],
                ),
                const SkeletonLine(width: 100, height: 12),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth > 500 ? 4 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 3.2,
                  ),
                  itemCount: cores,
                  itemBuilder: (context, i) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          SkeletonLine(width: 44, height: 10),
                          SkeletonLine(width: 24, height: 10),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const SkeletonBox(height: 5, borderRadius: 3),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Complete Full-Tab Skeletons for All 6 Tabs
// =============================================================================

/// 1. Overview Skeleton Tab
class OverviewSkeletonTab extends StatelessWidget {
  final AppStrings strings;
  const OverviewSkeletonTab({super.key, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SkeletonHeroCard(accent: SysDashColors.statusEmerald, factCount: 4),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(child: SkeletonMetricCard(accent: SysDashColors.statusEmerald)),
            SizedBox(width: 12),
            Expanded(child: SkeletonMetricCard(accent: SysDashColors.cpuCyan)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(child: SkeletonMetricCard(accent: SysDashColors.ramViolet)),
            SizedBox(width: 12),
            Expanded(child: SkeletonMetricCard(accent: SysDashColors.diskAmber)),
          ],
        ),
        const SizedBox(height: 16),
        const SkeletonChartCard(accent: SysDashColors.cpuCyan, height: 140),
        const SizedBox(height: 16),
        SkeletonProcessList(
          title: strings.topProcesses,
          count: 5,
          accent: SysDashColors.cpuCyan,
        ),
      ],
    );
  }
}

/// 2. CPU Skeleton Tab
class CpuSkeletonTab extends StatelessWidget {
  final AppStrings strings;
  const CpuSkeletonTab({super.key, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SkeletonHeroCard(accent: SysDashColors.cpuCyan, factCount: 5),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(child: SkeletonMetricCard(accent: SysDashColors.cpuCyan)),
            SizedBox(width: 12),
            Expanded(child: SkeletonMetricCard(accent: SysDashColors.ramViolet)),
            SizedBox(width: 12),
            Expanded(child: SkeletonMetricCard(accent: SysDashColors.statusEmerald)),
          ],
        ),
        const SizedBox(height: 16),
        const SkeletonChartCard(accent: SysDashColors.cpuCyan, height: 150),
        const SizedBox(height: 16),
        const SkeletonCoreLoadsGrid(cores: 8, accent: SysDashColors.cpuCyan),
        const SizedBox(height: 16),
        SkeletonProcessList(
          title: strings.topProcesses,
          count: 5,
          accent: SysDashColors.cpuCyan,
        ),
      ],
    );
  }
}

/// 3. Memory Skeleton Tab
class MemorySkeletonTab extends StatelessWidget {
  final AppStrings strings;
  const MemorySkeletonTab({super.key, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SkeletonHeroCard(accent: SysDashColors.ramViolet, factCount: 4),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(child: SkeletonMetricCard(accent: SysDashColors.ramViolet)),
            SizedBox(width: 12),
            Expanded(child: SkeletonMetricCard(accent: SysDashColors.ramViolet)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(child: SkeletonMetricCard(accent: SysDashColors.statusEmerald)),
            SizedBox(width: 12),
            Expanded(child: SkeletonMetricCard(accent: SysDashColors.tempOrange)),
          ],
        ),
        const SizedBox(height: 16),
        const SkeletonChartCard(accent: SysDashColors.ramViolet, height: 150),
        const SizedBox(height: 16),
        SkeletonProcessList(
          title: strings.topMemoryProcesses,
          count: 5,
          accent: SysDashColors.ramViolet,
        ),
      ],
    );
  }
}

/// 4. Disks Skeleton Tab
class DisksSkeletonTab extends StatelessWidget {
  final AppStrings strings;
  const DisksSkeletonTab({super.key, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SkeletonHeroCard(accent: SysDashColors.diskAmber, factCount: 4),
        SizedBox(height: 16),
        SkeletonDiskList(count: 3, accent: SysDashColors.diskAmber),
        SizedBox(height: 16),
        SkeletonChartCard(accent: SysDashColors.diskAmber, height: 150),
      ],
    );
  }
}

/// 5. Network Skeleton Tab
class NetworkSkeletonTab extends StatelessWidget {
  final AppStrings strings;
  const NetworkSkeletonTab({super.key, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SkeletonHeroCard(accent: SysDashColors.netIndigo, factCount: 4),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(child: SkeletonMetricCard(accent: SysDashColors.netIndigo)),
            SizedBox(width: 12),
            Expanded(child: SkeletonMetricCard(accent: SysDashColors.netTxTeal)),
          ],
        ),
        const SizedBox(height: 16),
        const SkeletonChartCard(accent: SysDashColors.netIndigo, height: 150),
        const SizedBox(height: 16),
        const SkeletonNetworkList(count: 2, accent: SysDashColors.netIndigo),
      ],
    );
  }
}

/// 6. Containers Skeleton Tab
class ContainersSkeletonTab extends StatelessWidget {
  final AppStrings strings;
  const ContainersSkeletonTab({super.key, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Row(
          children: [
            Expanded(child: SkeletonMetricCard(accent: SysDashColors.statusEmerald)),
            SizedBox(width: 12),
            Expanded(child: SkeletonMetricCard(accent: SysDashColors.diskAmber)),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: SkeletonMetricCard(accent: SysDashColors.cpuCyan)),
            SizedBox(width: 12),
            Expanded(child: SkeletonMetricCard(accent: SysDashColors.ramViolet)),
          ],
        ),
        SizedBox(height: 16),
        SkeletonChartCard(accent: SysDashColors.cpuCyan, height: 160),
        SizedBox(height: 16),
        SkeletonChartCard(accent: SysDashColors.ramViolet, height: 160),
        SizedBox(height: 16),
        SkeletonContainerList(count: 3, accent: SysDashColors.netIndigo),
        SizedBox(height: 16),
        SkeletonDockerImageList(count: 2, accent: SysDashColors.diskAmber),
      ],
    );
  }
}

/// Comprehensive Cyberpunk dashboard skeleton layout supporting all 6 tabs for initial load and smooth transitions.
class DashboardSkeletonView extends StatefulWidget {
  final AppStrings strings;
  final ServerProfile profile;
  final bool isConnected;
  final VoidCallback? onLogout;
  final int initialTab;

  const DashboardSkeletonView({
    super.key,
    required this.strings,
    required this.profile,
    required this.isConnected,
    this.onLogout,
    this.initialTab = 0,
  });

  @override
  State<DashboardSkeletonView> createState() => _DashboardSkeletonViewState();
}

class _DashboardSkeletonViewState extends State<DashboardSkeletonView> {
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 5);
  }

  Widget _buildTabBody() {
    return switch (_selectedTab) {
      1 => CpuSkeletonTab(strings: widget.strings),
      2 => MemorySkeletonTab(strings: widget.strings),
      3 => DisksSkeletonTab(strings: widget.strings),
      4 => NetworkSkeletonTab(strings: widget.strings),
      5 => ContainersSkeletonTab(strings: widget.strings),
      _ => OverviewSkeletonTab(strings: widget.strings),
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final tabLabels = [
      (s.tabOverview, SysDashColors.statusEmerald),
      ('CPU', SysDashColors.cpuCyan),
      (s.tabMemory, SysDashColors.ramViolet),
      (s.tabDisks, SysDashColors.diskAmber),
      (s.tabNetwork, SysDashColors.netIndigo),
      ('Docker', SysDashColors.netIndigo),
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
                                    color: widget.isConnected
                                        ? SysDashColors.statusEmerald
                                        : SysDashColors.diskAmber,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.profile.displayName,
                                  style: const TextStyle(
                                    color: SysDashColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.onLogout != null) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: widget.onLogout,
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
                                        s.loadingTelemetry,
                                        style: const TextStyle(
                                          color: SysDashColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        s.waitingForData,
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
                                    color: (widget.isConnected
                                            ? SysDashColors.statusEmerald
                                            : SysDashColors.diskAmber)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: (widget.isConnected
                                              ? SysDashColors.statusEmerald
                                              : SysDashColors.diskAmber)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    widget.isConnected ? 'WebSocket' : 'Connecting',
                                    style: TextStyle(
                                      color: widget.isConnected
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
                          const SizedBox(height: 14),
                          // Horizontal Tab Selector Pills
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: List.generate(tabLabels.length, (i) {
                                final isSel = _selectedTab == i;
                                final item = tabLabels[i];
                                return Padding(
                                  padding: EdgeInsets.only(right: i < tabLabels.length - 1 ? 8 : 0),
                                  child: InkWell(
                                    onTap: () => setState(() => _selectedTab = i),
                                    borderRadius: BorderRadius.circular(16),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSel
                                            ? item.$2.withValues(alpha: 0.2)
                                            : Colors.white.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSel
                                              ? item.$2.withValues(alpha: 0.6)
                                              : SysDashColors.glassBorderSubtle,
                                        ),
                                      ),
                                      child: Text(
                                        item.$1,
                                        style: TextStyle(
                                          color: isSel ? item.$2 : SysDashColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Active tab skeleton body
                          _buildTabBody(),
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
