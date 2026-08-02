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

class _PickedPdf {
  final String name;
  final Uint8List bytes;
  final int pageCount;
  _PickedPdf({required this.name, required this.bytes, required this.pageCount});
}

/// دمج عدة ملفات PDF بملف واحد، بترتيب قابل للتعديل بالسحب والإفلات.
class MergePdfScreen extends StatefulWidget {
  const MergePdfScreen({super.key});

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen> {
  final List<_PickedPdf> _files = [];
  bool _merging = false;

  Future<void> _addFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;

    for (final f in result.files) {
      Uint8List? bytes = f.bytes;
      if (bytes == null && f.path != null) {
        bytes = await File(f.path!).readAsBytes();
      }
      if (bytes == null) continue;
      try {
        final count = PdfPageOps.countPages(bytes);
        setState(() => _files.add(_PickedPdf(name: f.name, bytes: bytes!, pageCount: count)));
      } catch (_) {
        if (!mounted) return;
        final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppText.t('read_error_prefix', lang)} ${f.name}')),
        );
      }
    }
  }

  Future<void> _merge() async {
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    String tr(String key) => AppText.t(key, lang);

    if (_files.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('merge_min2'))),
      );
      return;
    }

    setState(() => _merging = true);
    try {
      final refs = <PageRef>[];
      for (final f in _files) {
        for (var i = 0; i < f.pageCount; i++) {
          refs.add(PageRef(sourceLabel: f.name, sourceBytes: f.bytes, pageIndex: i));
        }
      }

      final mergedBytes = await PdfPageOps.buildFromPages(refs);

      final dir = await getApplicationDocumentsDirectory();
      final outPath = '${dir.path}/MN-Doc_مدمج_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outFile = File(outPath);
      await outFile.writeAsBytes(mergedBytes, flush: true);

      if (!mounted) return;
      setState(() => _merging = false);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('merge_success_title')),
          content: Text('${tr('scanner_pagecount_label')} ${refs.length}\n${tr('path_label')} $outPath'),
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
      setState(() => _merging = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('merge_error_prefix')} $e')));
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
      appBar: AppBar(title: Text(tr('tool_merge_t'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _addFiles,
              icon: const Icon(Icons.add_rounded),
              label: Text(tr('merge_add_files')),
            ),
          ),
          if (_files.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.merge_type_rounded, size: 48, color: AppColors.textMuted.withOpacity(0.4)),
                      const SizedBox(height: 10),
                      Text(
                        tr('merge_hint'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _files.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _files.removeAt(oldIndex);
                    _files.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final f = _files[index];
                  return Card(
                    key: ValueKey('${f.name}_$index'),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryDark.withOpacity(0.1),
                        child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${f.pageCount} ${tr('pages_word')}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => setState(() => _files.removeAt(index)),
                      ),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: (_merging || _files.length < 2) ? null : _merge,
              icon: _merging
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.merge_type_rounded),
              label: Text(_merging ? tr('merge_merging') : '${tr('merge_button')} (${_files.length})'),
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
