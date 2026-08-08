part of '../../pdf_editor_screen.dart';

/// لقطة قابلة للتوسّع لحالة المحرر.
///
/// تحتوي على حالة النصوص والصور والرسومات والأشكال
/// حتى يتم استخدامها في نظام Undo / Redo.
///
/// الصور تستخدم ImageAnnotation المستقل الموجود في:
/// lib/screens/pdf_editor/models/image_annotation.dart
///
/// يتم نسخ هندسة الصورة فقط، بينما تتم مشاركة Uint8List
/// الخاصة بالصورة نفسها لتجنب نسخ بيانات الصور الكبيرة
/// عند إنشاء عدة لقطات لحالة المحرر.
class _EditorSnapshot {
  final List<_TextAnnotation> textAnnotations;
  final List<ImageAnnotation> imageAnnotations;
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
    List<ImageAnnotation> images,
    List<_DrawingStroke> strokes,
    List<_ShapeAnnotation> shapes,
  ) {
    return _EditorSnapshot(
      textAnnotations: annotations
          .map((a) => a.copy())
          .toList(growable: false),
      imageAnnotations: images
          .map((a) => a.copy())
          .toList(growable: false),
      drawingStrokes: strokes
          .map((s) => s.copy())
          .toList(growable: false),
      shapeAnnotations: shapes
          .map((s) => s.copy())
          .toList(growable: false),
    );
  }
}