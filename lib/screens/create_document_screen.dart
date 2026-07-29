import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';
import 'pdf_editor_screen.dart';

/// إنشاء مستند جديد من الصفر (PDF أو نص) بعنوان ومحتوى حرّ،
/// ثم إمكانية فتحه فورًا في محرر الـPDF لإضافة المزيد من التعديلات.
class CreateDocumentScreen extends StatefulWidget {
  const CreateDocumentScreen({super.key});

  @override
  State<CreateDocumentScreen> createState() => _CreateDocumentScreenState();
}

class _CreateDocumentScreenState extends State<CreateDocumentScreen> {
  final _titleController = TextEditingController(text: 'مستند بدون عنوان');
  final _bodyController = TextEditingController();
  bool _saving = false;

  Future<void> _createPdf() async {
    setState(() => _saving = true);
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _titleController.text,
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 16),
              pw.Text(_bodyController.text, style: const pw.TextStyle(fontSize: 14)),
            ],
          ),
        ),
      );

      final bytes = await doc.save();
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/MN-Doc_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path);
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      setState(() => _saving = false);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم إنشاء المستند'),
          content: const Text('ماذا تريد أن تفعل الآن؟'),
          actions: [
            TextButton(
              onPressed: () => Share.shareXFiles([XFile(path)]),
              child: const Text('مشاركة'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // إغلاق الحوار
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => PdfEditorScreen(filePath: path)),
                );
              },
              child: const Text('فتح للتحرير'),
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
      appBar: AppBar(title: const Text('إنشاء مستند جديد')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'عنوان المستند'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _bodyController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  labelText: 'المحتوى',
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saving ? null : _createPdf,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(_saving ? 'جارٍ الإنشاء...' : 'إنشاء ملف PDF'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
            ),
          ],
        ),
      ),
    );
  }
}
