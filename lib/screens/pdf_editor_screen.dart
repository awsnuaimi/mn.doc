import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
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
import 'manage_pages_screen.dart';

/// نص مضاف إلى صفحة PDF.
///
/// المصدر الوحيد للحقيقة هو (pageNumber, dx, dy) بإحداثيات صفحة PDF نفسها.
/// لا نخزّن أي إحداثيات شاشة داخل التعليق؛ موضع المعاينة يُشتق لحظيًا من
/// تحويل الصفحة الحالية، لذلك الإضافة والنقل والحفظ تستخدم النظام نفسه.
class _TextAnnotation {
  int pageNumber; // يبدأ من 1
  double dx; // X بنقاط PDF
  double dy; // Y بنقاط PDF
  String text;
  double fontSize;
  Color color;
  TextAlign alignment;

  _TextAnnotation({
    required this.pageNumber,
    required this.dx,
    required this.dy,
    required this.text,
    this.fontSize = 16,
    this.color = Colors.black,
    this.alignment = TextAlign.right,
  });

  _TextAnnotation copy() => _TextAnnotation(
        pageNumber: pageNumber,
        dx: dx,
        dy: dy,
        text: text,
        fontSize: fontSize,
        color: color,
        alignment: alignment,
      );
}


class _ImageAnnotation {
  int pageNumber;
  double dx;
  double dy;
  double width;
  double height;
  final Uint8List bytes;

  _ImageAnnotation({required this.pageNumber, required this.dx, required this.dy, required this.width, required this.height, required this.bytes});

  // بيانات الصورة نفسها لا تتغير بعد إنشاء التعليق، لذلك نسخ حالة المحرر
  // يشارك نفس Uint8List بدل استنساخ عدة ميغابايت مع كل Undo/Redo.
  // الموضع والحجم يبقيان مستقلين لأنهما قيم scalar داخل كائن جديد.
  _ImageAnnotation copy() => _ImageAnnotation(
    pageNumber: pageNumber,
    dx: dx,
    dy: dy,
    width: width,
    height: height,
    bytes: bytes,
  );
}

/// تحويل هندسي من إحداثيات صفحة PDF (points) إلى إحداثيات الـViewer (pixels).
/// يُعاد حسابه/معايرته من ضغطة Syncfusion الحقيقية، ولا يدخل في بيانات النص.
class _PdfPageTransform {
  final double scale;
  final Offset origin;

  const _PdfPageTransform({required this.scale, required this.origin});

  Offset pdfToViewer(Offset pdfPoint) => origin + pdfPoint * scale;
}

/// لقطة قابلة للتوسّع لحالة المحرر. تحتوي النصوص والصور المخصّصة.
/// نسخ الصور هنا خفيف: _ImageAnnotation.copy() ينسخ هندسة التعليق فقط
/// ويشارك bytes الصورة غير المعدّلة بين اللقطات، لمنع تضخم ذاكرة Undo/Redo.
class _EditorSnapshot {
  final List<_TextAnnotation> textAnnotations;
  final List<_ImageAnnotation> imageAnnotations;

  _EditorSnapshot({required this.textAnnotations, required this.imageAnnotations});

