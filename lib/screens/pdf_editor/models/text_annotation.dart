part of '../../pdf_editor_screen.dart';

/// نص مضاف إلى صفحة PDF.
///
/// المصدر الوحيد للحقيقة هو (pageNumber, dx, dy) بإحداثيات صفحة PDF نفسها.
/// لا نخزّن أي إحداثيات شاشة داخل التعليق؛ موضع المعاينة يُشتق لحظيًا من
/// تحويل الصفحة الحالية، لذلك الإضافة والنقل والحفظ تستخدم النظام نفسه.
class _TextAnnotation {
  int pageNumber; // يبدأ من 1
  double dx; // X بنقاط PDF
  double dy; // Y بنقاط PDF
  String text;
  double fontSize;
  Color color;
  TextAlign alignment;

  _TextAnnotation({
    required this.pageNumber,
    required this.dx,
    required this.dy,
    required this.text,
    this.fontSize = 16,
    this.color = Colors.black,
    this.alignment = TextAlign.right,
  });

  _TextAnnotation copy() => _TextAnnotation(
        pageNumber: pageNumber,
        dx: dx,
        dy: dy,
        text: text,
        fontSize: fontSize,
        color: color,
        alignment: alignment,
      );
}
