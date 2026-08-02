import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// يحمّل خط "Noto Naskh Arabic" المضمّن بالتطبيق — الخطوط القياسية
/// بمكتبات PDF (Helvetica وغيرها) لا تدعم الحروف العربية إطلاقًا،
/// فلازم خط TrueType حقيقي مضمّن لعرض/تصدير أي نص عربي بشكل صحيح.
class ArabicFontLoader {
  static const _assetPath = 'assets/fonts/NotoNaskhArabic-Regular.ttf';

  static ByteData? _cachedByteData;
  static pw.Font? _cachedPwFont;

  static Future<ByteData> _loadByteData() async {
    return _cachedByteData ??= await rootBundle.load(_assetPath);
  }

  /// خط لاستخدامه مع مكتبة Syncfusion (محرر PDF، العلامة المائية، تعديل النص).
  static Future<sf.PdfFont> loadSyncfusionFont(double size, {bool bold = false}) async {
    final byteData = await _loadByteData();
    final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
    return sf.PdfTrueTypeFont(bytes, size, style: bold ? sf.PdfFontStyle.bold : sf.PdfFontStyle.regular);
  }

  /// خط لاستخدامه مع مكتبة pdf (إنشاء مستند جديد، تحويل Word، الإملاء الصوتي).
  static Future<pw.Font> loadPwFont() async {
    if (_cachedPwFont != null) return _cachedPwFont!;
    final byteData = await _loadByteData();
    _cachedPwFont = pw.Font.ttf(byteData);
    return _cachedPwFont!;
  }
}