  factory _EditorSnapshot.capture(List<_TextAnnotation> annotations, List<_ImageAnnotation> images) =>
      _EditorSnapshot(
        textAnnotations: annotations.map((a) => a.copy()).toList(growable: false),
        imageAnnotations: images.map((a) => a.copy()).toList(growable: false),
      );
}

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
  final List<_ImageAnnotation> _imageAnnotations = [];
  Uint8List? _pendingImageBytes;
  bool _addImageMode = false;

  // حركة الصورة تُعامل كعملية واحدة في Undo/Redo مهما كان عدد أحداث السحب.
  // لا نسجل لقطة عند مجرد لمس الصورة، بل فقط بعد أول حركة فعلية.
  _EditorSnapshot? _imageDragBefore;
  _ImageAnnotation? _draggingImage;
  bool _imageDragChanged = false;
  final GlobalKey _viewerKey = GlobalKey();

  // أبعاد الصفحات الأصلية بنقاط PDF + التحويل الحالي للصفحة المعروضة.
  // لا تُخزّن إحداثيات الشاشة داخل _TextAnnotation إطلاقًا.
  final Map<int, Size> _pdfPageSizes = <int, Size>{};
  final Map<int, _PdfPageTransform> _pageTransforms = <int, _PdfPageTransform>{};

  bool _addTextMode = false;
  bool _saving = false;
  Timer? _autoSaveDebounce; // يجمّع عدة تعديلات متتالية سريعة بعملية تصدير واحدة بدل تصدير كامل لكل تعديل
  Future<void>? _saveQueue; // طابور تسلسلي واحد لكل عمليات الحفظ (يدوي + تلقائي) لمنع تعارضهم على نفس الملف
  bool _disposed = false; // نمنع أي حفظ أو setState بعد التخلص من الشاشة
  String? _lastExportedPath; // آخر مسار تصدير ناجح — تستخدمه ميزات الذكاء الاصطناعي لقراءة أحدث نسخة
  bool _flattenFormsOnSave = false;
  bool _hasFormFields = false;
  int _currentPage = 1;
  double _zoomLevel = 1.0;

  // ------- تراجع/إعادة موحّد وقابل للتوسعة لكل عناصر المحرر -------
  final _EditorHistory _history = _EditorHistory(limit: 20);

  _EditorSnapshot _captureEditorState() => _EditorSnapshot.capture(_annotations, _imageAnnotations);

  void _restoreEditorState(_EditorSnapshot snapshot) {
    _annotations
      ..clear()
      ..addAll(snapshot.textAnnotations.map((a) => a.copy()));
    _imageAnnotations
      ..clear()
      ..addAll(snapshot.imageAnnotations.map((a) => a.copy()));
  }

  void _pushUndoState() {
    _history.record(_captureEditorState());
    if (mounted) setState(() {});
  }

  void _undo() {
    final previous = _history.undo(_captureEditorState());
    if (previous == null) return;
    setState(() => _restoreEditorState(previous));
    _scheduleAutoSave();
  }

  void _redo() {
    final next = _history.redo(_captureEditorState());
    if (next == null) return;
    setState(() => _restoreEditorState(next));
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
  int _documentRevision = 0;
  int _savedRevision = 0;

  void _markDocumentChanged() {
    _documentRevision++;
    _hasUnsavedChanges = _documentRevision != _savedRevision;
  }
  // ------- تحريك النص بالسحب المباشر -------
  _TextAnnotation? _movingAnnotation;
  _TextAnnotation? _moveSnapshot;
  List<_TextAnnotation>? _moveUndoSnapshot;
  Timer? _moveHoldTimer;
  int? _movePointerId;
  Offset? _lastMovePointerPosition;
  bool _moveGestureArmed = false;
  static const Duration _moveHoldDuration = Duration(seconds: 3);

  // ------- البحث داخل PDF (مع Debounce) -------
  bool _searchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult _searchResult = PdfTextSearchResult();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _disposed = true;
    _controller.dispose();
    _searchController.dispose();
    _searchResult.removeListener(_onSearchResultChanged);
    _searchDebounce?.cancel();
    _autoSaveDebounce?.cancel();
    _moveHoldTimer?.cancel();
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
    if (!_addTextMode && !_addImageMode) return;

    // دقة تحديد الموضع (شاشة ↔ نقاط PDF) مضمونة فقط عند التكبير الافتراضي
    // 100% — أي تكبير/تصغير يُدخل انحرافًا حقيقيًا بين ما يظهر على
    // الشاشة والمكان الفعلي بالملف. نطلب من المستخدم إعادة الزووم لـ100%
    // أول لضمان دقة الإضافة.
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

    // لو الضغطة وقعت خارج حدود الصفحة فعليًا (بالهوامش الفاضية حول
    // الصفحة مثلًا)، Syncfusion بترجع pageNumber = -1 وإحداثيات سالبة —
    // نرفضها صراحة بدل ما نضيف/ننقل نص بمكان غير منطقي.
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

    if (_addImageMode && _pendingImageBytes != null) {
      final pageSize = _pdfPageSizes[pageNumber];
      if (pageSize == null) return;
      const defaultWidth = 140.0;
      const defaultHeight = 100.0;
      _pushUndoState();
      setState(() {
        _imageAnnotations.add(_ImageAnnotation(
          pageNumber: pageNumber,
          dx: pagePoint.dx.clamp(0.0, (pageSize.width - defaultWidth).clamp(0.0, pageSize.width)).toDouble(),
          dy: pagePoint.dy.clamp(0.0, (pageSize.height - defaultHeight).clamp(0.0, pageSize.height)).toDouble(),
          width: defaultWidth, height: defaultHeight, bytes: Uint8List.fromList(_pendingImageBytes!),
        ));
        _pendingImageBytes = null;
        _addImageMode = false;
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

  Future<void> _pickImageForPdf() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (picked == null) return;
    final bytes = await File(picked.path).readAsBytes();
    if (!mounted) return;
    setState(() {
      _pendingImageBytes = bytes;
      _addImageMode = true;
      _addTextMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اضغط على المكان المطلوب داخل الصفحة لإضافة الصورة')));
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
  /// يحدّد أفضل مسار نقرأ منه النص لميزات الذكاء الاصطناعي. لو فيه أي
  /// تعديلات محتملة (نصوص مضافة أو حقول نماذج بالملف)، ننفّذ تصديرًا
  /// طازجًا عبر طابور الحفظ نفسه أولًا لضمان قراءة أحدث حالة فعليًا —
  /// وليس مجرد التحقق من وجود نسخة محفوظة قد تكون قديمة.
  Future<String> _currentBestFilePath() async {
    if ((_annotations.isNotEmpty || _imageAnnotations.isNotEmpty) || _hasFormFields) {
      try {
        return await _runQueuedSave(showResult: false).then((_) => _lastExportedPath ?? widget.filePath);
      } catch (_) {
        // فشل التصدير الطازج: نرجع لأفضل نسخة محفوظة سابقًا إن وُجدت
      }
    }
    final dir = await getApplicationDocumentsDirectory();
    final rawName = widget.filePath.split('/').last;
    final originalName = rawName.toLowerCase().endsWith('.pdf') ? rawName.substring(0, rawName.length - 4) : rawName;
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

  Future<void> _loadPdfPageSizes() async {
    sf.PdfDocument? document;
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      document = sf.PdfDocument(inputBytes: bytes);
      final sizes = <int, Size>{};
      for (var i = 0; i < document.pages.count; i++) {
        sizes[i + 1] = document.pages[i].getClientSize();
      }
      if (_disposed || !mounted) return;
      setState(() {
        _pdfPageSizes
          ..clear()
          ..addAll(sizes);
        _pageTransforms.clear();
      });
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('تعذر قراءة أبعاد صفحات PDF: $e');
        debugPrintStack(stackTrace: stack);
      }
    } finally {
      document?.dispose();
    }
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

    // في pageLayoutMode.single وعند zoom=1 يعرض العارض الصفحة ضمن المساحة
    // المتاحة مع الحفاظ على نسبة أبعادها. هذا هو المقياس الأساسي. لا نعتمد
    // على هوامش مفترضة: الـorigin يُستخرج من النقطة الفعلية التي أعادها
    // Syncfusion، لذلك أي padding داخلي يدخل في المعايرة تلقائيًا.
    final scaleX = viewport.width / pageSize.width;
    final scaleY = viewport.height / pageSize.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;
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
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final rendered = Size(pageSize.width * scale, pageSize.height * scale);
    return _PdfPageTransform(
      scale: scale,
      origin: Offset(
        (viewport.width - rendered.width) / 2,
        (viewport.height - rendered.height) / 2,
      ),
    );
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    unawaited(_loadPdfPageSizes());
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
    if (markChanged) _markDocumentChanged();
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
    if (showResult && mounted) setState(() => _saving = true);

    String? outPath;
    Object? error;
    final revisionBeingSaved = _documentRevision;
    try {
      outPath = await _exportToFile();
      _lastExportedPath = outPath;
      if (!_disposed) {
        _savedRevision = revisionBeingSaved;
        _hasUnsavedChanges = _documentRevision != _savedRevision;
        // لو حصل تعديل أثناء التصدير، لا نعتبره محفوظًا ونجدول نسخة لاحقة.
        if (_hasUnsavedChanges) _scheduleAutoSave(markChanged: false);
      }
    } catch (e, stack) {
      error = e;
      if (kDebugMode) {
        debugPrint('فشل الحفظ: $e');
        debugPrintStack(stackTrace: stack);
      }
    }

    if (_disposed || !mounted) return;

    if (showResult) {
      setState(() => _saving = false);
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

  Future<void> _saveDocument() => _runQueuedSave(showResult: true);

  /// يثبت أحدث Revision فعليًا قبل أي عملية بنيوية على الصفحات.
  /// لا يكفي انتظار حفظ كان موجودًا بالطابور، لأن المستخدم قد يعدّل المستند
  /// أثناء ذلك الحفظ. لذلك نعيد الحفظ حتى تتطابق النسخة المحفوظة مع الحالية.
  Future<bool> _flushLatestRevisionForStructuralOperation() async {
    if (_disposed) return false;

    _autoSaveDebounce?.cancel();
    await (_saveQueue ?? Future.value()).catchError((_) {});
    if (_disposed || !mounted) return false;

    final needsExport = _hasUnsavedChanges ||
        _annotations.isNotEmpty ||
        _imageAnnotations.isNotEmpty ||
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
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(tr('cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(tr('discard_exit')),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, null),
                  icon: const Icon(Icons.save_rounded),
                  label: Text(tr('save')),
                ),
              ],
            ),
          );
          if (!context.mounted) return;

          if (shouldDiscard == true) {
            // خروج صريح بدون حفظ.
            _autoSaveDebounce?.cancel();
            _hasUnsavedChanges = false;
            Navigator.pop(context);
            return;
          }

          if (shouldDiscard == null) {
            // زر "حفظ": لا نخرج إلا بعد تثبيت أحدث Revision فعليًا.
            final saved = await _flushLatestRevisionForStructuralOperation();
            if (!context.mounted) return;

            if (saved && !_hasUnsavedChanges) {
              Navigator.pop(context);
            } else {
              final lang = Provider.of<AppSettingsController>(
                context,
                listen: false,
              ).languageCode;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppText.t('ed_save_error_prefix', lang)),
                ),
              );
            }
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
            onPressed: !_history.canUndo ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            tooltip: tr('redo'),
            onPressed: !_history.canRedo ? null : _redo,
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
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'إدارة الصفحات بالصور المصغرة',
            onPressed: _saving ? null : _openPageManager,
          ),
          IconButton(
            icon: Icon(_addTextMode ? Icons.text_fields_rounded : Icons.text_fields_outlined),
            tooltip: tr('ed_addtext_tooltip'),
            onPressed: () => setState(() { _addTextMode = !_addTextMode; if (_addTextMode) { _addImageMode = false; _pendingImageBytes = null; } }),
          ),
          IconButton(
            icon: Icon(_addImageMode ? Icons.image_rounded : Icons.add_photo_alternate_outlined),
            tooltip: 'إضافة صورة إلى PDF',
            onPressed: _pickImageForPdf,
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
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'اسحب النص بإصبعك إلى المكان المطلوب',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelTextMove,
                    child: Text(tr('cancel'), style: const TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: _confirmTextMove,
                    child: Text(
                      tr('ed_nudge_done'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
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
                    if (!mounted) return;
                    setState(() => _currentPage = details.newPageNumber);
                  },
                  onZoomLevelChanged: (details) {
                    if (!mounted) return;
                    setState(() {
                      _zoomLevel = details.newZoomLevel;
                      // أي تغيير zoom يغيّر إسقاط الصفحة على الشاشة. بما أن
                      // Tt يعمل بدقة عند 100% فقط، نمسح التحويلات القديمة.
                      _pageTransforms.clear();
                    });
                  },
                  onDocumentLoaded: _onDocumentLoaded,
                  onTap: _handlePdfTap,
                  // تعليقات Syncfusion المدمجة (تظليل/تسطير/شطب/ملاحظة لاصقة)
                  // وتعبئة حقول النماذج لا تمر بكودنا الخاص إطلاقًا — بدون
                  // هذه الاستدعاءات، أي تعديل منها ما كان رح يُحفَظ تلقائيًا.
                  onAnnotationAdded: (_) => _scheduleAutoSave(),
                  onAnnotationEdited: (_) => _scheduleAutoSave(),
                  onAnnotationRemoved: (_) => _scheduleAutoSave(),
                  onFormFieldValueChanged: (_) => _scheduleAutoSave(),
                ),
                // طبقة عرض النصوص المضافة على الصفحة الحالية فقط
                ..._annotations
                    .where((a) => a.pageNumber == _currentPage)
                    .map((ann) => _buildAnnotationOverlay(ann)),
                ..._imageAnnotations
                    .where((a) => a.pageNumber == _currentPage)
                    .map((ann) => _buildImageOverlay(ann)),
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

  Widget _buildImageOverlay(_ImageAnnotation ann) {
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

  void _finishImageDrag(_ImageAnnotation ann) {
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

  void _resizeImage(_ImageAnnotation ann, double factor) {
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

  void _showImageActionSheet(_ImageAnnotation ann) {
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
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
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

class _TextDialogResult {
  final String text;
  final double fontSize;
  final Color color;
  final TextAlign alignment;
  _TextDialogResult({required this.text, required this.fontSize, required this.color, this.alignment = TextAlign.right});
}
