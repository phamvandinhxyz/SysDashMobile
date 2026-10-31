import 'package:flutter/material.dart';

/// Glassmorphism design tokens for SysDash supporting both Dark & Light themes.
class SysDashColors {
  SysDashColors._();

  static ThemeMode currentThemeMode = ThemeMode.dark;

  static bool get isDark {
    if (currentThemeMode == ThemeMode.dark) return true;
    if (currentThemeMode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  // Canvas backgrounds
  // Dark: Deep void space #070B14 -> #0F172A
  // Light: Clean, modern luminous porcelain canvas #F6F8FC -> #EDF2F7
  static Color get bgPrimary => isDark ? const Color(0xFF070B14) : const Color(0xFFF6F8FC);
  static Color get bgSecondary => isDark ? const Color(0xFF0F172A) : const Color(0xFFEDF2F7);
  static Color get bgTertiary => isDark ? const Color(0xFF1E1B4B) : const Color(0xFFE2E8F0);

  // Frosted Glass Surfaces
  // Dark: Translucent obsidian sheen (10% to 3% white)
  // Light: Luminous frosted porcelain (96% to 88% white)
  static Color get glassFillTop => isDark ? const Color(0x1AFFFFFF) : const Color(0xF5FFFFFF);
  static Color get glassFillBottom => isDark ? const Color(0x08FFFFFF) : const Color(0xEBF8FAFC);

  // Card Borders & Specular rim lighting
  // Dark: 28% white specular highlight -> 7% white subtle rim
  // Light: 60% white crisp specular top -> 10% slate rim for clear card definition
  static Color get glassBorderHighlight => isDark ? const Color(0x47FFFFFF) : const Color(0x99FFFFFF);
  static Color get glassBorderSubtle => isDark ? const Color(0x12FFFFFF) : const Color(0x1A0F172A);

  // Surface elements & inputs
  // Dark: Translucent dark input
  // Light: Soft recessed slate fill
  static Color get glassInput => isDark ? const Color(0x0FFFFFFF) : const Color(0xFFF1F5F9);
  static Color get surfaceSubtle => isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0x0A0F172A);
  static Color get dividerColor => isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0x140F172A);

  // Typography (WCAG AAA / AA verified)
  // Dark: Crisp Ice White #F8FAFC, Slate 400 #94A3B8, Slate 500 #64748B
  // Light: Deep Slate 900 #0F172A, Slate 600 #475569, Slate 500 #64748B
  static Color get textPrimary => isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  static Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  static Color get textMuted => isDark ? const Color(0xFF64748B) : const Color(0xFF64748B);

  // Metric Accents - Adaptive contrast
  // Dark: High-luminance neon glow on dark obsidian
  // Light: Deep, vibrant rich saturated tones (WCAG AA compliant on white/porcelain)
  static Color get cpuCyan => isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
  static Color get tempOrange => isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
  static Color get ramViolet => isDark ? const Color(0xFFA855F7) : const Color(0xFF7C3AED);
  static Color get swapPink => isDark ? const Color(0xFFEC4899) : const Color(0xFFDB2777);
  static Color get diskAmber => isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
  static Color get diskWriteRose => isDark ? const Color(0xFFF43F5E) : const Color(0xFFE11D48);
  static Color get netIndigo => isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5);
  static Color get netTxTeal => isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
  static Color get statusEmerald => isDark ? const Color(0xFF10B981) : const Color(0xFF059669);
  static Color get statusCrimson => isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);

  // Compile-time default fallbacks for optional constructor parameters
  static const Color defaultCpuCyan = Color(0xFF38BDF8);
  static const Color defaultTempOrange = Color(0xFFFB923C);
  static const Color defaultRamViolet = Color(0xFFA855F7);
  static const Color defaultDiskAmber = Color(0xFFF59E0B);
  static const Color defaultNetIndigo = Color(0xFF6366F1);
  static const Color defaultStatusEmerald = Color(0xFF10B981);
  static const Color defaultStatusCrimson = Color(0xFFEF4444);

  /// Picks a semantic colour for a usage percentage (0-100).
  static Color forUsage(double percent) {
    if (percent >= 85) return statusCrimson;
    if (percent >= 65) return diskAmber;
    return statusEmerald;
  }
}
