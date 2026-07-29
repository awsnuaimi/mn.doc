import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../theme/app_theme.dart';
import 'summarize_screen.dart';
import 'ai_chat_screen.dart';
import 'translate_screen.dart';

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
  final List<_TextAnnotation> _annotations = [];
  final GlobalKey _viewerKey = GlobalKey();

  bool _addTextMode = false;
  bool _saving = false;
  int _currentPage = 1;

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
                  Text('إضافة نص', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'اكتب النص هنا...'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('حجم الخط:'),
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
                      const Text('اللون:'),
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
                    child: const Text('إضافة'),
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
    }
  }

  Future<void> _saveDocument() async {
    setState(() => _saving = true);
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final sf.PdfDocument document = sf.PdfDocument(inputBytes: bytes);

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

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم الحفظ بنجاح'),
          content: Text('تم حفظ الملف في:\n$outPath'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Share.shareXFiles([XFile(outPath)], text: 'ملف من MN-Doc');
              },
              child: const Text('مشاركة'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filePath.split('/').last, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(_addTextMode ? Icons.text_fields_rounded : Icons.text_fields_outlined),
            tooltip: 'وضع إضافة نص',
            onPressed: () => setState(() => _addTextMode = !_addTextMode),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.smart_toy_rounded),
            tooltip: 'ميزات الذكاء الاصطناعي',
            onSelected: _openAiFeature,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'summarize', child: Text('تلخيص هذا المستند')),
              PopupMenuItem(value: 'chat', child: Text('اسأل عن هذا المستند')),
              PopupMenuItem(value: 'translate', child: Text('ترجمة نص من المستند')),
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
                  tooltip: 'حفظ',
                  onPressed: _annotations.isEmpty ? null : _saveDocument,
                ),
        ],
      ),
      body: Column(
        children: [
          if (_addTextMode)
            Container(
              width: double.infinity,
              color: AppColors.accent.withOpacity(0.12),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Text(
                'وضع إضافة النص مفعّل — اضغط في أي مكان على الصفحة لإدراج نص',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
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
                    controller: _controller,
                    // عرض صفحة واحدة في كل مرة لضمان دقة وضع النصوص المضافة
                    pageLayoutMode: PdfPageLayoutMode.single,
                    onPageChanged: (details) {
                      _currentPage = details.newPageNumber;
                    },
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
