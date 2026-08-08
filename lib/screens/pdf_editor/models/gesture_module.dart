part of '../../pdf_editor_screen.dart';

/// التقاط ضغطات المستخدم على صفحة الـPDF وتحويل إحداثيات الشاشة لإحداثيات
/// PDF الحقيقية (المعايرة والتحويل العكسي)، وتوجيه الضغطة لإضافة نص أو
/// صورة. نُقل من pdf_editor_screen.dart لتقليل حجمها.
mixin GestureModule on State<PdfEditorScreen> {
  EditorState get editorState;
  PdfViewerController get _controller;
  Uint8List? get _pendingImageBytes;
  set _pendingImageBytes(Uint8List? value);
  List<ImageAnnotation> get _imageAnnotations;
  List<_TextAnnotation> get _annotations;
  bool get _showFloatingToolbar;
  set _showFloatingToolbar(bool value);
  _TextAnnotation? get _selectedAnnotation;
  set _selectedAnnotation(_TextAnnotation? value);
  Future<_TextDialogResult?> _showTextDialog({
    String initialText,
    double initialSize,
    Color initialColor,
    TextAlign initialAlignment,
  });
  void _pushUndoState();
  void _scheduleAutoSave({bool markChanged = true});

  final Map<int, Size> _pdfPageSizes = <int, Size>{};
  final Map<int, _PdfPageTransform> _pageTransforms = <int, _PdfPageTransform>{};
  final GlobalKey _viewerKey = GlobalKey();

  void _handlePdfTap(PdfGestureDetails details) async {
    setState(() {
      _showFloatingToolbar = false;
      _selectedAnnotation = null;
    });

    if (!editorState.addTextMode && !editorState.addImageMode) return;

    // pagePosition: الموضع الحقيقي بنقاط PDF (دقيق، يُستخدم للحفظ).
    // position: الموضع بكسلات عنصر العرض (تقريبي، للمعاينة الحيّة فقط).
    final pagePoint = details.pagePosition;
    final pageNumber = details.pageNumber;

    // لو الضغطة وقعت خارج حدود الصفحة فعليًا (بالهوامش الفاضية حول
    // الصفحة مثلًا)، Syncfusion بترجع pageNumber = -1 وإحداثيات سالبة —
    // نرفضها صريحة بدل ما نضيف/ننقل نص بمكان غير منطقي.
    if (pageNumber < 1 || pagePoint.dx < 0 || pagePoint.dy < 0) return;

    // نعاير تحويل الصفحة من الضغطة نفسها: Syncfusion يعطينا في الحدث ذاته
    // النقطة في نظام الصفحة (pagePosition) والنقطة المناظرة داخل الـViewer
    // (position). نستخدم أبعاد الصفحة الحقيقية لحساب المقياس، ثم نستخرج
    // origin بحيث تكون النقطة المضغوطة متطابقة رياضيًا 100% في النظامين.
    _calibratePageTransform(
      pageNumber: pageNumber,
      pdfPoint: pagePoint,
      viewerPoint: details.position,
    );

    if (editorState.addImageMode && _pendingImageBytes != null) {
      final pageSize = _pdfPageSizes[pageNumber];
      if (pageSize == null) return;
      const defaultWidth = 140.0;
      const defaultHeight = 100.0;
      _pushUndoState();
      setState(() {
        _imageAnnotations.add(ImageAnnotation(
          pageNumber: pageNumber,
          dx: pagePoint.dx.clamp(0.0, (pageSize.width - defaultWidth).clamp(0.0, pageSize.width)).toDouble(),
          dy: pagePoint.dy.clamp(0.0, (pageSize.height - defaultHeight).clamp(0.0, pageSize.height)).toDouble(),
          width: defaultWidth, height: defaultHeight, bytes: Uint8List.fromList(_pendingImageBytes!),
        ));
        _pendingImageBytes = null;
        editorState.addImageMode = false;
      });
      _scheduleAutoSave();
      return;
    }

    final result = await _showTextDialog();
    if (result == null || result.text.trim().isEmpty) return;

    _pushUndoState();
    setState(() {
      _annotations.add(_TextAnnotation(
        pageNumber: pageNumber, dx: pagePoint.dx, dy: pagePoint.dy, text: result.text,
        fontSize: result.fontSize, color: result.color, alignment: result.alignment,
      ));
    });
    _scheduleAutoSave();
  }

  Offset? _eventToPdfPoint(PointerEvent event, int pageNumber) {
    final transform =
        _pageTransforms[pageNumber] ?? _fallbackPageTransform(pageNumber);
    final pageSize = _pdfPageSizes[pageNumber];
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (transform == null ||
        pageSize == null ||
        box == null ||
        transform.scale <= 0) {
      return null;
    }
    final local = box.globalToLocal(event.position);
    final pdf = transform.viewerToPdf(local);
    if (pdf.dx < 0 ||
        pdf.dy < 0 ||
        pdf.dx > pageSize.width ||
        pdf.dy > pageSize.height) {
      return null;
    }
    return pdf;
  }

  void _calibratePageTransform({
    required int pageNumber,
    required Offset pdfPoint,
    required Offset viewerPoint,
  }) {
    final pageSize = _pdfPageSizes[pageNumber];
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (pageSize == null || box == null || pageSize.width <= 0 || pageSize.height <= 0) {
      return;
    }

    final viewport = box.size;
    if (viewport.width <= 0 || viewport.height <= 0) return;

    // في pageLayoutMode.single نحسب مقياس fit الأساسي ثم نضربه بمستوى
    // التكبير الحالي. لا نعتمد
    // على هوامش مفترضة: الـorigin يُستخرج من النقطة الفعلية التي أعادها
    // Syncfusion، لذلك أي padding داخلي يدخل في المعايرة تلقائيًا.
    final scaleX = viewport.width / pageSize.width;
    final scaleY = viewport.height / pageSize.height;
    final baseScale = scaleX < scaleY ? scaleX : scaleY;
    final scale = baseScale * editorState.zoomLevel;
    final origin = viewerPoint - pdfPoint * scale;

    _pageTransforms[pageNumber] = _PdfPageTransform(scale: scale, origin: origin);
  }

  _PdfPageTransform? _fallbackPageTransform(int pageNumber) {
    final pageSize = _pdfPageSizes[pageNumber];
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (pageSize == null || box == null || pageSize.width <= 0 || pageSize.height <= 0) {
      return null;
    }
    final viewport = box.size;
    if (viewport.width <= 0 || viewport.height <= 0) return null;
    final scaleX = viewport.width / pageSize.width;
    final scaleY = viewport.height / pageSize.height;
    final baseScale = scaleX < scaleY ? scaleX : scaleY;
    final scale = baseScale * editorState.zoomLevel;
    final rendered = Size(pageSize.width * scale, pageSize.height * scale);
    final scroll = _controller.scrollOffset;

    // عند التكبير، Syncfusion يحرك الصفحة داخل viewport بواسطة scrollOffset.
    // نعيد بناء نفس التحويل: تمركز المحور إن بقيت الصفحة أصغر من viewport،
    // وإلا يبدأ من حافة المحتوى ثم نطرح إزاحة التمرير الحالية.
    final centeredX =
        rendered.width < viewport.width ? (viewport.width - rendered.width) / 2 : 0.0;
    final centeredY =
        rendered.height < viewport.height ? (viewport.height - rendered.height) / 2 : 0.0;

    return _PdfPageTransform(
      scale: scale,
      origin: Offset(
        centeredX - scroll.dx,
        centeredY - scroll.dy,
      ),
    );
  }
}
