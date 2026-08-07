import 'dart:ui';

/// يمثل صورة تمت إضافتها فوق صفحة PDF.
class ImageAnnotation {
  final String id;

  final int page;

  final Uint8List bytes;

  Offset position;

  Size size;

  double rotation;

  bool isSelected;

  ImageAnnotation({
    required this.id,
    required this.page,
    required this.bytes,
    required this.position,
    required this.size,
    this.rotation = 0,
    this.isSelected = false,
  });

  ImageAnnotation copyWith({
    String? id,
    int? page,
    Uint8List? bytes,
    Offset? position,
    Size? size,
    double? rotation,
    bool? isSelected,
  }) {
    return ImageAnnotation(
      id: id ?? this.id,
      page: page ?? this.page,
      bytes: bytes ?? this.bytes,
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  ImageAnnotation clone() {
    return ImageAnnotation(
      id: id,
      page: page,
      bytes: bytes,
      position: position,
      size: size,
      rotation: rotation,
      isSelected: isSelected,
    );
  }
}