import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../services/secure_redaction.dart';
import '../theme/app_theme.dart';

class _RedactBox {
  final int pageNumber;
  double dx, dy, w, h; // نسبية (0..1) لأبعاد الصفحة
  String replacementText;
  _RedactBox({
    required this.pageNumber,
    required this.dx,
    required this.dy,
    required this.w,
    required this.h,
    this.replacementText = '',
  });
}

/// حجب آمن لمحتوى PDF مع إمكانية إضافة نص بديل.
/// الصفحة التي تحتوي حجبًا تُسطّح إلى صورة، وتُمسح البكسلات الحساسة قبل
/// إعادة إدراجها في PDF، لذلك لا تبقى طبقة النص/الصورة الأصلية تحت التغطية.
class RedactEditScreen extends StatefulWidget {
  const RedactEditScreen({super.key});

  @override
  State<RedactEditScreen> createState() => _RedactEditScreenState();
}

class _RedactEditScreenState extends State<RedactEditScreen> {
  final PdfViewerController _controller = PdfViewerController();
  final GlobalKey _viewerKey = GlobalKey();

  String? _filePath;
  int _currentPage = 1;
  bool _saving = false;

  final List<_RedactBox> _boxes = [];
  Offset? _dragStart;
  Offset? _dragCurrent;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;
    if (!mounted) return;
    setState(() => _filePath = result.files.single.path!);
  }

  void _onPanStart(DragStartDetails details) {
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() {
      _dragStart = box.globalToLocal(details.globalPosition);
      _dragCurrent = _dragStart;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() => _dragCurrent = box.globalToLocal(details.globalPosition));
  }

  Future<void> _onPanEnd(DragEndDetails details) async {
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _dragStart == null || _dragCurrent == null) return;
    final size = box.size;

    final left = _dragStart!.dx < _dragCurrent!.dx ? _dragStart!.dx : _dragCurrent!.dx;
    final top = _dragStart!.dy < _dragCurrent!.dy ? _dragStart!.dy : _dragCurrent!.dy;
    final width = (_dragCurrent!.dx - _dragStart!.dx).abs();
    final height = (_dragCurrent!.dy - _dragStart!.dy).abs();

    setState(() {
      _dragStart = null;
      _dragCurrent = null;
    });

    if (width < 10 || height < 10) return; // تجاهل السحبات الصغيرة جدًا (نقرة غير مقصودة)

    final replacement = await _askReplacementText();
    if (!mounted) return;
    setState(() {
      _boxes.add(_RedactBox(
        pageNumber: _currentPage,
        dx: left / size.width,
        dy: top / size.height,
        w: width / size.width,
        h: height / size.height,
        replacementText: replacement ?? '',
      ));
    });
  }

  Future<String?> _askReplacementText() async {
    final controller = TextEditingController();
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    String tr(String key) => AppText.t(key, lang);

    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('redact_dialog_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('redact_dialog_desc'), style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: tr('redact_field_hint'))),
            ],
          ),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: Text(tr('redact_done_btn'))),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _save() async {
    if (_filePath == null || _boxes.isEmpty || _saving) return;
    setState(() => _saving = true);
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    String tr(String key) => AppText.t(key, lang);

    try {
      final inputBytes = await File(_filePath!).readAsBytes();
      final regions = _boxes
          .map(
            (b) => SecureRedactionRegion(
              pageIndex: b.pageNumber - 1,
              x: b.dx,
              y: b.dy,
              width: b.w,
              height: b.h,
              replacementText: b.replacementText,
            ),
          )
          .toList(growable: false);

      final savedBytes = await SecureRedactionService.apply(
        inputBytes: inputBytes,
        regions: regions,
      );

      final dir = await getApplicationDocumentsDirectory();
      final originalName = _filePath!.split('/').last.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');
      final outPath = await _uniqueOutputPath(dir.path, '${originalName}_محجوب_آمن', '.pdf');
      await File(outPath).writeAsBytes(savedBytes, flush: true);

      // تحقق بنيوي بسيط: الملف الناتج يجب أن يكون موجودًا وغير فارغ قبل النجاح.
      final outFile = File(outPath);
      if (!await outFile.exists() || await outFile.length() == 0) {
        throw StateError('فشل التحقق من ملف PDF الناتج.');
      }

      if (!mounted) return;
      setState(() => _saving = false);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('saved')),
          content: Text('${tr('path_label')} $outPath'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('ed_close'))),
            ElevatedButton(onPressed: () => Share.shareXFiles([XFile(outPath)]), child: Text(tr('ed_share'))),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('error_prefix')} $e')));
    }
  }

  Future<String> _uniqueOutputPath(String directory, String baseName, String extension) async {
    var candidate = '$directory/$baseName$extension';
    var suffix = 1;
    while (await File(candidate).exists()) {
      candidate = '$directory/$baseName ($suffix)$extension';
      suffix++;
    }
    return candidate;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final lang = settings.languageCode;
    String tr(String key) => AppText.t(key, lang);

    if (_filePath == null) {
      return Directionality(
        textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(title: Text(tr('redact_appbar_initial'))),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      tr('redact_note'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.folder_open_rounded), label: Text(tr('select_pdf_btn'))),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
      appBar: AppBar(
        title: Text(tr('redact_appbar_active')),
        actions: [
          _saving
              ? const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : IconButton(icon: const Icon(Icons.save_rounded), onPressed: _boxes.isEmpty ? null : _save, tooltip: tr('save')),
        ],
      ),
      body: Stack(
        key: _viewerKey,
        children: [
          GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: SfPdfViewer.file(
              File(_filePath!),
              controller: _controller,
              pageLayoutMode: PdfPageLayoutMode.single,
              scrollDirection: PdfScrollDirection.horizontal,
              onPageChanged: (details) => _currentPage = details.newPageNumber,
            ),
          ),
          if (_dragStart != null && _dragCurrent != null)
            Positioned(
              left: (_dragStart!.dx < _dragCurrent!.dx ? _dragStart!.dx : _dragCurrent!.dx),
              top: (_dragStart!.dy < _dragCurrent!.dy ? _dragStart!.dy : _dragCurrent!.dy),
              width: (_dragCurrent!.dx - _dragStart!.dx).abs(),
              height: (_dragCurrent!.dy - _dragStart!.dy).abs(),
              child: Container(color: AppColors.accent.withOpacity(0.3)),
            ),
          ..._boxes.where((b) => b.pageNumber == _currentPage).map((b) {
            final size = _viewerKey.currentContext?.size ?? const Size(400, 700);
            return Positioned(
              left: b.dx * size.width,
              top: b.dy * size.height,
              width: b.w * size.width,
              height: b.h * size.height,
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.red, width: 1.5)),
                alignment: Alignment.center,
                child: b.replacementText.isNotEmpty
                    ? Text(b.replacementText, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)
                    : null,
              ),
            );
          }),
        ],
      ),
      ),
    );
  }
}
