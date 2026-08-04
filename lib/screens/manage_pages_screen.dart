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

/// حذف صفحات معيّنة أو إعادة ترتيبها داخل ملف PDF واحد.
class ManagePagesScreen extends StatefulWidget {
  final String? initialFilePath;
  const ManagePagesScreen({super.key, this.initialFilePath});

  @override
  State<ManagePagesScreen> createState() => _ManagePagesScreenState();
}

class _ManagePagesScreenState extends State<ManagePagesScreen> {
  String? _fileName;
  Uint8List? _bytes;
  List<int> _pageOrder = []; // فهارس الصفحات الأصلية بالترتيب الحالي
  final List<List<int>> _undoStack = <List<int>>[];
  final List<List<int>> _redoStack = <List<int>>[];
  bool _processing = false;
  bool _hasPageChanges = false;

  void _recordPageState() {
    _undoStack.add(List<int>.from(_pageOrder));
    _redoStack.clear();
    if (_undoStack.length > 30) _undoStack.removeAt(0);
    _hasPageChanges = true;
  }

  void _undoPages() {
    if (_undoStack.isEmpty || _processing) return;
    _redoStack.add(List<int>.from(_pageOrder));
    setState(() {
      _pageOrder = _undoStack.removeLast();
      _hasPageChanges = true;
    });
  }

  void _redoPages() {
    if (_redoStack.isEmpty || _processing) return;
    _undoStack.add(List<int>.from(_pageOrder));
    setState(() {
      _pageOrder = _redoStack.removeLast();
      _hasPageChanges = true;
    });
  }

  @override
  void initState() {
    super.initState();
    final path = widget.initialFilePath;
    if (path != null && path.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialFile(path));
    }
  }

  Future<void> _loadInitialFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      final count = PdfPageOps.countPages(bytes);
      if (!mounted) return;
      setState(() {
        _fileName = path.split(Platform.pathSeparator).last;
        _bytes = bytes;
        _pageOrder = List.generate(count, (i) => i);
        _undoStack.clear();
        _redoStack.clear();
        _hasPageChanges = false;
      });
    } catch (e) {
      if (!mounted) return;
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppText.t('read_error_prefix', lang)} $e')),
      );
    }
  }

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
        _undoStack.clear();
        _redoStack.clear();
        _hasPageChanges = false;
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
      setState(() {
        _processing = false;
        _hasPageChanges = false;
      });
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
                // نعيد المسار للمحرر الأصلي بدل إنشاء محرر ثانٍ من داخل
                // مدير الصفحات. هكذا تبقى العملية البنيوية transaction واحدة
                // ولا تتكوّن شاشات متداخلة بحالات حفظ مختلفة.
                Navigator.pop(context, outPath);
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
      child: PopScope(
        canPop: !_hasPageChanges && !_processing,
        onPopInvoked: (didPop) async {
          if (didPop || _processing) return;
          final discard = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(tr('unsaved_title')),
              content: Text(tr('unsaved_body')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(tr('cancel')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(tr('discard_exit')),
                ),
              ],
            ),
          );
          if (discard == true && mounted) Navigator.pop(context);
        },
        child: Scaffold(
      appBar: AppBar(
        title: Text(tr('tool_pages_t')),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: tr('undo'),
            onPressed: (_undoStack.isEmpty || _processing) ? null : _undoPages,
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            tooltip: tr('redo'),
            onPressed: (_redoStack.isEmpty || _processing) ? null : _redoPages,
          ),
        ],
      ),
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
                      _recordPageState();
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
                            onPressed: () {
                              _recordPageState();
                              setState(() => _pageOrder.removeAt(index));
                            },
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
      ),
    );
  }
}
