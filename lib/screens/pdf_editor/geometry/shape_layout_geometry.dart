part of '../../pdf_editor_screen.dart';

abstract final class _ShapeLayoutGeometry {
  static Map<_ShapeAnnotation, Offset> alignmentTranslations(
    Iterable<_ShapeAnnotation> shapes, {
    required String mode,
  }) {
    final items = shapes.toList(growable: false);
    final selection = _ShapeGeometry.selectionBounds(items);
    if (items.length < 2 || selection == null) return const {};

    final result = <_ShapeAnnotation, Offset>{};
    for (final shape in items) {
      final bounds = _ShapeGeometry.bounds(shape);
      Offset delta;
      switch (mode) {
        case 'left':
          delta = Offset(selection.left - bounds.left, 0);
          break;
        case 'right':
          delta = Offset(selection.right - bounds.right, 0);
          break;
        case 'top':
          delta = Offset(0, selection.top - bounds.top);
          break;
        case 'bottom':
          delta = Offset(0, selection.bottom - bounds.bottom);
          break;
        case 'centerH':
          delta = Offset(selection.center.dx - bounds.center.dx, 0);
          break;
        case 'centerV':
          delta = Offset(0, selection.center.dy - bounds.center.dy);
          break;
        default:
          continue;
      }
      if (delta != Offset.zero) result[shape] = delta;
    }
    return result;
  }

  static Map<_ShapeAnnotation, Offset> centerDistributionTranslations(
    Iterable<_ShapeAnnotation> shapes, {
    required bool horizontal,
  }) {
    final items = shapes.toList(growable: false);
    if (items.length < 3) return const {};
    items.sort((a, b) => horizontal
        ? _ShapeGeometry.bounds(a).center.dx
            .compareTo(_ShapeGeometry.bounds(b).center.dx)
        : _ShapeGeometry.bounds(a).center.dy
            .compareTo(_ShapeGeometry.bounds(b).center.dy));

    final first = _ShapeGeometry.bounds(items.first).center;
    final last = _ShapeGeometry.bounds(items.last).center;
    final step = horizontal
        ? (last.dx - first.dx) / (items.length - 1)
        : (last.dy - first.dy) / (items.length - 1);

    final result = <_ShapeAnnotation, Offset>{};
    for (var i = 1; i < items.length - 1; i++) {
      final bounds = _ShapeGeometry.bounds(items[i]);
      final target =
          (horizontal ? first.dx : first.dy) + step * i;
      final delta = horizontal
          ? Offset(target - bounds.center.dx, 0)
          : Offset(0, target - bounds.center.dy);
      if (delta != Offset.zero) result[items[i]] = delta;
    }
    return result;
  }

  static Map<_ShapeAnnotation, Offset> equalGapTranslations(
    Iterable<_ShapeAnnotation> shapes, {
    required bool horizontal,
  }) {
    final items = shapes.toList(growable: false);
    if (items.length < 3) return const {};
    items.sort((a, b) => horizontal
        ? _ShapeGeometry.bounds(a).left
            .compareTo(_ShapeGeometry.bounds(b).left)
        : _ShapeGeometry.bounds(a).top
            .compareTo(_ShapeGeometry.bounds(b).top));

    final first = _ShapeGeometry.bounds(items.first);
    final last = _ShapeGeometry.bounds(items.last);
    final totalExtent = items.fold<double>(
      0,
      (sum, shape) => sum +
          (horizontal
              ? _ShapeGeometry.bounds(shape).width
              : _ShapeGeometry.bounds(shape).height),
    );
    final span =
        horizontal ? last.right - first.left : last.bottom - first.top;
    final gap = (span - totalExtent) / (items.length - 1);

    var cursor = horizontal ? first.right + gap : first.bottom + gap;
    final result = <_ShapeAnnotation, Offset>{};
    for (var i = 1; i < items.length - 1; i++) {
      final bounds = _ShapeGeometry.bounds(items[i]);
      final delta = horizontal
          ? Offset(cursor - bounds.left, 0)
          : Offset(0, cursor - bounds.top);
      if (delta != Offset.zero) result[items[i]] = delta;
      cursor += (horizontal ? bounds.width : bounds.height) + gap;
    }
    return result;
  }
}
