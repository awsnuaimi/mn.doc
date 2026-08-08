part of '../../pdf_editor_screen.dart';

/// كل منطق الحفظ التلقائي والتصدير والحفظ اليدوي وإدارة نسخ المستند
/// (Revision). نُقل من pdf_editor_screen.dart لتقليل حجمها.
mixin SaveModule on State<PdfEditorScreen> {
  EditorState get editorState;
  PdfViewerController get _controller;
  bool get _disposed;
  List<_TextAnnotation> get _annotations;
  List<ImageAnnotation> get _imageAnnotations;
  List<_DrawingStroke> get _drawingStrokes;
  List<_ShapeAnnotation> get _shapeAnnotations;
  ImageAnnotation? get _draggingImage;
  _TextAnnotation? get _movingAnnotation;
  bool get _moveGestureArmed;
  bool get _hasFormFields;

  // ------- تتبّع التعديلات غير المحفوظة -------
  int _documentRevision = 0;
  int _savedRevision = 0;
  Timer? _autoSaveDebounce;
  Future<void>? _saveQueue;
  int _autoSaveRetryCount = 0;
  static const int _maxAutoSaveRetries = 2;
  String? _lastExportedPath;
  bool _flattenFormsOnSave = false;

  void _markDocumentChanged() {
    _documentRevision++;
    editorState.setUnsaved(_documentRevision != _savedRevision);

    // بعض التعديلات (خصوصًا تعليقات Syncfusion وحقول النماذج) تصل عبر
    // callbacks لا يسبقها setState من كودنا. يجب إعادة بناء PopScope فورًا
    // حتى تتحول canPop إلى false في نفس Revision ولا تبقى قيمة قديمة تسمح
    // بالخروج قبل أن يبدأ/يكتمل AutoSave.
    if (mounted) setState(() {});
  }

  /// المنطق الأساسي لتصدير المستند (يُستخدم من الحفظ اليدوي والحفظ التلقائي
  /// معًا) — يعيد مسار الملف الناتج، أو يرمي استثناء عند الفشل.
  List<List<Offset>> _styledLineSegments(
    Offset start,
    Offset end,
    _ShapeLineStyle style,
  ) {
    if (style == _ShapeLineStyle.solid) {
      return <List<Offset>>[<Offset>[start, end]];
    }
    final delta = end - start;
    final length = delta.distance;
    if (length <= 0.01) return const <List<Offset>>[];
    final unit = delta / length;
    final dash = style == _ShapeLineStyle.dashed ? 10.0 : 2.0;
    final gap = style == _ShapeLineStyle.dashed ? 6.0 : 5.0;
    final result = <List<Offset>>[];
    var cursor = 0.0;
    while (cursor < length) {
      final segEnd = (cursor + dash).clamp(0.0, length).toDouble();
      result.add(<Offset>[
        start + unit * cursor,
        start + unit * segEnd,
      ]);
      cursor += dash + gap;
    }
    return result;
  }

  Future<String> _exportToFile() async {
    // الخطوة 1: احفظ نسخة تتضمن تعليقات العارض المدمجة
    // (تظليل/تسطير/شطب/ملاحظات لاصقة) وبيانات حقول النموذج التي عبّأها المستخدم.
    final List<int> viewerBytes = await _controller.saveDocument(
      flattenOption: _flattenFormsOnSave ? PdfFlattenOption.formFields : PdfFlattenOption.none,
    );

    // الخطوة 2: افتح تلك النسخة وأضف فوقها نصوصنا المخصّصة (المربّعات النصية).
    final sf.PdfDocument document = sf.PdfDocument(inputBytes: viewerBytes);
    late final List<int> savedBytes;

    // لقطة ثابتة من التعليقات قبل الحلقة — الحلقة فيها await (تحميل خط)،
    // فلو المستخدم أضاف/عدّل نصًا بالمنتصف، تعديل _annotations الحيّة
    // أثناء المرور عليها ممكن يرمي ConcurrentModificationError.
    final annotationsSnapshot = _annotations.map((a) => a.copy()).toList(growable: false);
    final imagesSnapshot = _imageAnnotations.map((a) => a.copy()).toList(growable: false);
    final strokesSnapshot = _drawingStrokes.map((s) => s.copy()).toList(growable: false);
    final shapesSnapshot = _shapeAnnotations.map((s) => s.copy()).toList(growable: false);

    try {
      for (final ann in annotationsSnapshot) {
        final pageIndex = ann.pageNumber - 1;
        if (pageIndex < 0 || pageIndex >= document.pages.count) continue;
        final page = document.pages[pageIndex];
        final pageSize = page.getClientSize();

        final font = await ArabicFontLoader.loadSyncfusionFont(ann.fontSize);
        final brush = sf.PdfSolidBrush(
          sf.PdfColor(ann.color.red, ann.color.green, ann.color.blue),
        );

        final pdfAlignment = switch (ann.alignment) {
          TextAlign.left => sf.PdfTextAlignment.left,
          TextAlign.center => sf.PdfTextAlignment.center,
          TextAlign.right => sf.PdfTextAlignment.right,
          _ => sf.PdfTextAlignment.right,
        };

        // ارتفاع الصندوق يعتمد على عدد الأسطر الفعلي (النص يسمح حتى 3 أسطر)
        // بدل قيمة ثابتة، لتفادي قص أي سطر إضافي عند التصدير.
        final lineCount = '\n'.allMatches(ann.text).length + 1;
        final boxHeight = ann.fontSize * 1.3 * lineCount;

        // نحصر موضع النص ضمن حدود الصفحة فعليًا (وليس بس عرض الصندوق) —
        // يحمي من حالات نادرة تكون فيها dx/dy خارج الصفحة قليلًا (مثلًا
        // بسبب فارق تقريبي بالحساب)، بدل نص يظهر مقصوصًا أو خارج الصفحة.
        const minBoxWidth = 60.0;
        final safeX = ann.dx.clamp(0.0, (pageSize.width - minBoxWidth).clamp(0.0, pageSize.width)).toDouble();
        final safeY = ann.dy.clamp(0.0, (pageSize.height - boxHeight).clamp(0.0, pageSize.height)).toDouble();
        final availableWidth = pageSize.width - safeX;
        final boxWidth = availableWidth < minBoxWidth ? minBoxWidth : availableWidth;

        page.graphics.drawString(
          ann.text,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(
            safeX,
            safeY,
            boxWidth,
            boxHeight,
          ),
          format: sf.PdfStringFormat(alignment: pdfAlignment),
        );
      }

      for (final ann in imagesSnapshot) {
        final pageIndex = ann.pageNumber - 1;
        if (pageIndex < 0 || pageIndex >= document.pages.count) continue;
        final page = document.pages[pageIndex];
        final pageSize = page.getClientSize();
        final safeW = ann.width.clamp(20.0, pageSize.width).toDouble();
        final safeH = ann.height.clamp(20.0, pageSize.height).toDouble();
        final safeX = ann.dx.clamp(0.0, (pageSize.width - safeW).clamp(0.0, pageSize.width)).toDouble();
        final safeY = ann.dy.clamp(0.0, (pageSize.height - safeH).clamp(0.0, pageSize.height)).toDouble();
        final image = sf.PdfBitmap(ann.bytes);
        page.graphics.drawImage(image, Rect.fromLTWH(safeX, safeY, safeW, safeH));
      }

      for (final stroke in strokesSnapshot) {
        final pageIndex = stroke.pageNumber - 1;
        if (pageIndex < 0 || pageIndex >= document.pages.count) continue;
        if (stroke.points.length < 2) continue;

        final page = document.pages[pageIndex];
        final pageSize = page.getClientSize();
        final pen = sf.PdfPen(
          sf.PdfColor(stroke.color.red, stroke.color.green, stroke.color.blue),
          width: stroke.thickness,
        );

        for (var i = 1; i < stroke.points.length; i++) {
          final a = stroke.points[i - 1];
          final b = stroke.points[i];
          final ax = a.dx.clamp(0.0, pageSize.width).toDouble();
          final ay = a.dy.clamp(0.0, pageSize.height).toDouble();
          final bx = b.dx.clamp(0.0, pageSize.width).toDouble();
          final by = b.dy.clamp(0.0, pageSize.height).toDouble();
          page.graphics.drawLine(pen, Offset(ax, ay), Offset(bx, by));
        }
      }

      for (final shape in shapesSnapshot) {
        final pageIndex = shape.pageNumber - 1;
        if (pageIndex < 0 || pageIndex >= document.pages.count) continue;
        final page = document.pages[pageIndex];
        final pageSize = page.getClientSize();
        final start = Offset(
          shape.start.dx.clamp(0.0, pageSize.width).toDouble(),
          shape.start.dy.clamp(0.0, pageSize.height).toDouble(),
        );
        final end = Offset(
          shape.end.dx.clamp(0.0, pageSize.width).toDouble(),
          shape.end.dy.clamp(0.0, pageSize.height).toDouble(),
        );
        final pen = sf.PdfPen(
          sf.PdfColor(shape.color.red, shape.color.green, shape.color.blue),
          width: shape.thickness,
        );

        if (shape.kind == _ShapeKind.line || shape.kind == _ShapeKind.arrow) {
          for (final segment
              in _styledLineSegments(start, end, shape.lineStyle)) {
            page.graphics.drawLine(pen, segment[0], segment[1]);
          }
          if (shape.kind == _ShapeKind.arrow) {
            final delta = end - start;
            final length = delta.distance;
            if (length > 0.01) {
              final unit = delta / length;
              final perp = Offset(-unit.dy, unit.dx);
              final head =
                  (10.0 + shape.thickness * 2).clamp(10.0, 24.0).toDouble();
              final wing = head * 0.45;
              final base = end - unit * head;
              final p1 = base + perp * wing;
              final p2 = base - perp * wing;
              page.graphics.drawLine(pen, end, p1);
              page.graphics.drawLine(pen, end, p2);
              if (shape.arrowHeadStyle == _ArrowHeadStyle.closed) {
                page.graphics.drawLine(pen, p1, p2);
              }
            }
          }
        } else {
          final rect = Rect.fromPoints(start, end);
          sf.PdfBrush? brush;
          final fill = shape.fillColor;
          if (fill != null) {
            final alpha =
                (shape.fillOpacity.clamp(0.0, 1.0) * 255).round();
            brush = sf.PdfSolidBrush(
              sf.PdfColor(fill.red, fill.green, fill.blue, alpha),
            );
          }
          if (shape.kind == _ShapeKind.rectangle) {
            page.graphics.drawRectangle(bounds: rect, pen: pen, brush: brush);
          } else {
            page.graphics.drawEllipse(rect, pen: pen, brush: brush);
          }
        }
      }

      savedBytes = await document.save();
    } finally {
      // نضمن تحرير موارد المستند (Native) حتى لو فشل الرسم أو الحفظ —
      // بدون هذا، أي استثناء أثناء التصدير يسرّب ذاكرة المستند بصمت.
      document.dispose();
    }

    final dir = await getApplicationDocumentsDirectory();
    final rawName = widget.filePath.split('/').last;
    var originalName = rawName.toLowerCase().endsWith('.pdf')
        ? rawName.substring(0, rawName.length - 4)
        : rawName;

    // عند إعادة فتح نسخة محفوظة ثم تعديلها مرة أخرى لا نراكم لاحقة
    // _MN-Doc في اسم الملف (مثل file_MN-Doc_MN-Doc.pdf). نستخدم اسمًا
    // مستقرًا لنفس سلسلة الـRevision، مع إزالة أي لواحق قديمة متكررة.
    const revisionSuffix = '_MN-Doc';
    while (originalName.toLowerCase().endsWith(revisionSuffix.toLowerCase())) {
      originalName =
          originalName.substring(0, originalName.length - revisionSuffix.length);
    }
    if (originalName.trim().isEmpty) originalName = 'document';

    final outPath = '${dir.path}/${originalName}_MN-Doc.pdf';

    // حفظ آمن (Atomic Save): نكتب أولًا لملف مؤقت، ثم نستبدل الملف
    // النهائي به فقط بعد اكتمال الكتابة بنجاح — لو انقطع التطبيق أو
    // الطاقة أثناء الكتابة، الملف الأصلي (إن وُجد) يبقى سليمًا ولا
    // نحصل على ملف ناقص/تالف بمكانه.
    final tmpFile = File('$outPath.tmp');
    try {
      await tmpFile.writeAsBytes(savedBytes, flush: true);
      // بعض أنظمة الملفات ترفض rename لو الملف الهدف موجود مسبقًا —
      // نحذفه صراحة أول لضمان نجاح الاستبدال بغض النظر عن المنصة.
      final destFile = File(outPath);
      if (await destFile.exists()) {
        await destFile.delete();
      }
      await tmpFile.rename(outPath);
    } catch (e) {
      // تنظيف الملف المؤقت لو فشلت العملية، حتى لا يبقى بواقي معطوبة
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
      rethrow;
    }

    return outPath;
  }

  /// حفظ تلقائي وصامت — يُستدعى فور إضافة/تعديل/نقل أي نص، بدون الحاجة
  /// لضغط زر الحفظ يدويًا. يُظهر إشعارًا صغيرًا بس (مو نافذة كاملة)
  /// حتى لا يقاطع المستخدم أثناء إضافة عدة نصوص متتالية.
  /// يجدول حفظًا تلقائيًا بعد فترة قصيرة من التوقف عن التعديل (بدل تصدير
  /// الملف كاملًا فورًا مع كل تعديل) — مهم للأداء مع الملفات الكبيرة،
  /// خصوصًا لو المستخدم عدّل/نقل نفس النص عدة مرات متتالية بسرعة.
  bool get _hasActiveCustomGesture =>
      _draggingImage != null || (_movingAnnotation != null && _moveGestureArmed);

  void _scheduleAutoSave({bool markChanged = true}) {
    if (_disposed) return;
    if (markChanged) {
      _markDocumentChanged();
      _autoSaveRetryCount = 0;
    }
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 1200), () {
      if (_disposed) return;

      // لا نصدّر المستند بينما المستخدم في منتصف سحب صورة/توقيع أو نص.
      // التصدير أثناء gesture قد يلتقط موضعًا وسيطًا ثم يكتب ملفًا لا يطابق
      // الحالة التي ثبّتها المستخدم بعد رفع إصبعه. نؤجل نفس Revision فقط،
      // من دون زيادته، إلى أن تنتهي الحركة ثم يحفظ الموضع النهائي.
      if (_hasActiveCustomGesture) {
        _scheduleAutoSave(markChanged: false);
        return;
      }
      unawaited(_runQueuedSave(showResult: false));
    });
  }

  /// طابور حفظ تسلسلي واحد: كل طلب حفظ (تلقائي أو يدوي) ينتظر أي حفظ
  /// سابق لسا شغّال قبل ما يبلّش، بدل ما يشتغلوا بالتوازي على نفس
  /// الملف المؤقت (سبب تعارض حقيقي كان ممكن يصير قبل هالتعديل).
  Future<void> _runQueuedSave({required bool showResult}) {
    final previous = _saveQueue ?? Future.value();
    final current = previous
        .catchError((_) {}) // خطأ بحفظ سابق ما لازم يوقف الطابور بالكامل
        .then((_) => _performSave(showResult: showResult));
    _saveQueue = current;
    return current;
  }

  Future<void> _performSave({required bool showResult}) async {
    if (_disposed) return;
    _autoSaveDebounce?.cancel();
    if (showResult && mounted) editorState.setSaving(true);

    String? outPath;
    Object? error;
    final revisionBeingSaved = _documentRevision;
    try {
      outPath = await _exportToFile();
      _lastExportedPath = outPath;
      if (!_disposed) {
        _savedRevision = revisionBeingSaved;
        editorState.setUnsaved(_documentRevision != _savedRevision);
        _autoSaveRetryCount = 0;
        // لو حصل تعديل أثناء التصدير، لا نعتبره محفوظًا ونجدول نسخة لاحقة.
        if (editorState.hasUnsavedChanges) _scheduleAutoSave(markChanged: false);
      }
    } catch (e, stack) {
      error = e;

      // فشل AutoSave لا يغيّر savedRevision، لذلك يبقى المستند Dirty.
      // نعيد المحاولة تلقائيًا بعد مهلة قصيرة، لكن بعدد محدود حتى لا ندخل
      // في حلقة تصدير لا نهائية عند خطأ دائم (مساحة تخزين/صلاحيات/ملف تالف).
      if (!showResult &&
          !_disposed &&
          editorState.hasUnsavedChanges &&
          _autoSaveRetryCount < _maxAutoSaveRetries) {
        _autoSaveRetryCount++;
        _autoSaveDebounce?.cancel();
        _autoSaveDebounce = Timer(
          Duration(seconds: 2 * _autoSaveRetryCount),
          () {
            if (!_disposed && editorState.hasUnsavedChanges) {
              unawaited(_runQueuedSave(showResult: false));
            }
          },
        );
      }

      if (kDebugMode) {
        debugPrint('فشل الحفظ: $e');
        debugPrintStack(stackTrace: stack);
      }
    }

    if (_disposed || !mounted) return;

    if (showResult) {
      editorState.setSaving(false);
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      String tr(String key) => AppText.t(key, lang);

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('ed_save_error_prefix')} $error')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('ed_saved_title')),
          content: Text('${tr('ed_saved_path_prefix')}\n$outPath'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Share.shareXFiles([XFile(outPath!)], text: '${tr('file_from_app_prefix')} MN-Doc');
              },
              child: Text(tr('ed_share')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => PdfEditorScreen(filePath: outPath!)),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
              child: Text(tr('ed_open_saved_file')),
            ),
          ],
        ),
      );
    } else if (error == null) {
      setState(() {});
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppText.t('ed_autosaved', lang), style: const TextStyle(fontSize: 12)),
            duration: const Duration(milliseconds: 900),
            behavior: SnackBarBehavior.floating,
            width: 180,
          ),
        );
    }
  }

  Future<void> _saveDocument() async {
    if (_disposed || editorState.saving) return;

    // الحفظ اليدوي يجب أن يعني "احفظ أحدث Revision"، لا مجرد Revision كان
    // موجودًا لحظة الضغط على الزر. قد يعدّل المستخدم المستند أثناء عملية
    // التصدير الأولى، لذلك نثبّت أحدث حالة أولًا ثم نعرض نتيجة الحفظ.
    editorState.setSaving(true);
    _autoSaveDebounce?.cancel();

    Object? error;
    String? outPath;

    try {
      // انتظر أي AutoSave سابق قبل بدء دورة الحفظ اليدوي.
      await (_saveQueue ?? Future.value()).catchError((_) {});

      // نكرر عند الضرورة فقط إذا حدث تعديل جديد أثناء التصدير.
      for (var attempt = 0; attempt < 3; attempt++) {
        final revisionBeforeSave = _documentRevision;
        await _runQueuedSave(showResult: false);

        if (_savedRevision == _documentRevision &&
            _savedRevision == revisionBeforeSave &&
            _lastExportedPath != null) {
          outPath = _lastExportedPath;
          break;
        }
      }

      if (outPath == null || editorState.hasUnsavedChanges) {
        throw StateError('تعذر تثبيت أحدث نسخة من المستند.');
      }
    } catch (e, stack) {
      error = e;
      if (kDebugMode) {
        debugPrint('فشل الحفظ اليدوي: $e');
        debugPrintStack(stackTrace: stack);
      }
    }

    if (_disposed || !mounted) return;
    editorState.setSaving(false);

    final lang =
        Provider.of<AppSettingsController>(context, listen: false).languageCode;
    String tr(String key) => AppText.t(key, lang);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('ed_save_error_prefix')} $error')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('ed_saved_title')),
        content: Text('${tr('ed_saved_path_prefix')}\n$outPath'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Share.shareXFiles(
                [XFile(outPath!)],
                text: '${tr('file_from_app_prefix')} MN-Doc',
              );
            },
            child: Text(tr('ed_share')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PdfEditorScreen(filePath: outPath!),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
            ),
            child: Text(tr('ed_open_saved_file')),
          ),
        ],
      ),
    );
  }

  /// يثبت أحدث Revision فعليًا قبل أي عملية بنيوية على الصفحات.
  /// لا يكفي انتظار حفظ كان موجودًا بالطابور، لأن المستخدم قد يعدّل المستند
  /// أثناء ذلك الحفظ. لذلك نعيد الحفظ حتى تتطابق النسخة المحفوظة مع الحالية.
  Future<bool> _flushLatestRevisionForStructuralOperation() async {
    if (_disposed) return false;

    _autoSaveDebounce?.cancel();
    await (_saveQueue ?? Future.value()).catchError((_) {});
    if (_disposed || !mounted) return false;

    final needsExport = editorState.hasUnsavedChanges ||
        _annotations.isNotEmpty ||
        _imageAnnotations.isNotEmpty ||
        _drawingStrokes.isNotEmpty ||
        _shapeAnnotations.isNotEmpty ||
        _hasFormFields;
    if (!needsExport) return true;

    // حد أمان يمنع حلقة لا نهائية لو فشل التصدير أو استمرت تعديلات جديدة
    // بالتزامن مع محاولة فتح مدير الصفحات.
    for (var attempt = 0; attempt < 3; attempt++) {
      final revisionBeforeSave = _documentRevision;
      await _runQueuedSave(showResult: false);
      if (_disposed || !mounted) return false;

      if (_savedRevision == _documentRevision &&
          _savedRevision == revisionBeforeSave &&
          _lastExportedPath != null) {
        return true;
      }
    }

    return false;
  }

  Future<void> _openPageManager() async {
    // قبل أي عملية بنيوية نثبت أحدث Revision، بما فيه النصوص والصور
    // والتواقيع/الأختام وحقول النماذج وتعليقات Syncfusion. الاعتماد على
    // _runQueuedSave مرة واحدة فقط كان يترك نافذة سباق إذا حدث تعديل أثناء
    // الحفظ، كما أن الشرط القديم لم يكن يشمل _imageAnnotations.
    final ready = await _flushLatestRevisionForStructuralOperation();
    if (!mounted) return;

    if (!ready) {
      final lang = Provider.of<AppSettingsController>(
        context,
        listen: false,
      ).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppText.t('ed_save_error_prefix', lang))),
      );
      return;
    }

    final sourcePath = _lastExportedPath ?? widget.filePath;

    final managedPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ManagePagesScreen(initialFilePath: sourcePath),
      ),
    );

    if (!mounted || managedPath == null || managedPath == sourcePath) return;

    // العملية البنيوية أنشأت Revision جديدًا. إعادة إنشاء الشاشة على هذا
    // المسار تجعل widget.filePath نفسه يشير إلى أحدث نسخة، لذلك أي AutoSave
    // أو AI أو مشاركة أو تعديل لاحق يبدأ من الـRevision الصحيح.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PdfEditorScreen(filePath: managedPath),
      ),
    );
  }
}
