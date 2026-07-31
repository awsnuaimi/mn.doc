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

/// يحوّل صورة إلى شكل "ممسوح ضوئيًا" (أبيض وأسود بتباين أعلى) — يعمل
/// بخيط منفصل عبر compute() لتفادي تجميد الواجهة أثناء التقاط عدة صفحات.
Uint8List enhanceImageIsolate(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  var processed = img.grayscale(decoded);
  processed = img.adjustColor(processed, contrast: 1.4, brightness: 1.05);
  return Uint8List.fromList(img.encodeJpg(processed, quality: 90));
}
