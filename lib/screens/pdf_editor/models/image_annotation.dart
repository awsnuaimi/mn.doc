part of '../../pdf_editor_screen.dart';

class _ImageAnnotation {
  int pageNumber;
  double dx;
  double dy;
  double width;
  double height;
  final Uint8List bytes;

  _ImageAnnotation({required this.pageNumber, required this.dx, required this.dy, required this.width, required this.height, required this.bytes});

  // بيانات الصورة نفسها لا تتغير بعد إنشاء التعليق، لذلك نسخ حالة المحرر
  // يشارك نفس Uint8List بدل استنساخ عدة ميغابايت مع كل Undo/Redo.
  // الموضع والحجم يبقيان مستقلين لأنهما قيم scalar داخل كائن جديد.
  _ImageAnnotation copy() => _ImageAnnotation(
    pageNumber: pageNumber,
    dx: dx,
    dy: dy,
    width: width,
    height: height,
    bytes: bytes,
  );
}
