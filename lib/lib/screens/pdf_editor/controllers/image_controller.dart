import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/image_annotation.dart';
import '../models/editor_snapshot.dart';

class ImageController extends ChangeNotifier {
  final List<ImageAnnotation> images = [];

  Uint8List? pendingImageBytes;

  ImageAnnotation? draggingImage;

  EditorSnapshot? dragSnapshot;

  bool dragChanged = false;

  void add(ImageAnnotation image) {
    images.add(image);
    notifyListeners();
  }

  void remove(ImageAnnotation image) {
    images.remove(image);
    notifyListeners();
  }

  void clear() {
    images.clear();
    notifyListeners();
  }

  void startDrag(
    ImageAnnotation image,
    EditorSnapshot snapshot,
  ) {
    draggingImage = image;
    dragSnapshot = snapshot;
    dragChanged = false;
  }

  void finishDrag() {
    draggingImage = null;
    dragSnapshot = null;
    dragChanged = false;
    notifyListeners();
  }

  void markChanged() {
    dragChanged = true;
  }

  void setPendingImage(Uint8List bytes) {
    pendingImageBytes = bytes;
    notifyListeners();
  }

  void clearPendingImage() {
    pendingImageBytes = null;
    notifyListeners();
  }
}