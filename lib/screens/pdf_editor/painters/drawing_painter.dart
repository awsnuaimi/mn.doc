part of '../../pdf_editor_screen.dart';

class _PdfDrawingPainter extends CustomPainter {
  final _DrawingStroke stroke;
  final _PdfPageTransform transform;

  const _PdfDrawingPainter({
    required this.stroke,
    required this.transform,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (stroke.points.length < 2) return;
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.thickness * transform.scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final first = transform.pdfToViewer(stroke.points.first);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < stroke.points.length; i++) {
      final p = transform.pdfToViewer(stroke.points[i]);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PdfDrawingPainter oldDelegate) => true;
}
