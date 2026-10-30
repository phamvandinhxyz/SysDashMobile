import 'package:flutter/material.dart';

/// Glassmorphism Dark Mode design tokens for SysDash.
class SysDashColors {
  SysDashColors._();

  // Deep Space backgrounds
  static const Color bgPrimary = Color(0xFF070B14); // Deep Abyssal Navy
  static const Color bgSecondary = Color(0xFF0F172A); // Slate Midnight
  static const Color bgTertiary = Color(0xFF1E1B4B); // Deep Indigo Glow

  // Glass surfaces & borders
  static const Color glassFillTop = Color(0x1AFFFFFF); // 10% white
  static const Color glassFillBottom = Color(0x08FFFFFF); // 3% white
  static const Color glassBorderHighlight = Color(0x47FFFFFF); // 28% white
  static const Color glassBorderSubtle = Color(0x12FFFFFF); // 7% white
  static const Color glassInput = Color(0x0FFFFFFF); // 6% white

  // Typography (>= 4.5:1 on dark surfaces)
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Metric accents
  static const Color cpuCyan = Color(0xFF38BDF8);
  static const Color tempOrange = Color(0xFFFB923C);
  static const Color ramViolet = Color(0xFFA855F7);
  static const Color swapPink = Color(0xFFEC4899);
  static const Color diskAmber = Color(0xFFF59E0B);
  static const Color diskWriteRose = Color(0xFFF43F5E);
  static const Color netIndigo = Color(0xFF6366F1);
  static const Color netTxTeal = Color(0xFF2DD4BF);
  static const Color statusEmerald = Color(0xFF10B981);
  static const Color statusCrimson = Color(0xFFEF4444);

  /// Picks a semantic colour for a usage percentage (0-100).
  static Color forUsage(double percent) {
    if (percent >= 85) return statusCrimson;
    if (percent >= 65) return diskAmber;
    return statusEmerald;
  }
}
