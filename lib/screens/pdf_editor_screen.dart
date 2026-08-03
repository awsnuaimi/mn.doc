import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../theme/app_theme.dart';
import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../services/isolate_helpers.dart';
import '../services/arabic_font_loader.dart';
import 'summarize_screen.dart';
import 'ai_chat_screen.dart';
import 'translate_screen.dart';
import 'tts_reader_screen.dart';

/// نص تمت إضافته فوق صفحة معيّنة من ملف PDF.
/// dx/dy إحداثيات حقيقية بنقاط PDF (وليست نسبية) — تُستخدم مباشرة عند
/// الحفظ الفعلي داخل الملف. previewFracX/Y هي كسور تقريبية (0-1) منفصلة
/// تُستخدم فقط لعرض المعاينة الحيّة على الشاشة (راجع تعليقات الحقول بالأسفل).
class _TextAnnotation {
  int pageNumber; // يبدأ من 1
  double dx; // إحداثي X الحقيقي بنقاط PDF (يُستخدم للحفظ النهائي بدقة)
  double dy; // إحداثي Y الحقيقي بنقاط PDF (يُستخدم للحفظ النهائي بدقة)
  double previewFracX; // كسر تقريبي (0-1) من عرض الشاشة، للمعاينة الحيّة فقط
  double previewFracY; // كسر تقريبي (0-1) من ارتفاع الشاشة، للمعاينة الحيّة فقط
  String text;
  double fontSize;
  Color color;
  TextAlign alignment;

  _TextAnnotation({
    required this.pageNumber,
    required this.dx,
    required this.dy,
    required this.previewFracX,
    required this.previewFracY,
    required this.text,
    this.fontSize = 16,
    this.color = Colors.black,
    this.alignment = TextAlign.right,
  });

  _TextAnnotation copy() => _TextAnnotation(
        pageNumber: pageNumber,
        dx: dx,
        dy: dy,
        previewFracX: previewFracX,
        previewFracY: previewFracY,
        text: text,
        fontSize: fontSize,
        color: color,
        alignment: alignment,
      );
}

class PdfEditorScreen extends StatefulWidget {
  final String filePath;
  const PdfEditorScreen({super.key, required this.filePath});

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  final PdfViewerController _controller = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfViewerStateKey = GlobalKey();
  final List<_TextAnnotation> _annotations = [];
  final GlobalKey _viewerKey = GlobalKey();

  bool _addTextMode = false;
  bool _saving = false;
  bool _autoSaving = false;
  bool _pendingAutoSave = false; // تعديل جديد وصل أثناء حفظ جارٍ — يُنفَّذ فور انتهاء الحالي
  bool _disposed = false;
  Future<void> _saveQueue = Future<void>.value(); // تسلسل كل عمليات التصدير لمنع أي كتابة متزامنة
  Timer? _autoSaveDebounce; // يجمّع عدة تعديلات متتالية سريعة بعملية تصدير واحدة بدل تصدير كامل لكل تعديل
  bool _flattenFormsOnSave = false;
  bool _hasFormFields = false;
  int _currentPage = 1;
  double _zoomLevel = 1.0;

  // ------- تراجع/إعادة (Undo/Redo) لتعليقات النص المضافة -------
  final List<List<_TextAnnotation>> _undoStack = [];
  final List<List<_TextAnnotation>> _redoStack = [];

