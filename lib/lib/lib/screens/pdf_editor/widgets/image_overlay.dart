import 'package:flutter/material.dart';

import '../models/image_annotation.dart';
import '../geometry/pdf_page_transform.dart';

class ImageOverlay extends StatelessWidget {
  final ImageAnnotation annotation;
  final PdfPageTransform transform;

  final VoidCallback onTap;

  final GestureDragStartCallback onPanStart;

  final GestureDragUpdateCallback onPanUpdate;

  final GestureDragEndCallback onPanEnd;

  final GestureDragCancelCallback onPanCancel;

  const ImageOverlay({
    super.key,
    required this.annotation,
    required this.transform,
    required this.onTap,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
  });

  @override
  Widget build(BuildContext context) {
    final point = transform.pdfToViewer(
      Offset(annotation.dx, annotation.dy),
    );

    return Positioned(
      left: point.dx,
      top: point.dy,
      width: annotation.width * transform.scale,
      height: annotation.height * transform.scale,
      child: GestureDetector(
        onTap: onTap,
        onPanStart: onPanStart,
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
        onPanCancel: onPanCancel,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.blue,
              width: 1,
            ),
          ),
          child: Image.memory(
            annotation.bytes,
            fit: BoxFit.fill,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image_rounded),
          ),
        ),
      ),
    );
  }
}