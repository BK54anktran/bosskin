import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static final LanguageService instance = LanguageService._();
  LanguageService._();

  static const Locale vi = Locale('vi', 'VN');
  static const Locale en = Locale('en', 'US');
  static const supportedLocales = [vi, en];
  static const _storageKey = 'app_locale';

  Locale _locale = vi;
  Locale get locale => _locale;

  bool get isEnglish => _locale.languageCode == 'en';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_storageKey);
    if (code == 'en') {
      _locale = en;
    } else {
      _locale = vi;
    }
  }

  Future<void> setLocale(Locale locale) async {
    final next = locale.languageCode == 'en' ? en : vi;
    if (_locale == next) return;

    _locale = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, next.languageCode);
    notifyListeners();
  }

  String get localeLabel => isEnglish ? 'English' : 'Tiếng Việt';
}
