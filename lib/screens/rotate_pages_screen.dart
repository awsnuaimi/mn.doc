import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/pdf_page_ops.dart';
import '../theme/app_theme.dart';
import 'pdf_editor_screen.dart';

class _PageEntry {
  final int originalIndex;
  int rotation; // 0, 90, 180, 270
  bool removed;
  bool isBlank;
  _PageEntry({required this.originalIndex, this.rotation = 0, this.removed = false, this.isBlank = false});
}

/// تدوير صفحات PDF فرديًا، مع إمكانية اكتشاف وإزالة الصفحات الفارغة تلقائيًا.
class RotatePagesScreen extends StatefulWidget {
  const RotatePagesScreen({super.key});

  @override
  State<RotatePagesScreen> createState() => _RotatePagesScreenState();
}

class _RotatePagesScreenState extends State<RotatePagesScreen> {
  String? _fileName;
  Uint8List? _bytes;
  List<_PageEntry> _pages = [];
  bool _scanningBlanks = false;
  bool _saving = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final bytes = result.files.single.bytes!;
    try {
      final count = PdfPageOps.countPages(bytes);
      setState(() {
        _fileName = result.files.single.name;
        _bytes = bytes;
        _pages = List.generate(count, (i) => _PageEntry(originalIndex: i));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر قراءة الملف: $e')));
    }
  }

  Future<void> _detectBlankPages() async {
    if (_bytes == null) return;
    setState(() => _scanningBlanks = true);
    int blankCount = 0;
    for (final p in _pages) {
      final blank = PdfPageOps.isPageBlank(_bytes!, p.originalIndex);
      p.isBlank = blank;
      if (blank) blankCount++;
    }
    if (!mounted) return;
    setState(() => _scanningBlanks = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(blankCount == 0 ? 'لم يتم العثور على صفحات فارغة' : 'وُجدت $blankCount صفحة فارغة — حدّدت للحذف تلقائيًا')),
    );
    if (blankCount > 0) {
      setState(() {
        for (final p in _pages) {
          if (p.isBlank) p.removed = true;
        }
      });
    }
  }

  void _rotate(_PageEntry entry, int delta) {
    setState(() => entry.rotation = (entry.rotation + delta + 360) % 360);
  }

  Future<void> _save() async {
    if (_bytes == null) return;
    final activePages = _pages.where((p) => !p.removed).toList();
    if (activePages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لازم يبقى صفحة واحدة على الأقل')));
      return;
    }

    setState(() => _saving = true);
    try {
      final refs = activePages
          .map((p) => PageRef(sourceLabel: _fileName ?? '', sourceBytes: _bytes!, pageIndex: p.originalIndex, rotation: p.rotation))
          .toList();
      final outBytes = await PdfPageOps.buildFromPages(refs);

      final dir = await getApplicationDocumentsDirectory();
      final originalName = (_fileName ?? 'file').replaceAll('.pdf', '');
      final outPath = '${dir.path}/${originalName}_معدّل_التدوير.pdf';
      await File(outPath).writeAsBytes(outBytes, flush: true);

      if (!mounted) return;
      setState(() => _saving = false);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم الحفظ'),
          content: Text('عدد الصفحات النهائي: ${refs.length}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
            ElevatedButton(
              onPressed: () => Share.shareXFiles([XFile(outPath)]),
              child: const Text('مشاركة'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PdfEditorScreen(filePath: outPath)));
              },
              child: const Text('فتح'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تدوير وإزالة الصفحات الفارغة'),
        actions: [
          if (_bytes != null)
            IconButton(
              icon: _scanningBlanks
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_fix_high_rounded),
              tooltip: 'اكتشاف الصفحات الفارغة',
              onPressed: _scanningBlanks ? null : _detectBlankPages,
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
                    Text('اختر ملف PDF للبدء', style: TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('اختيار ملف PDF'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final p = _pages[index];
                      return Card(
                        color: p.removed ? Colors.red.withOpacity(0.06) : null,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primaryDark.withOpacity(0.1),
                            child: Text('${p.originalIndex + 1}'),
                          ),
                          title: Text(
                            p.removed ? 'محذوفة' : 'دوران: ${p.rotation}°${p.isBlank ? ' (فارغة)' : ''}',
                            style: TextStyle(color: p.removed ? Colors.red : null),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.rotate_left_rounded),
                                onPressed: p.removed ? null : () => _rotate(p, -90),
                              ),
                              IconButton(
                                icon: const Icon(Icons.rotate_right_rounded),
                                onPressed: p.removed ? null : () => _rotate(p, 90),
                              ),
                              IconButton(
                                icon: Icon(p.removed ? Icons.restore_rounded : Icons.delete_outline_rounded,
                                    color: p.removed ? Colors.green : Colors.red),
                                onPressed: () => setState(() => p.removed = !p.removed),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ كملف جديد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
