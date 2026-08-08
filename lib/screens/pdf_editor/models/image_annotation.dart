part of '../../pdf_editor_screen.dart';

/// يمثل صورة تمت إضافتها فوق صفحة PDF.
///
/// هذا النموذج نُقل من pdf_editor_screen.dart إلى ملف مستقل
/// لتقليل حجم الشاشة الرئيسية للمحرر مع الحفاظ على نفس
/// نظام الإحداثيات والسلوك الحالي.
class ImageAnnotation {
  int pageNumber;

  double dx;

  double dy;

  double width;

  double height;

  final Uint8List bytes;

  ImageAnnotation({
    required this.pageNumber,
    required this.dx,
    required this.dy,
    required this.width,
    required this.height,
    required this.bytes,
  });

  /// إنشاء نسخة من حالة الصورة لاستخدامها في Undo / Redo.
  ///
  /// تتم مشاركة bytes بدل نسخ بيانات الصورة نفسها لتقليل
  /// استهلاك الذاكرة عند إنشاء عدة لقطات.
  ImageAnnotation copy() {
    return ImageAnnotation(
      pageNumber: pageNumber,
      dx: dx,
      dy: dy,
      width: width,
      height: height,
      bytes: bytes,
    );
  }
}