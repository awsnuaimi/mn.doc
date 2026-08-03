import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/table_extractor.dart';
import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../theme/app_theme.dart';

/// استخراج تقريبي لجداول PDF وتصديرها كملف Excel.
/// (طريقة تخمينية بالاعتماد على مواقع النصوص — راجع الملاحظة أعلى الشاشة)
class ExtractTableScreen extends StatefulWidget {
  const ExtractTableScreen({super.key});

  @override
  State<ExtractTableScreen> createState() => _ExtractTableScreenState();
}

class _ExtractTableScreenState extends State<ExtractTableScreen> {
  String? _fileName;
  Uint8List? _bytes;
  int _pageCount = 0;
  int _selectedPage = 0; // -1 يعني كل الصفحات
  bool _processing = false;
  List<List<String>>? _preview;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final bytes = result.files.single.bytes!;
    final count = TableExtractor.countPages(bytes);
    if (!mounted) return;
    setState(() {
      _fileName = result.files.single.name;
      _bytes = bytes;
      _pageCount = count;
      _selectedPage = 0;
      _preview = null;
    });
  }

  void _previewPage() {
    if (_bytes == null) return;
    final rows = TableExtractor.extractPageAsRows(_bytes!, _selectedPage);
    setState(() => _preview = rows);
  }

  Future<void> _exportToExcel() async {
    if (_bytes == null) return;
    setState(() => _processing = true);
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    String tr(String key) => AppText.t(key, lang);

    try {
      final excelFile = xls.Excel.createExcel();
      final defaultSheetName = excelFile.getDefaultSheet()!;

      final pagesToExport = _selectedPage == -1 ? List.generate(_pageCount, (i) => i) : [_selectedPage];

      for (final pageIndex in pagesToExport) {
        final sheet = excelFile['${tr('scanner_page_label')} ${pageIndex + 1}'];
        final rows = TableExtractor.extractPageAsRows(_bytes!, pageIndex);
        for (final row in rows) {
          sheet.appendRow(row.map((cell) => xls.TextCellValue(cell)).toList());
        }
      }
      excelFile.delete(defaultSheetName);

      final bytes = excelFile.save();
      if (bytes == null) throw Exception(tr('table_create_error'));

      final dir = await getApplicationDocumentsDirectory();
      final originalName = (_fileName ?? 'file').replaceAll('.pdf', '');
      final outPath = '${dir.path}/${originalName}_جداول.xlsx';
      await File(outPath).writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      setState(() => _processing = false);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('table_exported_title')),
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
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final lang = settings.languageCode;
    String tr(String key) => AppText.t(key, lang);

    return Directionality(
      textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
      appBar: AppBar(title: Text(tr('tool_table_t'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(
                tr('table_note'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(_fileName == null ? tr('select_pdf_btn') : _fileName!, overflow: TextOverflow.ellipsis),
            ),
            if (_bytes != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedPage,
                decoration: InputDecoration(labelText: tr('page_field_label')),
                items: [
                  DropdownMenuItem(value: -1, child: Text(tr('table_all_pages'))),
                  ...List.generate(_pageCount, (i) => DropdownMenuItem(value: i, child: Text('${tr('scanner_page_label')} ${i + 1}'))),
                ],
                onChanged: (v) => setState(() {
                  _selectedPage = v!;
                  _preview = null;
                }),
              ),
              const SizedBox(height: 12),
              if (_selectedPage != -1)
                OutlinedButton.icon(
                  onPressed: _previewPage,
                  icon: const Icon(Icons.visibility_rounded),
                  label: Text(tr('table_preview_btn')),
                ),
              if (_preview != null) ...[
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: List.generate(
                        _preview!.isEmpty ? 0 : _preview!.map((r) => r.length).reduce((a, b) => a > b ? a : b),
                        (i) => DataColumn(label: Text('${tr('table_column_label')} ${i + 1}')),
                      ),
                      rows: _preview!
                          .map((row) => DataRow(cells: row.map((c) => DataCell(Text(c))).toList()))
                          .toList(),
                    ),
                  ),
                ),
              ] else
                const Spacer(),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _processing ? null : _exportToExcel,
                icon: _processing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.table_chart_rounded),
                label: Text(_processing ? tr('table_exporting') : tr('table_export_btn')),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, minimumSize: const Size(double.infinity, 50)),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
