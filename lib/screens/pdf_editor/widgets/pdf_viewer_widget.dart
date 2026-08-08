import 'package:flutter/material.dart';

/// غلاف دلالي عام لمنطقة عارض الـPDF بالكامل (العارض نفسه + كل الطبقات
/// فوقه: نصوص، صور، أشكال، شريط أدوات عائم، أزرار زوم). يقبل قائمة
/// children عامة بدل معاملات محدّدة، بحيث يبقى الاستدعاء الفعلي لـ
/// SfPdfViewer.file (بكل معاملاته وcallbacks الخاصة فيه) أول عنصر
/// بالقائمة، ونضيف باقي الطبقات بجانبه بنفس ترتيب Stack الأصلي.
class PdfViewerWidget extends StatelessWidget {
  final List<Widget> children;

  const PdfViewerWidget({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: children,
    );
  }
}
