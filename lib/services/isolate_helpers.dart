import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:image/image.dart' as img;

/// ملاحظة: هذه الدوال يجب أن تبقى "top-level" (خارج أي كلاس) عشان
/// نقدر نشغّلها عبر compute() بخيط (Isolate) منفصل بالخلفية — هيك ما
/// تتجمد واجهة المستخدم أثناء معالجة ملفات PDF كبيرة أو صور عالية الدقة.

/// يستخرج كامل النص من بايتات ملف PDF — يعمل بخيط منفصل عبر compute().
String extractPdfTextIsolate(Uint8List bytes) {
  final document = sf.PdfDocument(inputBytes: bytes);
  final text = sf.PdfTextExtractor(document).extractText();
  document.dispose();
  return text;
}

/// معطيات تحسين الصورة — يجب أن تبقى قابلة للتسلسل بين الـ Isolates
/// (لا كائنات معقّدة)، لذا نستخدم كلاسًا بسيطًا فيه القيم الأساسية فقط.
class EnhanceParams {
  final Uint8List bytes;
  final double contrast;
  final double brightness;
  EnhanceParams({required this.bytes, this.contrast = 1.4, this.brightness = 1.05});
}

/// يحوّل صورة إلى شكل "ممسوح ضوئيًا" (أبيض وأسود) بتباين وسطوع قابلين
/// للتعديل — يعمل بخيط منفصل عبر compute() لتفادي تجميد الواجهة.
Uint8List enhanceImageIsolate(EnhanceParams params) {
  final decoded = img.decodeImage(params.bytes);
  if (decoded == null) return params.bytes;
  var processed = img.grayscale(decoded);
  processed = img.adjustColor(processed, contrast: params.contrast, brightness: params.brightness);
  return Uint8List.fromList(img.encodeJpg(processed, quality: 90));
}
