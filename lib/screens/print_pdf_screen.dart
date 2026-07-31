import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../theme/app_theme.dart';

/// طباعة ملف PDF مباشرة عبر نافذة الطباعة الأصلية للموبايل
/// (تدعم الطابعات اللاسلكية، الحفظ كـ PDF، أو المشاركة أيضًا).
class PrintPdfScreen extends StatefulWidget {
  final String? initialFilePath;
  const PrintPdfScreen({super.key, this.initialFilePath});

  @override
  State<PrintPdfScreen> createState() => _PrintPdfScreenState();
}

class _PrintPdfScreenState extends State<PrintPdfScreen> {
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _filePath = widget.initialFilePath;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;
    setState(() => _filePath = result.files.single.path!);
  }

  Future<void> _print() async {
    if (_filePath == null) return;
    final bytes = await File(_filePath!).readAsBytes();
    await Printing.layoutPdf(onLayout: (format) async => bytes);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final lang = settings.languageCode;
    String tr(String key) => AppText.t(key, lang);

    return Directionality(
      textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
      appBar: AppBar(title: Text(tr('tool_print_t'))),
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
            const SizedBox(height: 20),
            if (_filePath != null)
              Expanded(
                child: PdfPreview(
                  build: (format) => File(_filePath!).readAsBytes(),
                  canDebug: false,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Text(tr('print_preview_hint'), style: TextStyle(color: AppColors.textMuted)),
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _filePath == null ? null : _print,
              icon: const Icon(Icons.print_rounded),
              label: Text(tr('print_btn')),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, minimumSize: const Size(double.infinity, 50)),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
