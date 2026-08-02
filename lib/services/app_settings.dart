import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إعدادات التطبيق العامة (تُحفظ محليًا على الجهاز فقط):
/// - وضع الثيم (فاتح/ليلي/تلقائي)
/// - اللغة (عربي/إنجليزي/ألماني/فرنسي/تركي/بولندي)
/// - اسم المستخدم (ملف شخصي محلي، ليس تسجيل دخول حقيقي على سيرفر)
class AppSettingsController extends ChangeNotifier {
  static const _keyThemeMode = 'theme_mode';
  static const _keyLocale = 'app_locale';
  static const _keyDisplayName = 'display_name';

  /// اللغات المدعومة فعليًا بالتطبيق — أي قيمة أخرى محفوظة (تالفة أو
  /// من إصدار قديم) يتم تجاهلها والرجوع للعربية كافتراضي آمن.
  static const _supportedLocales = {'ar', 'en', 'de', 'fr', 'tr', 'pl'};

  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('ar');
  String _displayName = '';

  // نسخة واحدة مخزّنة مؤقتًا من SharedPreferences بدل طلبها بكل دالة
  SharedPreferences? _prefsCache;
  Future<SharedPreferences> get _prefs async => _prefsCache ??= await SharedPreferences.getInstance();

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;
  String get displayName => _displayName;
  bool get isArabic => _locale.languageCode == 'ar';
  bool get isRtl => _locale.languageCode == 'ar';

  Future<void> load() async {
    final prefs = await _prefs;
    final themeStr = prefs.getString(_keyThemeMode);
    _themeMode = switch (themeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    var localeStr = prefs.getString(_keyLocale) ?? 'ar';
    if (!_supportedLocales.contains(localeStr)) {
      localeStr = 'ar'; // حماية من قيمة تالفة أو غير مدعومة
    }
    _locale = Locale(localeStr);

    _displayName = prefs.getString(_keyDisplayName) ?? '';
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await _prefs;
    await prefs.setString(_keyThemeMode, mode.name);
  }

  Future<void> setLocale(Locale locale) async {
    final code = _supportedLocales.contains(locale.languageCode) ? locale.languageCode : 'ar';
    _locale = Locale(code);
    notifyListeners();
    final prefs = await _prefs;
    await prefs.setString(_keyLocale, code);
  }

  Future<void> setDisplayName(String name) async {
    final cleaned = name.trim();
    final capped = cleaned.length > 50 ? cleaned.substring(0, 50) : cleaned;
    _displayName = capped;
    notifyListeners();
    final prefs = await _prefs;
    await prefs.setString(_keyDisplayName, capped);
  }
}
