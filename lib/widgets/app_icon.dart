import 'package:flutter/material.dart';
import 'package:system_dash/theme/app_colors.dart';

/// Reusable application icon displaying the 3-tier Server Blades branding
/// with a 100% transparent background for in-app screens (Login, Top Bar).
class SysDashAppIcon extends StatelessWidget {
  final double size;
  final double? borderRadius;

  const SysDashAppIcon({
    super.key,
    this.size = 24,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/icon/app_icon_transparent.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _FallbackBlades(size: size),
      ),
    );
  }
}

class _FallbackBlades extends StatelessWidget {
  final double size;

  const _FallbackBlades({required this.size});

  @override
  Widget build(BuildContext context) {
    final bladeH = size * 0.18;
    final spacing = size * 0.08;
    final bladeW = size * 0.88;

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _blade(bladeW, bladeH, SysDashColors.statusEmerald),
            SizedBox(height: spacing),
            _blade(bladeW, bladeH, SysDashColors.cpuCyan),
            SizedBox(height: spacing),
            _blade(bladeW, bladeH, SysDashColors.netIndigo),
          ],
        ),
      ),
    );
  }

  Widget _blade(double w, double h, Color led) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(h * 0.35),
        border: Border.all(
          color: const Color(0xFF475569),
          width: 1,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: w * 0.08),
      alignment: Alignment.centerRight,
      child: Container(
        width: h * 0.45,
        height: h * 0.45,
        decoration: BoxDecoration(
          color: led,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: led.withValues(alpha: 0.6),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}
