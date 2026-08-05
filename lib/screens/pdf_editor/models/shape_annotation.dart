part of '../../pdf_editor_screen.dart';

enum _ShapeKind { line, arrow, rectangle, ellipse }
enum _ShapeLineStyle { solid, dashed, dotted }
enum _ArrowHeadStyle { open, closed }

class _ShapeAnnotation {
  int pageNumber;
  Offset start;
  Offset end;
  _ShapeKind kind;
  Color color;
  double thickness;
  Color? fillColor;
  double fillOpacity;
  _ShapeLineStyle lineStyle;
  _ArrowHeadStyle arrowHeadStyle;

  _ShapeAnnotation({
    required this.pageNumber,
    required this.start,
    required this.end,
    required this.kind,
    required this.color,
    required this.thickness,
    this.fillColor,
    this.fillOpacity = 0.25,
    this.lineStyle = _ShapeLineStyle.solid,
    this.arrowHeadStyle = _ArrowHeadStyle.open,
  });

  _ShapeAnnotation copy() => _ShapeAnnotation(
        pageNumber: pageNumber,
        start: start,
        end: end,
        kind: kind,
        color: color,
        thickness: thickness,
        fillColor: fillColor,
        fillOpacity: fillOpacity,
        lineStyle: lineStyle,
        arrowHeadStyle: arrowHeadStyle,
      );
}
