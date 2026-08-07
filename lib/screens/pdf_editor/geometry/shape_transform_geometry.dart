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
}
