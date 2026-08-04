import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../theme/app_theme.dart';
import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../services/isolate_helpers.dart';
import '../services/arabic_font_loader.dart';
import '../services/signature_library.dart';
import 'summarize_screen.dart';
import 'ai_chat_screen.dart';
import 'translate_screen.dart';
import 'tts_reader_screen.dart';

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
  double boxWidth; // عرض صندوق النص بنقاط PDF

  _TextAnnotation({
    required this.pageNumber,
    required this.dx,
    required this.dy,
    required this.text,
    this.fontSize = 16,
    this.color = Colors.black,
    this.alignment = TextAlign.right,
    this.boxWidth = 240,
  });

  _TextAnnotation copy() => _TextAnnotation(
        pageNumber: pageNumber,
        dx: dx,
        dy: dy,
        text: text,
        fontSize: fontSize,
        color: color,
        alignment: alignment,
        boxWidth: boxWidth,
      );
}

class _PdfImageElement {
  int pageNumber;
  double dx;
  double dy;
  double width;
  double height;
  double rotation;
  Uint8List bytes;
  String kind;

  _PdfImageElement({
    required this.pageNumber,
    required this.dx,
    required this.dy,
    required this.width,
    required this.height,
    required this.bytes,
    this.rotation = 0,
    this.kind = 'image',
  });

  _PdfImageElement copy() => _PdfImageElement(
        pageNumber: pageNumber, dx: dx, dy: dy, width: width, height: height,
        rotation: rotation, bytes: Uint8List.fromList(bytes), kind: kind,
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
  final List<_PdfImageElement> _imageElements = [];
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
    if (!_addTextMode) return;

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

    final result = await _showTextDialog();
    if (result == null || result.text.trim().isEmpty) return;

    _pushUndoState();
    setState(() {
      _annotations.add(_TextAnnotation(
        pageNumber: pageNumber,
        dx: pagePoint.dx,
        dy: pagePoint.dy,
        text: result.text,
        fontSize: result.fontSize,
        color: result.color,
        alignment: result.alignment,
        boxWidth: result.boxWidth,
      ));
    });
    _scheduleAutoSave();
  }

