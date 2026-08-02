import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../services/docx_text_extractor.dart';
import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../services/arabic_font_loader.dart';
import '../theme/app_theme.dart';
import 'pdf_editor_screen.dart';

/// تحويل ملف Word (.docx) إلى PDF — يستخرج النص فقط (بدون تنسيق أو صور
/// أو جداول)، مع إمكانية مراجعة/تعديل النص قبل التصدير.
class WordToPdfScreen extends StatefulWidget {
  const WordToPdfScreen({super.key});

  @override
  State<WordToPdfScreen> createState() => _WordToPdfScreenState();
}

class _WordToPdfScreenState extends State<WordToPdfScreen> {
  final _textController = TextEditingController();
  String? _fileName;
  bool _extracting = false;
  bool _saving = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['docx'], withData: true);
    if (result == null || result.files.single.bytes == null) return;

    setState(() => _extracting = true);
    try {
      final text = DocxTextExtractor.extractText(result.files.single.bytes!);
      setState(() {
        _fileName = result.files.single.name;
        _textController.text = text;
        _extracting = false;
      });
    } catch (e) {
      setState(() => _extracting = false);
      if (!mounted) return;
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppText.t('read_error_prefix', lang)} $e')));
    }
  }

  Future<void> _exportToPdf() async {
    if (_textController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    String tr(String key) => AppText.t(key, lang);

    try {
      final arabicFont = await ArabicFontLoader.loadPwFont();
      final doc = pw.Document();
      final title = (_fileName ?? tr('create_doc_default_title')).replaceAll('.docx', '');

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(title, style: pw.TextStyle(font: arabicFont, fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text(_textController.text, style: pw.TextStyle(font: arabicFont, fontSize: 12)),
          ],
        ),
      );

      final bytes = await doc.save();
      final dir = await getApplicationDocumentsDirectory();
      final outPath = '${dir.path}/${title}_MN-Doc.pdf';
      await File(outPath).writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      setState(() => _saving = false);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('word_converted_title')),
          content: Text(tr('word_converted_note')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('ed_close'))),
            ElevatedButton(
              onPressed: () => Share.shareXFiles([XFile(outPath)]),
              child: Text(tr('ed_share')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PdfEditorScreen(filePath: outPath)));
              },
              child: Text(tr('scanner_open_file')),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('error_prefix')} $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final lang = settings.languageCode;
    String tr(String key) => AppText.t(key, lang);

    return Directionality(
      textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
      appBar: AppBar(title: Text(tr('tool_word_t'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(
                tr('word_note'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _extracting ? null : _pickFile,
              icon: _extracting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.folder_open_rounded),
              label: Text(_fileName ?? tr('word_pick_hint'), overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(hintText: tr('sm_hint_input')),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: (_saving || _textController.text.trim().isEmpty) ? null : _exportToPdf,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(_saving ? tr('word_exporting') : tr('word_export_btn')),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, minimumSize: const Size(double.infinity, 50)),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
