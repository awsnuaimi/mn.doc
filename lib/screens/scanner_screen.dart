import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';
import '../services/app_settings.dart';
import '../services/app_text.dart';
import 'pdf_editor_screen.dart';
import 'document_camera_screen.dart';

class _ScannedPage {
  final File file;
  bool enhanced;
  _ScannedPage({required this.file, this.enhanced = false});
}

/// مسح ضوئي للمستندات: التقاط عدة صفحات بالكاميرا، تحسينها (اختياري)،
/// وترتيبها، ثم تصديرها كملف PDF واحد.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final List<_ScannedPage> _pages = [];
  bool _autoEnhance = true;
  bool _capturing = false;
  bool _saving = false;

  Future<void> _capturePage() async {
    setState(() => _capturing = true);
    try {
      final capturedPath = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const DocumentCameraScreen()),
      );
      if (capturedPath == null) {
        setState(() => _capturing = false);
        return;
      }

      File finalFile = File(capturedPath);
      if (_autoEnhance) {
        finalFile = await _enhance(finalFile);
      }

      setState(() {
        _pages.add(_ScannedPage(file: finalFile, enhanced: _autoEnhance));
        _capturing = false;
      });
    } catch (e) {
      setState(() => _capturing = false);
      if (!mounted) return;
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppText.t('scanner_capture_error', lang)} $e')));
    }
  }

  /// يحوّل الصورة لشكل "ممسوح ضوئيًا": أبيض وأسود مع رفع التباين والحدة.
  Future<File> _enhance(File original) async {
    final bytes = await original.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return original;

    var processed = img.grayscale(decoded);
    processed = img.adjustColor(processed, contrast: 1.4, brightness: 1.05);

    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/scan_enhanced_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final outFile = File(outPath);
    await outFile.writeAsBytes(img.encodeJpg(processed, quality: 90));
    return outFile;
  }

  Future<void> _saveAsPdf() async {
    if (_pages.isEmpty) return;
    setState(() => _saving = true);
    try {
      final doc = pw.Document();
      for (final page in _pages) {
        final bytes = await page.file.readAsBytes();
        final image = pw.MemoryImage(bytes);
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (context) => pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
          ),
        );
      }

      final bytes = await doc.save();
      final dir = await getApplicationDocumentsDirectory();
      final outPath = '${dir.path}/MN-Doc_ممسوح_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await File(outPath).writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      setState(() => _saving = false);
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      String tr(String key) => AppText.t(key, lang);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('scanner_success_title')),
          content: Text('${tr('scanner_pagecount_label')} ${_pages.length}'),
          actions: [
            TextButton(
              onPressed: () => Share.shareXFiles([XFile(outPath)]),
              child: Text(tr('ed_share')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => PdfEditorScreen(filePath: outPath)),
                );
              },
              child: Text(tr('scanner_open_file')),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppText.t('ed_save_error_prefix', lang)} $e')));
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
      appBar: AppBar(
        title: Text(tr('scanner')),
        actions: [
          if (_pages.isNotEmpty)
            _saving
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  )
                : IconButton(
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    tooltip: tr('scanner_save_tooltip'),
                    onPressed: _saveAsPdf,
                  ),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            value: _autoEnhance,
            onChanged: (v) => setState(() => _autoEnhance = v),
            title: Text(tr('scanner_enhance_title')),
            subtitle: Text(tr('scanner_enhance_subtitle')),
            activeThumbColor: AppColors.primaryDark,
          ),
          const Divider(height: 1),
          Expanded(
            child: _pages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 48, color: AppColors.textMuted.withOpacity(0.4)),
                          const SizedBox(height: 10),
                          Text(
                            tr('scanner_empty_hint'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pages.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _pages.removeAt(oldIndex);
                        _pages.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final p = _pages[index];
                      return Card(
                        key: ValueKey(p.file.path),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(p.file, width: 50, height: 60, fit: BoxFit.cover),
                          ),
                          title: Text('${tr('scanner_page_label')} ${index + 1}'),
                          subtitle: Text(p.enhanced ? tr('scanner_enhanced') : tr('scanner_original')),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            onPressed: () => setState(() => _pages.removeAt(index)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _capturing ? null : _capturePage,
              icon: _capturing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.camera_alt_rounded),
              label: Text(_capturing ? tr('scanner_capturing') : '${tr('scanner_capture_btn')} (${_pages.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
