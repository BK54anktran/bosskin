import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// Bước F — chọn giao diện sáng / tối / theo hệ thống, lưu trên máy.
/// [effectiveDark] quyết định [AppTheme.isDark]; app dựng lại toàn bộ khi giá trị này đổi.
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  static final ThemeController instance = ThemeController._();
  ThemeController._();

  static const _storageKey = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  bool get effectiveDark => switch (_mode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system =>
          SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
      };

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = switch (prefs.getString(_storageKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    AppTheme.isDark = effectiveDark;
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, mode.name);
    _apply();
  }

  @override
  void didChangePlatformBrightness() {
    if (_mode == ThemeMode.system) _apply();
  }

  void _apply() {
    AppTheme.isDark = effectiveDark;
    notifyListeners();
  }
}
