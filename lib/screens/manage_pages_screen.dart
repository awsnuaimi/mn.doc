import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/pdf_page_ops.dart';
import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../theme/app_theme.dart';
import 'pdf_editor_screen.dart';

/// حذف صفحات معيّنة أو إعادة ترتيبها داخل ملف PDF واحد.
class ManagePagesScreen extends StatefulWidget {
  const ManagePagesScreen({super.key});

  @override
  State<ManagePagesScreen> createState() => _ManagePagesScreenState();
}

class _ManagePagesScreenState extends State<ManagePagesScreen> {
  String? _fileName;
  Uint8List? _bytes;
  List<int> _pageOrder = []; // فهارس الصفحات الأصلية بالترتيب الحالي
  bool _processing = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    if (!mounted) return;

    final bytes = result.files.single.bytes!;
    try {
      final count = PdfPageOps.countPages(bytes);
      setState(() {
        _fileName = result.files.single.name;
        _bytes = bytes;
        _pageOrder = List.generate(count, (i) => i);
      });
    } catch (e) {
      if (!mounted) return;
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppText.t('read_error_prefix', lang)} $e')));
    }
  }

  Future<void> _save() async {
    if (_bytes == null || _pageOrder.isEmpty) return;
    setState(() => _processing = true);
    try {
      final refs = _pageOrder
          .map((i) => PageRef(sourceLabel: _fileName ?? '', sourceBytes: _bytes!, pageIndex: i))
          .toList();
      final outBytes = await PdfPageOps.buildFromPages(refs);

      final dir = await getApplicationDocumentsDirectory();
      final outPath = '${dir.path}/MN-Doc_معدّل_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await File(outPath).writeAsBytes(outBytes, flush: true);

      if (!mounted) return;
      setState(() => _processing = false);
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      String tr(String key) => AppText.t(key, lang);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('saved')),
          content: Text('${tr('pages_final_count')} ${refs.length}'),
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
      setState(() => _processing = false);
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppText.t('error_prefix', lang)} $e')));
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
      appBar: AppBar(title: Text(tr('tool_pages_t'))),
      body: _bytes == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('pages_pick_hint'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.folder_open_rounded),
                      label: Text(tr('select_pdf_btn')),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '$_fileName — ${_pageOrder.length} ${tr('pages_word')} ${tr('pages_summary_suffix')}',
                    style: const TextStyle(fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _pageOrder.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _pageOrder.removeAt(oldIndex);
                        _pageOrder.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final originalPageNumber = _pageOrder[index] + 1;
                      return Card(
                        key: ValueKey('page_${_pageOrder[index]}_$index'),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primaryDark.withOpacity(0.1),
                            child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          title: Text('${tr('scanner_page_label')} $originalPageNumber (${tr('pages_original_label')})'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            onPressed: () => setState(() => _pageOrder.removeAt(index)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: (_processing || _pageOrder.isEmpty) ? null : _save,
                    icon: _processing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: Text(_processing ? tr('processing') : tr('pages_save_new')),
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
