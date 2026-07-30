import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إعدادات التطبيق العامة (تُحفظ محليًا على الجهاز فقط):
/// - وضع الثيم (فاتح/ليلي/تلقائي)
/// - اللغة (عربي/إنجليزي) — مطبّقة حاليًا على الشاشة الرئيسية وشاشة الإعدادات فقط
/// - اسم المستخدم (ملف شخصي محلي، ليس تسجيل دخول حقيقي على سيرفر)
class AppSettingsController extends ChangeNotifier {
  static const _keyThemeMode = 'theme_mode';
  static const _keyLocale = 'app_locale';
  static const _keyDisplayName = 'display_name';

  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('ar');
  String _displayName = '';

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  String get displayName => _displayName;
  bool get isArabic => _locale.languageCode == 'ar';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_keyThemeMode);
    _themeMode = switch (themeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final localeStr = prefs.getString(_keyLocale) ?? 'ar';
    _locale = Locale(localeStr);
    _displayName = prefs.getString(_keyDisplayName) ?? '';
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode.name);
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, locale.languageCode);
  }

  Future<void> setDisplayName(String name) async {
    _displayName = name;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDisplayName, name);
  }
}
