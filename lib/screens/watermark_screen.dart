import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../services/arabic_font_loader.dart';
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
    if (!mounted) return;
    setState(() => _filePath = result.files.single.path!);
  }

  Future<void> _apply() async {
    if (_filePath == null || _textController.text.trim().isEmpty) return;
    setState(() => _processing = true);
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    String tr(String key) => AppText.t(key, lang);

    try {
      final bytes = await File(_filePath!).readAsBytes();
      final document = sf.PdfDocument(inputBytes: bytes);
      late final List<int> savedBytes;
      try {
        final font = await ArabicFontLoader.loadSyncfusionFont(_fontSize, bold: true);
        final brush = sf.PdfSolidBrush(sf.PdfColor(150, 150, 150));

        for (int i = 0; i < document.pages.count; i++) {
          final page = document.pages[i];
          final size = page.getClientSize();
          final graphics = page.graphics;

          graphics.save();
          try {
            graphics.setTransparency(_opacity);
            graphics.translateTransform(size.width / 2, size.height / 2);
            graphics.rotateTransform(_rotation);

            final textSize = font.measureString(_textController.text);
            graphics.drawString(
              _textController.text,
              font,
              brush: brush,
              bounds: Rect.fromLTWH(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height),
            );
          } finally {
            graphics.restore();
          }
        }

        savedBytes = await document.save();
      } finally {
        document.dispose();
      }

      final dir = await getApplicationDocumentsDirectory();
      final originalName = _filePath!.split('/').last.replaceAll('.pdf', '');
      final outPath = '${dir.path}/${originalName}_علامة_مائية.pdf';
      await File(outPath).writeAsBytes(savedBytes, flush: true);

      if (!mounted) return;
      setState(() => _processing = false);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('watermark_added_title')),
          content: Text('${tr('path_label')} $outPath'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('ed_close'))),
            ElevatedButton(
              onPressed: () => Share.shareXFiles([XFile(outPath)]),
              child: Text(tr('ed_share')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('error_prefix')} $e')));
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final lang = settings.languageCode;
    String tr(String key) => AppText.t(key, lang);

    return Directionality(
      textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
      appBar: AppBar(title: Text(tr('tool_watermark_t'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(_filePath == null ? tr('select_pdf_btn') : _filePath!.split('/').last, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _textController,
              decoration: InputDecoration(labelText: tr('watermark_text_label')),
            ),
            const SizedBox(height: 16),
            Text('${tr('watermark_opacity_label')} ${(_opacity * 100).round()}%'),
            Slider(value: _opacity, min: 0.05, max: 0.8, onChanged: (v) => setState(() => _opacity = v)),
            Text('${tr('ed_dialog_fontsize')} ${_fontSize.round()}'),
            Slider(value: _fontSize, min: 20, max: 100, onChanged: (v) => setState(() => _fontSize = v)),
            Text('${tr('watermark_rotation_label')} ${_rotation.round()}°'),
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
              label: Text(_processing ? tr('processing') : tr('watermark_apply_btn')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
