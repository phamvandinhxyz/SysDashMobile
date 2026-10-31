import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shared blur strength for all glass surfaces (allows BackdropGroup batching).
final ImageFilter kGlassBlur = ImageFilter.blur(sigmaX: 18, sigmaY: 18);

/// Frosted glass container: translucent gradient fill, backdrop blur and a
/// thin border with specular corner lighting.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? glowColor;
  final bool highlighted;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.glowColor,
    this.highlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glow = glowColor ?? SysDashColors.cpuCyan;
    final radius = BorderRadius.circular(borderRadius);
    final isDark = SysDashColors.isDark;

    Widget surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  highlighted ? glow.withValues(alpha: 0.18) : SysDashColors.glassFillTop,
                  SysDashColors.glassFillBottom,
                  glow.withValues(alpha: highlighted ? 0.08 : 0.03),
                ]
              : [
                  highlighted ? glow.withValues(alpha: 0.12) : SysDashColors.glassFillTop,
                  SysDashColors.glassFillBottom,
                  highlighted ? glow.withValues(alpha: 0.08) : SysDashColors.glassFillBottom,
                ],
          stops: const [0.0, 0.65, 1.0],
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      surface = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: glow.withValues(alpha: 0.14),
          highlightColor: glow.withValues(alpha: 0.08),
          child: surface,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.30)
                : const Color(0x0C0F172A),
            blurRadius: isDark ? 24 : 14,
            spreadRadius: isDark ? 0 : 0.5,
            offset: Offset(0, isDark ? 10 : 4),
          ),
          if (!isDark)
            const BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter.grouped(
          filter: kGlassBlur,
          child: CustomPaint(
            foregroundPainter: GlassBorderPainter(
              radius: borderRadius,
              glowColor: glow,
              highlighted: highlighted,
            ),
            child: surface,
          ),
        ),
      ),
    );
  }
}

/// Thin 1.1px gradient stroke lit from the top-left & bottom-right corners.
class GlassBorderPainter extends CustomPainter {
  final double radius;
  final Color glowColor;
  final bool highlighted;

  const GlassBorderPainter({
    required this.radius,
    required this.glowColor,
    this.highlighted = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final isDark = SysDashColors.isDark;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = highlighted ? 1.6 : 1.1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                highlighted
                    ? glowColor.withValues(alpha: 0.85)
                    : SysDashColors.glassBorderHighlight,
                SysDashColors.glassBorderSubtle,
                glowColor.withValues(alpha: highlighted ? 0.55 : 0.24),
              ]
            : [
                highlighted
                    ? glowColor.withValues(alpha: 0.85)
                    : SysDashColors.glassBorderHighlight,
                SysDashColors.glassBorderSubtle,
                highlighted
                    ? glowColor.withValues(alpha: 0.60)
                    : SysDashColors.glassBorderSubtle,
              ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.6), Radius.circular(radius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant GlassBorderPainter old) =>
      old.glowColor != glowColor ||
      old.highlighted != highlighted ||
      old.radius != radius;
}

/// Gradient backdrop with soft coloured light orbs – gives the glass
/// something to refract.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = SysDashColors.isDark;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              SysDashColors.bgPrimary,
              SysDashColors.bgSecondary,
              SysDashColors.bgPrimary,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -60,
              child: _GlowOrb(
                280,
                SysDashColors.cpuCyan.withValues(alpha: isDark ? 0.18 : 0.05),
              ),
            ),
            Positioned(
              top: 260,
              right: -90,
              child: _GlowOrb(
                320,
                SysDashColors.ramViolet.withValues(alpha: isDark ? 0.15 : 0.04),
              ),
            ),
            Positioned(
              bottom: -100,
              left: 30,
              child: _GlowOrb(
                280,
                SysDashColors.statusEmerald.withValues(alpha: isDark ? 0.12 : 0.04),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowOrb(this.size, this.color);

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );
}

/// Rounded tinted square holding an icon.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(size * 0.3),
      border: Border.all(color: color.withValues(alpha: 0.45)),
    ),
    child: Icon(icon, color: color, size: size * 0.52),
  );
}

/// Small rounded label pill.
class GlassPill extends StatelessWidget {
  final String text;
  final Color color;
  final bool monospace;

  const GlassPill({
    super.key,
    required this.text,
    required this.color,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        fontFamily: monospace ? 'monospace' : null,
      ),
    ),
  );
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? badge;
  final Color accent;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.badge,
    this.accent = SysDashColors.defaultCpuCyan,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accent == SysDashColors.defaultCpuCyan ? SysDashColors.cpuCyan : accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: effectiveAccent,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [BoxShadow(color: effectiveAccent.withValues(alpha: 0.6), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: SysDashColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Flexible(child: GlassPill(text: badge!, color: accent)),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Thin rounded progress bar.
class GlassProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double height;

  const GlassProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(99),
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      minHeight: height,
      backgroundColor: SysDashColors.isDark
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0x180F172A),
      valueColor: AlwaysStoppedAnimation<Color>(color),
    ),
  );
}

/// Circular gauge with a centred label.
class GlassGauge extends StatelessWidget {
  final double percent; // 0..100
  final Color color;
  final String label;
  final double size;

  const GlassGauge({
    super.key,
    required this.percent,
    required this.color,
    required this.label,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            strokeWidth: size * 0.09,
            strokeCap: StrokeCap.round,
            backgroundColor: SysDashColors.isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0x180F172A),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: SysDashColors.textPrimary,
            fontSize: size * 0.19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

