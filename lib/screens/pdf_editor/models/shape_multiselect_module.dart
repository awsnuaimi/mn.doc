part of '../../pdf_editor_screen.dart';

/// التحديد المتعدد للأشكال: تفعيل وضع التحديد المتعدد، تحديد الكل/عكس
/// التحديد على الصفحة، ونسخ/لصق/تكرار/حذف/ترتيب الطبقات كمجموعة.
/// نُقل من pdf_editor_screen.dart لتقليل حجمها.
mixin ShapeMultiselectModule on State<PdfEditorScreen> {
  EditorState get editorState;
  Map<int, Size> get _pdfPageSizes;
  void _pushUndoState();
  void _scheduleAutoSave({bool markChanged = true});
  Offset _shapePasteOffset(_ShapeAnnotation source);

  // حقول مملوكة فعليًا بـShapeSelectionModule.
  List<_ShapeAnnotation> get _shapeAnnotations;
  _ShapeAnnotation? get _selectedShape;
  set _selectedShape(_ShapeAnnotation? value);
  List<_ShapeAnnotation> get _selectedShapes;
  List<_ShapeAnnotation> get _shapeClipboardGroup;
  set _shapeClipboardGroup(List<_ShapeAnnotation> value);
  bool get _multiSelectMode;
  set _multiSelectMode(bool value);

  void _toggleMultiSelectMode() {
    setState(() {
      _multiSelectMode = !_multiSelectMode;
      _selectedShapes.clear();
      if (_multiSelectMode && _selectedShape != null) {
        _selectedShapes.add(_selectedShape!);
      }
    });
  }

  void _selectAllShapesOnCurrentPage() {
    final pageShapes = _shapeAnnotations
        .where((shape) => shape.pageNumber == editorState.currentPage)
        .toList(growable: false);
    setState(() {
      _selectedShapes
        ..clear()
        ..addAll(pageShapes);
      _selectedShape = pageShapes.isEmpty ? null : pageShapes.last;
    });
  }

  void _invertShapeSelectionOnCurrentPage() {
    final pageShapes = _shapeAnnotations
        .where((shape) => shape.pageNumber == editorState.currentPage)
        .toList(growable: false);
    final previouslySelected = _selectedShapes.toSet();

    setState(() {
      _selectedShapes
        ..clear()
        ..addAll(
          pageShapes.where((shape) => !previouslySelected.contains(shape)),
        );
      _selectedShape =
          _selectedShapes.isEmpty ? null : _selectedShapes.last;
    });
  }

  void _clearShapeMultiSelection() {
    if (_selectedShapes.isEmpty && _selectedShape == null) return;
    setState(() {
      _selectedShapes.clear();
      _selectedShape = null;
    });
  }

  void _toggleShapeInMultiSelection(_ShapeAnnotation shape) {
    setState(() {
      if (_selectedShapes.contains(shape)) {
        _selectedShapes.remove(shape);
      } else {
        _selectedShapes.add(shape);
      }
      _selectedShape =
          _selectedShapes.isEmpty ? null : _selectedShapes.last;
    });
  }


  void _deleteSelectedShapes() {
    if (_selectedShapes.isEmpty) return;
    _pushUndoState();
    setState(() {
      _shapeAnnotations.removeWhere(_selectedShapes.contains);
      _selectedShapes.clear();
      _selectedShape = null;
    });
    _scheduleAutoSave();
  }

  void _copySelectedShapes() {
    if (_selectedShapes.isEmpty) return;
    _shapeClipboardGroup =
        _selectedShapes.map((shape) => shape.copy()).toList(growable: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم نسخ ${_shapeClipboardGroup.length} أشكال'),
          duration: const Duration(milliseconds: 900),
        ),
      );
    }
  }

  void _pasteShapeGroup() {
    if (_shapeClipboardGroup.isEmpty) return;
    final pasted = <_ShapeAnnotation>[];
    for (final source in _shapeClipboardGroup) {
      final item = source.copy();
      final sourceSize = _pdfPageSizes[source.pageNumber];
      final targetSize = _pdfPageSizes[editorState.currentPage];
      if (source.pageNumber != editorState.currentPage &&
          sourceSize != null &&
          targetSize != null &&
          sourceSize.width > 0 &&
          sourceSize.height > 0) {
        final sx = targetSize.width / sourceSize.width;
        final sy = targetSize.height / sourceSize.height;
        item.start = Offset(source.start.dx * sx, source.start.dy * sy);
        item.end = Offset(source.end.dx * sx, source.end.dy * sy);
      }
      item.pageNumber = editorState.currentPage;
      item.start += const Offset(14, 14);
      item.end += const Offset(14, 14);
      pasted.add(item);
    }
    _pushUndoState();
    setState(() {
      _shapeAnnotations.addAll(pasted);
      _selectedShapes
        ..clear()
        ..addAll(pasted);
      _selectedShape = pasted.isEmpty ? null : pasted.last;
      _multiSelectMode = true;
    });
    _scheduleAutoSave();
  }

  void _duplicateSelectedShapes() {
    if (_selectedShapes.isEmpty) return;
    final duplicates = _selectedShapes.map((shape) {
      final item = shape.copy();
      final offset = _shapePasteOffset(item);
      item.start += offset;
      item.end += offset;
      return item;
    }).toList(growable: false);
    _pushUndoState();
    setState(() {
      _shapeAnnotations.addAll(duplicates);
      _selectedShapes
        ..clear()
        ..addAll(duplicates);
      _selectedShape = duplicates.isEmpty ? null : duplicates.last;
    });
    _scheduleAutoSave();
  }

  void _bringSelectedShapesForward() {
    if (_selectedShapes.isEmpty) return;
    final selected = _selectedShapes.toSet();
    var canMove = false;
    for (var i = _shapeAnnotations.length - 2; i >= 0; i--) {
      final current = _shapeAnnotations[i];
      final next = _shapeAnnotations[i + 1];
      if (selected.contains(current) &&
          !selected.contains(next) &&
          current.pageNumber == next.pageNumber) {
        canMove = true;
        break;
      }
    }
    if (!canMove) return;
    _pushUndoState();
    setState(() {
      for (var i = _shapeAnnotations.length - 2; i >= 0; i--) {
        final current = _shapeAnnotations[i];
        final next = _shapeAnnotations[i + 1];
        if (selected.contains(current) &&
            !selected.contains(next) &&
            current.pageNumber == next.pageNumber) {
          _shapeAnnotations[i] = next;
          _shapeAnnotations[i + 1] = current;
        }
      }
    });
    _scheduleAutoSave();
  }

  void _sendSelectedShapesBackward() {
    if (_selectedShapes.isEmpty) return;
    final selected = _selectedShapes.toSet();
    var canMove = false;
    for (var i = 1; i < _shapeAnnotations.length; i++) {
      final current = _shapeAnnotations[i];
      final previous = _shapeAnnotations[i - 1];
      if (selected.contains(current) &&
          !selected.contains(previous) &&
          current.pageNumber == previous.pageNumber) {
        canMove = true;
        break;
      }
    }
    if (!canMove) return;
    _pushUndoState();
    setState(() {
      for (var i = 1; i < _shapeAnnotations.length; i++) {
        final current = _shapeAnnotations[i];
        final previous = _shapeAnnotations[i - 1];
        if (selected.contains(current) &&
            !selected.contains(previous) &&
            current.pageNumber == previous.pageNumber) {
          _shapeAnnotations[i] = previous;
          _shapeAnnotations[i - 1] = current;
        }
      }
    });
    _scheduleAutoSave();
  }

  void _bringSelectedShapesToFront() {
    if (_selectedShapes.isEmpty) return;
    final selected = _selectedShapes.toSet();
    final pages = _selectedShapes.map((shape) => shape.pageNumber).toSet();
    var changed = false;

    for (final page in pages) {
      final pageItems =
          _shapeAnnotations.where((shape) => shape.pageNumber == page).toList();
      final selectedOnPage =
          pageItems.where(selected.contains).toList(growable: false);
      if (selectedOnPage.isEmpty) continue;
      final reordered = <_ShapeAnnotation>[
        ...pageItems.where((shape) => !selected.contains(shape)),
        ...selectedOnPage,
      ];
      for (var i = 0; i < pageItems.length; i++) {
        if (!identical(pageItems[i], reordered[i])) {
          changed = true;
          break;
        }
      }
      if (changed) break;
    }
    if (!changed) return;

    _pushUndoState();
    setState(() {
      for (final page in pages) {
        final indexes = <int>[];
        final pageItems = <_ShapeAnnotation>[];
        for (var i = 0; i < _shapeAnnotations.length; i++) {
          if (_shapeAnnotations[i].pageNumber == page) {
            indexes.add(i);
            pageItems.add(_shapeAnnotations[i]);
          }
        }
        final selectedOnPage =
            pageItems.where(selected.contains).toList(growable: false);
        final reordered = <_ShapeAnnotation>[
          ...pageItems.where((shape) => !selected.contains(shape)),
          ...selectedOnPage,
        ];
        for (var i = 0; i < indexes.length; i++) {
          _shapeAnnotations[indexes[i]] = reordered[i];
        }
      }
    });
    _scheduleAutoSave();
  }

  void _sendSelectedShapesToBack() {
    if (_selectedShapes.isEmpty) return;
    final selected = _selectedShapes.toSet();
    final pages = _selectedShapes.map((shape) => shape.pageNumber).toSet();
    var changed = false;

    for (final page in pages) {
      final pageItems =
          _shapeAnnotations.where((shape) => shape.pageNumber == page).toList();
      final selectedOnPage =
          pageItems.where(selected.contains).toList(growable: false);
      if (selectedOnPage.isEmpty) continue;
      final reordered = <_ShapeAnnotation>[
        ...selectedOnPage,
        ...pageItems.where((shape) => !selected.contains(shape)),
      ];
      for (var i = 0; i < pageItems.length; i++) {
        if (!identical(pageItems[i], reordered[i])) {
          changed = true;
          break;
        }
      }
      if (changed) break;
    }
    if (!changed) return;

    _pushUndoState();
    setState(() {
      for (final page in pages) {
        final indexes = <int>[];
        final pageItems = <_ShapeAnnotation>[];
        for (var i = 0; i < _shapeAnnotations.length; i++) {
          if (_shapeAnnotations[i].pageNumber == page) {
            indexes.add(i);
            pageItems.add(_shapeAnnotations[i]);
          }
        }
        final selectedOnPage =
            pageItems.where(selected.contains).toList(growable: false);
        final reordered = <_ShapeAnnotation>[
          ...selectedOnPage,
          ...pageItems.where((shape) => !selected.contains(shape)),
        ];
        for (var i = 0; i < indexes.length; i++) {
          _shapeAnnotations[indexes[i]] = reordered[i];
        }
      }
    });
    _scheduleAutoSave();
  }

}
