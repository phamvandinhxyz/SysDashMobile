import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import 'flags.dart';

/// Multiple-choice language selector dropdown styled with Glassmorphism.
/// Displays a compact flag + code pill and expands into a clean selection menu.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = LanguageScope.controllerOf(context);
    final currentLang = controller.value;
    final isVi = currentLang == AppLanguage.vi;

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
      child: PopupMenuButton<AppLanguage>(
        tooltip: isVi ? 'Chọn ngôn ngữ' : 'Select language',
        initialValue: currentLang,
        offset: const Offset(0, 42),
        onSelected: (lang) => controller.setLanguage(lang),
        itemBuilder: (context) => [
          _buildMenuItem(
            value: AppLanguage.vi,
            name: 'Tiếng Việt',
            code: 'VI',
            painter: const VietnamFlagPainter(),
            isSelected: currentLang == AppLanguage.vi,
          ),
          _buildMenuItem(
            value: AppLanguage.en,
            name: 'English',
            code: 'EN',
            painter: const UkFlagPainter(),
            isSelected: currentLang == AppLanguage.en,
          ),
        ],
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: SysDashColors.cpuCyan.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: CustomPaint(
                  size: const Size(20, 13),
                  painter: isVi ? const VietnamFlagPainter() : const UkFlagPainter(),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                isVi ? 'VI' : 'EN',
                style: TextStyle(
                  color: SysDashColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: SysDashColors.textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<AppLanguage> _buildMenuItem({
    required AppLanguage value,
    required String name,
    required String code,
    required CustomPainter painter,
    required bool isSelected,
  }) {
    return PopupMenuItem<AppLanguage>(
      value: value,
      height: 44,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: CustomPaint(
              size: const Size(22, 14),
              painter: painter,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            name,
            style: TextStyle(
              color: isSelected ? SysDashColors.cpuCyan : SysDashColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: isSelected
                  ? SysDashColors.cpuCyan.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected
                    ? SysDashColors.cpuCyan.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              code,
              style: TextStyle(
                color: isSelected ? SysDashColors.cpuCyan : SysDashColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (isSelected)
            Icon(
              Icons.check_rounded,
              color: SysDashColors.cpuCyan,
              size: 18,
            )
          else
            const SizedBox(width: 18),
        ],
      ),
    );
  }
}

/// Backward compatibility alias for LanguageSelector.
typedef LanguageToggleButton = LanguageSelector;
