import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../theme/app_theme.dart';

/// التعرف على رموز QR والباركود من صورة، أو من صفحة داخل ملف PDF.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final BarcodeScanner _scanner = BarcodeScanner();
  String? _imagePath;
  bool _scanning = false;
  List<Barcode> _results = [];

  @override
  void dispose() {
    _scanner.close();
    super.dispose();
  }

  Future<void> _scanImagePath(String path) async {
    setState(() {
      _imagePath = path;
      _scanning = true;
      _results = [];
    });
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    String tr(String key) => AppText.t(key, lang);

    try {
      final input = InputImage.fromFilePath(path);
      final barcodes = await _scanner.processImage(input);
      if (!mounted) return;
      setState(() {
        _results = barcodes;
        _scanning = false;
      });
      if (barcodes.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('barcode_none_found'))));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _scanning = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('barcode_scan_error')} $e')));
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 95);
    if (picked == null) return;
    await _scanImagePath(picked.path);
  }

  Future<void> _scanFromPdf() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;

    setState(() => _scanning = true);
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    String tr(String key) => AppText.t(key, lang);

    try {
      final bytes = await File(result.files.single.path!).readAsBytes();
      final doc = sf.PdfDocument(inputBytes: bytes);
      final pageCount = doc.pages.count;
      doc.dispose();

      if (!mounted) return;
      final chosenPage = await showDialog<int>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(tr('barcode_pick_page_title')),
          children: List.generate(
            pageCount,
            (i) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: Text('${tr('scanner_page_label')} ${i + 1}'),
            ),
          ),
        ),
      );
      if (chosenPage == null) {
        if (!mounted) return;
        setState(() => _scanning = false);
        return;
      }

      final dir = await getTemporaryDirectory();
      String? pagePath;
      await for (final page in Printing.raster(bytes, pages: [chosenPage], dpi: 200)) {
        final png = await page.toPng();
        pagePath = '${dir.path}/barcode_scan_${DateTime.now().microsecondsSinceEpoch}.png';
        await File(pagePath).writeAsBytes(png, flush: true);
        break;
      }

      if (pagePath != null) {
        await _scanImagePath(pagePath);
      } else {
        if (!mounted) return;
        setState(() => _scanning = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _scanning = false);
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
      appBar: AppBar(title: Text(tr('tool_barcode_t'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: Text(tr('camera')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: Text(tr('gallery')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _scanFromPdf,
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: Text(tr('barcode_scan_from_pdf')),
            ),
            const SizedBox(height: 16),
            if (_imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(_imagePath!), height: 160, fit: BoxFit.contain),
              ),
            const SizedBox(height: 16),
            if (_scanning) const Center(child: CircularProgressIndicator()),
            if (_results.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final b = _results[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.qr_code_rounded),
                        title: Text(b.displayValue ?? b.rawValue ?? '—'),
                        subtitle: Text(b.type.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: b.displayValue ?? b.rawValue ?? ''));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('copied'))));
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}
