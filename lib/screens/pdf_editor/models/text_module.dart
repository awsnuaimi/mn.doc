part of '../../pdf_editor_screen.dart';

/// كل منطق تعليقات النص: إضافة/تعديل، تحريكها بالسحب المباشر (الضغط
/// المطوّل)، الشريط العائم عند التحديد، وعرضها فوق الصفحة. نُقل من
/// pdf_editor_screen.dart لتقليل حجمها.
mixin TextModule on State<PdfEditorScreen> {
  Map<int, _PdfPageTransform> get _pageTransforms;
  Map<int, Size> get _pdfPageSizes;
  _PdfPageTransform? _fallbackPageTransform(int pageNumber);
  void _pushUndoState();
  void _scheduleAutoSave({bool markChanged = true});
  Timer? get _autoSaveDebounce;
  _EditorHistory get _history;
  List<ImageAnnotation> get _imageAnnotations;
  List<_DrawingStroke> get _drawingStrokes;
  List<_ShapeAnnotation> get _shapeAnnotations;

  final List<_TextAnnotation> _annotations = [];
  _TextAnnotation? _movingAnnotation;
  Offset? _toolbarPosition;
  bool _showFloatingToolbar = false;
  _TextAnnotation? _selectedAnnotation;
  _TextAnnotation? _moveSnapshot;
  List<_TextAnnotation>? _moveUndoSnapshot;
  Timer? _moveHoldTimer;
  int? _movePointerId;
  Offset? _lastMovePointerPosition;
  bool _moveGestureArmed = false;
  static const Duration _moveHoldDuration = Duration(seconds: 3);

  Future<_TextDialogResult?> _showTextDialog({
    String initialText = '',
    double initialSize = 16,
    Color initialColor = Colors.black,
    TextAlign initialAlignment = TextAlign.right,
  }) {
    final controller = TextEditingController(text: initialText);
    double fontSize = initialSize;
    Color color = initialColor;
    TextAlign alignment = initialAlignment;
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    String tr(String key) => AppText.t(key, lang);

    return showModalBottomSheet<_TextDialogResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('ed_dialog_title'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(hintText: tr('ed_dialog_hint')),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(tr('ed_dialog_fontsize')),
                      Expanded(
                        child: Slider(
                          value: fontSize,
                          min: 8,
                          max: 48,
                          divisions: 40,
                          label: fontSize.round().toString(),
                          onChanged: (v) => setSheetState(() => fontSize = v),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text('${fontSize.round()}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(tr('ed_dialog_color')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Colors.black,
                              Colors.red,
                              Colors.blue,
                              AppColors.accent,
                              Colors.green,
                              Colors.amber,
                              Colors.deepOrange,
                              Colors.purple,
                            ]
                                .map((c) => GestureDetector(
                                      onTap: () => setSheetState(() => color = c),
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: c,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: color == c ? AppColors.primaryDark : Colors.transparent,
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(tr('ed_dialog_alignment')),
                      const SizedBox(width: 12),
                      SegmentedButton<TextAlign>(
                        segments: const [
                          ButtonSegment(value: TextAlign.right, icon: Icon(Icons.format_align_right_rounded)),
                          ButtonSegment(value: TextAlign.center, icon: Icon(Icons.format_align_center_rounded)),
                          ButtonSegment(value: TextAlign.left, icon: Icon(Icons.format_align_left_rounded)),
                        ],
                        selected: {alignment},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => setSheetState(() => alignment = s.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _TextDialogResult(text: controller.text, fontSize: fontSize, color: color, alignment: alignment),
                    ),
                    child: Text(tr('ed_dialog_add')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editAnnotation(_TextAnnotation ann) async {
    final result = await _showTextDialog(
      initialText: ann.text,
      initialSize: ann.fontSize,
      initialColor: ann.color,
      initialAlignment: ann.alignment,
    );
    if (result == null) return;
    _pushUndoState();
    setState(() {
      if (result.text.trim().isEmpty) {
        _annotations.remove(ann);
      } else {
        ann.text = result.text;
        ann.fontSize = result.fontSize;
        ann.color = result.color;
        ann.alignment = result.alignment;
      }
    });
    _scheduleAutoSave();
  }

  Widget _buildAnnotationOverlay(_TextAnnotation ann) {
    final transform = _pageTransforms[ann.pageNumber] ?? _fallbackPageTransform(ann.pageNumber);
    if (transform == null) return const SizedBox.shrink();

    final screenPoint = transform.pdfToViewer(Offset(ann.dx, ann.dy));
    final isMoving = identical(ann, _movingAnnotation);
    final previewFontSize = ann.fontSize * transform.scale;

    // نعطي النص hit-area معقولة من دون تخزين أي إحداثيات شاشة في البيانات.
    // أثناء السحب تتغير ann.dx/ann.dy مباشرة بنقاط PDF، لذلك المكان الظاهر
    // والمكان الذي سيُحفظ لاحقًا هما الشيء نفسه حرفيًا.
    final estimatedWidth = _estimateTextWidth(ann, transform.scale);
    final estimatedHeight = _estimateTextHeight(ann, transform.scale);

    return Positioned(
      left: screenPoint.dx,
      top: screenPoint.dy,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) => _onTextPointerDown(ann, event),
        onPointerMove: (event) => _onTextPointerMove(ann, event),
        onPointerUp: (event) => _onTextPointerUp(ann, event),
        onPointerCancel: (event) => _onTextPointerCancel(ann, event),
        child: SizedBox(
          width: estimatedWidth,
          height: estimatedHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: isMoving ? null : () => _showAnnotationActionSheet(ann),
                  child: Container(
                    alignment: _alignmentFor(ann.alignment),
                    padding: isMoving ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2) : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      border: isMoving ? Border.all(color: AppColors.accent, width: 2) : null,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      ann.text,
                      textAlign: ann.alignment,
                      maxLines: 3,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontSize: previewFontSize,
                        height: 1.3,
                        color: ann.color,
                      ),
                    ),
                  ),
                ),
              ),
              if (isMoving) ..._buildMoveDirectionIndicators(),
            ],
          ),
        ),
      ),
    );
  }

  Alignment _alignmentFor(TextAlign alignment) {
    switch (alignment) {
      case TextAlign.left:
      case TextAlign.start:
        return Alignment.centerLeft;
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.right:
      case TextAlign.end:
        return Alignment.centerRight;
      case TextAlign.justify:
        return Alignment.center;
    }
  }

  double _estimateTextWidth(_TextAnnotation ann, double scale) {
    final painter = TextPainter(
      text: TextSpan(
        text: ann.text,
        style: TextStyle(fontSize: ann.fontSize * scale, height: 1.3),
      ),
      textDirection: TextDirection.rtl,
      maxLines: 3,
    )..layout(maxWidth: 360 * scale);
    return (painter.width + 12).clamp(48.0, 380.0 * scale);
  }

  double _estimateTextHeight(_TextAnnotation ann, double scale) {
    final painter = TextPainter(
      text: TextSpan(
        text: ann.text,
        style: TextStyle(fontSize: ann.fontSize * scale, height: 1.3),
      ),
      textDirection: TextDirection.rtl,
      maxLines: 3,
    )..layout(maxWidth: 360 * scale);
    return (painter.height + 8).clamp(28.0, 160.0 * scale);
  }

  List<Widget> _buildMoveDirectionIndicators() {
    Widget indicator(IconData icon) => IgnorePointer(
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        );

    return [
      Positioned(top: -38, left: 0, right: 0, child: Center(child: indicator(Icons.arrow_upward_rounded))),
      Positioned(bottom: -38, left: 0, right: 0, child: Center(child: indicator(Icons.arrow_downward_rounded))),
      Positioned(left: -38, top: 0, bottom: 0, child: Center(child: indicator(Icons.arrow_back_rounded))),
      Positioned(right: -38, top: 0, bottom: 0, child: Center(child: indicator(Icons.arrow_forward_rounded))),
    ];
  }

  void _onTextPointerDown(_TextAnnotation ann, PointerDownEvent event) {
    _moveHoldTimer?.cancel();
    _movePointerId = event.pointer;
    _lastMovePointerPosition = event.position;

    // إذا كان النص محددًا أصلًا، يبدأ السحب فورًا. وإلا ننتظر 3 ثوانٍ
    // كما طلب المستخدم، ثم ندخل وضع التحريك من دون فتح نافذة أخرى.
    if (identical(ann, _movingAnnotation)) {
      _moveGestureArmed = true;
      return;
    }

    _moveGestureArmed = false;
    _moveHoldTimer = Timer(_moveHoldDuration, () {
      if (!mounted || _movePointerId != event.pointer) return;
      _autoSaveDebounce?.cancel();
      setState(() {
        _movingAnnotation = ann;
        _moveSnapshot = ann.copy();
        _moveUndoSnapshot = _annotations.map((a) => a.copy()).toList();
        _moveGestureArmed = true;
      });
    });
  }

  void _onTextPointerMove(_TextAnnotation ann, PointerMoveEvent event) {
    if (_movePointerId != event.pointer) return;

    final previous = _lastMovePointerPosition;
    _lastMovePointerPosition = event.position;
    if (previous == null) return;

    if (!_moveGestureArmed || !identical(ann, _movingAnnotation)) {
      // حركة الإصبع قبل اكتمال 3 ثوانٍ تلغي الضغط المطوّل حتى لا يدخل
      // وضع النقل بالخطأ أثناء تمرير الصفحة.
      if ((event.position - previous).distance > 3) {
        _moveHoldTimer?.cancel();
      }
      return;
    }

    final transform = _pageTransforms[ann.pageNumber] ?? _fallbackPageTransform(ann.pageNumber);
    final pageSize = _pdfPageSizes[ann.pageNumber];
    if (transform == null || pageSize == null || transform.scale <= 0) return;

    final viewerDelta = event.position - previous;
    final pdfDelta = viewerDelta / transform.scale;

    // هذه هي النقطة الحاسمة: لا نحرك Overlay مستقلًا. نحرك إحداثيات PDF
    // نفسها مع كل حركة إصبع، والـOverlay يعاد إسقاطه منها فورًا.
    final maxX = (pageSize.width - 4).clamp(0.0, pageSize.width);
    final maxY = (pageSize.height - ann.fontSize * 1.4).clamp(0.0, pageSize.height);
    setState(() {
      ann.dx = (ann.dx + pdfDelta.dx).clamp(0.0, maxX).toDouble();
      ann.dy = (ann.dy + pdfDelta.dy).clamp(0.0, maxY).toDouble();
    });
  }

  void _onTextPointerUp(_TextAnnotation ann, PointerUpEvent event) {
    if (_movePointerId != event.pointer) return;
    _moveHoldTimer?.cancel();
    _movePointerId = null;
    _lastMovePointerPosition = null;
    _moveGestureArmed = false;
    // لا نثبت هنا. يبقى الإطار ظاهرًا حتى يختار المستخدم تثبيت أو إلغاء.
  }

  void _onTextPointerCancel(_TextAnnotation ann, PointerCancelEvent event) {
    if (_movePointerId != event.pointer) return;
    _moveHoldTimer?.cancel();
    _movePointerId = null;
    _lastMovePointerPosition = null;
    _moveGestureArmed = false;
  }

  void _cancelTextMove() {
    final ann = _movingAnnotation;
    final snap = _moveSnapshot;
    if (ann == null) return;
    setState(() {
      if (snap != null) {
        ann.pageNumber = snap.pageNumber;
        ann.dx = snap.dx;
        ann.dy = snap.dy;
      }
      _movingAnnotation = null;
      _moveSnapshot = null;
      _moveUndoSnapshot = null;
    });
  }

  void _confirmTextMove() {
    final before = _moveUndoSnapshot;
    if (_movingAnnotation == null) return;

    // التثبيت لا يحسب أي موضع جديد إطلاقًا. ann.dx/ann.dy هما بالفعل
    // الموضع النهائي الذي كان ظاهرًا أثناء السحب، لذلك لا توجد "قفزة".
    if (before != null) {
      _history.record(_EditorSnapshot(
        textAnnotations: before.map((a) => a.copy()).toList(growable: false),
        imageAnnotations:
            _imageAnnotations.map((a) => a.copy()).toList(growable: false),
        drawingStrokes:
            _drawingStrokes.map((s) => s.copy()).toList(growable: false),
      shapeAnnotations:
            _shapeAnnotations.map((s) => s.copy()).toList(growable: false),
      ));
}
    setState(() {
      _movingAnnotation = null;
      _moveSnapshot = null;
      _moveUndoSnapshot = null;
    });
    _scheduleAutoSave();
  }

  /// عند الضغط على نص موجود: قائمة صغيرة "تعديل" أو "نقل" — النقل يعتمد
  /// على نفس آلية الضغط الدقيقة المستخدمة بالإضافة (بدل السحب بالإصبع
  /// غير المضمون هندسيًا)، فيضغط المستخدم على المكان الجديد مباشرة.
  void _showAnnotationActionSheet(_TextAnnotation ann) {

    final transform =
        _pageTransforms[ann.pageNumber] ??
        _fallbackPageTransform(ann.pageNumber);

    if (transform != null) {
      final point = transform.pdfToViewer(
        Offset(ann.dx, ann.dy),
      );

      setState(() {
        _selectedAnnotation = ann;
        _toolbarPosition = Offset(
          point.dx,
          point.dy - 55,
        );
        _showFloatingToolbar = true;
      });
    }

    final lang = Provider.of<AppSettingsController>(
      context,
      listen: false,
    ).languageCode;

    String tr(String key) => AppText.t(key, lang);
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: Text(tr('ed_action_edit')),
              onTap: () {
                Navigator.pop(sheetContext);
                _editAnnotation(ann);
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_with_rounded),
              title: Text(tr('ed_action_move')),
              onTap: () {
                Navigator.pop(sheetContext);
                _autoSaveDebounce?.cancel();
                setState(() {
                  _movingAnnotation = ann;
                  _moveSnapshot = ann.copy();
                  _moveUndoSnapshot = _annotations.map((a) => a.copy()).toList();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: Text(tr('ed_action_delete'), style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetContext);
                _pushUndoState();
                setState(() => _annotations.remove(ann));
                _scheduleAutoSave();
              },
            ),
          ],
        ),
      ),
    );
  }
}