  void _pushUndoState() {
    _undoStack.add(_annotations.map((a) => a.copy()).toList());
    _redoStack.clear();
    if (_undoStack.length > 20) _undoStack.removeAt(0); // حد أقصى لتفادي استهلاك ذاكرة زائد
    _hasUnsavedChanges = true;
    // نحدّث الواجهة هون مباشرة (مثلًا لتفعيل زري تراجع/إعادة فورًا)
    // بدل الاعتماد على استدعاء خارجي قد يُنسى مستقبلًا عند إضافة مسار جديد.
    if (mounted) setState(() {});
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_annotations.map((a) => a.copy()).toList());
    final prev = _undoStack.removeLast();
    setState(() {
      _annotations
        ..clear()
        ..addAll(prev);
    });
    _scheduleAutoSave();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_annotations.map((a) => a.copy()).toList());
    final next = _redoStack.removeLast();
    setState(() {
      _annotations
        ..clear()
        ..addAll(next);
    });
    _scheduleAutoSave();
  }

  void _zoomIn() {
    setState(() => _zoomLevel = (_zoomLevel + 0.25).clamp(1.0, 3.0));
    _controller.zoomLevel = _zoomLevel;
  }

  void _zoomOut() {
    setState(() => _zoomLevel = (_zoomLevel - 0.25).clamp(1.0, 3.0));
    _controller.zoomLevel = _zoomLevel;
  }

  void _resetZoom() {
    setState(() => _zoomLevel = 1.0);
    _controller.zoomLevel = 1.0;
  }

  // ------- تتبّع التعديلات غير المحفوظة -------
  bool _hasUnsavedChanges = false;
  _TextAnnotation? _movingAnnotation; // النص الجاري نقله حاليًا (وضع "انقل هون")

  // ------- البحث داخل PDF (مع Debounce) -------
  bool _searchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult _searchResult = PdfTextSearchResult();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _disposed = true;
    _pendingAutoSave = false;
    _controller.dispose();
    _searchController.dispose();
    _searchResult.removeListener(_onSearchResultChanged);
    _searchDebounce?.cancel();
    _autoSaveDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  void _search(String query) {
    if (query.trim().isEmpty) {
      _searchResult.clear();
      setState(() {});
      return;
    }
    _searchResult.removeListener(_onSearchResultChanged);
    _searchResult = _controller.searchText(query);
    _searchResult.addListener(_onSearchResultChanged);
    setState(() {});
  }

  void _onSearchResultChanged() {
    if (mounted) setState(() {});
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    _searchResult.removeListener(_onSearchResultChanged);
    _searchResult.clear();
    setState(() {
      _searchVisible = false;
      _searchController.clear();
    });
  }

  void _handlePdfTap(PdfGestureDetails details) async {
    if (!_addTextMode && _movingAnnotation == null) return;

    // دقة تحديد الموضع (شاشة ↔ نقاط PDF) مضمونة فقط عند التكبير الافتراضي
    // 100% — أي تكبير/تصغير يُدخل انحرافًا حقيقيًا بين ما يظهر على
    // الشاشة والمكان الفعلي بالملف. نطلب من المستخدم إعادة الزووم لـ100%
    // أول لضمان دقة الإضافة/النقل.
    if ((_zoomLevel - 1.0).abs() > 0.01) {
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppText.t('ed_zoom_reset_needed', lang))),
      );
      return;
    }

    // pagePosition: الموضع الحقيقي بنقاط PDF (دقيق، يُستخدم للحفظ).
    // position: الموضع بكسلات عنصر العرض (تقريبي، للمعاينة الحيّة فقط).
    final pagePoint = details.pagePosition;
    final pageNumber = details.pageNumber;
    // Syncfusion يعيد -1 عند الضغط خارج حدود صفحة PDF. تجاهل هذه الضغطة
    // بدل إنشاء/نقل تعليق بإحداثيات غير صالحة.
    if (pageNumber < 1 || pagePoint.dx < 0 || pagePoint.dy < 0) return;

    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    final widgetSize = box?.size ?? const Size(400, 700);
    final previewFracX = (details.position.dx / widgetSize.width).clamp(0.0, 1.0);
    final previewFracY = (details.position.dy / widgetSize.height).clamp(0.0, 1.0);

    // وضع "نقل نص موجود": بدل السحب بالإصبع (غير دقيق هندسيًا)، نستخدم
    // نفس آلية الضغط الدقيقة المستخدمة بالإضافة — هيك النقل مضمون بنفس
    // دقة الإضافة تمامًا، بدل معامل تحويل تقريبي.
    if (_movingAnnotation != null) {
      final moved = _movingAnnotation!;
      _pushUndoState();
      setState(() {
        moved.pageNumber = pageNumber;
        moved.dx = pagePoint.dx;
        moved.dy = pagePoint.dy;
        moved.previewFracX = previewFracX;
        moved.previewFracY = previewFracY;
        _movingAnnotation = null;
      });
      _scheduleAutoSave();
      return;
    }

    final result = await _showTextDialog();
    if (result == null || result.text.trim().isEmpty) return;

    _pushUndoState();
    setState(() {
      _annotations.add(_TextAnnotation(
        pageNumber: pageNumber,
        dx: pagePoint.dx,
        dy: pagePoint.dy,
        previewFracX: previewFracX,
        previewFracY: previewFracY,
        text: result.text,
        fontSize: result.fontSize,
        color: result.color,
        alignment: result.alignment,
      ));
    });
    _scheduleAutoSave();
  }

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

  /// يستخرج كامل النص من ملف الـPDF الحالي بخيط منفصل (Isolate) بالخلفية
  /// عبر compute() — لتفادي تجميد الواجهة مع ملفات PDF كبيرة، لاستخدامه
  /// بميزات الذكاء الاصطناعي (التلخيص/الدردشة/الترجمة/القراءة الصوتية).
  Future<String> _extractFullText() async {
    // ميزات AI يجب أن ترى أحدث حالة للمستند، بما فيها التعليقات وحقول
    // النماذج والنصوص المضافة في هذه الشاشة، لا النسخة الأصلية فقط.
    final latestPath = await _runSerializedExport();
    final bytes = await File(latestPath).readAsBytes();
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

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    final formFields = _controller.getFormFields();
    if (formFields.isNotEmpty) {
      setState(() => _hasFormFields = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppText.t('ed_form_fields_detected', lang)} (${formFields.length})'),
            duration: const Duration(seconds: 4),
          ),
        );
      });
    }
  }

  void _setAnnotationMode(PdfAnnotationMode mode) {
    setState(() {
      _controller.annotationMode =
          _controller.annotationMode == mode ? PdfAnnotationMode.none : mode;
    });
  }

  /// المنطق الأساسي لتصدير المستند (يُستخدم من الحفظ اليدوي والحفظ التلقائي
  /// معًا) — يعيد مسار الملف الناتج، أو يرمي استثناء عند الفشل.
  Future<String> _exportToFile() async {
    if (_disposed) throw StateError('PDF editor is disposed');
    // Snapshot يمنع تغيّر القائمة أثناء await داخل حلقة الرسم.
    final annotationsSnapshot = _annotations.map((a) => a.copy()).toList(growable: false);
    // الخطوة 1: احفظ نسخة تتضمن تعليقات العارض المدمجة
    // (تظليل/تسطير/شطب/ملاحظات لاصقة) وبيانات حقول النموذج التي عبّأها المستخدم.
    final List<int> viewerBytes = await _controller.saveDocument(
      flattenOption: _flattenFormsOnSave ? PdfFlattenOption.formFields : PdfFlattenOption.none,
    );

    // الخطوة 2: افتح تلك النسخة وأضف فوقها نصوصنا المخصّصة (المربّعات النصية).
    final sf.PdfDocument document = sf.PdfDocument(inputBytes: viewerBytes);
    late final List<int> savedBytes;

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

        // إبقاء صندوق النص داخل الصفحة حتى عند الضغط قرب الحواف.
        final safeX = ann.dx.clamp(0.0, (pageSize.width - 1).clamp(0.0, double.infinity)).toDouble();
        final safeY = ann.dy.clamp(0.0, (pageSize.height - 1).clamp(0.0, double.infinity)).toDouble();
        final availableWidth = (pageSize.width - safeX).clamp(1.0, pageSize.width).toDouble();
        final availableHeight = (pageSize.height - safeY).clamp(1.0, pageSize.height).toDouble();

        page.graphics.drawString(
          ann.text,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(
            safeX,
            safeY,
            availableWidth,
            boxHeight.clamp(1.0, availableHeight).toDouble(),
          ),
          format: sf.PdfStringFormat(alignment: pdfAlignment),
        );
      }

      savedBytes = await document.save();
    } finally {
      // نضمن تحرير موارد المستند (Native) حتى لو فشل الرسم أو الحفظ —
      // بدون هذا، أي استثناء أثناء التصدير يسرّب ذاكرة المستند بصمت.
      document.dispose();
    }

    final dir = await getApplicationDocumentsDirectory();
    final rawName = widget.filePath.split('/').last;
    final originalName = rawName.toLowerCase().endsWith('.pdf') ? rawName.substring(0, rawName.length - 4) : rawName;
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

  /// يمرّر كل عمليات التصدير عبر طابور واحد. هذا يمنع الحفظ اليدوي
  /// والتلقائي (أو استخراج AI) من الكتابة إلى ملف .tmp نفسه بالتوازي.
  Future<String> _runSerializedExport() {
    final completer = Completer<String>();
    _saveQueue = _saveQueue.then((_) async {
      if (_disposed) {
        completer.completeError(StateError('PDF editor is disposed'));
        return;
      }
      try {
        completer.complete(await _exportToFile());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  void _onViewerContentChanged() {
    if (_disposed) return;
    _scheduleAutoSave();
    if (mounted) setState(() {});
  }

  /// حفظ تلقائي وصامت — يُستدعى فور إضافة/تعديل/نقل أي نص، بدون الحاجة
  /// لضغط زر الحفظ يدويًا. يُظهر إشعارًا صغيرًا بس (مو نافذة كاملة)
  /// حتى لا يقاطع المستخدم أثناء إضافة عدة نصوص متتالية.
  /// يجدول حفظًا تلقائيًا بعد فترة قصيرة من التوقف عن التعديل (بدل تصدير
  /// الملف كاملًا فورًا مع كل تعديل) — مهم للأداء مع الملفات الكبيرة،
  /// خصوصًا لو المستخدم عدّل/نقل نفس النص عدة مرات متتالية بسرعة.
  void _scheduleAutoSave() {
    if (_disposed) return;
    _hasUnsavedChanges = true;
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 1200), _autoSaveSilently);
  }

  Future<void> _autoSaveSilently() async {
    if (_disposed) return;
    if (_autoSaving) {
      // فيه حفظ شغّال حاليًا — بدل ما نتجاهل هالتعديل، نعلّمه "معلّق"
      // وينفَّذ تلقائيًا فور ما ينتهي الحفظ الحالي، حتى ما نخسر أي تعديل.
      _pendingAutoSave = true;
      return;
    }
    _autoSaving = true;
    _pendingAutoSave = false;
    try {
      await _runSerializedExport();
      // لو وصل تعديل جديد أثناء التصدير (_pendingAutoSave رجعت true)، ما
      // نعتبر الحالة "محفوظة" بعد — الحفظ التالي (بالأسفل بـfinally) هو
      // يلي رح يحدّث الحالة فعليًا لما يخلص.
      if (!_pendingAutoSave) _hasUnsavedChanges = false;
      if (mounted) {
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
    } catch (e, stack) {
      // نبقيها صامتة بالنسبة للمستخدم (له زر الحفظ اليدوي كبديل)، لكن
      // نسجّلها بوضع Debug حتى نقدر نشخّص أي مشكلة حفظ متكررة مستقبلًا.
      if (kDebugMode) {
        debugPrint('فشل الحفظ التلقائي: $e');
        debugPrintStack(stackTrace: stack);
      }
    } finally {
      _autoSaving = false;
      if (_pendingAutoSave && !_disposed) {
        // وصل تعديل جديد أثناء الحفظ — نفّذ حفظًا آخر فورًا حتى لا يضيع.
        _pendingAutoSave = false;
        unawaited(_autoSaveSilently());
      }
    }
  }

  Future<void> _saveDocument() async {
    _autoSaveDebounce?.cancel();
    setState(() => _saving = true);
    try {
      final outPath = await _runSerializedExport();
      _hasUnsavedChanges = false;

      if (!mounted) return;
      setState(() => _saving = false);
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      String tr(String key) => AppText.t(key, lang);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('ed_saved_title')),
          content: Text('${tr('ed_saved_path_prefix')}\n$outPath'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Share.shareXFiles([XFile(outPath)], text: '${tr('file_from_app_prefix')} MN-Doc');
              },
              child: Text(tr('ed_share')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => PdfEditorScreen(filePath: outPath)),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
              child: Text(tr('ed_open_saved_file')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppText.t('ed_save_error_prefix', lang)} $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSearchResult = _searchResult.hasResult;
    final settings = context.watch<AppSettingsController>();
    final lang = settings.languageCode;
    String tr(String key) => AppText.t(key, lang);

    return Directionality(
      textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: PopScope(
        canPop: !_hasUnsavedChanges,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(tr('unsaved_title')),
              content: Text(tr('unsaved_body')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('cancel'))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(tr('discard_exit')),
                ),
              ],
            ),
          );
          if (shouldDiscard == true && context.mounted) {
            Navigator.pop(context);
          }
        },
        child: Scaffold(
      // نمنع تغيّر حجم الشاشة عند ظهور لوحة المفاتيح — هذا يضمن بقاء
      // موضع النصوص المضافة مستقرًا بصريًا حتى أثناء فتح نافذة التعديل.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(widget.filePath.split('/').last, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: tr('undo'),
            onPressed: _undoStack.isEmpty ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            tooltip: tr('redo'),
            onPressed: _redoStack.isEmpty ? null : _redo,
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: tr('ed_search_tooltip'),
            onPressed: () => setState(() => _searchVisible = !_searchVisible),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded),
            tooltip: tr('ed_bookmarks_tooltip'),
            onPressed: () => _pdfViewerStateKey.currentState?.openBookmarkView(),
          ),
          IconButton(
            icon: Icon(_addTextMode ? Icons.text_fields_rounded : Icons.text_fields_outlined),
            tooltip: tr('ed_addtext_tooltip'),
            onPressed: () => setState(() => _addTextMode = !_addTextMode),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.smart_toy_rounded),
            tooltip: tr('ed_ai_tooltip'),
            onSelected: _openAiFeature,
            itemBuilder: (context) => [
              PopupMenuItem(value: 'summarize', child: Text(tr('ed_ai_summarize'))),
              PopupMenuItem(value: 'chat', child: Text(tr('ed_ai_chat'))),
              PopupMenuItem(value: 'translate', child: Text(tr('ed_ai_translate'))),
              PopupMenuItem(value: 'read_aloud', child: Text(tr('tool_tts_t'))),
            ],
          ),
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                )
              : IconButton(
                  icon: Badge(
                    isLabelVisible: _hasUnsavedChanges,
                    smallSize: 8,
                    backgroundColor: Colors.orangeAccent,
                    child: const Icon(Icons.save_rounded),
                  ),
                  tooltip: tr('save'),
                  onPressed: _saveDocument,
                ),
        ],
      ),
      body: Column(
        children: [
          if (_searchVisible)
            Container(
              color: AppColors.primaryDark.withOpacity(0.06),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: tr('ed_search_hint'),
                        isDense: true,
                      ),
                      onSubmitted: _search,
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  if (hasSearchResult) ...[
                    Text('${_searchResult.currentInstanceIndex}/${_searchResult.totalInstanceCount}',
                        style: const TextStyle(fontSize: 12)),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      onPressed: () => _searchResult.previousInstance(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      onPressed: () => _searchResult.nextInstance(),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _closeSearch,
                  ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _annotationChip(
                    icon: Icons.border_color_rounded,
                    label: tr('ed_highlight'),
                    mode: PdfAnnotationMode.highlight,
                  ),
                  _annotationChip(
                    icon: Icons.format_underlined_rounded,
                    label: tr('ed_underline'),
                    mode: PdfAnnotationMode.underline,
                  ),
                  _annotationChip(
                    icon: Icons.strikethrough_s_rounded,
                    label: tr('ed_strikethrough'),
                    mode: PdfAnnotationMode.strikethrough,
                  ),
                  _annotationChip(
                    icon: Icons.sticky_note_2_rounded,
                    label: tr('ed_stickynote'),
                    mode: PdfAnnotationMode.stickyNote,
                  ),
                ],
              ),
            ),
          ),
          if (_hasFormFields)
            Container(
              width: double.infinity,
              color: Colors.green.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.fact_check_rounded, size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tr('ed_form_banner'), style: const TextStyle(fontSize: 12)),
                  ),
                  Text(tr('ed_form_flatten'), style: const TextStyle(fontSize: 11)),
                  Switch(
                    value: _flattenFormsOnSave,
                    onChanged: (v) => setState(() => _flattenFormsOnSave = v),
                  ),
                ],
              ),
            ),
          if (_addTextMode)
            Container(
              width: double.infinity,
              color: AppColors.accent.withOpacity(0.12),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                tr('ed_addtext_banner'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (_movingAnnotation != null)
            Container(
              width: double.infinity,
              color: AppColors.primaryDark.withOpacity(0.15),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('ed_tap_new_location'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _movingAnnotation = null),
                    child: Text(tr('cancel'), style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              key: _viewerKey,
              children: [
                SfPdfViewer.file(
                  File(widget.filePath),
                  key: _pdfViewerStateKey,
                  controller: _controller,
                  // عرض صفحة واحدة في كل مرة لضمان دقة وضع النصوص المضافة
                  pageLayoutMode: PdfPageLayoutMode.single,
                  onPageChanged: (details) {
                    _currentPage = details.newPageNumber;
                  },
                  onDocumentLoaded: _onDocumentLoaded,
                  // أي تعديل داخل أدوات Syncfusion نفسها يجب أن يدخل في
                  // unsaved/autosave، وليس فقط نصوصنا المخصصة.
                  onAnnotationAdded: (_) => _onViewerContentChanged(),
                  onAnnotationEdited: (_) => _onViewerContentChanged(),
                  onAnnotationRemoved: (_) => _onViewerContentChanged(),
                  onFormFieldValueChanged: (_) => _onViewerContentChanged(),
                  onTap: _handlePdfTap,
                ),
                // طبقة عرض النصوص المضافة على الصفحة الحالية فقط
                ..._annotations
                    .where((a) => a.pageNumber == _currentPage)
                    .map((ann) => _buildAnnotationOverlay(ann)),
                // أزرار التكبير/التصغير العائمة
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'zoom_in',
                        onPressed: _zoomIn,
                        backgroundColor: AppColors.primaryDark,
                        child: const Icon(Icons.add_rounded, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoom_out',
                        onPressed: _zoomOut,
                        backgroundColor: AppColors.primaryDark,
                        child: const Icon(Icons.remove_rounded, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoom_reset',
                        onPressed: _resetZoom,
                        backgroundColor: AppColors.textMuted,
                        child: const Icon(Icons.center_focus_strong_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
      ),
    );
  }

  Widget _annotationChip({required IconData icon, required String label, required PdfAnnotationMode mode}) {
    final active = _controller.annotationMode == mode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        avatar: Icon(icon, size: 18, color: active ? Colors.white : AppColors.primaryDark),
        label: Text(label),
        selected: active,
        selectedColor: AppColors.primaryDark,
        labelStyle: TextStyle(
          color: active ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppColors.textDark),
          fontSize: 12,
        ),
        onSelected: (_) => _setAnnotationMode(mode),
      ),
    );
  }

  Widget _buildAnnotationOverlay(_TextAnnotation ann) {
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? const Size(400, 700);
    final isBeingMoved = identical(ann, _movingAnnotation);
    return Positioned(
      left: ann.previewFracX * size.width,
      top: ann.previewFracY * size.height,
      child: GestureDetector(
        onTap: () => _showAnnotationActionSheet(ann),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            border: isBeingMoved ? Border.all(color: AppColors.accent, width: 2) : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            ann.text,
            textAlign: ann.alignment,
            style: TextStyle(fontSize: ann.fontSize * 0.8, color: ann.color),
          ),
        ),
      ),
    );
  }

  /// عند الضغط على نص موجود: قائمة صغيرة "تعديل" أو "نقل" — النقل يعتمد
  /// على نفس آلية الضغط الدقيقة المستخدمة بالإضافة (بدل السحب بالإصبع
  /// غير المضمون هندسيًا)، فيضغط المستخدم على المكان الجديد مباشرة.
  void _showAnnotationActionSheet(_TextAnnotation ann) {
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    String tr(String key) => AppText.t(key, lang);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: Text(tr('ed_action_edit')),
              onTap: () {
                Navigator.pop(context);
                _editAnnotation(ann);
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_with_rounded),
              title: Text(tr('ed_action_move')),
              onTap: () {
                Navigator.pop(context);
                if ((_zoomLevel - 1.0).abs() > 0.01) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('ed_zoom_reset_needed'))),
                  );
                  return;
                }
                setState(() => _movingAnnotation = ann);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('ed_tap_new_location'))),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: Text(tr('ed_action_delete'), style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
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

class _TextDialogResult {
  final String text;
  final double fontSize;
  final Color color;
  final TextAlign alignment;
  _TextDialogResult({required this.text, required this.fontSize, required this.color, this.alignment = TextAlign.right});
}
