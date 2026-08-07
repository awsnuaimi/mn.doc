part of '../../pdf_editor_screen.dart';


abstract final class _ShapeTransformGeometry {
  const _ShapeTransformGeometry._();

  static Offset rotatePoint(
    Offset point,
    Offset pivot,
    double radians,
  ) {
    final dx = point.dx - pivot.dx;
    final dy = point.dy - pivot.dy;
    final cosA = math.cos(radians);
    final sinA = math.sin(radians);

    return Offset(
      pivot.dx + dx * cosA - dy * sinA,
      pivot.dy + dx * sinA + dy * cosA,
    );
  }

  static Offset rotateAroundPivot(
    Offset point,
    Offset pivot,
    double radians,
  ) => rotatePoint(point, pivot, radians);

  static Offset flipHorizontal(Offset point, double centerX) =>
      Offset(centerX - (point.dx - centerX), point.dy);

  static Offset flipVertical(Offset point, double centerY) =>
      Offset(point.dx, centerY - (point.dy - centerY));

  static ({Offset start, Offset end}) rotateShape(
    _ShapeAnnotation shape,
    Offset pivot,
    double radians,
  ) => (
    start: rotatePoint(shape.start, pivot, radians),
    end: rotatePoint(shape.end, pivot, radians),
  );

  static ({Offset start, Offset end}) flipShapeHorizontal(
    _ShapeAnnotation shape,
    double centerX,
  ) => (
    start: flipHorizontal(shape.start, centerX),
    end: flipHorizontal(shape.end, centerX),
  );

  static ({Offset start, Offset end}) flipShapeVertical(
    _ShapeAnnotation shape,
    double centerY,
  ) => (
    start: flipVertical(shape.start, centerY),
    end: flipVertical(shape.end, centerY),
  );


  static Rect calculateSelectionBounds(
    Iterable<_ShapeAnnotation> shapes,
  ) {
    if (shapes.isEmpty) return Rect.zero;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final shape in shapes) {
      final pts = [shape.start, shape.end];
      for (final p in pts) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static Offset calculateGroupCenter(
    Iterable<_ShapeAnnotation> shapes,
  ) {
    return calculateSelectionBounds(shapes).center;
  }

}
