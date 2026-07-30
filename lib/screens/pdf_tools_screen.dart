import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../theme/app_theme.dart';
import '../services/app_settings.dart';
import '../services/app_text.dart';
import 'merge_pdf_screen.dart';
import 'manage_pages_screen.dart';
import 'signature_screen.dart';
import 'protect_pdf_screen.dart';
import 'watermark_screen.dart';
import 'compress_pdf_screen.dart';
import 'compare_pdf_screen.dart';
import 'rotate_pages_screen.dart';
import 'tts_reader_screen.dart';
import 'extract_table_screen.dart';
import 'manage_signatures_screen.dart';
import 'word_to_pdf_screen.dart';
import 'images_to_pdf_screen.dart';
import 'pdf_to_images_screen.dart';
import 'print_pdf_screen.dart';
import 'barcode_scanner_screen.dart';
import 'redact_edit_screen.dart';
import 'voice_dictation_screen.dart';
import 'repair_pdf_screen.dart';

/// مركز أدوات PDF المتقدمة: دمج، حذف/ترتيب صفحات، وتوقيع إلكتروني.
class PdfToolsScreen extends StatelessWidget {
  const PdfToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final lang = settings.languageCode;
    String tr(String key) => AppText.t(key, lang);

    final tools = [
      _ToolData(
        icon: Icons.merge_type_rounded,
        title: tr('tool_merge_t'),
        subtitle: tr('tool_merge_s'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MergePdfScreen())),
      ),
      _ToolData(
        icon: Icons.reorder_rounded,
        title: tr('tool_pages_t'),
        subtitle: tr('tool_pages_s'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagePagesScreen())),
      ),
      _ToolData(
        icon: Icons.draw_rounded,
        title: tr('tool_sign_t'),
        subtitle: tr('tool_sign_s'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignatureScreen())),
      ),
      _ToolData(
        icon: Icons.badge_rounded,
        title: tr('tool_signmanage_t'),
        subtitle: tr('tool_signmanage_s'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageSignaturesScreen())),
      ),
      _ToolData(
        icon: Icons.lock_rounded,
        title: tr('tool_protect_t'),
        subtitle: tr('tool_protect_s'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProtectPdfScreen())),
      ),
      _ToolData(
        icon: Icons.water_drop_rounded,
        title: tr('tool_watermark_t'),
        subtitle: tr('tool_watermark_s'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WatermarkScreen())),
      ),
      _ToolData(
        icon: Icons.compress_rounded,
        title: tr('tool_compress_t'),
        subtitle: tr('tool_compress_s'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompressPdfScreen())),
      ),
      _ToolData(
        icon: Icons.compare_arrows_rounded,
        title: tr('tool_compare_t'),
        subtitle: tr('tool_compare_s'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComparePdfScreen())),
      ),
      _ToolData(
        icon: Icons.rotate_right_rounded,
        title: tr('tool_rotate_t'),
        subtitle: tr('tool_rotate_s'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RotatePagesScreen())),
      ),
      _ToolData(
        icon: Icons.record_voice_over_rounded,
        title: tr('tool_tts_t'),
        subtitle: tr('tool_tts_s'),
        onTap: () => _openTtsFromPdf(context),
      ),
      _ToolData(
        icon: Icons.table_chart_rounded,
        title: tr('tool_table_t'),
        subtitle: tr('tool_table_s'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExtractTableScreen())),
      ),
      _ToolData(
        icon: Icons.description_rounded,
        title: tr('tool_word_t'),
        subtitle: tr('tool_word_s'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WordToPdfScreen())),
      ),
      _ToolData(
        icon: Icons.perm_media_rounded,
        title: tr('tool_img2pdf_t'),
        subtitle: tr('tool_img2pdf_s'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImagesToPdfScreen())),
      ),
      _ToolData(
        icon: Icons.image_rounded,
        title: tr('tool_pdf2img_t'),
        subtitle: tr('tool_pdf2img_s'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfToImagesScreen())),
      ),
      _ToolData(
        icon: Icons.print_rounded,
        title: tr('tool_print_t'),
        subtitle: tr('tool_print_s'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrintPdfScreen())),
      ),
      _ToolData(
        icon: Icons.qr_code_scanner_rounded,
        title: tr('tool_barcode_t'),
        subtitle: tr('tool_barcode_s'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BarcodeScannerScreen())),
      ),
      _ToolData(
        icon: Icons.edit_note_rounded,
        title: tr('tool_redact_t'),
        subtitle: tr('tool_redact_s'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RedactEditScreen())),
      ),
      _ToolData(
        icon: Icons.mic_rounded,
        title: tr('tool_dictation_t'),
        subtitle: tr('tool_dictation_s'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceDictationScreen())),
      ),
      _ToolData(
        icon: Icons.build_rounded,
        title: tr('tool_repair_t'),
        subtitle: tr('tool_repair_s'),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RepairPdfScreen())),
      ),
    ];

    return Directionality(
      textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(tr('pdf_tools_appbar'))),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tools.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final t = tools[i];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primaryDark.withOpacity(0.1),
                  child: Icon(t.icon, color: AppColors.primaryDark),
                ),
                title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(t.subtitle, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: t.onTap,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ToolData {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  _ToolData({required this.icon, required this.title, required this.subtitle, required this.onTap});
}

/// يختار المستخدم ملف PDF، يستخرج نصه، ثم يفتح شاشة القراءة الصوتية مباشرة.
Future<void> _openTtsFromPdf(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
  if (result == null || result.files.single.path == null) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  String text = '';
  try {
    final document = sf.PdfDocument(inputBytes: File(result.files.single.path!).readAsBytesSync());
    text = sf.PdfTextExtractor(document).extractText();
    document.dispose();
  } catch (_) {
    text = '';
  }

  if (!context.mounted) return;
  Navigator.pop(context); // إغلاق مؤشر التحميل

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TtsReaderScreen(initialText: text, title: result.files.single.name),
    ),
  );
}
