import 'package:flutter/material.dart';

import '../services/secure_credential_store.dart';
import 'app_colors.dart';

/// Holds the active app theme mode (dark, light, or system) and notifies listeners.
class ThemeController extends ValueNotifier<ThemeMode> {
  final SecureCredentialStore? store;

  ThemeController({this.store, ThemeMode initial = ThemeMode.dark}) : super(initial) {
    SysDashColors.currentThemeMode = initial;
    _loadFromStore();
  }

  Future<void> _loadFromStore() async {
    if (store == null) return;
    try {
      final saved = await store!.getThemeMode();
      if (saved != null) {
        if (saved == 'light') {
          setTheme(ThemeMode.light);
        } else if (saved == 'dark') {
          setTheme(ThemeMode.dark);
        } else if (saved == 'system') {
          setTheme(ThemeMode.system);
        }
      }
    } catch (_) {}
  }

  void setTheme(ThemeMode mode) {
    if (value != mode) {
      value = mode;
      SysDashColors.currentThemeMode = mode;
      notifyListeners();
      store?.setThemeMode(mode.name);
    }
  }

  void toggle() {
    if (value == ThemeMode.dark) {
      setTheme(ThemeMode.light);
    } else {
      setTheme(ThemeMode.dark);
    }
  }
}

/// Exposes [ThemeController] to the widget tree.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController? maybeControllerOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    return scope?.notifier;
  }

  static ThemeController controllerOf(BuildContext context) {
    final controller = maybeControllerOf(context);
    assert(controller != null, 'ThemeScope not found in widget tree');
    return controller!;
  }

  static ThemeMode? maybeOf(BuildContext context) => maybeControllerOf(context)?.value;

  static ThemeMode of(BuildContext context) => controllerOf(context).value;
}
