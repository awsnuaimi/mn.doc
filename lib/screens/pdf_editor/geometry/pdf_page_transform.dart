part of '../../pdf_editor_screen.dart';

/// تحويل هندسي من إحداثيات صفحة PDF (points) إلى إحداثيات الـViewer (pixels).
/// يُعاد حسابه/معايرته من ضغطة Syncfusion الحقيقية، ولا يدخل في بيانات النص.
class _PdfPageTransform {
  final double scale;
  final Offset origin;

  const _PdfPageTransform({required this.scale, required this.origin});

  Offset pdfToViewer(Offset pdfPoint) => origin + pdfPoint * scale;
  Offset viewerToPdf(Offset viewerPoint) => (viewerPoint - origin) / scale;
}
