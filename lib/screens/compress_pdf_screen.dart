import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../theme/app_theme.dart';

/// ضغط حجم ملف PDF عبر إعادة بناء هيكل الملف وإزالة التكرار الداخلي.
class CompressPdfScreen extends StatefulWidget {
  const CompressPdfScreen({super.key});

  @override
  State<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends State<CompressPdfScreen> {
  String? _filePath;
  int? _originalSize;
  int? _newSize;
  bool _processing = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    setState(() {
      _filePath = file.path;
      _originalSize = file.lengthSync();
      _newSize = null;
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _compress() async {
    if (_filePath == null) return;
    setState(() => _processing = true);
    try {
      final bytes = await File(_filePath!).readAsBytes();
      final document = sf.PdfDocument(inputBytes: bytes);

      // إعادة بناء الملف بالكامل بدل التحديث الإضافي، مع أعلى مستوى ضغط متاح
      document.fileStructure.incrementalUpdate = false;
      document.compressionLevel = sf.PdfCompressionLevel.best;

      final savedBytes = await document.save();
      document.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final originalName = _filePath!.split('/').last.replaceAll('.pdf', '');
      final outPath = '${dir.path}/${originalName}_مضغوط.pdf';
      final outFile = File(outPath);
      await outFile.writeAsBytes(savedBytes, flush: true);

      if (!mounted) return;
      setState(() {
        _processing = false;
        _newSize = savedBytes.length;
      });

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم الضغط'),
          content: Text(
            'الحجم الأصلي: ${_formatSize(_originalSize!)}\n'
            'الحجم بعد الضغط: ${_formatSize(savedBytes.length)}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
            ElevatedButton(
              onPressed: () => Share.shareXFiles([XFile(outPath)]),
              child: const Text('مشاركة'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _processing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ضغط حجم PDF')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(_filePath == null ? 'اختيار ملف PDF' : _filePath!.split('/').last, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 16),
            if (_originalSize != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الحجم الحالي: ${_formatSize(_originalSize!)}'),
                      if (_newSize != null) ...[
                        const SizedBox(height: 6),
                        Text('الحجم بعد الضغط: ${_formatSize(_newSize!)}',
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'ملاحظة: الضغط يعمل بشكل أفضل مع الملفات النصية أو التي أُعيد حفظها عدة مرات. '
              'الملفات المليئة بالصور عالية الدقة قد تنخفض بنسبة أقل.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: (_filePath == null || _processing) ? null : _compress,
              icon: _processing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.compress_rounded),
              label: Text(_processing ? 'جارٍ الضغط...' : 'ضغط الملف'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}