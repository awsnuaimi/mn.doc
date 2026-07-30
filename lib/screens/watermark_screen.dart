import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../theme/app_theme.dart';

/// إضافة علامة مائية نصية لكل صفحات ملف PDF.
class WatermarkScreen extends StatefulWidget {
  const WatermarkScreen({super.key});

  @override
  State<WatermarkScreen> createState() => _WatermarkScreenState();
}

class _WatermarkScreenState extends State<WatermarkScreen> {
  String? _filePath;
  final _textController = TextEditingController(text: 'سري');
  double _opacity = 0.3;
  double _fontSize = 60;
  double _rotation = -45;
  bool _processing = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;
    setState(() => _filePath = result.files.single.path!);
  }

  Future<void> _apply() async {
    if (_filePath == null || _textController.text.trim().isEmpty) return;
    setState(() => _processing = true);
    try {
      final bytes = await File(_filePath!).readAsBytes();
      final document = sf.PdfDocument(inputBytes: bytes);

      final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, _fontSize, style: sf.PdfFontStyle.bold);
      final brush = sf.PdfSolidBrush(sf.PdfColor(150, 150, 150));

      for (int i = 0; i < document.pages.count; i++) {
        final page = document.pages[i];
        final size = page.getClientSize();
        final graphics = page.graphics;

        graphics.save();
        graphics.setTransparency(_opacity);
        // انقل نقطة الأصل لمنتصف الصفحة، ثم دوّر، ثم ارسم النص متمركزًا
        graphics.translateTransform(size.width / 2, size.height / 2);
        graphics.rotateTransform(_rotation);

        final textSize = font.measureString(_textController.text);
        graphics.drawString(
          _textController.text,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height),
        );
        graphics.restore();
      }

      final savedBytes = await document.save();
      document.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final originalName = _filePath!.split('/').last.replaceAll('.pdf', '');
      final outPath = '${dir.path}/${originalName}_علامة_مائية.pdf';
      await File(outPath).writeAsBytes(savedBytes, flush: true);

      if (!mounted) return;
      setState(() => _processing = false);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تمت إضافة العلامة المائية'),
          content: Text('المسار: $outPath'),
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
      appBar: AppBar(title: const Text('إضافة علامة مائية')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(_filePath == null ? 'اختيار ملف PDF' : _filePath!.split('/').last, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(labelText: 'نص العلامة المائية'),
            ),
            const SizedBox(height: 16),
            Text('الشفافية: ${(_opacity * 100).round()}%'),
            Slider(value: _opacity, min: 0.05, max: 0.8, onChanged: (v) => setState(() => _opacity = v)),
            Text('حجم الخط: ${_fontSize.round()}'),
            Slider(value: _fontSize, min: 20, max: 100, onChanged: (v) => setState(() => _fontSize = v)),
            Text('زاوية الدوران: ${_rotation.round()}°'),
            Slider(value: _rotation, min: -90, max: 90, onChanged: (v) => setState(() => _rotation = v)),
            const SizedBox(height: 20),
            // معاينة تقريبية
            Container(
              height: 140,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryDark.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Transform.rotate(
                angle: _rotation * math.pi / 180,
                child: Opacity(
                  opacity: _opacity,
                  child: Text(
                    _textController.text,
                    style: TextStyle(fontSize: _fontSize / 2, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: (_filePath == null || _processing) ? null : _apply,
              icon: _processing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.water_drop_rounded),
              label: Text(_processing ? 'جارٍ المعالجة...' : 'تطبيق العلامة المائية'),
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