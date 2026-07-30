import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';
import 'pdf_editor_screen.dart';

class _PickedImage {
  final String name;
  final Uint8List bytes;
  _PickedImage({required this.name, required this.bytes});
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;

    for (final f in result.files) {
      if (f.bytes == null) continue;
      setState(() => _images.add(_PickedImage(name: f.name, bytes: f.bytes!)));
    }
  }

  Future<void> _exportToPdf() async {
    if (_images.isEmpty) return;
    setState(() => _saving = true);
    try {
      final doc = pw.Document();
      for (final img in _images) {
        final image = pw.MemoryImage(img.bytes);
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
          title: const Text('تم إنشاء الملف بنجاح'),
          content: Text('عدد الصفحات: ${_images.length}'),
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
      appBar: AppBar(title: const Text('تحويل صور إلى PDF')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _addImages,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: const Text('إضافة صور'),
            ),
          ),
          Expanded(
            child: _images.isEmpty
                ? Center(child: Text('أضف صورة أو أكثر، ورتّبهم بالسحب حسب ترتيب صفحات PDF', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _images.length,
                    onReorder: (oldIndex, newIndex) {
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
                          leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.memory(img.bytes, width: 45, height: 55, fit: BoxFit.cover)),
                          title: Text('صفحة ${index + 1}'),
                          subtitle: Text(img.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            onPressed: () => setState(() => _images.removeAt(index)),
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
              label: Text(_saving ? 'جارٍ الإنشاء...' : 'إنشاء PDF (${_images.length} صفحة)'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, minimumSize: const Size(double.infinity, 50)),
            ),
          ),
        ],
      ),
    );
  }
}