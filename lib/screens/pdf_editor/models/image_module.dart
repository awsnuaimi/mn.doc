part of '../../pdf_editor_screen.dart';

/// كل منطق تعليقات الصور: اختيار صورة من المعرض، وضعها على الصفحة، سحبها،
/// تكبيرها/تصغيرها، وحذفها. نُقل من pdf_editor_screen.dart لتقليل حجمها.
mixin ImageModule on State<PdfEditorScreen> {
  EditorState get editorState;
  Map<int, _PdfPageTransform> get _pageTransforms;
  Map<int, Size> get _pdfPageSizes;
  _PdfPageTransform? _fallbackPageTransform(int pageNumber);
  void _pushUndoState();
  void _scheduleAutoSave({bool markChanged = true});
  Timer? get _autoSaveDebounce;
  _EditorHistory get _history;
  _EditorSnapshot _captureEditorState();

  final List<ImageAnnotation> _imageAnnotations = [];
  Uint8List? _pendingImageBytes;

  // حركة الصورة تُعامل كعملية واحدة في Undo/Redo مهما كان عدد أحداث السحب.
  // لا نسجل لقطة عند مجرد لمس الصورة، بل فقط بعد أول حركة فعلية.
  _EditorSnapshot? _imageDragBefore;
  ImageAnnotation? _draggingImage;
  bool _imageDragChanged = false;

  Future<void> _pickImageForPdf() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (picked == null) return;
    final bytes = await File(picked.path).readAsBytes();
    if (!mounted) return;
    setState(() {
      _pendingImageBytes = bytes;
      editorState.addImageMode = true;
      editorState.addTextMode = false;
      editorState.drawMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اضغط على المكان المطلوب داخل الصفحة لإضافة الصورة')));
  }

  Widget _buildImageOverlay(ImageAnnotation ann) {
    final transform = _pageTransforms[ann.pageNumber] ?? _fallbackPageTransform(ann.pageNumber);
    if (transform == null) return const SizedBox.shrink();
    final point = transform.pdfToViewer(Offset(ann.dx, ann.dy));
    return Positioned(
      left: point.dx, top: point.dy, width: ann.width * transform.scale, height: ann.height * transform.scale,
      child: GestureDetector(
        onPanStart: (_) {
          // أوقف أي AutoSave كان على وشك البدء حتى لا يحفظ موضعًا وسيطًا.
          _autoSaveDebounce?.cancel();
          _draggingImage = ann;
          _imageDragBefore = _captureEditorState();
          _imageDragChanged = false;
        },
        onPanUpdate: (d) {
          final pageSize = _pdfPageSizes[ann.pageNumber];
          if (pageSize == null || transform.scale <= 0) return;
          final delta = d.delta / transform.scale;
          if (delta.distanceSquared <= 0) return;

          final nextX = (ann.dx + delta.dx)
              .clamp(0.0, (pageSize.width - ann.width).clamp(0.0, pageSize.width))
              .toDouble();
          final nextY = (ann.dy + delta.dy)
              .clamp(0.0, (pageSize.height - ann.height).clamp(0.0, pageSize.height))
              .toDouble();
          if ((nextX - ann.dx).abs() < 0.001 && (nextY - ann.dy).abs() < 0.001) return;

          _imageDragChanged = true;
          setState(() {
            ann.dx = nextX;
            ann.dy = nextY;
          });
        },
        onPanEnd: (_) => _finishImageDrag(ann),
        onPanCancel: () => _finishImageDrag(ann),
        onTap: () => _showImageActionSheet(ann),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: AppColors.accent, width: 1)),
          child: Image.memory(ann.bytes, fit: BoxFit.fill, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded)),
        ),
      ),
    );
  }

  void _finishImageDrag(ImageAnnotation ann) {
    if (!identical(_draggingImage, ann)) return;
    final before = _imageDragBefore;
    final changed = _imageDragChanged;
    _draggingImage = null;
    _imageDragBefore = null;
    _imageDragChanged = false;

    if (!changed || before == null) return;
    _history.record(before);
    if (mounted) setState(() {}); // تفعيل زر Undo فورًا
    _scheduleAutoSave();
  }

  void _resizeImage(ImageAnnotation ann, double factor) {
    final pageSize = _pdfPageSizes[ann.pageNumber];
    if (pageSize == null) return;
    _pushUndoState();
    setState(() {
      ann.width = (ann.width * factor).clamp(30.0, pageSize.width).toDouble();
      ann.height = (ann.height * factor).clamp(30.0, pageSize.height).toDouble();
      ann.dx = ann.dx.clamp(0.0, (pageSize.width - ann.width).clamp(0.0, pageSize.width)).toDouble();
      ann.dy = ann.dy.clamp(0.0, (pageSize.height - ann.height).clamp(0.0, pageSize.height)).toDouble();
    });
    _scheduleAutoSave();
  }

  void _showImageActionSheet(ImageAnnotation ann) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(child: Wrap(children: [
        ListTile(leading: const Icon(Icons.zoom_in_rounded), title: const Text('تكبير الصورة'), onTap: () { Navigator.pop(sheetContext); _resizeImage(ann, 1.2); }),
        ListTile(leading: const Icon(Icons.zoom_out_rounded), title: const Text('تصغير الصورة'), onTap: () { Navigator.pop(sheetContext); _resizeImage(ann, 0.8); }),
        ListTile(leading: const Icon(Icons.delete_outline_rounded, color: Colors.red), title: const Text('حذف الصورة', style: TextStyle(color: Colors.red)), onTap: () {
          Navigator.pop(sheetContext); _pushUndoState(); setState(() => _imageAnnotations.remove(ann)); _scheduleAutoSave();
        }),
      ])),
    );
  }
}
