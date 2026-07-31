import 'dart:convert';
import 'dart:typed_data';
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
  static const _timeout = Duration(seconds: 30);

  /// عدد أقصى لرسائل سجل المحادثة المُرسلة مع كل طلب — يمنع تضخم
  /// حجم الطلب (واستهلاك الحصة المجانية) مع محادثات طويلة.
  static const _maxHistoryMessages = 20;

  /// يترجم رمز حالة HTTP لرسالة عربية مفهومة للمستخدم العادي.
  static Exception _friendlyError(int statusCode, String body) {
    switch (statusCode) {
      case 429:
        return Exception('لقد وصلت إلى الحد المجاني المسموح مؤقتًا من Gemini. حاول مرة أخرى بعد دقيقة.');
      case 503:
      case 500:
      case 502:
        return Exception('خدمة Gemini غير متاحة حاليًا (ضغط على الخوادم). حاول مرة أخرى بعد قليل.');
      case 400:
        return Exception('طلب غير صالح — قد يكون مفتاح API غير صحيح. تحقق منه بالإعدادات.');
      case 403:
        return Exception('تم رفض الوصول — تأكد من صحة مفتاح API بالإعدادات.');
      default:
        return Exception('خطأ من خدمة Gemini ($statusCode): $body');
    }
  }

  static Future<String> _generate({
    required String prompt,
    List<Map<String, String>> history = const [],
  }) async {
    final apiKey = await AiSettings.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('لم يتم إدخال مفتاح Gemini API بعد. اذهب إلى الإعدادات لإضافته (مجاني).');
    }

    final uri = Uri.parse('$_baseUrl/$_model:generateContent?key=$apiKey');

    // قصّ السجل لآخر عدد رسائل مسموح لتفادي تضخم الطلب مع محادثات طويلة
    final trimmedHistory =
        history.length > _maxHistoryMessages ? history.sublist(history.length - _maxHistoryMessages) : history;

    final contents = [
      ...trimmedHistory.map((m) => {
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

    late final http.Response response;
    try {
      response = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'contents': contents}))
          .timeout(_timeout);
    } catch (e) {
      throw Exception('تعذّر الاتصال بخدمة Gemini (تحقق من اتصال الإنترنت): $e');
    }

    if (response.statusCode != 200) {
      throw _friendlyError(response.statusCode, response.body);
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

  /// يكتشف نوع صورة (JPEG/PNG/WebP) من أول بايتات الملف (Magic Bytes)
  /// بدل افتراض JPEG دائمًا — يحسّن دقة قراءة الصور من مصادر مختلفة.
  static String _detectImageMimeType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    // JPEG أو أي نوع آخر غير معروف — الافتراضي الأكثر شيوعًا لصور الكاميرا
    return 'image/jpeg';
  }

  /// تعرف ضوئي على النص داخل صورة عبر الذكاء الاصطناعي — يدعم العربية
  /// وأي لغة أخرى (بعكس التعرف الضوئي المجاني المحلي المحدود بلغات معيّنة).
  /// يحتاج اتصال إنترنت ومفتاح Gemini API مجاني.
  static Future<String> extractTextFromImage(Uint8List imageBytes) async {
    final apiKey = await AiSettings.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('لم يتم إدخال مفتاح Gemini API بعد. اذهب إلى الإعدادات لإضافته (مجاني).');
    }

    final uri = Uri.parse('$_baseUrl/$_model:generateContent?key=$apiKey');
    final base64Image = base64Encode(imageBytes);
    final mimeType = _detectImageMimeType(imageBytes);

    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': 'استخرج كل النص الموجود بهذه الصورة بالضبط كما هو، بدون أي تعليق أو مقدمة أو ترجمة — فقط النص الخام كما يظهر بالصورة.'},
            {
              'inline_data': {'mime_type': mimeType, 'data': base64Image}
            },
          ],
        },
      ],
    });

    late final http.Response response;
    try {
      response = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body).timeout(_timeout);
    } catch (e) {
      throw Exception('تعذّر الاتصال بخدمة Gemini (تحقق من اتصال الإنترنت): $e');
    }

    if (response.statusCode != 200) {
      throw _friendlyError(response.statusCode, response.body);
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
}
