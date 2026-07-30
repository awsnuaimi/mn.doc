import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

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
    try {
      final input = InputImage.fromFilePath(path);
      final barcodes = await _scanner.processImage(input);
      setState(() {
        _results = barcodes;
        _scanning = false;
      });
      if (barcodes.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم العثور على أي رمز بالصورة')));
      }
    } catch (e) {
      setState(() => _scanning = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء المسح: $e')));
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
    try {
      final bytes = await File(result.files.single.path!).readAsBytes();
      final doc = sf.PdfDocument(inputBytes: bytes);
      final pageCount = doc.pages.count;
      doc.dispose();

      if (!mounted) return;
      final chosenPage = await showDialog<int>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('اختر صفحة للمسح'),
          children: List.generate(
            pageCount,
            (i) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: Text('صفحة ${i + 1}'),
            ),
          ),
        ),
      );
      if (chosenPage == null) {
        setState(() => _scanning = false);
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      String? pagePath;
      await for (final page in Printing.raster(bytes, pages: [chosenPage], dpi: 200)) {
        final png = await page.toPng();
        pagePath = '${dir.path}/barcode_scan_page.png';
        await File(pagePath).writeAsBytes(png, flush: true);
        break;
      }

      if (pagePath != null) {
        await _scanImagePath(pagePath);
      } else {
        setState(() => _scanning = false);
      }
    } catch (e) {
      setState(() => _scanning = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التعرف على QR والباركود')),
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
                    label: const Text('كاميرا'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('صورة'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _scanFromPdf,
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('مسح من صفحة PDF'),
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
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ')));
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
    );
  }
}
