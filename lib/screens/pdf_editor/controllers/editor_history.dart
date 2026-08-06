part of '../../pdf_editor_screen.dart';

class _EditorHistory {
  final int limit;
  final List<_EditorSnapshot> _undo = <_EditorSnapshot>[];
  final List<_EditorSnapshot> _redo = <_EditorSnapshot>[];

  _EditorHistory({this.limit = 20});

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void record(_EditorSnapshot before) {
    _undo.add(before);
    _redo.clear();
    if (_undo.length > limit) _undo.removeAt(0);
  }

  _EditorSnapshot? undo(_EditorSnapshot current) {
    if (_undo.isEmpty) return null;
    _redo.add(current);
    return _undo.removeLast();
  }

  _EditorSnapshot? redo(_EditorSnapshot current) {
    if (_redo.isEmpty) return null;
    _undo.add(current);
    if (_undo.length > limit) _undo.removeAt(0);
    return _redo.removeLast();
  }
}
