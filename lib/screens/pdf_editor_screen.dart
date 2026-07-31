import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../theme/app_theme.dart';
import '../services/app_settings.dart';
import '../services/app_text.dart';
import 'summarize_screen.dart';
import 'ai_chat_screen.dart';
import 'translate_screen.dart';
import 'tts_reader_screen.dart';

/// نص تمت إضافته فوق صفحة معيّنة من ملف PDF.
/// الإحداثيات dx/dy نسبية (0..1) بالنسبة لأبعاد الصفحة المعروضة،
/// مما يسمح بحسابها بدقة عند الحفظ الفعلي داخل ملف الـPDF.
class _TextAnnotation {
  int pageNumber; // يبدأ من 1
  double dx;
  double dy;
  String text;
  double fontSize;
  Color color;

  _TextAnnotation({
    required this.pageNumber,
    required this.dx,
    required this.dy,
    required this.text,
    this.fontSize = 16,
    this.color = Colors.black,
  });
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
  bool _flattenFormsOnSave = false;
  bool _hasFormFields = false;
  int _currentPage = 1;

  // ------- البحث داخل PDF -------
  bool _searchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult _searchResult = PdfTextSearchResult();

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _searchResult.removeListener(_onSearchResultChanged);
    super.dispose();
  }

  void _search(String query) {
    if (query.trim().isEmpty) return;
    _searchResult = _controller.searchText(query);
    _searchResult.addListener(_onSearchResultChanged);
    setState(() {});
  }

  void _onSearchResultChanged() {
    if (mounted) setState(() {});
  }

  void _closeSearch() {
    _searchResult.removeListener(_onSearchResultChanged);
    _searchResult.clear();
    setState(() {
      _searchVisible = false;
      _searchController.clear();
    });
  }

  void _handleTapDown(TapDownDetails details) async {
    if (!_addTextMode) return;

    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    final size = box.size;
    final relX = (local.dx / size.width).clamp(0.0, 1.0);
    final relY = (local.dy / size.height).clamp(0.0, 1.0);

    final result = await _showTextDialog();
    if (result == null || result.text.trim().isEmpty) return;

    setState(() {
      _annotations.add(_TextAnnotation(
        pageNumber: _currentPage,
        dx: relX,
        dy: relY,
        text: result.text,
        fontSize: result.fontSize,
        color: result.color,
      ));
    });
  }

  Future<_TextDialogResult?> _showTextDialog({String initialText = '', double initialSize = 16, Color initialColor = Colors.black}) {
    final controller = TextEditingController(text: initialText);
    double fontSize = initialSize;
    Color color = initialColor;
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
                    ],
                  ),
                  Row(
                    children: [
                      Text(tr('ed_dialog_color')),
                      const SizedBox(width: 12),
                      ...[Colors.black, Colors.red, Colors.blue, AppColors.accent, Colors.green]
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
                              )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _TextDialogResult(text: controller.text, fontSize: fontSize, color: color),
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
    );
    if (result == null) return;
    setState(() {
      if (result.text.trim().isEmpty) {
        _annotations.remove(ann);
      } else {
        ann.text = result.text;
        ann.fontSize = result.fontSize;
        ann.color = result.color;
      }
    });
  }

  /// يستخرج كامل النص من ملف الـPDF الحالي (عبر Syncfusion PdfTextExtractor)
  /// لاستخدامه في ميزات الذكاء الاصطناعي (التلخيص/الدردشة/الترجمة).
  Future<String> _extractFullText() async {
    final bytes = await File(widget.filePath).readAsBytes();
    final document = sf.PdfDocument(inputBytes: bytes);
    final extractor = sf.PdfTextExtractor(document);
    final text = extractor.extractText();
    document.dispose();
    return text;
  }

  Future<void> _openAiFeature(String feature) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    String text = '';
    try {
      text = await _extractFullText();
    } catch (_) {
      text = '';
    }
    if (!mounted) return;
    Navigator.pop(context); // إغلاق مؤشر التحميل

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هذا الملف يحتوي ${formFields.length} حقل/حقول قابلة للتعبئة — اضغط عليها مباشرة لملئها'),
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

  Future<void> _saveDocument() async {
    setState(() => _saving = true);
    try {
      // الخطوة 1: احفظ نسخة تتضمن تعليقات العارض المدمجة
      // (تظليل/تسطير/شطب/ملاحظات لاصقة) وبيانات حقول النموذج التي عبّأها المستخدم.
      final List<int> viewerBytes = await _controller.saveDocument(
        flattenOption: _flattenFormsOnSave ? PdfFlattenOption.formFields : PdfFlattenOption.none,
      );

      // الخطوة 2: افتح تلك النسخة وأضف فوقها نصوصنا المخصّصة (المربّعات النصية).
      final sf.PdfDocument document = sf.PdfDocument(inputBytes: viewerBytes);

      for (final ann in _annotations) {
        final pageIndex = ann.pageNumber - 1;
        if (pageIndex < 0 || pageIndex >= document.pages.count) continue;
        final page = document.pages[pageIndex];
        final pageSize = page.getClientSize();

        final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, ann.fontSize);
        final brush = sf.PdfSolidBrush(
          sf.PdfColor(ann.color.red, ann.color.green, ann.color.blue),
        );

        page.graphics.drawString(
          ann.text,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(
            ann.dx * pageSize.width,
            ann.dy * pageSize.height,
            pageSize.width - (ann.dx * pageSize.width),
            ann.fontSize * 2,
          ),
        );
      }

      final List<int> savedBytes = await document.save();
      document.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final originalName = widget.filePath.split('/').last.replaceAll('.pdf', '');
      final outPath = '${dir.path}/${originalName}_MN-Doc.pdf';
      final outFile = File(outPath);
      await outFile.writeAsBytes(savedBytes, flush: true);

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
              onPressed: () => Navigator.pop(context),
              child: Text(tr('ed_close')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Share.shareXFiles([XFile(outPath)], text: 'ملف من MN-Doc');
              },
              child: Text(tr('ed_share')),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
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
      child: Scaffold(
      appBar: AppBar(
        title: Text(widget.filePath.split('/').last, overflow: TextOverflow.ellipsis),
        actions: [
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
                  icon: const Icon(Icons.save_rounded),
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
          Expanded(
            child: Stack(
              key: _viewerKey,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: _handleTapDown,
                  child: SfPdfViewer.file(
                    File(widget.filePath),
                    key: _pdfViewerStateKey,
                    controller: _controller,
                    // عرض صفحة واحدة في كل مرة لضمان دقة وضع النصوص المضافة
                    pageLayoutMode: PdfPageLayoutMode.single,
                    onPageChanged: (details) {
                      _currentPage = details.newPageNumber;
                    },
                    onDocumentLoaded: _onDocumentLoaded,
                  ),
                ),
                // طبقة عرض النصوص المضافة على الصفحة الحالية فقط
                ..._annotations
                    .where((a) => a.pageNumber == _currentPage)
                    .map((ann) => _buildAnnotationOverlay(ann)),
              ],
            ),
          ),
        ],
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
    return Positioned(
      left: ann.dx * size.width,
      top: ann.dy * size.height,
      child: GestureDetector(
        onTap: () => _editAnnotation(ann),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.accent.withOpacity(0.6), width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            ann.text,
            style: TextStyle(fontSize: ann.fontSize * 0.8, color: ann.color),
          ),
        ),
      ),
    );
  }
}

class _TextDialogResult {
  final String text;
  final double fontSize;
  final Color color;
  _TextDialogResult({required this.text, required this.fontSize, required this.color});
}
