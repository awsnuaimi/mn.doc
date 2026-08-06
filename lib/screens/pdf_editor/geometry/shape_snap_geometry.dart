part of '../../pdf_editor_screen.dart';

class _ShapeSnapResult {
  const _ShapeSnapResult({
    required this.delta,
    this.guideX,
    this.guideY,
  });

  final Offset delta;
  final double? guideX;
  final double? guideY;
}

abstract final class _ShapeSnapGeometry {
  static _ShapeSnapResult calculate({
    required Rect movingBounds,
    required Offset proposed,
    required int pageNumber,
    required Set<_ShapeAnnotation> moving,
    required Size? pageSize,
    required Iterable<_ShapeAnnotation> shapes,
    required double zoomLevel,
  }) {
    final moved = movingBounds.shift(proposed);
    final threshold = 6.0 / zoomLevel;
    double? bestDx;
    double? bestDy;
    double? guideX;
    double? guideY;

    final xTargets = <double>[];
    final yTargets = <double>[];
    if (pageSize != null) {
      xTargets.addAll([0, pageSize.width / 2, pageSize.width]);
      yTargets.addAll([0, pageSize.height / 2, pageSize.height]);
    }

    for (final other in shapes) {
      if (other.pageNumber != pageNumber || moving.contains(other)) continue;
      final bounds = _ShapeGeometry.bounds(other);
      xTargets.addAll([bounds.left, bounds.center.dx, bounds.right]);
      yTargets.addAll([bounds.top, bounds.center.dy, bounds.bottom]);
    }

    final movingXs = [moved.left, moved.center.dx, moved.right];
    final movingYs = [moved.top, moved.center.dy, moved.bottom];

    for (final movingX in movingXs) {
      for (final targetX in xTargets) {
        final distance = targetX - movingX;
        if (distance.abs() <= threshold &&
            (bestDx == null || distance.abs() < bestDx.abs())) {
          bestDx = distance;
          guideX = targetX;
        }
      }
    }

    for (final movingY in movingYs) {
      for (final targetY in yTargets) {
        final distance = targetY - movingY;
        if (distance.abs() <= threshold &&
            (bestDy == null || distance.abs() < bestDy.abs())) {
          bestDy = distance;
          guideY = targetY;
        }
      }
    }

    return _ShapeSnapResult(
      delta: proposed + Offset(bestDx ?? 0, bestDy ?? 0),
      guideX: guideX,
      guideY: guideY,
    );
  }
}
