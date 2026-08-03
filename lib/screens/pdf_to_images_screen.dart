import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../theme/app_theme.dart';

/// تحويل صفحات PDF إلى صور PNG منفصلة (صفحة واحدة أو كل الصفحات).
class PdfToImagesScreen extends StatefulWidget {
  const PdfToImagesScreen({super.key});

  @override
  State<PdfToImagesScreen> createState() => _PdfToImagesScreenState();
}

class _PdfToImagesScreenState extends State<PdfToImagesScreen> {
  String? _filePath;
  int _pageCount = 0;
  int _selectedPage = -1; // -1 = كل الصفحات
  bool _converting = false;
  List<String> _outputPaths = [];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final bytes = await File(path).readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);
    final count = doc.pages.count;
    doc.dispose();
    if (!mounted) return;

    setState(() {
      _filePath = path;
      _pageCount = count;
      _selectedPage = -1;
      _outputPaths = [];
    });
  }

  Future<void> _convert() async {
    if (_filePath == null) return;
    setState(() {
      _converting = true;
      _outputPaths = [];
    });
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    String tr(String key) => AppText.t(key, lang);

    try {
      final bytes = await File(_filePath!).readAsBytes();
      final dir = await getApplicationDocumentsDirectory();
      final baseName = _filePath!.split('/').last.replaceAll('.pdf', '');

      final pageIndices = _selectedPage == -1 ? null : [_selectedPage];
      int pageNum = (_selectedPage == -1) ? 1 : _selectedPage + 1;
      final paths = <String>[];

      await for (final page in Printing.raster(bytes, pages: pageIndices, dpi: 150)) {
        final png = await page.toPng();
        final outPath = '${dir.path}/${baseName}_صفحة_$pageNum.png';
        await File(outPath).writeAsBytes(png, flush: true);
        paths.add(outPath);
        pageNum++;
      }

      if (!mounted) return;
      setState(() {
        _converting = false;
        _outputPaths = paths;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _converting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('pdf2img_convert_error')} $e')));
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
      appBar: AppBar(title: Text(tr('tool_pdf2img_t'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(_filePath == null ? tr('select_pdf_btn') : _filePath!.split('/').last, overflow: TextOverflow.ellipsis),
            ),
            if (_filePath != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedPage,
                decoration: InputDecoration(labelText: tr('page_field_label')),
                items: [
                  DropdownMenuItem(value: -1, child: Text(tr('table_all_pages'))),
                  ...List.generate(_pageCount, (i) => DropdownMenuItem(value: i, child: Text('${tr('scanner_page_label')} ${i + 1}'))),
                ],
                onChanged: (v) => setState(() => _selectedPage = v!),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _converting ? null : _convert,
                icon: _converting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.image_rounded),
                label: Text(_converting ? tr('pdf2img_converting') : tr('pdf2img_convert_btn')),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, minimumSize: const Size(double.infinity, 50)),
              ),
            ],
            if (_outputPaths.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('${_outputPaths.length} ${tr('pdf2img_ready_suffix')}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
                  itemCount: _outputPaths.length,
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(_outputPaths[i]), fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Share.shareXFiles(_outputPaths.map((p) => XFile(p)).toList()),
                icon: const Icon(Icons.share_rounded),
                label: Text(tr('pdf2img_share_btn')),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
