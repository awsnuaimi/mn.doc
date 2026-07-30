import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../services/docx_text_extractor.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر قراءة الملف: $e')));
    }
  }

  Future<void> _exportToPdf() async {
    if (_textController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final doc = pw.Document();
      final title = (_fileName ?? 'مستند').replaceAll('.docx', '');

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text(_textController.text, style: const pw.TextStyle(fontSize: 12)),
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
          title: const Text('تم التحويل بنجاح'),
          content: const Text('تذكير: النص فقط تم تحويله، بدون تنسيق أو صور من الملف الأصلي.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
            ElevatedButton(
              onPressed: () => Share.shareXFiles([XFile(outPath)]),
              child: const Text('مشاركة'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PdfEditorScreen(filePath: outPath)));
              },
              child: const Text('فتح'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحويل Word إلى PDF')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Text(
                'ملاحظة: يستخرج النص فقط من ملف Word، بدون تنسيق أو صور أو جداول من الملف الأصلي.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _extracting ? null : _pickFile,
              icon: _extracting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.folder_open_rounded),
              label: Text(_fileName ?? 'اختيار ملف Word (.docx)', overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(hintText: 'سيظهر النص المستخرج هنا، ويمكنك تعديله قبل التصدير...'),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: (_saving || _textController.text.trim().isEmpty) ? null : _exportToPdf,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(_saving ? 'جارٍ التصدير...' : 'تصدير كـ PDF'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, minimumSize: const Size(double.infinity, 50)),
            ),
          ],
        ),
      ),
    );
  }
}