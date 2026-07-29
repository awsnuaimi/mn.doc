import 'package:shared_preferences/shared_preferences.dart';

/// تخزين محلي بسيط لإعدادات الذكاء الاصطناعي (مفتاح Gemini API المجاني).
/// المفتاح يُحفظ على الجهاز فقط ولا يُرسل لأي خادم غير Google.
class AiSettings {
  static const _keyGeminiApiKey = 'gemini_api_key';

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGeminiApiKey);
  }

  static Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGeminiApiKey, key.trim());
  }

  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyGeminiApiKey);
  }

  static Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }
}
