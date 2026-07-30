import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../theme/app_theme.dart';
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

/// مركز أدوات PDF المتقدمة: دمج، حذف/ترتيب صفحات، وتوقيع إلكتروني.
class PdfToolsScreen extends StatelessWidget {
  const PdfToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = [
      _ToolData(
        icon: Icons.merge_type_rounded,
        title: 'دمج ملفات PDF',
        subtitle: 'اجمع عدة ملفات بملف واحد بالترتيب اللي تحدده',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MergePdfScreen())),
      ),
      _ToolData(
        icon: Icons.reorder_rounded,
        title: 'حذف وإعادة ترتيب الصفحات',
        subtitle: 'احذف صفحات معينة أو رتّب صفحات الملف بالسحب',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagePagesScreen())),
      ),
      _ToolData(
        icon: Icons.draw_rounded,
        title: 'توقيع إلكتروني',
        subtitle: 'اختر توقيع/ختم محفوظ، أو ارسم جديدًا، وضعه بالملف',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignatureScreen())),
      ),
      _ToolData(
        icon: Icons.badge_rounded,
        title: 'إدارة التواقيع والأختام',
        subtitle: 'عرض وحذف التواقيع والأختام المحفوظة',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageSignaturesScreen())),
      ),
      _ToolData(
        icon: Icons.lock_rounded,
        title: 'حماية بكلمة مرور',
        subtitle: 'أضف أو أزل كلمة مرور من ملف PDF',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProtectPdfScreen())),
      ),
      _ToolData(
        icon: Icons.water_drop_rounded,
        title: 'علامة مائية',
        subtitle: 'أضف نص علامة مائية بأي زاوية وشفافية',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WatermarkScreen())),
      ),
      _ToolData(
        icon: Icons.compress_rounded,
        title: 'ضغط حجم PDF',
        subtitle: 'قلّل حجم الملف قدر الإمكان',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompressPdfScreen())),
      ),
      _ToolData(
        icon: Icons.compare_arrows_rounded,
        title: 'مقارنة ملفين PDF',
        subtitle: 'أظهر الفروقات النصية بين ملفين',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComparePdfScreen())),
      ),
      _ToolData(
        icon: Icons.rotate_right_rounded,
        title: 'تدوير وإزالة الصفحات الفارغة',
        subtitle: 'دوّر أي صفحة واكتشف الصفحات الفارغة تلقائيًا',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RotatePagesScreen())),
      ),
      _ToolData(
        icon: Icons.record_voice_over_rounded,
        title: 'قراءة المستند بصوت',
        subtitle: 'اختر ملف PDF واستمع لمحتواه',
        onTap: () => _openTtsFromPdf(context),
      ),
      _ToolData(
        icon: Icons.table_chart_rounded,
        title: 'استخراج جداول PDF إلى Excel',
        subtitle: 'تصدير تقريبي للجداول (طريقة تخمينية)',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExtractTableScreen())),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('أدوات PDF المتقدمة')),
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
