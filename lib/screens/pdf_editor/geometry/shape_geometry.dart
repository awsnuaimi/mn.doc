part of '../../pdf_editor_screen.dart';

abstract final class _ShapeGeometry {
  static Rect bounds(_ShapeAnnotation shape) =>
      Rect.fromPoints(shape.start, shape.end);

  static Rect? selectionBounds(Iterable<_ShapeAnnotation> shapes) {
    final items = shapes.toList(growable: false);
    if (items.isEmpty) return null;

    var bounds = _ShapeGeometry.bounds(items.first);
    for (var i = 1; i < items.length; i++) {
      bounds = bounds.expandToInclude(_ShapeGeometry.bounds(items[i]));
    }
    return bounds;
  }

  static void translate(_ShapeAnnotation shape, Offset delta) {
    shape.start += delta;
    shape.end += delta;
  }
}
