part of '../../pdf_editor_screen.dart';

/// محاذاة/توسيط/توزيع الأشكال المحدَّدة (أكثر من شكل). نُقل من
/// pdf_editor_screen.dart لتقليل حجمها.
mixin ShapeLayoutModule on State<PdfEditorScreen> {
  Map<int, Size> get _pdfPageSizes;
  void _pushUndoState();
  void _scheduleAutoSave({bool markChanged = true});

  // حقل مملوك فعليًا بـShapeSelectionModule.
  List<_ShapeAnnotation> get _selectedShapes;

  void _centerSelectedShapesOnPage({required bool horizontal}) {
    if (_selectedShapes.isEmpty) return;
    final pageNumber = _selectedShapes.first.pageNumber;
    if (_selectedShapes.any((shape) => shape.pageNumber != pageNumber)) return;
    final pageSize = _pdfPageSizes[pageNumber];
    final bounds = _ShapeGeometry.selectionBounds(_selectedShapes);
    if (pageSize == null || bounds == null) return;

    final delta = horizontal
        ? Offset(pageSize.width / 2 - bounds.center.dx, 0)
        : Offset(0, pageSize.height / 2 - bounds.center.dy);
    if (delta.distanceSquared == 0) return;

    _pushUndoState();
    setState(() {
      for (final shape in _selectedShapes) {
        _ShapeGeometry.translate(shape, delta);
      }
    });
    _scheduleAutoSave();
  }

  void _alignSelectedShapes(String mode) {
    if (_selectedShapes.length < 2) return;
    final translations = _ShapeLayoutGeometry.alignmentTranslations(
      _selectedShapes,
      mode: mode,
    );
    if (translations.isEmpty) return;
    _pushUndoState();
    setState(() {
      for (final entry in translations.entries) {
        _ShapeGeometry.translate(entry.key, entry.value);
      }
    });
    _scheduleAutoSave();
  }

  void _distributeSelectedShapes(bool horizontal) {
    if (_selectedShapes.length < 3) return;
    final translations = _ShapeLayoutGeometry.centerDistributionTranslations(
      _selectedShapes,
      horizontal: horizontal,
    );
    if (translations.isEmpty) return;
    _pushUndoState();
    setState(() {
      for (final entry in translations.entries) {
        _ShapeGeometry.translate(entry.key, entry.value);
      }
    });
    _scheduleAutoSave();
  }

  void _distributeSelectedShapesByGap(bool horizontal) {
    if (_selectedShapes.length < 3) return;
    final translations = _ShapeLayoutGeometry.equalGapTranslations(
      _selectedShapes,
      horizontal: horizontal,
    );
    if (translations.isEmpty) return;

    _pushUndoState();
    setState(() {
      for (final entry in translations.entries) {
        _ShapeGeometry.translate(entry.key, entry.value);
      }
    });
    _scheduleAutoSave();
  }

}
