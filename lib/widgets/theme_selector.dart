import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';

/// Clean glass dropdown allowing users to select Dark, Light, or System theme.
class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final s = LanguageScope.of(context);
    final controller = ThemeScope.controllerOf(context);
    final currentMode = controller.value;
    final isDark = SysDashColors.isDark;

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: isDark ? const Color(0xF00F172A) : const Color(0xF2FFFFFF),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: SysDashColors.glassBorderHighlight),
          ),
          elevation: 12,
        ),
      ),
      child: PopupMenuButton<ThemeMode>(
        tooltip: s.themeDesc,
        initialValue: currentMode,
        offset: const Offset(0, 42),
        onSelected: (mode) => controller.setTheme(mode),
        itemBuilder: (context) => [
          _buildMenuItem(
            value: ThemeMode.dark,
            name: s.themeDark,
            icon: Icons.dark_mode_rounded,
            isSelected: currentMode == ThemeMode.dark,
          ),
          _buildMenuItem(
            value: ThemeMode.light,
            name: s.themeLight,
            icon: Icons.light_mode_rounded,
            isSelected: currentMode == ThemeMode.light,
          ),
          _buildMenuItem(
            value: ThemeMode.system,
            name: s.themeSystem,
            icon: Icons.brightness_auto_rounded,
            isSelected: currentMode == ThemeMode.system,
          ),
        ],
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: SysDashColors.ramViolet.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                currentMode == ThemeMode.light
                    ? Icons.light_mode_rounded
                    : (currentMode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.brightness_auto_rounded),
                size: 16,
                color: SysDashColors.ramViolet,
              ),
              const SizedBox(width: 6),
              Text(
                currentMode == ThemeMode.light
                    ? s.themeLight
                    : (currentMode == ThemeMode.dark ? s.themeDark : s.themeSystem),
                style: TextStyle(
                  color: SysDashColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 18,
                color: SysDashColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<ThemeMode> _buildMenuItem({
    required ThemeMode value,
    required String name,
    required IconData icon,
    required bool isSelected,
  }) {
    return PopupMenuItem<ThemeMode>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? SysDashColors.ramViolet : SysDashColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: isSelected ? SysDashColors.ramViolet : SysDashColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, color: SysDashColors.ramViolet, size: 18),
        ],
      ),
    );
  }
}
