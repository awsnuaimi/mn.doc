part of '../../pdf_editor_screen.dart';

class _PdfShapePainter extends CustomPainter {
  final _ShapeAnnotation shape;
  final _PdfPageTransform transform;
  final bool selected;

  const _PdfShapePainter({
    required this.shape,
    required this.transform,
    this.selected = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final start = transform.pdfToViewer(shape.start);
    final end = transform.pdfToViewer(shape.end);
    final paint = Paint()
      ..color = shape.color
      ..strokeWidth = shape.thickness * transform.scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (shape.kind == _ShapeKind.line || shape.kind == _ShapeKind.arrow) {
      _paintStyledLine(canvas, start, end, paint, shape.lineStyle);
      if (shape.kind == _ShapeKind.arrow) {
        final delta = end - start;
        final length = delta.distance;
        if (length > 0.01) {
          final unit = delta / length;
          final perp = Offset(-unit.dy, unit.dx);
          final head = (10.0 + shape.thickness * 2)
                  .clamp(10.0, 24.0)
                  .toDouble() *
              transform.scale;
          final wing = head * 0.45;
          final base = end - unit * head;
          final p1 = base + perp * wing;
          final p2 = base - perp * wing;
          canvas.drawLine(end, p1, paint);
          canvas.drawLine(end, p2, paint);
          if (shape.arrowHeadStyle == _ArrowHeadStyle.closed) {
            canvas.drawLine(p1, p2, paint);
          }
        }
      }
      if (selected) _paintSelection(canvas, start, end);
      return;
    }

    final rect = Rect.fromPoints(start, end);
    final fill = shape.fillColor;
    if (fill != null) {
      final fillPaint = Paint()
        ..color = fill.withOpacity(shape.fillOpacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      if (shape.kind == _ShapeKind.rectangle) {
        canvas.drawRect(rect, fillPaint);
      } else {
        canvas.drawOval(rect, fillPaint);
      }
    }
    if (shape.kind == _ShapeKind.rectangle) {
      canvas.drawRect(rect, paint);
    } else {
      canvas.drawOval(rect, paint);
    }

    if (selected) _paintSelection(canvas, start, end);
  }

  void _paintStyledLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    _ShapeLineStyle style,
  ) {
    if (style == _ShapeLineStyle.solid) {
      canvas.drawLine(start, end, paint);
      return;
    }
    final delta = end - start;
    final length = delta.distance;
    if (length <= 0.01) return;
    final unit = delta / length;
    final dash =
        (style == _ShapeLineStyle.dashed ? 10.0 : 2.0) * transform.scale;
    final gap =
        (style == _ShapeLineStyle.dashed ? 6.0 : 5.0) * transform.scale;
    var cursor = 0.0;
    while (cursor < length) {
      final segEnd = (cursor + dash).clamp(0.0, length).toDouble();
      canvas.drawLine(start + unit * cursor, start + unit * segEnd, paint);
      cursor += dash + gap;
    }
  }

  void _paintSelection(Canvas canvas, Offset start, Offset end) {
    final selectionPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleBorder = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final bounds = Rect.fromPoints(start, end).inflate(6);
    canvas.drawRect(bounds, selectionPaint);
    for (final p in [start, end]) {
      canvas.drawCircle(p, 7, handlePaint);
      canvas.drawCircle(p, 7, handleBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _PdfShapePainter oldDelegate) => true;
}