  Future<_TextDialogResult?> _showTextDialog({
    String initialText = '',
    double initialSize = 16,
    Color initialColor = Colors.black,
    TextAlign initialAlignment = TextAlign.right,
    double initialBoxWidth = 240,
  }) {
    final controller = TextEditingController(text: initialText);
    double fontSize = initialSize;
    Color color = initialColor;
    TextAlign alignment = initialAlignment;
    double boxWidth = initialBoxWidth.clamp(80.0, 500.0);
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('عرض صندوق النص'),
                      Expanded(
                        child: Slider(
                          value: boxWidth, min: 80, max: 500, divisions: 84,
                          label: '${boxWidth.round()} pt',
                          onChanged: (v) => setSheetState(() => boxWidth = v),
                        ),
                      ),
                      SizedBox(width: 48, child: Text('${boxWidth.round()}', textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _TextDialogResult(text: controller.text, fontSize: fontSize, color: color, alignment: alignment, boxWidth: boxWidth),
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
      initialBoxWidth: ann.boxWidth,
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
        ann.boxWidth = result.boxWidth;
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
    if (_annotations.isNotEmpty || _imageElements.isNotEmpty || _hasFormFields) {
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

  Future<void> _addImageFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (picked == null) return;
    final bytes = await File(picked.path).readAsBytes();
    _insertImageElement(bytes, kind: 'image');
  }

  Future<void> _addSavedMark() async {
    final marks = await SignatureLibrary.list();
    if (!mounted) return;
    if (marks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد تواقيع أو أختام محفوظة. أنشئ توقيعًا من أداة التوقيع أولًا.')),
      );
      return;
    }
    final mark = await showModalBottomSheet<SavedMark>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: marks.length,
          itemBuilder: (_, i) {
            final m = marks[i];
            return ListTile(
              leading: SizedBox(width: 56, height: 40, child: Image.file(File(m.filePath), fit: BoxFit.contain)),
              title: Text(m.name),
              subtitle: Text(m.type == MarkType.signature ? 'توقيع' : 'ختم'),
              onTap: () => Navigator.pop(sheetContext, m),
            );
          },
        ),
      ),
    );
    if (mark == null) return;
    final bytes = await File(mark.filePath).readAsBytes();
    _insertImageElement(bytes, kind: mark.type == MarkType.signature ? 'signature' : 'stamp');
  }

  void _insertImageElement(Uint8List bytes, {required String kind}) {
    final pageSize = _pdfPageSizes[_currentPage];
    if (pageSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('انتظر حتى يكتمل تحميل صفحة PDF ثم حاول مجددًا.')));
      return;
    }
    final w = kind == 'image' ? 180.0 : 150.0;
    final h = kind == 'image' ? 120.0 : 65.0;
    setState(() {
      _imageElements.add(_PdfImageElement(
        pageNumber: _currentPage,
        dx: ((pageSize.width - w) / 2).clamp(0.0, pageSize.width),
        dy: ((pageSize.height - h) / 2).clamp(0.0, pageSize.height),
        width: w, height: h, bytes: bytes, kind: kind,
      ));
      _hasUnsavedChanges = true;
    });
    _scheduleAutoSave();
  }

  Future<void> _showImageElementActions(_PdfImageElement e) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.aspect_ratio_rounded),
            title: const Text('الحجم والتدوير'),
            onTap: () { Navigator.pop(sheetContext); _editImageGeometry(e); },
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: const Text('نسخ'),
            onTap: () {
              Navigator.pop(sheetContext);
              final c = e.copy();
              c.dx += 12; c.dy += 12;
              setState(() { _imageElements.add(c); _hasUnsavedChanges = true; });
              _scheduleAutoSave();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            title: const Text('حذف', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(sheetContext);
              setState(() { _imageElements.remove(e); _hasUnsavedChanges = true; });
              _scheduleAutoSave();
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _editImageGeometry(_PdfImageElement e) async {
    double width = e.width, rotation = e.rotation;
    final ratio = e.height <= 0 ? 1.0 : e.width / e.height;
    final result = await showModalBottomSheet<List<double>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('الحجم والتدوير', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(children: [
              const Text('الحجم'),
              Expanded(child: Slider(value: width.clamp(50, 400), min: 50, max: 400, onChanged: (v) => setSheet(() => width = v))),
              Text('${width.round()}'),
            ]),
            Row(children: [
              const Text('التدوير'),
              Expanded(child: Slider(value: rotation.clamp(-180, 180), min: -180, max: 180, divisions: 72, onChanged: (v) => setSheet(() => rotation = v))),
              Text('${rotation.round()}°'),
            ]),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, [width, rotation]), child: const Text('تطبيق')),
          ]),
        ),
      )),
    );
    if (result == null) return;
    setState(() {
      e.width = result[0];
      e.height = result[0] / ratio;
      e.rotation = result[1];
      _hasUnsavedChanges = true;
    });
    _scheduleAutoSave();
  }

  Widget _buildImageElementOverlay(_PdfImageElement e) {
    final transform = _pageTransforms[e.pageNumber] ?? _fallbackPageTransform(e.pageNumber);
    if (transform == null) return const SizedBox.shrink();
    final point = transform.pdfToViewer(Offset(e.dx, e.dy));
    return Positioned(
      left: point.dx,
      top: point.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showImageElementActions(e),
        onPanUpdate: (d) {
          final pageSize = _pdfPageSizes[e.pageNumber];
          if (pageSize == null || transform.scale <= 0) return;
          final delta = d.delta / transform.scale;
          setState(() {
            e.dx = (e.dx + delta.dx).clamp(0.0, (pageSize.width - e.width).clamp(0.0, pageSize.width)).toDouble();
            e.dy = (e.dy + delta.dy).clamp(0.0, (pageSize.height - e.height).clamp(0.0, pageSize.height)).toDouble();
            _hasUnsavedChanges = true;
          });
        },
        onPanEnd: (_) => _scheduleAutoSave(),
        child: Transform.rotate(
          angle: e.rotation * 3.141592653589793 / 180.0,
          child: Container(
            width: e.width * transform.scale,
            height: e.height * transform.scale,
            decoration: BoxDecoration(border: Border.all(color: AppColors.accent, width: 1.5)),
            child: Image.memory(e.bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
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
        final requestedWidth = ann.boxWidth.clamp(minBoxWidth, pageSize.width);
        final boxWidth = requestedWidth > availableWidth ? availableWidth : requestedWidth;

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

      final imageSnapshot = _imageElements.map((e) => e.copy()).toList(growable: false);
      for (final e in imageSnapshot) {
        final pageIndex = e.pageNumber - 1;
        if (pageIndex < 0 || pageIndex >= document.pages.count) continue;
        final page = document.pages[pageIndex];
        final graphics = page.graphics;
        final bitmap = sf.PdfBitmap(e.bytes);
        graphics.save();
        try {
          final cx = e.dx + e.width / 2;
          final cy = e.dy + e.height / 2;
          graphics.translateTransform(cx, cy);
          graphics.rotateTransform(e.rotation);
          graphics.drawImage(bitmap, Rect.fromLTWH(-e.width / 2, -e.height / 2, e.width, e.height));
        } finally {
          graphics.restore();
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
  void _scheduleAutoSave() {
    if (_disposed) return;
    _hasUnsavedChanges = true;
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 1200), () {
      if (!_disposed) unawaited(_runQueuedSave(showResult: false));
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
    try {
      outPath = await _exportToFile();
      _lastExportedPath = outPath;
      if (!_disposed) _hasUnsavedChanges = false;
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

  // ═══════════════════════════════════════════════════════════════
  // إدارة صفحات PDF — حذف / تدوير / صفحة فارغة / نسخ
  // ═══════════════════════════════════════════════════════════════

  Future<String> _preparePageOperationSource() async {
    // نمر عبر طابور الحفظ أولًا حتى تدخل النصوص والصور والتواقيع
    // والتعليقات وحقول النماذج في النسخة التي سنجري عليها عملية الصفحات.
    await _runQueuedSave(showResult: false);
    return _lastExportedPath ?? widget.filePath;
  }

  sf.PdfPageRotateAngle _rotateRightValue(sf.PdfPageRotateAngle value) {
    switch (value) {
      case sf.PdfPageRotateAngle.rotateAngle0:
        return sf.PdfPageRotateAngle.rotateAngle90;
      case sf.PdfPageRotateAngle.rotateAngle90:
        return sf.PdfPageRotateAngle.rotateAngle180;
      case sf.PdfPageRotateAngle.rotateAngle180:
        return sf.PdfPageRotateAngle.rotateAngle270;
      case sf.PdfPageRotateAngle.rotateAngle270:
        return sf.PdfPageRotateAngle.rotateAngle0;
    }
  }

  sf.PdfPageRotateAngle _rotateLeftValue(sf.PdfPageRotateAngle value) {
    switch (value) {
      case sf.PdfPageRotateAngle.rotateAngle0:
        return sf.PdfPageRotateAngle.rotateAngle270;
      case sf.PdfPageRotateAngle.rotateAngle90:
        return sf.PdfPageRotateAngle.rotateAngle0;
      case sf.PdfPageRotateAngle.rotateAngle180:
        return sf.PdfPageRotateAngle.rotateAngle90;
      case sf.PdfPageRotateAngle.rotateAngle270:
        return sf.PdfPageRotateAngle.rotateAngle180;
    }
  }

  Future<void> _runPageOperation(String operation) async {
    if (_saving) return;

    if (operation == 'delete' && _pdfPageSizes.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن حذف الصفحة الوحيدة في المستند.')),
      );
      return;
    }

    if (operation == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('حذف الصفحة'),
          content: Text('هل تريد حذف الصفحة $_currentPage نهائيًا من النسخة الجديدة؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _saving = true);
    sf.PdfDocument? document;
    try {
      final sourcePath = await _preparePageOperationSource();
      final sourceBytes = await File(sourcePath).readAsBytes();
      document = sf.PdfDocument(inputBytes: sourceBytes);

      final pageIndex = (_currentPage - 1).clamp(0, document.pages.count - 1);

      switch (operation) {
        case 'rotate_right':
          final page = document.pages[pageIndex];
          page.rotation = _rotateRightValue(page.rotation);
          break;

        case 'rotate_left':
          final page = document.pages[pageIndex];
          page.rotation = _rotateLeftValue(page.rotation);
          break;

        case 'delete':
          document.pages.removeAt(pageIndex);
          break;

        case 'blank_before':
          final currentSize = document.pages[pageIndex].size;
          document.pages.insert(pageIndex, currentSize);
          break;

        case 'blank_after':
          final currentSize = document.pages[pageIndex].size;
          document.pages.insert(pageIndex + 1, currentSize);
          break;

        case 'duplicate':
          // createTemplate يلتقط محتوى الصفحة الحالية، ثم نرسمه على صفحة
          // جديدة بالحجم نفسه. هذا يتجنب الاعتماد على API نسخ غير موجودة.
          final sourcePage = document.pages[pageIndex];
          final template = sourcePage.createTemplate();
          final newPage = document.pages.insert(pageIndex + 1, sourcePage.size);
          newPage.graphics.drawPdfTemplate(
            template,
            Offset.zero,
            sourcePage.size,
          );
          break;
      }

      final bytes = await document.save();
      final dir = await getApplicationDocumentsDirectory();
      final rawName = widget.filePath.split('/').last;
      final baseName = rawName.toLowerCase().endsWith('.pdf')
          ? rawName.substring(0, rawName.length - 4)
          : rawName;
      final outPath =
          '${dir.path}/${baseName}_pages_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final tmp = File('$outPath.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(outPath);

      if (!mounted) return;
      setState(() => _saving = false);

      // نفتح النسخة البنيوية الجديدة فورًا؛ هكذا يعيد SfPdfViewer تحميل
      // عدد الصفحات وترتيبها ودورانها من الملف نفسه.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PdfEditorScreen(filePath: outPath)),
      );
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('فشلت عملية إدارة الصفحات: $e');
        debugPrintStack(stackTrace: stack);
      }
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تنفيذ عملية الصفحة. لم يتم تعديل الملف الأصلي.')),
      );
    } finally {
      document?.dispose();
    }
  }


  Future<String> _writePageOperationDocument(sf.PdfDocument document, String tag) async {
    final bytes = await document.save();
    final dir = await getApplicationDocumentsDirectory();
    final rawName = widget.filePath.split('/').last;
    final baseName = rawName.toLowerCase().endsWith('.pdf')
        ? rawName.substring(0, rawName.length - 4)
        : rawName;
    final outPath = '${dir.path}/${baseName}_${tag}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final tmp = File('$outPath.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(outPath);
    return outPath;
  }

  Future<void> _openStructuralResult(String outPath) async {
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PdfEditorScreen(filePath: outPath)),
    );
  }

  Future<void> _moveCurrentPage(int delta) async {
    if (_saving || _pdfPageSizes.length < 2) return;
    final oldIndex = _currentPage - 1;
    final newIndex = oldIndex + delta;
    if (newIndex < 0 || newIndex >= _pdfPageSizes.length) return;
    setState(() => _saving = true);
    sf.PdfDocument? document;
    try {
      final sourcePath = await _preparePageOperationSource();
      document = sf.PdfDocument(inputBytes: await File(sourcePath).readAsBytes());
      final order = List<int>.generate(document.pages.count, (i) => i);
      final moved = order.removeAt(oldIndex);
      order.insert(newIndex, moved);
      document.pages.reArrangePages(order);
      final outPath = await _writePageOperationDocument(document, 'reordered');
      await _openStructuralResult(outPath);
    } catch (e, stack) {
      if (kDebugMode) { debugPrint('فشل إعادة ترتيب الصفحات: $e'); debugPrintStack(stackTrace: stack); }
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إعادة ترتيب الصفحة.')));
      }
    } finally { document?.dispose(); }
  }

  Future<void> _importPagesFromPdf() async {
    if (_saving) return;
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;
    setState(() => _saving = true);
    sf.PdfDocument? target;
    sf.PdfDocument? source;
    try {
      final basePath = await _preparePageOperationSource();
      target = sf.PdfDocument(inputBytes: await File(basePath).readAsBytes());
      source = sf.PdfDocument(inputBytes: await File(path).readAsBytes());
      var insertAt = (_currentPage).clamp(0, target.pages.count);
      for (var i = 0; i < source.pages.count; i++) {
        final src = source.pages[i];
        final template = src.createTemplate();
        final page = target.pages.insert(insertAt++, src.size);
        page.graphics.drawPdfTemplate(template, Offset.zero, src.size);
      }
      final outPath = await _writePageOperationDocument(target, 'imported');
      await _openStructuralResult(outPath);
    } catch (e, stack) {
      if (kDebugMode) { debugPrint('فشل استيراد الصفحات: $e'); debugPrintStack(stackTrace: stack); }
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر استيراد صفحات PDF.')));
      }
    } finally { source?.dispose(); target?.dispose(); }
  }

  Future<void> _extractPages(Set<int> selected) async {
    if (_saving || selected.isEmpty) return;
    setState(() => _saving = true);
    sf.PdfDocument? source;
    sf.PdfDocument? output;
    try {
      final sourcePath = await _preparePageOperationSource();
      source = sf.PdfDocument(inputBytes: await File(sourcePath).readAsBytes());
      output = sf.PdfDocument();
      output.pages.removeAt(0);
      final ordered = selected.toList()..sort();
      for (final pageNumber in ordered) {
        final src = source.pages[pageNumber - 1];
        final template = src.createTemplate();
        final dst = output.pages.add(src.size);
        dst.graphics.drawPdfTemplate(template, Offset.zero, src.size);
      }
      final outPath = await _writePageOperationDocument(output, 'extracted');
      if (!mounted) return;
      setState(() => _saving = false);
      await Share.shareXFiles([XFile(outPath)], text: 'صفحات مستخرجة من MN-Doc');
    } catch (e, stack) {
      if (kDebugMode) { debugPrint('فشل استخراج الصفحات: $e'); debugPrintStack(stackTrace: stack); }
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر استخراج الصفحات.')));
      }
    } finally { output?.dispose(); source?.dispose(); }
  }

  Future<void> _runMultiPageOperation(Set<int> selected, String operation) async {
    if (_saving || selected.isEmpty) return;
    final ordered = selected.toList()..sort();

    if (operation == 'delete' && ordered.length >= _pdfPageSizes.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن حذف جميع صفحات المستند. اترك صفحة واحدة على الأقل.')),
      );
      return;
    }

    if (operation == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('حذف الصفحات المحددة'),
          content: Text('سيتم حذف ${ordered.length} صفحة من النسخة الجديدة. هل تريد المتابعة؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _saving = true);
    sf.PdfDocument? document;
    try {
      final sourcePath = await _preparePageOperationSource();
      document = sf.PdfDocument(inputBytes: await File(sourcePath).readAsBytes());

      switch (operation) {
        case 'rotate_right':
          for (final n in ordered) {
            final page = document.pages[n - 1];
            page.rotation = _rotateRightValue(page.rotation);
          }
          break;
        case 'rotate_left':
          for (final n in ordered) {
            final page = document.pages[n - 1];
            page.rotation = _rotateLeftValue(page.rotation);
          }
          break;
        case 'delete':
          for (final n in ordered.reversed) {
            document.pages.removeAt(n - 1);
          }
          break;
        case 'duplicate':
          final templates = <sf.PdfTemplate>[];
          final sizes = <Size>[];
          for (final n in ordered) {
            final src = document.pages[n - 1];
            templates.add(src.createTemplate());
            sizes.add(src.size);
          }
          for (var i = 0; i < templates.length; i++) {
            final dst = document.pages.add(sizes[i]);
            dst.graphics.drawPdfTemplate(templates[i], Offset.zero, sizes[i]);
          }
          break;
      }

      final tag = operation == 'delete'
          ? 'multi_deleted'
          : operation == 'duplicate'
              ? 'multi_duplicated'
              : 'multi_rotated';
      final outPath = await _writePageOperationDocument(document, tag);
      await _openStructuralResult(outPath);
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('فشلت العملية الجماعية للصفحات: $e');
        debugPrintStack(stackTrace: stack);
      }
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تنفيذ العملية على الصفحات المحددة.')),
        );
      }
    } finally {
      document?.dispose();
    }
  }

  Future<void> _showMultiPageSelector() async {
    final count = _pdfPageSizes.length;
    if (count == 0) return;
    final selected = <int>{_currentPage};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .72,
            child: Column(children: [
              ListTile(
                title: const Text('تحديد عدة صفحات'),
                subtitle: Text('المحدد: ${selected.length}'),
                trailing: TextButton(
                  onPressed: () => setSheetState(() {
                    if (selected.length == count) { selected.clear(); } else { selected.addAll(List.generate(count, (i) => i + 1)); }
                  }),
                  child: Text(selected.length == count ? 'إلغاء الكل' : 'تحديد الكل'),
                ),
              ),
              const Divider(height: 1),
              Expanded(child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8),
                itemCount: count,
                itemBuilder: (_, i) {
                  final page = i + 1;
                  final active = selected.contains(page);
                  return InkWell(
                    onTap: () => setSheetState(() => active ? selected.remove(page) : selected.add(page)),
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: active ? AppColors.accent : Colors.grey), borderRadius: BorderRadius.circular(8), color: active ? AppColors.accent.withOpacity(.12) : null),
                      child: Stack(children: [Center(child: Text('$page', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), if (active) const Positioned(top: 4, right: 4, child: Icon(Icons.check_circle, size: 18))]),
                    ),
                  );
                },
              )),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: selected.isEmpty ? null : () { final s = Set<int>.from(selected); Navigator.pop(sheetContext); _runMultiPageOperation(s, 'rotate_right'); },
                      icon: const Icon(Icons.rotate_right_rounded), label: const Text('يمين'))),
                    const SizedBox(width: 6),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: selected.isEmpty ? null : () { final s = Set<int>.from(selected); Navigator.pop(sheetContext); _runMultiPageOperation(s, 'rotate_left'); },
                      icon: const Icon(Icons.rotate_left_rounded), label: const Text('يسار'))),
                    const SizedBox(width: 6),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: selected.isEmpty ? null : () { final s = Set<int>.from(selected); Navigator.pop(sheetContext); _runMultiPageOperation(s, 'duplicate'); },
                      icon: const Icon(Icons.copy_all_rounded), label: const Text('نسخ'))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: selected.isEmpty ? null : () { final s = Set<int>.from(selected); Navigator.pop(sheetContext); _extractPages(s); },
                      icon: const Icon(Icons.call_split_rounded), label: const Text('استخراج'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: selected.isEmpty ? null : () { final s = Set<int>.from(selected); Navigator.pop(sheetContext); _runMultiPageOperation(s, 'delete'); },
                      icon: const Icon(Icons.delete_outline_rounded), label: const Text('حذف'))),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showPageTools() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.description_rounded),
                title: const Text('إدارة الصفحات'),
                subtitle: Text(
                  'الصفحة الحالية: $_currentPage من ${_pdfPageSizes.isEmpty ? "…" : _pdfPageSizes.length}',
                ),
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      leading: const Icon(Icons.rotate_right_rounded),
                      title: const Text('تدوير يمين'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _runPageOperation('rotate_right');
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      leading: const Icon(Icons.rotate_left_rounded),
                      title: const Text('تدوير يسار'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _runPageOperation('rotate_left');
                      },
                    ),
                  ),
                ],
              ),
              ListTile(
                leading: const Icon(Icons.copy_all_rounded),
                title: const Text('نسخ الصفحة'),
                subtitle: const Text('إنشاء نسخة بعد الصفحة الحالية'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _runPageOperation('duplicate');
                },
              ),
              ListTile(
                leading: const Icon(Icons.note_add_rounded),
                title: const Text('صفحة فارغة قبل الحالية'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _runPageOperation('blank_before');
                },
              ),
              ListTile(
                leading: const Icon(Icons.post_add_rounded),
                title: const Text('صفحة فارغة بعد الحالية'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _runPageOperation('blank_after');
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.swap_vert_rounded),
                title: const Text('إعادة ترتيب الصفحة الحالية'),
                subtitle: const Text('تحريك الصفحة خطوة للأمام أو للخلف'),
                trailing: Wrap(spacing: 4, children: [
                  IconButton(onPressed: _currentPage <= 1 ? null : () { Navigator.pop(sheetContext); _moveCurrentPage(-1); }, icon: const Icon(Icons.arrow_back_rounded)),
                  IconButton(onPressed: _currentPage >= _pdfPageSizes.length ? null : () { Navigator.pop(sheetContext); _moveCurrentPage(1); }, icon: const Icon(Icons.arrow_forward_rounded)),
                ]),
              ),
              ListTile(
                leading: const Icon(Icons.library_add_rounded),
                title: const Text('استيراد صفحات من PDF آخر'),
                subtitle: const Text('تُضاف بعد الصفحة الحالية'),
                onTap: () { Navigator.pop(sheetContext); _importPagesFromPdf(); },
              ),
              ListTile(
                leading: const Icon(Icons.checklist_rounded),
                title: const Text('تحديد عدة صفحات'),
                subtitle: const Text('لاستخراج مجموعة صفحات إلى ملف مستقل'),
                onTap: () { Navigator.pop(sheetContext); _showMultiPageSelector(); },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                title: const Text('حذف الصفحة', style: TextStyle(color: Colors.red)),
                subtitle: const Text('لا يتم تعديل الملف الأصلي'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _runPageOperation('delete');
                },
              ),
            ],
          ),
        ),
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
            icon: const Icon(Icons.layers_rounded),
            tooltip: 'إدارة الصفحات',
            onPressed: _showPageTools,
          ),
          IconButton(
            icon: Icon(_addTextMode ? Icons.text_fields_rounded : Icons.text_fields_outlined),
            tooltip: tr('ed_addtext_tooltip'),
            onPressed: () => setState(() => _addTextMode = !_addTextMode),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_photo_alternate_rounded),
            tooltip: 'إضافة صورة / توقيع / ختم',
            onSelected: (value) {
              if (value == 'image') _addImageFromGallery();
              if (value == 'mark') _addSavedMark();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'image', child: ListTile(leading: Icon(Icons.image_rounded), title: Text('إضافة صورة'))),
              PopupMenuItem(value: 'mark', child: ListTile(leading: Icon(Icons.draw_rounded), title: Text('توقيع أو ختم محفوظ'))),
            ],
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
                ..._imageElements
                    .where((e) => e.pageNumber == _currentPage)
                    .map((e) => _buildImageElementOverlay(e)),
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
    final estimatedWidth = (ann.boxWidth * transform.scale).clamp(48.0, 520.0 * transform.scale);
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
                      maxLines: 8,
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
      _undoStack.add(before);
      _redoStack.clear();
      if (_undoStack.length > 20) _undoStack.removeAt(0);
    }
    setState(() {
      _movingAnnotation = null;
      _moveSnapshot = null;
      _moveUndoSnapshot = null;
      _hasUnsavedChanges = true;
    });
    _scheduleAutoSave();
  }

  /// عند الضغط على نص موجود: قائمة صغيرة "تعديل" أو "نقل" — النقل يعتمد
  /// على نفس آلية الضغط الدقيقة المستخدمة بالإضافة (بدل السحب بالإصبع
  /// غير المضمون هندسيًا)، فيضغط المستخدم على المكان الجديد مباشرة.
  Future<void> _splitTextAnnotation(_TextAnnotation ann) async {
    final source = ann.text.trim();
    if (source.length < 2) return;
    final middle = source.length ~/ 2;
    int cut = source.lastIndexOf(' ', middle);
    if (cut < 1) cut = source.indexOf(' ', middle);
    if (cut < 1) cut = middle;

    final leftController = TextEditingController(text: source.substring(0, cut).trim());
    final rightController = TextEditingController(text: source.substring(cut).trim());
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تقسيم النص'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('عدّل الجزأين ثم اضغط تقسيم. سيصبح كل جزء صندوق نص مستقلًا ويمكن نقله وتغيير عرضه.'),
            const SizedBox(height: 12),
            TextField(controller: leftController, maxLines: 4, decoration: const InputDecoration(labelText: 'الجزء الأول')),
            const SizedBox(height: 10),
            TextField(controller: rightController, maxLines: 4, decoration: const InputDecoration(labelText: 'الجزء الثاني')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, [leftController.text.trim(), rightController.text.trim()]),
            child: const Text('تقسيم'),
          ),
        ],
      ),
    );
    leftController.dispose();
    rightController.dispose();
    if (result == null || result.length != 2 || result[0].isEmpty || result[1].isEmpty || !mounted) return;

    final pageSize = _pdfPageSizes[ann.pageNumber];
    _pushUndoState();
    setState(() {
      final halfWidth = (ann.boxWidth / 2).clamp(80.0, 250.0);
      ann.text = result[0];
      ann.boxWidth = halfWidth;
      final desiredX = ann.dx + halfWidth + 12;
      final secondX = pageSize == null ? desiredX : desiredX.clamp(0.0, (pageSize.width - halfWidth).clamp(0.0, pageSize.width)).toDouble();
      final secondY = (pageSize != null && (secondX - ann.dx).abs() < 20)
          ? (ann.dy + ann.fontSize * 2.2).clamp(0.0, pageSize.height - ann.fontSize * 1.4).toDouble()
          : ann.dy;
      _annotations.add(_TextAnnotation(
        pageNumber: ann.pageNumber,
        dx: secondX,
        dy: secondY,
        text: result[1],
        fontSize: ann.fontSize,
        color: ann.color,
        alignment: ann.alignment,
        boxWidth: halfWidth,
      ));
    });
    _scheduleAutoSave();
  }

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
                setState(() {
                  _movingAnnotation = ann;
                  _moveSnapshot = ann.copy();
                  _moveUndoSnapshot = _annotations.map((a) => a.copy()).toList();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.call_split_rounded),
              title: const Text('تقسيم النص'),
              subtitle: const Text('تحويل النص إلى صندوقين مستقلين'),
              onTap: () {
                Navigator.pop(sheetContext);
                _splitTextAnnotation(ann);
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
  final double boxWidth;
  _TextDialogResult({required this.text, required this.fontSize, required this.color, this.alignment = TextAlign.right, this.boxWidth = 240});
}
