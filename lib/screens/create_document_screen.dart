import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../services/arabic_font_loader.dart';
import '../theme/app_theme.dart';
import 'pdf_editor_screen.dart';

enum _DocAlign { left, center, right, justify }

class _ParagraphData {
  final TextEditingController controller;
  double fontSize;
  bool bold;
  bool italic;
  bool underline;
  _DocAlign align;
  TextDirection direction;
  double lineHeight;

  _ParagraphData({
    String text = '',
    this.fontSize = 14,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.align = _DocAlign.left,
    this.direction = TextDirection.ltr,
    this.lineHeight = 1.35,
  }) : controller = TextEditingController(text: text);

  void dispose() => controller.dispose();
}

class CreateDocumentScreen extends StatefulWidget {
  const CreateDocumentScreen({super.key});

  @override
  State<CreateDocumentScreen> createState() => _CreateDocumentScreenState();
}

class _CreateDocumentScreenState extends State<CreateDocumentScreen> {
  final _titleController = TextEditingController();
  final List<_ParagraphData> _paragraphs = <_ParagraphData>[];

  bool _saving = false;
  bool _titleInit = false;
  int _activeIndex = 0;

  static final RegExp _rtlChars = RegExp(
    r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]',
  );

  @override
  void initState() {
    super.initState();
    _paragraphs.add(_ParagraphData());
  }

  _ParagraphData get _active => _paragraphs[_activeIndex];

  bool _isRtlText(String text) => _rtlChars.hasMatch(text);

  TextAlign _flutterAlign(_DocAlign value) {
    switch (value) {
      case _DocAlign.left:
        return TextAlign.left;
      case _DocAlign.center:
        return TextAlign.center;
      case _DocAlign.right:
        return TextAlign.right;
      case _DocAlign.justify:
        return TextAlign.justify;
    }
  }

  pw.TextAlign _pdfAlign(_DocAlign value) {
    switch (value) {
      case _DocAlign.left:
        return pw.TextAlign.left;
      case _DocAlign.center:
        return pw.TextAlign.center;
      case _DocAlign.right:
        return pw.TextAlign.right;
      case _DocAlign.justify:
        return pw.TextAlign.justify;
    }
  }

  pw.TextDirection _pdfDirection(TextDirection value) {
    return value == TextDirection.rtl
        ? pw.TextDirection.rtl
        : pw.TextDirection.ltr;
  }

  void _addParagraph({int? after}) {
    final source = _active;
    final insertAt =
        ((after ?? _activeIndex) + 1).clamp(0, _paragraphs.length);

    setState(() {
      _paragraphs.insert(
        insertAt,
        _ParagraphData(
          fontSize: source.fontSize,
          bold: source.bold,
          italic: source.italic,
          underline: source.underline,
          align: source.align,
          direction: source.direction,
          lineHeight: source.lineHeight,
        ),
      );
      _activeIndex = insertAt;
    });
  }

  void _removeParagraph(int index) {
    if (_paragraphs.length == 1) {
      _paragraphs.first.controller.clear();
      setState(() {
        _activeIndex = 0;
      });
      return;
    }

    final removed = _paragraphs.removeAt(index);
    removed.dispose();

    setState(() {
      if (_activeIndex >= _paragraphs.length) {
        _activeIndex = _paragraphs.length - 1;
      } else if (index < _activeIndex) {
        _activeIndex--;
      }
    });
  }

  Future<void> _createPdf() async {
    if (_saving) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      final arabicFont = await ArabicFontLoader.loadPwFont();
      final doc = pw.Document();

      final title = _titleController.text.trim();
      final widgets = <pw.Widget>[];

      if (title.isNotEmpty) {
        final titleRtl = _isRtlText(title);
        widgets.add(
          pw.Directionality(
            textDirection:
                titleRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Text(
              title,
              textAlign:
                  titleRtl ? pw.TextAlign.right : pw.TextAlign.left,
              style: pw.TextStyle(
                font: arabicFont,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 14));
      }

      // Each logical paragraph is split by newlines into independent PDF
      // widgets. This prevents one very tall pw.Text widget from exceeding
      // the printable page height.
      for (final paragraph in _paragraphs) {
        final raw = paragraph.controller.text;
        final lines = raw.split('\n');

        if (lines.isEmpty || raw.trim().isEmpty) {
          widgets.add(
            pw.SizedBox(height: paragraph.fontSize * paragraph.lineHeight),
          );
          continue;
        }

        for (final line in lines) {
          if (line.isEmpty) {
            widgets.add(
              pw.SizedBox(height: paragraph.fontSize * paragraph.lineHeight),
            );
            continue;
          }

          widgets.add(
            pw.Directionality(
              textDirection: _pdfDirection(paragraph.direction),
              child: pw.Text(
                line,
                textAlign: _pdfAlign(paragraph.align),
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: paragraph.fontSize,
                  fontWeight: paragraph.bold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  fontStyle: paragraph.italic
                      ? pw.FontStyle.italic
                      : pw.FontStyle.normal,
                  decoration: paragraph.underline
                      ? pw.TextDecoration.underline
                      : pw.TextDecoration.none,
                  lineSpacing:
                      paragraph.fontSize * (paragraph.lineHeight - 1.0),
                ),
              ),
            ),
          );
        }

        widgets.add(pw.SizedBox(height: 8));
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(40, 44, 40, 44),
          build: (_) => widgets,
        ),
      );

      final bytes = await doc.save();
      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/MN-Doc_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await File(path).writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      setState(() => _saving = false);

      final lang =
          Provider.of<AppSettingsController>(context, listen: false)
              .languageCode;
      String tr(String key) => AppText.t(key, lang);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('create_doc_success_title')),
          content: Text(tr('create_doc_success_body')),
          actions: [
            TextButton(
              onPressed: () => Share.shareXFiles([XFile(path)]),
              child: Text(tr('ed_share')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfEditorScreen(filePath: path),
                  ),
                );
              },
              child: Text(tr('create_doc_open_edit')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);

      final lang =
          Provider.of<AppSettingsController>(context, listen: false)
              .languageCode;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppText.t('error_prefix', lang)} $e'),
        ),
      );
    }
  }

  Widget _formatButton({
    required IconData icon,
    required String tooltip,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        isSelected: selected,
        icon: Icon(icon),
        selectedIcon: Icon(icon, color: AppColors.primaryDark),
        style: IconButton.styleFrom(
          backgroundColor:
              selected ? AppColors.primaryDark.withOpacity(0.12) : null,
        ),
      ),
    );
  }

  Widget _toolbar() {
    final p = _active;

    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.format_size_rounded, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Slider(
                    value: p.fontSize,
                    min: 8,
                    max: 36,
                    divisions: 28,
                    label: '${p.fontSize.round()}',
                    onChanged: (v) => setState(() => p.fontSize = v),
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${p.fontSize.round()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _formatButton(
                    icon: Icons.format_bold_rounded,
                    tooltip: 'Bold',
                    selected: p.bold,
                    onPressed: () => setState(() => p.bold = !p.bold),
                  ),
                  _formatButton(
                    icon: Icons.format_italic_rounded,
                    tooltip: 'Italic',
                    selected: p.italic,
                    onPressed: () => setState(() => p.italic = !p.italic),
                  ),
                  _formatButton(
                    icon: Icons.format_underlined_rounded,
                    tooltip: 'Underline',
                    selected: p.underline,
                    onPressed: () =>
                        setState(() => p.underline = !p.underline),
                  ),
                  const SizedBox(width: 4),
                  _formatButton(
                    icon: Icons.format_align_left_rounded,
                    tooltip: 'Left',
                    selected: p.align == _DocAlign.left,
                    onPressed: () =>
                        setState(() => p.align = _DocAlign.left),
                  ),
                  _formatButton(
                    icon: Icons.format_align_center_rounded,
                    tooltip: 'Center',
                    selected: p.align == _DocAlign.center,
                    onPressed: () =>
                        setState(() => p.align = _DocAlign.center),
                  ),
                  _formatButton(
                    icon: Icons.format_align_right_rounded,
                    tooltip: 'Right',
                    selected: p.align == _DocAlign.right,
                    onPressed: () =>
                        setState(() => p.align = _DocAlign.right),
                  ),
                  _formatButton(
                    icon: Icons.format_align_justify_rounded,
                    tooltip: 'Justify',
                    selected: p.align == _DocAlign.justify,
                    onPressed: () =>
                        setState(() => p.align = _DocAlign.justify),
                  ),
                  const SizedBox(width: 4),
                  _formatButton(
                    icon: Icons.format_textdirection_r_to_l_rounded,
                    tooltip: 'RTL',
                    selected: p.direction == TextDirection.rtl,
                    onPressed: () =>
                        setState(() => p.direction = TextDirection.rtl),
                  ),
                  _formatButton(
                    icon: Icons.format_textdirection_l_to_r_rounded,
                    tooltip: 'LTR',
                    selected: p.direction == TextDirection.ltr,
                    onPressed: () =>
                        setState(() => p.direction = TextDirection.ltr),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                const Icon(Icons.format_line_spacing_rounded, size: 20),
                const SizedBox(width: 8),
                const Text('تباعد'),
                Expanded(
                  child: Slider(
                    value: p.lineHeight,
                    min: 1.0,
                    max: 2.0,
                    divisions: 10,
                    label: p.lineHeight.toStringAsFixed(1),
                    onChanged: (v) => setState(() => p.lineHeight = v),
                  ),
                ),
                Text(p.lineHeight.toStringAsFixed(1)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _paragraphCard(int index) {
    final p = _paragraphs[index];
    final active = index == _activeIndex;

    return Card(
      elevation: active ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              active ? AppColors.primaryDark : Theme.of(context).dividerColor,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  '${index + 1}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'إضافة فقرة بعدها',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() => _activeIndex = index);
                    _addParagraph(after: index);
                  },
                  icon: const Icon(Icons.add_rounded, size: 20),
                ),
                IconButton(
                  tooltip: 'حذف الفقرة',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _removeParagraph(index),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
              ],
            ),
            TextField(
              controller: p.controller,
              minLines: 2,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textDirection: p.direction,
              textAlign: _flutterAlign(p.align),
              style: TextStyle(
                fontSize: p.fontSize,
                fontWeight: p.bold ? FontWeight.bold : FontWeight.normal,
                fontStyle: p.italic ? FontStyle.italic : FontStyle.normal,
                decoration: p.underline ? TextDecoration.underline : null,
                height: p.lineHeight,
              ),
              decoration: const InputDecoration(
                hintText: 'اكتب الفقرة هنا...',
                border: InputBorder.none,
              ),
              onTap: () {
                if (_activeIndex != index) {
                  setState(() => _activeIndex = index);
                }
              },
              onChanged: (value) {
                if (value.length <= 2 && value.isNotEmpty) {
                  final detected = _isRtlText(value)
                      ? TextDirection.rtl
                      : TextDirection.ltr;
                  if (p.direction != detected) {
                    setState(() => p.direction = detected);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final paragraph in _paragraphs) {
      paragraph.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final lang = settings.languageCode;
    String tr(String key) => AppText.t(key, lang);

    if (!_titleInit) {
      _titleController.text = tr('create_doc_default_title');
      _titleInit = true;
    }

    return Directionality(
      textDirection:
          settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('create_document')),
          actions: [
            IconButton(
              tooltip: 'إضافة فقرة',
              onPressed: () => _addParagraph(),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: TextField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: tr('create_doc_title_label'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _toolbar(),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: _paragraphs.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _paragraphs.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: OutlinedButton.icon(
                          onPressed: () => _addParagraph(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('إضافة فقرة جديدة'),
                        ),
                      );
                    }
                    return _paragraphCard(index);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _createPdf,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded),
                  label: Text(
                    _saving
                        ? tr('create_doc_creating')
                        : tr('create_doc_button'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
