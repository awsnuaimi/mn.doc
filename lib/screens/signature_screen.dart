import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../theme/app_theme.dart';
import '../widgets/signature_pad.dart';

/// توقيع إلكتروني: ارسم توقيعك، ثم اختر ملف PDF واضغط بالمكان
/// المطلوب لختمه بالتوقيع، ثم احفظ نسخة موقّعة من الملف.
class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final GlobalKey<SignaturePadState> _padKey = GlobalKey<SignaturePadState>();
  final GlobalKey _viewerKey = GlobalKey();
  final PdfViewerController _controller = PdfViewerController();

  Uint8List? _signatureBytes;
  String? _pdfPath;
  int _currentPage = 1;
  double? _placedDx;
  double? _placedDy;
  bool _saving = false;

  Future<void> _confirmSignature() async {
    final bytes = await _padKey.currentState?.exportAsPng();
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ارسم توقيعك أولًا')),
      );
      return;
    }
    setState(() => _signatureBytes = bytes);
    await _pickPdf();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
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
    if (_pdfPath == null || _signatureBytes == null || _placedDx == null || _placedDy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اضغط على مكان التوقيع بالصفحة أولًا')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final pdfBytes = await File(_pdfPath!).readAsBytes();
      final document = sf.PdfDocument(inputBytes: pdfBytes);
      final pageIndex = _currentPage - 1;
      if (pageIndex < 0 || pageIndex >= document.pages.count) {
        throw Exception('رقم صفحة غير صالح');
      }
      final page = document.pages[pageIndex];
      final pageSize = page.getClientSize();

      final signatureImage = sf.PdfBitmap(_signatureBytes!);
      const sigWidth = 160.0;
      const sigHeight = 70.0;

      page.graphics.drawImage(
        signatureImage,
        Rect.fromLTWH(
          _placedDx! * pageSize.width,
          _placedDy! * pageSize.height,
          sigWidth,
          sigHeight,
        ),
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
    if (_pdfPath == null) {
      // خطوة 1: رسم التوقيع
      return Scaffold(
        appBar: AppBar(
          title: const Text('ارسم توقيعك'),
          actions: [
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () => _padKey.currentState?.clear(),
              tooltip: 'مسح',
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primaryDark.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SignaturePad(key: _padKey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _confirmSignature,
                icon: const Icon(Icons.check_rounded),
                label: const Text('متابعة — اختيار ملف PDF'),
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

    // خطوة 2: اختيار مكان التوقيع بالملف
    return Scaffold(
      appBar: AppBar(
        title: const Text('اضغط لتحديد مكان التوقيع'),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                )
              : IconButton(
                  icon: const Icon(Icons.save_rounded),
                  onPressed: _saveSignedPdf,
                  tooltip: 'حفظ',
                ),
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
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.accent, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _signatureBytes != null ? Image.memory(_signatureBytes!, fit: BoxFit.contain) : null,
              ),
            ),
        ],
      ),
    );
  }
}