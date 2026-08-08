part of '../../pdf_editor_screen.dart';

/// منطق وضع "الرسم الحر" بالقلم: التقاط ضغطات الإصبع وتحويلها لخطوط PDF،
/// وإعدادات القلم (اللون والسماكة). نُقل من pdf_editor_screen.dart.
mixin DrawingModule on State<PdfEditorScreen> {
  EditorState get editorState;
  Map<int, _PdfPageTransform> get _pageTransforms;
  Map<int, Size> get _pdfPageSizes;
  GlobalKey get _viewerKey;
  List<_DrawingStroke> get _drawingStrokes;
  _PdfPageTransform? _fallbackPageTransform(int pageNumber);
  void _pushUndoState();
  void _scheduleAutoSave({bool markChanged = true});

  _DrawingStroke? _activeDrawingStroke;
  Color _drawColor = Colors.red;
  double _drawThickness = 2.5;

  void _onDrawPointerDown(PointerDownEvent event) {
    if (!editorState.drawMode) return;
    final transform =
        _pageTransforms[editorState.currentPage] ?? _fallbackPageTransform(editorState.currentPage);
    final pageSize = _pdfPageSizes[editorState.currentPage];
    if (transform == null || pageSize == null || transform.scale <= 0) return;

    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(event.position);
    final pdf = transform.viewerToPdf(local);
    if (pdf.dx < 0 ||
        pdf.dy < 0 ||
        pdf.dx > pageSize.width ||
        pdf.dy > pageSize.height) {
      return;
    }

    _pushUndoState();
    setState(() {
      _activeDrawingStroke = _DrawingStroke(
        pageNumber: editorState.currentPage,
        points: <Offset>[pdf],
        color: _drawColor,
        thickness: _drawThickness,
      );
      _drawingStrokes.add(_activeDrawingStroke!);
    });
  }

  void _onDrawPointerMove(PointerMoveEvent event) {
    final stroke = _activeDrawingStroke;
    if (!editorState.drawMode || stroke == null) return;
    final transform =
        _pageTransforms[stroke.pageNumber] ?? _fallbackPageTransform(stroke.pageNumber);
    final pageSize = _pdfPageSizes[stroke.pageNumber];
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (transform == null || pageSize == null || box == null) return;

    final local = box.globalToLocal(event.position);
    final pdf = transform.viewerToPdf(local);
    final bounded = Offset(
      pdf.dx.clamp(0.0, pageSize.width).toDouble(),
      pdf.dy.clamp(0.0, pageSize.height).toDouble(),
    );

    if (stroke.points.isNotEmpty &&
        (bounded - stroke.points.last).distance < 0.8) {
      return;
    }
    setState(() => stroke.points.add(bounded));
  }

  void _finishDrawingStroke() {
    final stroke = _activeDrawingStroke;
    if (stroke == null) return;
    setState(() {
      if (stroke.points.length < 2) {
        _drawingStrokes.remove(stroke);
      }
      _activeDrawingStroke = null;
    });
    if (stroke.points.length >= 2) _scheduleAutoSave();
  }

  Future<void> _showDrawSettings() async {
    double thickness = _drawThickness;
    Color color = _drawColor;
    const colors = <Color>[
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'إعدادات القلم',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('السماكة'),
                    Expanded(
                      child: Slider(
                        value: thickness,
                        min: 1,
                        max: 10,
                        divisions: 18,
                        label: thickness.toStringAsFixed(1),
                        onChanged: (v) =>
                            setSheetState(() => thickness = v),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 12,
                  children: colors
                      .map(
                        (c) => GestureDetector(
                          onTap: () => setSheetState(() => color = c),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == c
                                    ? AppColors.accent
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _drawThickness = thickness;
                      _drawColor = color;
                    });
                    Navigator.pop(sheetContext);
                  },
                  child: const Text('تطبيق'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
