import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

import '../theme/app_theme.dart';
import '../services/app_settings.dart';
import '../services/isolate_helpers.dart';
import '../services/app_text.dart';
import 'pdf_editor_screen.dart';

class _ScannedPage {
  final File file;
  bool enhanced;
  _ScannedPage({required this.file, this.enhanced = false});
}

/// مسح ضوئي للمستندات: يستخدم كاشف حواف المستند الحقيقي من Google
/// (ML Kit Document Scanner) — يكتشف حواف الورقة تلقائيًا بالكاميرا
/// الحيّة، يصحّح الزاوية، ويقصّ الصورة بدقة — نفس تقنية تطبيقات المسح
/// الاحترافية. بعدها تقدر تحسّن الصفحات (أبيض وأسود) وترتّبها وتصدّرها PDF.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final List<_ScannedPage> _pages = [];
  bool _autoEnhance = true;
  double _contrast = 1.4;
  double _brightness = 1.05;
  bool _capturing = false;
  bool _saving = false;

  Future<void> _scanDocument() async {
    setState(() => _capturing = true);
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    String tr(String key) => AppText.t(key, lang);

    DocumentScanner? scanner;
    try {
      final options = DocumentScannerOptions(
        documentFormats: const {DocumentFormat.jpeg},
        mode: ScannerMode.filter,
        pageLimit: 20,
        isGalleryImport: false,
      );
      scanner = DocumentScanner(options: options);
      final result = await scanner.scanDocument();

      for (final imagePath in result.images ?? <String>[]) {
        File finalFile = File(imagePath);
        if (_autoEnhance) {
          finalFile = await _enhance(finalFile);
        }
        _pages.add(_ScannedPage(file: finalFile, enhanced: _autoEnhance));
      }

      if (mounted) setState(() => _capturing = false);
    } catch (e) {
      if (mounted) setState(() => _capturing = false);
      // تجاهل صامت لو المستخدم بس ألغى المسح (سلوك طبيعي، مو خطأ)
      if (!mounted) return;
      if (e.toString().toLowerCase().contains('cancel')) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('scanner_capture_error')} $e')));
    } finally {
      await scanner?.close();
    }
  }

  /// يحوّل الصورة لشكل "ممسوح ضوئيًا": أبيض وأسود مع رفع التباين والحدة.
  /// تتم المعالجة بخيط منفصل (Isolate) عبر compute() لتفادي تجميد
  /// الواجهة أثناء معالجة عدة صفحات متتالية.
  Future<File> _enhance(File original) async {
    final bytes = await original.readAsBytes();
    final processedBytes = await compute(
      enhanceImageIsolate,
      EnhanceParams(bytes: bytes, contrast: _contrast, brightness: _brightness),
    );

    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/scan_enhanced_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final outFile = File(outPath);
    await outFile.writeAsBytes(processedBytes);
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
      if (!mounted) return;
      setState(() => _saving = false);
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
          if (_autoEnhance)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(tr('scanner_contrast_label'), style: const TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: _contrast,
                          min: 1.0,
                          max: 2.0,
                          onChanged: (v) => setState(() => _contrast = v),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(tr('scanner_brightness_label'), style: const TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: _brightness,
                          min: 0.7,
                          max: 1.5,
                          onChanged: (v) => setState(() => _brightness = v),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
              onPressed: _capturing ? null : _scanDocument,
              icon: _capturing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.document_scanner_rounded),
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
