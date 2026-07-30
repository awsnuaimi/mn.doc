import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../services/signature_library.dart';
import '../theme/app_theme.dart';
import '../widgets/signature_pad.dart';

/// توقيع إلكتروني: اختر توقيعًا/ختمًا محفوظًا، أو ارسم توقيعًا جديدًا،
/// أو أضف ختمًا من صورة — ثم اختر مكانه بملف PDF واحفظ النسخة الموقّعة.
class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

enum _Step { choose, draw, placePdf }

class _SignatureScreenState extends State<SignatureScreen> {
  final GlobalKey<SignaturePadState> _padKey = GlobalKey<SignaturePadState>();
  final GlobalKey _viewerKey = GlobalKey();
  final PdfViewerController _controller = PdfViewerController();

  _Step _step = _Step.choose;
  List<SavedMark> _savedMarks = [];
  bool _loadingMarks = true;

  Uint8List? _activeMarkBytes; // العلامة المختارة حاليًا لختم الملف بها
  String? _pdfPath;
  int _currentPage = 1;
  double? _placedDx;
  double? _placedDy;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMarks();
  }

  Future<void> _loadMarks() async {
    final marks = await SignatureLibrary.list();
    if (!mounted) return;
    setState(() {
      _savedMarks = marks;
      _loadingMarks = false;
    });
  }

  // ---------------- خطوة الاختيار ----------------

  Future<void> _pickExistingMark(SavedMark mark) async {
    final bytes = await File(mark.filePath).readAsBytes();
    setState(() {
      _activeMarkBytes = bytes;
      _step = _Step.placePdf;
    });
    await _pickPdf();
  }

  Future<void> _addStampFromImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (picked == null) return;
    final bytes = await File(picked.path).readAsBytes();

    final name = await _askForName(defaultName: 'ختم');
    if (name == null) return; // المستخدم ألغى

    final mark = await SignatureLibrary.addMark(bytes: bytes, name: name, type: MarkType.stamp);
    await _loadMarks();

    setState(() {
      _activeMarkBytes = bytes;
      _step = _Step.placePdf;
    });
    await _pickPdf();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ "${mark.name}" بمكتبة الأختام')));
  }

  Future<String?> _askForName({required String defaultName}) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اسم للحفظ (اختياري)'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: defaultName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim().isEmpty ? defaultName : controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // ---------------- خطوة الرسم ----------------

  Future<void> _confirmDrawnSignature() async {
    final bytes = await _padKey.currentState?.exportAsPng();
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ارسم توقيعك أولًا')));
      return;
    }

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حفظ التوقيع؟'),
        content: const Text('هل تريد حفظ هذا التوقيع لاستخدامه لاحقًا بدون رسمه من جديد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('استخدام مرة واحدة فقط')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ للمستقبل')),
        ],
      ),
    );

    if (shouldSave == true) {
      final name = await _askForName(defaultName: 'توقيعي');
      if (name != null) {
        await SignatureLibrary.addMark(bytes: bytes, name: name, type: MarkType.signature);
        await _loadMarks();
      }
    }

    setState(() {
      _activeMarkBytes = bytes;
      _step = _Step.placePdf;
    });
    await _pickPdf();
  }

  // ---------------- خطوة اختيار ملف PDF ووضع العلامة ----------------

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _pdfPath = result.files.single.path!;
      _placedDx = null;
      _placedDy = null;
    });
  }

  void _handleTap(TapDownDetails details) {
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    final size = box.size;
    setState(() {
      _placedDx = (local.dx / size.width).clamp(0.0, 1.0);
      _placedDy = (local.dy / size.height).clamp(0.0, 1.0);
    });
  }

  Future<void> _saveSignedPdf() async {
    if (_pdfPath == null || _activeMarkBytes == null || _placedDx == null || _placedDy == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اضغط على مكان العلامة بالصفحة أولًا')));
      return;
    }

    setState(() => _saving = true);
    try {
      final pdfBytes = await File(_pdfPath!).readAsBytes();
      final document = sf.PdfDocument(inputBytes: pdfBytes);
      final pageIndex = _currentPage - 1;
      if (pageIndex < 0 || pageIndex >= document.pages.count) throw Exception('رقم صفحة غير صالح');
      final page = document.pages[pageIndex];
      final pageSize = page.getClientSize();

      final markImage = sf.PdfBitmap(_activeMarkBytes!);
      const markWidth = 160.0;
      const markHeight = 70.0;

      page.graphics.drawImage(
        markImage,
        Rect.fromLTWH(_placedDx! * pageSize.width, _placedDy! * pageSize.height, markWidth, markHeight),
      );

      final savedBytes = await document.save();
      document.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final originalName = _pdfPath!.split('/').last.replaceAll('.pdf', '');
      final outPath = '${dir.path}/${originalName}_موقّع.pdf';
      await File(outPath).writeAsBytes(savedBytes, flush: true);

      if (!mounted) return;
      setState(() => _saving = false);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم التوقيع بنجاح'),
          content: Text('المسار: $outPath'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Share.shareXFiles([XFile(outPath)]);
              },
              child: const Text('مشاركة'),
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
    switch (_step) {
      case _Step.choose:
        return _buildChooseStep();
      case _Step.draw:
        return _buildDrawStep();
      case _Step.placePdf:
        return _buildPlaceStep();
    }
  }

  Widget _buildChooseStep() {
    return Scaffold(
      appBar: AppBar(title: const Text('توقيع إلكتروني')),
      body: _loadingMarks
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ElevatedButton.icon(
                  onPressed: () => setState(() => _step = _Step.draw),
                  icon: const Icon(Icons.draw_rounded),
                  label: const Text('رسم توقيع جديد'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, minimumSize: const Size(double.infinity, 50)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _addStampFromImage,
                  icon: const Icon(Icons.image_rounded),
                  label: const Text('إضافة ختم من صورة'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                ),
                const SizedBox(height: 20),
                if (_savedMarks.isNotEmpty) ...[
                  Text('التواقيع والأختام المحفوظة', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: _savedMarks.length,
                    itemBuilder: (context, i) {
                      final mark = _savedMarks[i];
                      return InkWell(
                        onTap: () => _pickExistingMark(mark),
                        child: Card(
                          child: Column(
                            children: [
                              Expanded(child: Padding(padding: const EdgeInsets.all(6), child: Image.file(File(mark.filePath), fit: BoxFit.contain))),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(mark.name, style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('ما في توقيعات أو أختام محفوظة بعد', style: TextStyle(color: AppColors.textMuted)),
                  ),
              ],
            ),
    );
  }

  Widget _buildDrawStep() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ارسم توقيعك'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() => _step = _Step.choose)),
        actions: [
          IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => _padKey.currentState?.clear(), tooltip: 'مسح'),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border.all(color: AppColors.primaryDark.withOpacity(0.3)), borderRadius: BorderRadius.circular(12)),
              child: SignaturePad(key: _padKey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _confirmDrawnSignature,
              icon: const Icon(Icons.check_rounded),
              label: const Text('متابعة'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, minimumSize: const Size(double.infinity, 50)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceStep() {
    if (_pdfPath == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('اختر ملف PDF')),
        body: Center(
          child: ElevatedButton.icon(
            onPressed: _pickPdf,
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('اختيار ملف PDF'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('اضغط لتحديد مكان العلامة'),
        actions: [
          _saving
              ? const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : IconButton(icon: const Icon(Icons.save_rounded), onPressed: _saveSignedPdf, tooltip: 'حفظ'),
        ],
      ),
      body: Stack(
        key: _viewerKey,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: _handleTap,
            child: SfPdfViewer.file(
              File(_pdfPath!),
              controller: _controller,
              pageLayoutMode: PdfPageLayoutMode.single,
              onPageChanged: (details) => _currentPage = details.newPageNumber,
            ),
          ),
          if (_placedDx != null && _placedDy != null)
            Positioned(
              left: _placedDx! * (_viewerKey.currentContext?.size?.width ?? 400) - 5,
              top: _placedDy! * (_viewerKey.currentContext?.size?.height ?? 700) - 5,
              child: Container(
                width: 160,
                height: 70,
                decoration: BoxDecoration(border: Border.all(color: AppColors.accent, width: 2), borderRadius: BorderRadius.circular(6)),
                child: _activeMarkBytes != null ? Image.memory(_activeMarkBytes!, fit: BoxFit.contain) : null,
              ),
            ),
        ],
      ),
    );
  }
}
