import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/image_annotation.dart';

class ImageService {
  const ImageService();

  Future<Uint8List?> pickImage() async {
    final picker = ImagePicker();

    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );

    if (file == null) {
      return null;
    }

    return File(file.path).readAsBytes();
  }

  Size resize(
    Size currentSize,
    double factor,
    Size pageSize,
  ) {
    final width = (currentSize.width * factor)
        .clamp(30.0, pageSize.width)
        .toDouble();

    final height = (currentSize.height * factor)
        .clamp(30.0, pageSize.height)
        .toDouble();

    return Size(width, height);
  }

  Offset clampPosition({
    required Offset position,
    required Size imageSize,
    required Size pageSize,
  }) {
    return Offset(
      position.dx.clamp(
        0.0,
        (pageSize.width - imageSize.width)
            .clamp(0.0, pageSize.width),
      ),
      position.dy.clamp(
        0.0,
        (pageSize.height - imageSize.height)
            .clamp(0.0, pageSize.height),
      ),
    );
  }

  Offset applyDrag({
    required Offset current,
    required Offset delta,
    required Size imageSize,
    required Size pageSize,
  }) {
    return clampPosition(
      position: current + delta,
      imageSize: imageSize,
      pageSize: pageSize,
    );
  }

  ImageAnnotation duplicate(
    ImageAnnotation image,
  ) {
    return image.copy();
  }
}