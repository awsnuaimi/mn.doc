import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../theme/app_theme.dart';
import 'pdf_editor_screen.dart';

/// إصلاح ملفات PDF تالفة/معطوبة.
/// الطريقة: فتح الملف وإعادة بناء هيكله بالكامل (بدل نسخة "التحديث
/// الإضافي" المعطوبة)، ثم حفظه من جديد — هذا يُصلح كثيرًا من مشاكل
/// الفهرسة الداخلية الشائعة. لا يضمن إصلاح كل أنواع التلف (بعض الملفات
/// تالفة بشكل لا يمكن قراءته إطلاقًا، ولن نتمكن من فتحها أصلًا).
class RepairPdfScreen extends StatefulWidget {
  const RepairPdfScreen({super.key});

  @override
  State<RepairPdfScreen> createState() => _RepairPdfScreenState();
}

class _RepairPdfScreenState extends State<RepairPdfScreen> {
  String? _filePath;
  bool _processing = false;
  String? _statusMessage;
  bool? _success;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _filePath = result.files.single.path!;
      _statusMessage = null;
      _success = null;
    });
  }

  Future<void> _attemptRepair() async {
    if (_filePath == null) return;
    setState(() {
      _processing = true;
      _statusMessage = null;
      _success = null;
    });

    try {
      final bytes = await File(_filePath!).readAsBytes();

      sf.PdfDocument document;
      try {
        document = sf.PdfDocument(inputBytes: bytes);
      } catch (e) {
        setState(() {
          _processing = false;
          _success = false;
          _statusMessage = 'تعذّر فتح الملف إطلاقًا — التلف شديد جدًا ولا يمكن إصلاحه بهذه الطريقة.\n($e)';
        });
        return;
      }

      // إعادة بناء الهيكل بالكامل بدل التحديث الإضافي — هذا يُصلح
      // مشاكل الفهرسة الداخلية الشائعة في الملفات التالفة جزئيًا.
      document.fileStructure.incrementalUpdate = false;

      final pageCount = document.pages.count;
      final repairedBytes = await document.save();
      document.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final originalName = _filePath!.split('/').last.replaceAll('.pdf', '');
      final outPath = '${dir.path}/${originalName}_مُصلح.pdf';
      await File(outPath).writeAsBytes(repairedBytes, flush: true);

      setState(() {
        _processing = false;
        _success = true;
        _statusMessage = 'تم فتح الملف وإعادة بناء هيكله بنجاح ($pageCount صفحة). '
            'إذا كان الملف الأصلي يحتوي تلفًا بسيطًا بالفهرسة الداخلية، فالنسخة الجديدة يجب أن تعمل بشكل طبيعي.';
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تمت المحاولة'),
          content: Text(_statusMessage!),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
            ElevatedButton(onPressed: () => Share.shareXFiles([XFile(outPath)]), child: const Text('مشاركة')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PdfEditorScreen(filePath: outPath)));
              },
              child: const Text('فتح للتأكد'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _processing = false;
        _success = false;
        _statusMessage = 'تعذّرت المحاولة: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إصلاح ملف PDF تالف')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Text(
                'ملاحظة: هذه الأداة تحاول إصلاح مشاكل الفهرسة الداخلية الشائعة عبر إعادة بناء الملف. '
                'لا يمكنها إصلاح كل أنواع التلف — بعض الملفات التالفة بشدة لن يمكن فتحها إطلاقًا.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(_filePath == null ? 'اختيار ملف PDF' : _filePath!.split('/').last, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 20),
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_success == true ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_statusMessage!, style: TextStyle(color: _success == true ? Colors.green.shade800 : Colors.red.shade800)),
              ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: (_filePath == null || _processing) ? null : _attemptRepair,
              icon: _processing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.build_rounded),
              label: Text(_processing ? 'جارٍ المحاولة...' : 'محاولة الإصلاح'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, minimumSize: const Size(double.infinity, 50)),
            ),
          ],
        ),
      ),
    );
  }
}
