part of '../../pdf_editor_screen.dart';

class _DrawingStroke {
  int pageNumber;
  final List<Offset> points; // PDF points
  Color color;
  double thickness; // PDF points

  _DrawingStroke({
    required this.pageNumber,
    required this.points,
    required this.color,
    required this.thickness,
  });

  _DrawingStroke copy() => _DrawingStroke(
        pageNumber: pageNumber,
        points: List<Offset>.from(points),
        color: color,
        thickness: thickness,
      );
}
