import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../theme/app_theme.dart';
import 'pdf_editor_screen.dart';

class _PickedImage {
  final String name;
  final String path;
  const _PickedImage({required this.name, required this.path});
}

/// تحويل عدة صور إلى ملف PDF واحد (كل صورة = صفحة)، بترتيب قابل للتعديل.
class ImagesToPdfScreen extends StatefulWidget {
  const ImagesToPdfScreen({super.key});

  @override
  State<ImagesToPdfScreen> createState() => _ImagesToPdfScreenState();
}

class _ImagesToPdfScreenState extends State<ImagesToPdfScreen> {
  final List<_PickedImage> _images = [];
  bool _saving = false;

  Future<void> _addImages() async {
    if (_saving) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: false,
    );
    if (result == null || !mounted) return;

    final picked = result.files
        .where((f) => f.path != null)
        .map((f) => _PickedImage(name: f.name, path: f.path!))
        .toList(growable: false);
    if (picked.isEmpty) return;

    setState(() => _images.addAll(picked));
  }

  Future<void> _exportToPdf() async {
    if (_images.isEmpty) return;
    final images = List<_PickedImage>.of(_images);
    setState(() => _saving = true);
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    String tr(String key) => AppText.t(key, lang);

    try {
      final doc = pw.Document();
      for (final img in images) {
        // لا نحتفظ ببايتات كل الصور داخل State. نقرأ كل ملف فقط عند
        // بناء الـPDF، مما يزيل النسخة الدائمة الكبيرة من RAM.
        final imageBytes = await File(img.path).readAsBytes();
        final image = pw.MemoryImage(imageBytes);
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (context) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
          ),
        );
      }

      final bytes = await doc.save();
      final dir = await getApplicationDocumentsDirectory();
      final outPath = '${dir.path}/MN-Doc_صور_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await File(outPath).writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      setState(() => _saving = false);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('scanner_success_title')),
          content: Text('${tr('scanner_pagecount_label')} ${images.length}'),
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
      if (!mounted) return;
      setState(() => _saving = false);
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
      appBar: AppBar(title: Text(tr('tool_img2pdf_t'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _addImages,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(tr('img2pdf_add_images')),
            ),
          ),
          Expanded(
            child: _images.isEmpty
                ? Center(child: Text(tr('img2pdf_hint'), textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _images.length,
                    onReorder: (oldIndex, newIndex) {
                      if (_saving) return;
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _images.removeAt(oldIndex);
                        _images.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final img = _images[index];
                      return Card(
                        key: ValueKey('${img.name}_$index'),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.file(File(img.path), width: 45, height: 55, fit: BoxFit.cover, cacheWidth: 120)),
                          title: Text('${tr('scanner_page_label')} ${index + 1}'),
                          subtitle: Text(img.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            onPressed: _saving ? null : () => setState(() => _images.removeAt(index)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: (_images.isEmpty || _saving) ? null : _exportToPdf,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(_saving ? tr('img2pdf_creating') : '${tr('img2pdf_create_btn')} (${_images.length} ${tr('pages_word')})'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, minimumSize: const Size(double.infinity, 50)),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
