import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_settings.dart';

/// خدمة اتصال بسيطة بـ Google Gemini API (الفئة المجانية Free Tier).
///
/// كيفية الحصول على مفتاح مجاني:
///   1) افتح https://aistudio.google.com/apikey
///   2) سجّل الدخول بحساب Google واضغط "Create API key"
///   3) لا حاجة لبطاقة ائتمان — الفئة المجانية تعمل فورًا (مع حدود طلبات محدودة).
///
/// تُستخدم هذه الخدمة لميزتين تحتاجان فعليًا إلى نموذج لغوي:
///   - التلخيص الذكي (Abstractive Summarization) للنصوص الطويلة.
///   - المساعد الذكي للدردشة حول محتوى المستند.
///
/// ملاحظة: هذه الميزة تحتاج اتصال إنترنت ومفتاح مجاني خاص بالمستخدم،
/// على عكس الترجمة والتعرف الضوئي (OCR) اللذين يعملان بالكامل بدون إنترنت.
class GeminiService {
  static const _model = 'gemini-2.5-flash';
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  static Future<String> _generate({
    required String prompt,
    List<Map<String, String>> history = const [],
  }) async {
    final apiKey = await AiSettings.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('لم يتم إدخال مفتاح Gemini API بعد. اذهب إلى الإعدادات لإضافته (مجاني).');
    }

    final uri = Uri.parse('$_baseUrl/$_model:generateContent?key=$apiKey');

    final contents = [
      ...history.map((m) => {
            'role': m['role'],
            'parts': [
              {'text': m['text']}
            ],
          }),
      {
        'role': 'user',
        'parts': [
          {'text': prompt}
        ],
      },
    ];

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'contents': contents}),
    );

    if (response.statusCode != 200) {
      final body = response.body;
      throw Exception('خطأ من خدمة Gemini (${response.statusCode}): $body');
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('لم يتم استلام رد من النموذج.');
    }
    final parts = candidates[0]['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('رد فارغ من النموذج.');
    }
    return parts.map((p) => p['text'] ?? '').join('\n').trim();
  }

  /// تلخيص نص طويل (مستخرج من PDF أو OCR) في نقاط أو فقرة موجزة.
  static Future<String> summarize(String text, {String style = 'موجز في فقرة واحدة'}) async {
    final trimmed = text.length > 20000 ? text.substring(0, 20000) : text;
    final prompt =
        'لخّص النص التالي باللغة العربية بأسلوب: $style. لا تضف مقدمات، ابدأ مباشرة بالملخص:\n\n$trimmed';
    return _generate(prompt: prompt);
  }

  /// سؤال/محادثة عن محتوى مستند معيّن، مع الاحتفاظ بسياق المحادثة.
  static Future<String> askAboutDocument({
    required String documentText,
    required String question,
    List<Map<String, String>> history = const [],
  }) async {
    final trimmed = documentText.length > 20000 ? documentText.substring(0, 20000) : documentText;
    final prompt =
        'فيما يلي محتوى مستند. أجب عن سؤال المستخدم بالاعتماد عليه فقط، وإن لم تجد الإجابة فيه قل ذلك بوضوح.\n\n'
        '--- محتوى المستند ---\n$trimmed\n--- نهاية المستند ---\n\nسؤال المستخدم: $question';
    return _generate(prompt: prompt, history: history);
  }
}
