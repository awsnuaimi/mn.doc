part of '../../pdf_editor_screen.dart';

/// إنشاء الأشكال الجديدة (خط/سهم/مستطيل/دائرة) بالسحب على الصفحة.
/// نُقل من pdf_editor_screen.dart لتقليل حجمها.
///
/// الحقول المشتركة بين كل وحدات الأشكال (التحديد، الرسم، التحديد المتعدد،
/// المحاذاة، الخصائص) مملوكة فعليًا بـShapeSelectionModule تفاديًا لتكرار
/// إعلانها كحقول ملموسة بأكثر من مكان (Dart يرفض ذلك). هذا الملف يطلبها
/// كـgetters/setters مجرّدة فقط.
mixin ShapeDrawingModule on State<PdfEditorScreen> {
  EditorState get editorState;
  PdfViewerController get _controller;
  Color get _drawColor;
  double get _drawThickness;
  Offset? _eventToPdfPoint(PointerEvent event, int pageNumber);
  void _pushUndoState();
  void _scheduleAutoSave({bool markChanged = true});

  List<_ShapeAnnotation> get _shapeAnnotations;
  _ShapeKind? get _shapeMode;
  set _shapeMode(_ShapeKind? value);
  _ShapeAnnotation? get _selectedShape;
  set _selectedShape(_ShapeAnnotation? value);
  _ShapeAnnotation? get _activeShape;
  set _activeShape(_ShapeAnnotation? value);

  // حقول من وحدات أخرى تُصفَّر عند الدخول لوضع رسم شكل جديد.
  _DrawingStroke? get _activeDrawingStroke;
  set _activeDrawingStroke(_DrawingStroke? value);
  Uint8List? get _pendingImageBytes;
  set _pendingImageBytes(Uint8List? value);

  void _toggleShapeMode(_ShapeKind kind) {
    setState(() {
      _shapeMode = _shapeMode == kind ? null : kind;
      editorState.shapeEditMode = false;
      _selectedShape = null;
      editorState.drawMode = false;
      editorState.eraserMode = false;
      _activeDrawingStroke = null;
      _activeShape = null;
      editorState.addTextMode = false;
      editorState.addImageMode = false;
      _pendingImageBytes = null;
      _controller.annotationMode = PdfAnnotationMode.none;
    });
  }

  void _onShapePointerDown(PointerDownEvent event) {
    final kind = _shapeMode;
    if (kind == null) return;
    final pdf = _eventToPdfPoint(event, editorState.currentPage);
    if (pdf == null) return;
    _pushUndoState();
    setState(() {
      _activeShape = _ShapeAnnotation(
        pageNumber: editorState.currentPage,
        start: pdf,
        end: pdf,
        kind: kind,
        color: _drawColor,
        thickness: _drawThickness,
      );
      _shapeAnnotations.add(_activeShape!);
    });
  }

  void _onShapePointerMove(PointerMoveEvent event) {
    final shape = _activeShape;
    if (shape == null) return;
    final pdf = _eventToPdfPoint(event, shape.pageNumber);
    if (pdf == null) return;
    setState(() => shape.end = pdf);
  }

  void _finishShapeGesture() {
    final shape = _activeShape;
    if (shape == null) return;
    final meaningful = (shape.end - shape.start).distance >= 2.0;
    setState(() {
      if (!meaningful) _shapeAnnotations.remove(shape);
      _activeShape = null;
    });
    if (meaningful) _scheduleAutoSave();
  }
}
