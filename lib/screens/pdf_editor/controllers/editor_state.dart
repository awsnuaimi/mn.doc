import 'package:flutter/material.dart';

class EditorState extends ChangeNotifier {
  bool saving = false;

  bool addTextMode = false;
  bool addImageMode = false;

  bool drawMode = false;
  bool eraserMode = false;

  bool shapeEditMode = false;

  bool searchVisible = false;

  bool hasUnsavedChanges = false;

  int currentPage = 1;

  double zoomLevel = 1.0;

  void setSaving(bool value) {
    saving = value;
    notifyListeners();
  }

  void setCurrentPage(int page) {
    currentPage = page;
    notifyListeners();
  }

  void setZoom(double zoom) {
    zoomLevel = zoom;
    notifyListeners();
  }

  void setUnsaved(bool value) {
    hasUnsavedChanges = value;
    notifyListeners();
  }

  void toggleSearch() {
    searchVisible = !searchVisible;
    notifyListeners();
  }

  void toggleTextMode() {
    addTextMode = !addTextMode;
    if (addTextMode) {
      addImageMode = false;
      drawMode = false;
      eraserMode = false;
      shapeEditMode = false;
    }
    notifyListeners();
  }

  void toggleImageMode() {
    addImageMode = !addImageMode;
    if (addImageMode) {
      addTextMode = false;
      drawMode = false;
      eraserMode = false;
      shapeEditMode = false;
    }
    notifyListeners();
  }

  void toggleDrawMode() {
    drawMode = !drawMode;
    if (drawMode) {
      addTextMode = false;
      addImageMode = false;
      eraserMode = false;
      shapeEditMode = false;
    }
    notifyListeners();
  }

  void toggleEraserMode() {
    eraserMode = !eraserMode;
    if (eraserMode) {
      addTextMode = false;
      addImageMode = false;
      drawMode = false;
      shapeEditMode = false;
    }
    notifyListeners();
  }

  void toggleShapeEdit() {
    shapeEditMode = !shapeEditMode;
    if (shapeEditMode) {
      addTextMode = false;
      addImageMode = false;
      drawMode = false;
      eraserMode = false;
    }
    notifyListeners();
  }
}