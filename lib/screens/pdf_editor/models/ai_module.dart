part of '../../pdf_editor_screen.dart';

/// ميزات الذكاء الاصطناعي: استخراج النص الكامل من المستند (بخيط منفصل)،
/// وتوجيه المستخدم لشاشة التلخيص/الدردشة/الترجمة/القراءة الصوتية. نُقل
/// من pdf_editor_screen.dart لتقليل حجمها.
mixin AiModule on State<PdfEditorScreen> {
  List<_TextAnnotation> get _annotations;
  List<ImageAnnotation> get _imageAnnotations;
  List<_DrawingStroke> get _drawingStrokes;
  List<_ShapeAnnotation> get _shapeAnnotations;
  bool get _hasFormFields;
  Future<void> _runQueuedSave({required bool showResult});
  String? get _lastExportedPath;

  /// يستخرج كامل النص من ملف الـPDF الحالي بخيط منفصل (Isolate) بالخلفية
  /// عبر compute() — لتفادي تجميد الواجهة مع ملفات PDF كبيرة، لاستخدامه
  /// بميزات الذكاء الاصطناعي (التلخيص/الدردشة/الترجمة/القراءة الصوتية).
  /// يحدّد أفضل مسار نقرأ منه النص لميزات الذكاء الاصطناعي. لو فيه أي
  /// تعديلات محتملة (نصوص مضافة أو حقول نماذج بالملف)، ننفّذ تصديرًا
  /// طازجًا عبر طابور الحفظ نفسه أولًا لضمان قراءة أحدث حالة فعليًا —
  /// وليس مجرد التحقق من وجود نسخة محفوظة قد تكون قديمة.
  Future<String> _currentBestFilePath() async {
    if ((_annotations.isNotEmpty ||
            _imageAnnotations.isNotEmpty ||
            _drawingStrokes.isNotEmpty ||
            _shapeAnnotations.isNotEmpty) ||
        _hasFormFields) {
      try {
        return await _runQueuedSave(showResult: false).then((_) => _lastExportedPath ?? widget.filePath);
      } catch (_) {
        // فشل التصدير الطازج: نرجع لأفضل نسخة محفوظة سابقًا إن وُجدت
      }
    }
    final dir = await getApplicationDocumentsDirectory();
    final rawName = widget.filePath.split('/').last;
    var originalName = rawName.toLowerCase().endsWith('.pdf')
        ? rawName.substring(0, rawName.length - 4)
        : rawName;
    const revisionSuffix = '_MN-Doc';
    while (originalName.toLowerCase().endsWith(revisionSuffix.toLowerCase())) {
      originalName =
          originalName.substring(0, originalName.length - revisionSuffix.length);
    }
    if (originalName.trim().isEmpty) originalName = 'document';
    final savedPath = '${dir.path}/${originalName}_MN-Doc.pdf';
    if (await File(savedPath).exists()) return savedPath;
    return widget.filePath;
  }

  Future<String> _extractFullText() async {
    final path = await _currentBestFilePath();
    final bytes = await File(path).readAsBytes();
    return compute(extractPdfTextIsolate, bytes);
  }

  Future<void> _openAiFeature(String feature) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    String text = '';
    bool extractionFailed = false;
    try {
      text = await _extractFullText();
    } catch (_) {
      extractionFailed = true;
    }
    if (!mounted) return;
    Navigator.pop(context); // إغلاق مؤشر التحميل

    // نص فارغ أو استخراج فاشل: نوضّح السبب للمستخدم بدل ما ننتقل بصمت
    // لشاشة الذكاء الاصطناعي وهو يظن أن الميزة معطوبة.
    if (extractionFailed || text.trim().isEmpty) {
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppText.t('ed_extract_failed', lang))),
      );
      if (extractionFailed) return;
      // لو النص فاضي فعليًا (مو خطأ) بس المستخدم لسا يقدر يكمل — الميزات
      // التالية أصلاً بتتعامل مع نص فاضي بشكل معقول (تلخيص/ترجمة فاضية).
    }

    final title = widget.filePath.split('/').last;
    switch (feature) {
      case 'summarize':
        Navigator.push(context, MaterialPageRoute(builder: (_) => SummarizeScreen(initialText: text)));
        break;
      case 'chat':
        Navigator.push(context, MaterialPageRoute(builder: (_) => AiChatScreen(documentText: text, documentTitle: title)));
        break;
      case 'translate':
        Navigator.push(context, MaterialPageRoute(builder: (_) => TranslateScreen(initialText: text)));
        break;
      case 'read_aloud':
        Navigator.push(context, MaterialPageRoute(builder: (_) => TtsReaderScreen(initialText: text, title: title)));
        break;
    }
  }
}
