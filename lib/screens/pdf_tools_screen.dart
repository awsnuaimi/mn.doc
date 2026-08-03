import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../services/isolate_helpers.dart';

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

// ميزة طباعة العناوين مباشرة على الأظرف.
import 'envelope_screen.dart';

import 'barcode_scanner_screen.dart';
import 'redact_edit_screen.dart';
import 'voice_dictation_screen.dart';
import 'repair_pdf_screen.dart';

/// مركز أدوات PDF المتقدمة، مقسّم لفئات لتسهيل الوصول السريع.
class PdfToolsScreen extends StatelessWidget {
  const PdfToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final lang = settings.languageCode;

    String tr(String key) => AppText.t(key, lang);

    final categories = <_ToolCategory>[
      // ==============================================================
      // التحرير
      // ==============================================================
      _ToolCategory(
        title: tr('cat_editing'),
        icon: Icons.edit_note_rounded,
        tools: [
          _ToolData(
            icon: Icons.merge_type_rounded,
            title: tr('tool_merge_t'),
            subtitle: tr('tool_merge_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MergePdfScreen(),
              ),
            ),
          ),
          _ToolData(
            icon: Icons.reorder_rounded,
            title: tr('tool_pages_t'),
            subtitle: tr('tool_pages_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ManagePagesScreen(),
              ),
            ),
          ),
          _ToolData(
            icon: Icons.rotate_right_rounded,
            title: tr('tool_rotate_t'),
            subtitle: tr('tool_rotate_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RotatePagesScreen(),
              ),
            ),
          ),
          _ToolData(
            icon: Icons.compare_arrows_rounded,
            title: tr('tool_compare_t'),
            subtitle: tr('tool_compare_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ComparePdfScreen(),
              ),
            ),
          ),
          _ToolData(
            icon: Icons.edit_note_rounded,
            title: tr('tool_redact_t'),
            subtitle: tr('tool_redact_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RedactEditScreen(),
              ),
            ),
          ),
        ],
      ),

      // ==============================================================
      // التوقيع
      // ==============================================================
      _ToolCategory(
        title: tr('cat_signing'),
        icon: Icons.draw_rounded,
        tools: [
          _ToolData(
            icon: Icons.draw_rounded,
            title: tr('tool_sign_t'),
            subtitle: tr('tool_sign_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SignatureScreen(),
              ),
            ),
          ),
          _ToolData(
            icon: Icons.badge_rounded,
            title: tr('tool_signmanage_t'),
            subtitle: tr('tool_signmanage_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ManageSignaturesScreen(),
              ),
            ),
          ),
        ],
      ),

      // ==============================================================
      // الحماية
      // ==============================================================
      _ToolCategory(
        title: tr('cat_security'),
        icon: Icons.lock_rounded,
        tools: [
          _ToolData(
            icon: Icons.lock_rounded,
            title: tr('tool_protect_t'),
            subtitle: tr('tool_protect_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProtectPdfScreen(),
              ),
            ),
          ),
          _ToolData(
            icon: Icons.water_drop_rounded,
            title: tr('tool_watermark_t'),
            subtitle: tr('tool_watermark_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WatermarkScreen(),
              ),
            ),
          ),
        ],
      ),

      // ==============================================================
      // التحويل
      // ==============================================================
      _ToolCategory(
        title: tr('cat_conversion'),
        icon: Icons.swap_horiz_rounded,
        tools: [
          _ToolData(
            icon: Icons.description_rounded,
            title: tr('tool_word_t'),
            subtitle: tr('tool_word_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WordToPdfScreen(),
              ),
            ),
          ),
          _ToolData(
            icon: Icons.perm_media_rounded,
            title: tr('tool_img2pdf_t'),
            subtitle: tr('tool_img2pdf_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ImagesToPdfScreen(),
              ),
            ),
          ),
          _ToolData(
            icon: Icons.image_rounded,
            title: tr('tool_pdf2img_t'),
            subtitle: tr('tool_pdf2img_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PdfToImagesScreen(),
              ),
            ),
          ),
          _ToolData(
            icon: Icons.table_chart_rounded,
            title: tr('tool_table_t'),
            subtitle: tr('tool_table_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ExtractTableScreen(),
              ),
            ),
          ),
        ],
      ),

      // ==============================================================
      // الأدوات المساعدة
      // ==============================================================
      _ToolCategory(
        title: tr('cat_utilities'),
        icon: Icons.build_rounded,
        tools: [
          _ToolData(
            icon: Icons.compress_rounded,
            title: tr('tool_compress_t'),
            subtitle: tr('tool_compress_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CompressPdfScreen(),
              ),
            ),
          ),

          // ----------------------------------------------------------
          // طباعة ملف PDF
          // ----------------------------------------------------------
          _ToolData(
            icon: Icons.print_rounded,
            title: tr('tool_print_t'),
            subtitle: tr('tool_print_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PrintPdfScreen(),
              ),
            ),
          ),

          // ----------------------------------------------------------
          // طباعة مباشرة على ظرف
          // ----------------------------------------------------------
          _ToolData(
            icon: Icons.mail_outline_rounded,
            title: tr('tool_envelope_t'),
            subtitle: tr('tool_envelope_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EnvelopeScreen(),
              ),
            ),
          ),

          _ToolData(
            icon: Icons.qr_code_scanner_rounded,
            title: tr('tool_barcode_t'),
            subtitle: tr('tool_barcode_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BarcodeScannerScreen(),
              ),
            ),
          ),
          _ToolData(
            icon: Icons.mic_rounded,
            title: tr('tool_dictation_t'),
            subtitle: tr('tool_dictation_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VoiceDictationScreen(),
              ),
            ),
          ),
          _ToolData(
            icon: Icons.record_voice_over_rounded,
            title: tr('tool_tts_t'),
            subtitle: tr('tool_tts_s'),
            onTap: () => _openTtsFromPdf(context),
          ),
          _ToolData(
            icon: Icons.build_rounded,
            title: tr('tool_repair_t'),
            subtitle: tr('tool_repair_s'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RepairPdfScreen(),
              ),
            ),
          ),
        ],
      ),
    ];

    return Directionality(
      textDirection:
          settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('pdf_tools_appbar')),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          itemBuilder: (context, catIndex) {
            final category = categories[catIndex];

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        category.icon,
                        size: 18,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...category.tools.map(
                    (t) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              AppColors.primaryDark.withOpacity(0.1),
                          child: Icon(
                            t.icon,
                            color: AppColors.primaryDark,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          t.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          t.subtitle,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        trailing:
                            const Icon(Icons.chevron_left_rounded),
                        onTap: t.onTap,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ToolCategory {
  final String title;
  final IconData icon;
  final List<_ToolData> tools;

  _ToolCategory({
    required this.title,
    required this.icon,
    required this.tools,
  });
}

class _ToolData {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  _ToolData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

/// يختار المستخدم ملف PDF، يستخرج نصه،
/// ثم يفتح شاشة القراءة الصوتية مباشرة.
Future<void> _openTtsFromPdf(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );

  if (result == null || result.files.single.path == null) {
    return;
  }

  // المستخدم قد يكون غادر الشاشة أثناء FilePicker.
  if (!context.mounted) {
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  String text = '';

  try {
    final fileBytes =
        await File(result.files.single.path!).readAsBytes();

    text = await compute(
      extractPdfTextIsolate,
      fileBytes,
    );
  } catch (_) {
    text = '';
  }

  if (!context.mounted) {
    return;
  }

  // إغلاق مؤشر التحميل.
  Navigator.pop(context);

  if (!context.mounted) {
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TtsReaderScreen(
        initialText: text,
        title: result.files.single.name,
      ),
    ),
  );
}