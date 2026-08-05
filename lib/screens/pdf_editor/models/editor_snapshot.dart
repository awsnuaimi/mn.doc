part of '../../pdf_editor_screen.dart';

/// لقطة قابلة للتوسّع لحالة المحرر. تحتوي النصوص والصور المخصّصة.
/// نسخ الصور هنا خفيف: _ImageAnnotation.copy() ينسخ هندسة التعليق فقط
/// ويشارك bytes الصورة غير المعدّلة بين اللقطات، لمنع تضخم ذاكرة Undo/Redo.
class _EditorSnapshot {
  final List<_TextAnnotation> textAnnotations;
  final List<_ImageAnnotation> imageAnnotations;
  final List<_DrawingStroke> drawingStrokes;
  final List<_ShapeAnnotation> shapeAnnotations;

  _EditorSnapshot({
    required this.textAnnotations,
    required this.imageAnnotations,
    required this.drawingStrokes,
    required this.shapeAnnotations,
  });

  factory _EditorSnapshot.capture(
    List<_TextAnnotation> annotations,
    List<_ImageAnnotation> images,
    List<_DrawingStroke> strokes,
    List<_ShapeAnnotation> shapes,
  ) =>
      _EditorSnapshot(
        textAnnotations: annotations.map((a) => a.copy()).toList(growable: false),
        imageAnnotations: images.map((a) => a.copy()).toList(growable: false),
        drawingStrokes: strokes.map((s) => s.copy()).toList(growable: false),
        shapeAnnotations: shapes.map((s) => s.copy()).toList(growable: false),
      );
}
