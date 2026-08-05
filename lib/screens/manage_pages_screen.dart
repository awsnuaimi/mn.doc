import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../services/pdf_page_ops.dart';
import '../theme/app_theme.dart';

class _ManagedPage {
  final int originalIndex;
  int rotation;

  _ManagedPage({required this.originalIndex, this.rotation = 0});

  _ManagedPage copy() =>
      _ManagedPage(originalIndex: originalIndex, rotation: rotation);
}

/// مدير صفحات مرئي: صور مصغرة + تحديد متعدد + إعادة ترتيب بالسحب.
class ManagePagesScreen extends StatefulWidget {
  final String? initialFilePath;

  const ManagePagesScreen({super.key, this.initialFilePath});

  @override
  State<ManagePagesScreen> createState() => _ManagePagesScreenState();
}

class _ManagePagesScreenState extends State<ManagePagesScreen> {
  String? _fileName;
  Uint8List? _bytes;
  final List<_ManagedPage> _pages = [];
  final Map<int, Uint8List> _thumbnails = {};
  final Set<int> _selectedOriginalIndexes = {};
  bool _processing = false;
  bool _loadingThumbnails = false;
  bool _hasUnsavedStructuralChanges = false;

  // Undo/Redo مستقل للعمليات البنيوية داخل مدير الصفحات.
  // اللقطات خفيفة لأنها تحفظ ترتيب الصفحات ودورانها فقط، ولا تنسخ PDF أو الصور المصغرة.
  final List<List<_ManagedPage>> _structuralUndo = <List<_ManagedPage>>[];
  final List<List<_ManagedPage>> _structuralRedo = <List<_ManagedPage>>[];
  static const int _structuralHistoryLimit = 30;

  List<_ManagedPage> _capturePages() =>
      _pages.map((p) => p.copy()).toList(growable: false);

  void _recordStructuralState() {
    _structuralUndo.add(_capturePages());
    _structuralRedo.clear();
    if (_structuralUndo.length > _structuralHistoryLimit) {
      _structuralUndo.removeAt(0);
    }
  }

  void _restorePages(List<_ManagedPage> snapshot) {
    _pages
      ..clear()
      ..addAll(snapshot.map((p) => p.copy()));
    _selectedOriginalIndexes.clear();
    _hasUnsavedStructuralChanges = true;
  }

  void _undoStructural() {
    if (_structuralUndo.isEmpty || _processing) return;
    final current = _capturePages();
    final previous = _structuralUndo.removeLast();
    _structuralRedo.add(current);
    setState(() => _restorePages(previous));
  }

  void _redoStructural() {
    if (_structuralRedo.isEmpty || _processing) return;
    final current = _capturePages();
    final next = _structuralRedo.removeLast();
    _structuralUndo.add(current);
    if (_structuralUndo.length > _structuralHistoryLimit) {
      _structuralUndo.removeAt(0);
    }
    setState(() => _restorePages(next));
  }

