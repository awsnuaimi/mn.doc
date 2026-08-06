part of '../../pdf_editor_screen.dart';

class _PdfSnapGuidePainter extends CustomPainter {
  final double? guideX;
  final double? guideY;
  final _PdfPageTransform transform;

  const _PdfSnapGuidePainter({
    required this.guideX,
    required this.guideY,
    required this.transform,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.75)
      ..strokeWidth = 1.2;
    if (guideX != null) {
      final x = transform.pdfToViewer(Offset(guideX!, 0)).dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    if (guideY != null) {
      final y = transform.pdfToViewer(Offset(0, guideY!)).dy;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PdfSnapGuidePainter oldDelegate) =>
      guideX != oldDelegate.guideX ||
      guideY != oldDelegate.guideY ||
      transform != oldDelegate.transform;
}
