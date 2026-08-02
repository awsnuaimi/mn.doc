import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../theme/app_theme.dart';

/// إضافة أو إزالة كلمة مرور من ملف PDF (تشفير AES 256-bit).
class ProtectPdfScreen extends StatefulWidget {
  const ProtectPdfScreen({super.key});

  @override
  State<ProtectPdfScreen> createState() => _ProtectPdfScreenState();
}

class _ProtectPdfScreenState extends State<ProtectPdfScreen> {
  String? _filePath;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _mode = true; // true = إضافة كلمة مرور، false = إزالتها
  bool _processing = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;
    setState(() => _filePath = result.files.single.path!);
  }

  Future<void> _apply() async {
    if (_filePath == null) return;
    setState(() => _processing = true);
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    String tr(String key) => AppText.t(key, lang);

    try {
      final bytes = await File(_filePath!).readAsBytes();
      final sf.PdfDocument document;

      if (_mode) {
        // إضافة كلمة مرور جديدة
        document = sf.PdfDocument(inputBytes: bytes);
        document.security.userPassword = _newPasswordController.text;
        document.security.ownerPassword = _newPasswordController.text;
        document.security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
      } else {
        // إزالة كلمة مرور موجودة (تتطلب كلمة المرور الحالية للفتح)
        document = sf.PdfDocument(inputBytes: bytes, password: _currentPasswordController.text);
        document.security.userPassword = '';
        document.security.ownerPassword = '';
      }

      final savedBytes = await document.save();
      document.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final originalName = _filePath!.split('/').last.replaceAll('.pdf', '');
      final suffix = _mode ? 'محمي' : 'بدون_حماية';
      final outPath = '${dir.path}/${originalName}_$suffix.pdf';
      await File(outPath).writeAsBytes(savedBytes, flush: true);

      if (!mounted) return;
      setState(() => _processing = false);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(_mode ? tr('protect_encrypted_title') : tr('protect_removed_title')),
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
      setState(() => _processing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mode ? '${tr('error_prefix')} $e' : '${tr('protect_wrong_pw_error')} $e')),
      );
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
      appBar: AppBar(title: Text(tr('tool_protect_t'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(tr('protect_add_mode')), icon: const Icon(Icons.lock_rounded)),
                ButtonSegment(value: false, label: Text(tr('protect_remove_mode')), icon: const Icon(Icons.lock_open_rounded)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(_filePath == null ? tr('select_pdf_btn') : _filePath!.split('/').last, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 20),
            if (!_mode)
              TextField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(labelText: tr('protect_current_pw')),
              )
            else
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(labelText: tr('protect_new_pw')),
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: (_filePath == null || _processing) ? null : _apply,
              icon: _processing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_mode ? Icons.lock_rounded : Icons.lock_open_rounded),
              label: Text(_processing ? tr('processing') : (_mode ? tr('protect_encrypt_btn') : tr('protect_remove_mode'))),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