  @override
  void initState() {
    super.initState();
    final path = widget.initialFilePath;
    if (path != null && path.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPath(path));
    }
  }

  Future<void> _loadPath(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      await _setDocument(file.path.split(Platform.pathSeparator).last, bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح ملف PDF: $e')),
      );
    }
  }

  Future<void> _pickFile() async {
    if (_hasUnsavedStructuralChanges) {
      final discard = await _confirmDiscardStructuralChanges();
      if (discard != true || !mounted) return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null) return;
    final picked = result.files.single;
    Uint8List? bytes = picked.bytes;
    if (bytes == null && picked.path != null) {
      bytes = await File(picked.path!).readAsBytes();
    }
    if (bytes == null) return;
    await _setDocument(picked.name, bytes);
  }

  Future<void> _setDocument(String name, Uint8List bytes) async {
    try {
      final count = PdfPageOps.countPages(bytes);
      if (!mounted) return;
      setState(() {
        _fileName = name;
        _bytes = bytes;
        _pages
          ..clear()
          ..addAll(List.generate(count, (i) => _ManagedPage(originalIndex: i)));
        _selectedOriginalIndexes.clear();
        _thumbnails.clear();
        _hasUnsavedStructuralChanges = false;
        _structuralUndo.clear();
        _structuralRedo.clear();
      });
      await _generateThumbnails(bytes, count);
    } catch (e) {
      if (!mounted) return;
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppText.t('read_error_prefix', lang)} $e')),
      );
    }
  }

  Future<void> _generateThumbnails(Uint8List bytes, int count) async {
    setState(() => _loadingThumbnails = true);
    try {
      var i = 0;
      await for (final raster in Printing.raster(
        bytes,
        pages: List<int>.generate(count, (index) => index),
        dpi: 46,
      )) {
        final png = await raster.toPng();
        if (!mounted) return;
        setState(() => _thumbnails[i++] = png);
      }
    } catch (_) {
      // فشل المعاينة لا يمنع إدارة الصفحات؛ تبقى بطاقات الصفحات متاحة.
    } finally {
      if (mounted) setState(() => _loadingThumbnails = false);
    }
  }

  void _toggleSelection(_ManagedPage page) {
    setState(() {
      if (!_selectedOriginalIndexes.add(page.originalIndex)) {
        _selectedOriginalIndexes.remove(page.originalIndex);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedOriginalIndexes.length == _pages.length) {
        _selectedOriginalIndexes.clear();
      } else {
        _selectedOriginalIndexes
          ..clear()
          ..addAll(_pages.map((p) => p.originalIndex));
      }
    });
  }

  Iterable<_ManagedPage> get _selectedPages =>
      _pages.where((p) => _selectedOriginalIndexes.contains(p.originalIndex));

  void _rotateSelected(int delta) {
    if (_selectedOriginalIndexes.isEmpty || _processing) return;
    _recordStructuralState();
    setState(() {
      _hasUnsavedStructuralChanges = true;
      for (final page in _selectedPages) {
        page.rotation = (page.rotation + delta) % 360;
        if (page.rotation < 0) page.rotation += 360;
      }
    });
  }

  void _duplicateSelected() {
    if (_selectedOriginalIndexes.isEmpty || _processing) return;
    _recordStructuralState();
    setState(() {
      _hasUnsavedStructuralChanges = true;
      final selected = _selectedPages.toList();
      for (final source in selected.reversed) {
        final index = _pages.indexOf(source);
        _pages.insert(index + 1, source.copy());
      }
      _selectedOriginalIndexes.clear();
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedOriginalIndexes.isEmpty) return;
    if (_selectedOriginalIndexes.length >= _pages.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن حذف جميع صفحات المستند.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الصفحات'),
        content: Text('حذف ${_selectedOriginalIndexes.length} صفحة من النسخة الجديدة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _recordStructuralState();
    setState(() {
      _hasUnsavedStructuralChanges = true;
      _pages.removeWhere((p) => _selectedOriginalIndexes.contains(p.originalIndex));
      _selectedOriginalIndexes.clear();
    });
  }

  List<PageRef> _refsFor(Iterable<_ManagedPage> pages) {
    final bytes = _bytes!;
    return pages
        .map((p) => PageRef(
              sourceLabel: _fileName ?? '',
              sourceBytes: bytes,
              pageIndex: p.originalIndex,
              rotation: p.rotation,
            ))
        .toList();
  }

  Future<String> _writeRefs(List<PageRef> refs, String tag) async {
    if (refs.isEmpty) {
      throw StateError('لا توجد صفحات لإنشاء ملف PDF.');
    }

    final outBytes = await PdfPageOps.buildFromPages(refs);
    if (outBytes.isEmpty) {
      throw StateError('فشل إنشاء بيانات PDF.');
    }

    final dir = await getApplicationDocumentsDirectory();
    final outPath = '${dir.path}/MN-Doc_${tag}_${DateTime.now().millisecondsSinceEpoch}.pdf';

    // حفظ ذري للعمليات البنيوية: نكتب الملف كاملًا إلى مسار مؤقت أولًا،
    // ثم ننقله إلى الاسم النهائي فقط بعد نجاح الكتابة. بهذا لا يظهر ملف
    // نهائي ناقص لو انقطع التطبيق أو فشلت الكتابة أثناء حذف/تدوير/ترتيب الصفحات.
    final tmpFile = File('$outPath.tmp');
    try {
      await tmpFile.writeAsBytes(outBytes, flush: true);
      final finalFile = File(outPath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tmpFile.rename(outPath);
      return outPath;
    } catch (_) {
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
      rethrow;
    }
  }

  Future<void> _extractSelected() async {
    if (_bytes == null || _selectedOriginalIndexes.isEmpty || _processing) return;
    setState(() => _processing = true);
    try {
      final outPath = await _writeRefs(_refsFor(_selectedPages), 'extracted');
      if (!mounted) return;
      await Share.shareXFiles([XFile(outPath)], text: 'صفحات مستخرجة من MN-Doc');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر استخراج الصفحات: $e')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _save() async {
    if (_bytes == null || _pages.isEmpty || _processing) return;
    setState(() => _processing = true);
    try {
      final outPath = await _writeRefs(_refsFor(_pages), 'pages');
      if (!mounted) return;
      setState(() => _processing = false);
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      String tr(String key) => AppText.t(key, lang);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('saved')),
          content: Text('${tr('pages_final_count')} ${_pages.length}'),
          actions: [
            TextButton(
              onPressed: () => Share.shareXFiles([XFile(outPath)]),
              child: Text(tr('ed_share')),
            ),
            ElevatedButton(
              onPressed: () {
                // أغلق نافذة النجاح أولًا، ثم أعد المسار للمحرر الذي فتح
                // مدير الصفحات. المحرر نفسه سيتولى استبدال نسخته بالملف
                // البنيوي الجديد، وبذلك لا تتكون شاشتان متداخلتان للمحرر.
                Navigator.pop(context);
                _hasUnsavedStructuralChanges = false;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ ترتيب الصفحات: $e')));
    }
  }

  Widget _thumbnail(_ManagedPage page, int visibleIndex) {
    final selected = _selectedOriginalIndexes.contains(page.originalIndex);
    final image = _thumbnails[page.originalIndex];
    return Card(
      key: ValueKey('managed_${page.originalIndex}_${identityHashCode(page)}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      elevation: selected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? AppColors.accent : Colors.transparent,
          width: selected ? 2.2 : 0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _toggleSelection(page),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 92,
                height: 124,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: image == null
                          ? const Center(child: Icon(Icons.description_outlined, size: 38, color: Colors.grey))
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: RotatedBox(
                                quarterTurns: (page.rotation ~/ 90) % 4,
                                child: Image.memory(image, fit: BoxFit.contain),
                              ),
                            ),
                    ),
                    if (selected)
                      const Positioned(
                        top: 5,
                        right: 5,
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: AppColors.accent,
                          child: Icon(Icons.check, size: 15, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الصفحة ${visibleIndex + 1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text('الأصلية: ${page.originalIndex + 1}', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    if (page.rotation != 0) ...[
                      const SizedBox(height: 5),
                      Text('تدوير ${page.rotation}°', style: const TextStyle(fontSize: 12)),
                    ],
                    const SizedBox(height: 12),
                    const Text('اضغط للتحديد • اسحب المقبض لإعادة الترتيب', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              ReorderableDragStartListener(
                index: visibleIndex,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.drag_indicator_rounded, size: 30),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDiscardStructuralChanges() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديلات صفحات غير محفوظة'),
        content: const Text(
          'لديك حذف/تدوير/نسخ أو إعادة ترتيب لم يتم حفظه بعد. '
          'هل تريد تجاهل هذه التعديلات؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تجاهل'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleManagerBack() async {
    if (!_hasUnsavedStructuralChanges) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final discard = await _confirmDiscardStructuralChanges();
    if (discard == true && mounted) {
      _hasUnsavedStructuralChanges = false;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final lang = settings.languageCode;
    String tr(String key) => AppText.t(key, lang);
    final hasSelection = _selectedOriginalIndexes.isNotEmpty;

    return Directionality(
      textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: PopScope(
        canPop: !_hasUnsavedStructuralChanges,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          await _handleManagerBack();
        },
        child: Scaffold(
        appBar: AppBar(
          title: Text(hasSelection ? 'محدد: ${_selectedOriginalIndexes.length}' : tr('tool_pages_t')),
          actions: _bytes == null
              ? null
              : [
                  IconButton(
                    onPressed: (_processing || _structuralUndo.isEmpty) ? null : _undoStructural,
                    icon: const Icon(Icons.undo_rounded),
                    tooltip: 'تراجع عن عملية الصفحات',
                  ),
                  IconButton(
                    onPressed: (_processing || _structuralRedo.isEmpty) ? null : _redoStructural,
                    icon: const Icon(Icons.redo_rounded),
                    tooltip: 'إعادة عملية الصفحات',
                  ),
                  IconButton(onPressed: _selectAll, icon: const Icon(Icons.select_all_rounded), tooltip: 'تحديد الكل'),
                  IconButton(onPressed: _pickFile, icon: const Icon(Icons.folder_open_rounded), tooltip: 'فتح PDF آخر'),
                ],
        ),
        body: _bytes == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.view_carousel_rounded, size: 68, color: AppColors.primaryDark),
                      const SizedBox(height: 16),
                      Text(tr('pages_pick_hint'), textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.folder_open_rounded), label: Text(tr('select_pdf_btn'))),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  if (_loadingThumbnails) const LinearProgressIndicator(minHeight: 2),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Row(
                      children: [
                        Expanded(child: Text('$_fileName — ${_pages.length} صفحة', overflow: TextOverflow.ellipsis)),
                        Text('اسحب ↕', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: _pages.length,
                      onReorder: (oldIndex, newIndex) {
                        if (_processing) return;
                        if (newIndex > oldIndex) newIndex -= 1;
                        if (newIndex == oldIndex) return;
                        _recordStructuralState();
                        setState(() {
                          final item = _pages.removeAt(oldIndex);
                          _pages.insert(newIndex, item);
                          _selectedOriginalIndexes.clear();
                          _hasUnsavedStructuralChanges = true;
                        });
                      },
                      itemBuilder: (context, index) => _thumbnail(_pages[index], index),
                    ),
                  ),
                  if (hasSelection)
                    Material(
                      elevation: 8,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              IconButton(onPressed: () => _rotateSelected(-90), icon: const Icon(Icons.rotate_left_rounded), tooltip: 'تدوير يسار'),
                              IconButton(onPressed: () => _rotateSelected(90), icon: const Icon(Icons.rotate_right_rounded), tooltip: 'تدوير يمين'),
                              IconButton(onPressed: _duplicateSelected, icon: const Icon(Icons.copy_all_rounded), tooltip: 'نسخ'),
                              IconButton(onPressed: _processing ? null : _extractSelected, icon: const Icon(Icons.call_split_rounded), tooltip: 'استخراج'),
                              IconButton(onPressed: _deleteSelected, icon: const Icon(Icons.delete_outline_rounded, color: Colors.red), tooltip: 'حذف'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ElevatedButton.icon(
                        onPressed: (_processing || _pages.isEmpty) ? null : _save,
                        icon: _processing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded),
                        label: Text(_processing ? tr('processing') : tr('pages_save_new')),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, minimumSize: const Size(double.infinity, 50)),
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
