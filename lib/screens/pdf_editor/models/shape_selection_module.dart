part of '../../pdf_editor_screen.dart';

/// تحديد/تعديل شكل واحد: الدخول لوضع التعديل، السحب لتحريك الشكل أو
/// مقابضه، الانجذاب للحواف (Snap)، ونسخ/لصق/تكرار/حذف/ترتيب شكل مفرد.
/// يملك هذا الملف كل الحقول المشتركة بين وحدات الأشكال الخمسة (تفاديًا
/// لتكرار إعلانها كحقول ملموسة بأكثر من ملف)، والوحدات الأخرى تطلبها
/// كـgetters/setters مجرّدة. نُقل من pdf_editor_screen.dart لتقليل حجمها.
mixin ShapeSelectionModule on State<PdfEditorScreen> {
  EditorState get editorState;
  PdfViewerController get _controller;
  Map<int, Size> get _pdfPageSizes;
  Offset? _eventToPdfPoint(PointerEvent event, int pageNumber);
  double _distanceToSegment(Offset p, Offset a, Offset b);
  void _pushUndoState();
  void _scheduleAutoSave({bool markChanged = true});
  void _toggleShapeInMultiSelection(_ShapeAnnotation shape);

  // حقول من وحدات أخرى تُصفَّر عند الدخول لوضع تعديل الأشكال.
  _DrawingStroke? get _activeDrawingStroke;
  set _activeDrawingStroke(_DrawingStroke? value);
  Uint8List? get _pendingImageBytes;
  set _pendingImageBytes(Uint8List? value);

  // ------- الحقول المشتركة لكل وحدات الأشكال -------
  final List<_ShapeAnnotation> _shapeAnnotations = [];
  _ShapeAnnotation? _activeShape;
  _ShapeKind? _shapeMode;
  _ShapeAnnotation? _selectedShape;
  _ShapeAnnotation? _shapeClipboard;
  final List<_ShapeAnnotation> _selectedShapes = [];
  List<_ShapeAnnotation> _shapeClipboardGroup = [];
  bool _multiSelectMode = false;
  double? _snapGuideX;
  double? _snapGuideY;
  String? _shapeDragPart; // body | start | end
  Offset? _shapeDragLastPdf;
  bool _shapeEditGestureChanged = false;

  void _toggleShapeEditMode() {
    setState(() {
      editorState.shapeEditMode = !editorState.shapeEditMode;
      _selectedShape = null;
      _selectedShapes.clear();
      _multiSelectMode = false;
      _shapeDragPart = null;
      _shapeDragLastPdf = null;
      _shapeMode = null;
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

  double _shapeDistance(_ShapeAnnotation shape, Offset p) {
    if (shape.kind == _ShapeKind.line || shape.kind == _ShapeKind.arrow) {
      return _distanceToSegment(p, shape.start, shape.end);
    }
    final rect = Rect.fromPoints(shape.start, shape.end);
    final expanded = rect.inflate(8);
    if (!expanded.contains(p)) return double.infinity;
    final dLeft = (p.dx - rect.left).abs();
    final dRight = (p.dx - rect.right).abs();
    final dTop = (p.dy - rect.top).abs();
    final dBottom = (p.dy - rect.bottom).abs();
    if (shape.kind == _ShapeKind.rectangle) {
      return [dLeft, dRight, dTop, dBottom].reduce((a, b) => a < b ? a : b);
    }
    final center = rect.center;
    final rx = rect.width / 2;
    final ry = rect.height / 2;
    if (rx < 0.1 || ry < 0.1) return (p - center).distance;
    final nx = (p.dx - center.dx) / rx;
    final ny = (p.dy - center.dy) / ry;
    return ((math.sqrt(nx * nx + ny * ny)) - 1).abs() * ((rx + ry) / 2);
  }

  _ShapeAnnotation? _hitShape(Offset pdfPoint) {
    _ShapeAnnotation? best;
    var bestDistance = 12.0 / editorState.zoomLevel;
    for (final shape in _shapeAnnotations.reversed) {
      if (shape.pageNumber != editorState.currentPage) continue;
      final d = _shapeDistance(shape, pdfPoint);
      if (d <= bestDistance) {
        bestDistance = d;
        best = shape;
      }
    }
    return best;
  }

  void _onShapeEditPointerDown(PointerDownEvent event) {
    final pdf = _eventToPdfPoint(event, editorState.currentPage);
    if (pdf == null) return;

    final selected = _selectedShape;
    if (selected != null) {
      final handleRadius = 14.0 / editorState.zoomLevel;
      if ((pdf - selected.start).distance <= handleRadius) {
        _pushUndoState();
        _shapeDragPart = 'start';
        _shapeDragLastPdf = pdf;
        _shapeEditGestureChanged = false;
        return;
      }
      if ((pdf - selected.end).distance <= handleRadius) {
        _pushUndoState();
        _shapeDragPart = 'end';
        _shapeDragLastPdf = pdf;
        _shapeEditGestureChanged = false;
        return;
      }
    }

    final hit = _hitShape(pdf);
    if (_multiSelectMode) {
      if (hit == null) {
        setState(() {
          _selectedShapes.clear();
          _selectedShape = null;
        });
        _shapeDragPart = null;
        _shapeDragLastPdf = null;
        return;
      }
      if (!_selectedShapes.contains(hit)) {
        _toggleShapeInMultiSelection(hit);
        _shapeDragPart = null;
        _shapeDragLastPdf = null;
        return;
      }
      _selectedShape = hit;
      _pushUndoState();
      _shapeDragPart = 'group';
      _shapeDragLastPdf = pdf;
      _shapeEditGestureChanged = false;
      return;
    }

    setState(() => _selectedShape = hit);
    if (hit != null) {
      _pushUndoState();
      _shapeDragPart = 'body';
      _shapeDragLastPdf = pdf;
      _shapeEditGestureChanged = false;
    } else {
      _shapeDragPart = null;
      _shapeDragLastPdf = null;
    }
  }

  Offset _snapDeltaForBounds(
    Rect movingBounds,
    Offset proposed,
    int pageNumber,
    Set<_ShapeAnnotation> moving,
  ) {
    final result = _ShapeSnapGeometry.calculate(
      movingBounds: movingBounds,
      proposed: proposed,
      pageNumber: pageNumber,
      moving: moving,
      pageSize: _pdfPageSizes[pageNumber],
      shapes: _shapeAnnotations,
      zoomLevel: editorState.zoomLevel,
    );
    _snapGuideX = result.guideX;
    _snapGuideY = result.guideY;
    return result.delta;
  }

  void _onShapeEditPointerMove(PointerMoveEvent event) {
    final shape = _selectedShape;
    final part = _shapeDragPart;
    final last = _shapeDragLastPdf;
    if (shape == null || part == null || last == null) return;
    final pdf = _eventToPdfPoint(event, shape.pageNumber);
    if (pdf == null) return;

    setState(() {
      if (part == 'group' && _selectedShapes.isNotEmpty) {
        final delta = pdf - last;
        final pageSize = _pdfPageSizes[shape.pageNumber];
        if (pageSize == null) return;
        final bounds = _ShapeGeometry.selectionBounds(_selectedShapes);
        if (bounds == null) return;
        var corrected = _snapDeltaForBounds(
          bounds,
          delta,
          shape.pageNumber,
          _selectedShapes.toSet(),
        );
        if (bounds.left + corrected.dx < 0) {
          corrected += Offset(-(bounds.left + corrected.dx), 0);
        }
        if (bounds.right + corrected.dx > pageSize.width) {
          corrected += Offset(pageSize.width - (bounds.right + corrected.dx), 0);
        }
        if (bounds.top + corrected.dy < 0) {
          corrected += Offset(0, -(bounds.top + corrected.dy));
        }
        if (bounds.bottom + corrected.dy > pageSize.height) {
          corrected += Offset(0, pageSize.height - (bounds.bottom + corrected.dy));
        }
        for (final item in _selectedShapes) {
          item.start += corrected;
          item.end += corrected;
        }
      } else if (part == 'start') {
        shape.start = pdf;
      } else if (part == 'end') {
        shape.end = pdf;
      } else {
        var delta = pdf - last;
        final pageSize = _pdfPageSizes[shape.pageNumber];
        if (pageSize == null) return;
        delta = _snapDeltaForBounds(
          _ShapeGeometry.bounds(shape),
          delta,
          shape.pageNumber,
          {shape},
        );
        final newStart = shape.start + delta;
        final newEnd = shape.end + delta;
        final minX = newStart.dx < newEnd.dx ? newStart.dx : newEnd.dx;
        final maxX = newStart.dx > newEnd.dx ? newStart.dx : newEnd.dx;
        final minY = newStart.dy < newEnd.dy ? newStart.dy : newEnd.dy;
        final maxY = newStart.dy > newEnd.dy ? newStart.dy : newEnd.dy;
        var corrected = delta;
        if (minX < 0) corrected += Offset(-minX, 0);
        if (maxX > pageSize.width) corrected += Offset(pageSize.width - maxX, 0);
        if (minY < 0) corrected += Offset(0, -minY);
        if (maxY > pageSize.height) corrected += Offset(0, pageSize.height - maxY);
        shape.start += corrected;
        shape.end += corrected;
      }
      _shapeDragLastPdf = pdf;
      _shapeEditGestureChanged = true;
    });
  }

  void _finishShapeEditGesture() {
    if (_shapeEditGestureChanged) _scheduleAutoSave();
    _shapeDragPart = null;
    _shapeDragLastPdf = null;
    _shapeEditGestureChanged = false;
    if (_snapGuideX != null || _snapGuideY != null) {
      setState(() {
        _snapGuideX = null;
        _snapGuideY = null;
      });
    }
  }


  void _copySelectedShape() {
    final shape = _selectedShape;
    if (shape == null) return;
    _shapeClipboard = shape.copy();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ الشكل'), duration: Duration(milliseconds: 900)),
      );
    }
  }

  Offset _shapePasteOffset(_ShapeAnnotation source) {
    final pageSize = _pdfPageSizes[source.pageNumber];
    const step = 14.0;
    if (pageSize == null) return const Offset(step, step);
    final minX = source.start.dx < source.end.dx ? source.start.dx : source.end.dx;
    final maxX = source.start.dx > source.end.dx ? source.start.dx : source.end.dx;
    final minY = source.start.dy < source.end.dy ? source.start.dy : source.end.dy;
    final maxY = source.start.dy > source.end.dy ? source.start.dy : source.end.dy;
    var dx = step, dy = step;
    if (maxX + dx > pageSize.width) dx = -step;
    if (maxY + dy > pageSize.height) dy = -step;
    if (minX + dx < 0) dx = 0;
    if (minY + dy < 0) dy = 0;
    return Offset(dx, dy);
  }

  void _pasteShape() {
    final source = _shapeClipboard;
    if (source == null) return;
    final pasted = source.copy();
    final targetPage = editorState.currentPage;
    final sourceSize = _pdfPageSizes[source.pageNumber];
    final targetSize = _pdfPageSizes[targetPage];
    if (source.pageNumber != targetPage && sourceSize != null && targetSize != null &&
        sourceSize.width > 0 && sourceSize.height > 0) {
      final sx = targetSize.width / sourceSize.width;
      final sy = targetSize.height / sourceSize.height;
      pasted.start = Offset(source.start.dx * sx, source.start.dy * sy);
      pasted.end = Offset(source.end.dx * sx, source.end.dy * sy);
    }
    pasted.pageNumber = targetPage;
    final offset = _shapePasteOffset(pasted);
    pasted.start += offset;
    pasted.end += offset;
    _pushUndoState();
    setState(() {
      _shapeAnnotations.add(pasted);
      _selectedShape = pasted;
      editorState.shapeEditMode = true;
      _shapeMode = null;
      editorState.drawMode = false;
      editorState.eraserMode = false;
    });
    _scheduleAutoSave();
  }

  void _duplicateSelectedShape() {
    final shape = _selectedShape;
    if (shape == null) return;
    final duplicate = shape.copy();
    final offset = _shapePasteOffset(duplicate);
    duplicate.start += offset;
    duplicate.end += offset;
    _pushUndoState();
    setState(() {
      final index = _shapeAnnotations.indexOf(shape);
      if (index >= 0 && index < _shapeAnnotations.length - 1) {
        _shapeAnnotations.insert(index + 1, duplicate);
      } else {
        _shapeAnnotations.add(duplicate);
      }
      _selectedShape = duplicate;
    });
    _scheduleAutoSave();
  }

  void _bringSelectedShapeForward() {
    final shape = _selectedShape;
    if (shape == null) return;
    final index = _shapeAnnotations.indexOf(shape);
    if (index < 0) return;
    var next = -1;
    for (var i = index + 1; i < _shapeAnnotations.length; i++) {
      if (_shapeAnnotations[i].pageNumber == shape.pageNumber) { next = i; break; }
    }
    if (next < 0) return;
    _pushUndoState();
    setState(() {
      final other = _shapeAnnotations[next];
      _shapeAnnotations[next] = shape;
      _shapeAnnotations[index] = other;
    });
    _scheduleAutoSave();
  }

  void _sendSelectedShapeBackward() {
    final shape = _selectedShape;
    if (shape == null) return;
    final index = _shapeAnnotations.indexOf(shape);
    if (index < 0) return;
    var previous = -1;
    for (var i = index - 1; i >= 0; i--) {
      if (_shapeAnnotations[i].pageNumber == shape.pageNumber) { previous = i; break; }
    }
    if (previous < 0) return;
    _pushUndoState();
    setState(() {
      final other = _shapeAnnotations[previous];
      _shapeAnnotations[previous] = shape;
      _shapeAnnotations[index] = other;
    });
    _scheduleAutoSave();
  }

  void _deleteSelectedShape() {
    final shape = _selectedShape;
    if (shape == null) return;
    _pushUndoState();
    setState(() {
      _shapeAnnotations.remove(shape);
      _selectedShape = null;
    });
    _scheduleAutoSave();
  }

}
