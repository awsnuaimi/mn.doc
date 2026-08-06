part of '../../pdf_editor_screen.dart';

void _selectAllShapesOnCurrentPage() {
    final pageShapes = _shapeAnnotations
        .where((shape) => shape.pageNumber == _currentPage)
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
        .where((shape) => shape.pageNumber == _currentPage)
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

Rect? _selectedShapesBounds() {
    if (_selectedShapes.isEmpty) return null;
    double? left, top, right, bottom;
    for (final shape in _selectedShapes) {
      final l = shape.start.dx < shape.end.dx ? shape.start.dx : shape.end.dx;
      final r = shape.start.dx > shape.end.dx ? shape.start.dx : shape.end.dx;
      final tt = shape.start.dy < shape.end.dy ? shape.start.dy : shape.end.dy;
      final b = shape.start.dy > shape.end.dy ? shape.start.dy : shape.end.dy;
      left = left == null || l < left ? l : left;
      right = right == null || r > right ? r : right;
      top = top == null || tt < top ? tt : top;
      bottom = bottom == null || b > bottom ? b : bottom;
    }
    return Rect.fromLTRB(left!, top!, right!, bottom!);
  }
