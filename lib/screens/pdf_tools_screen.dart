import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'merge_pdf_screen.dart';
import 'manage_pages_screen.dart';
import 'signature_screen.dart';
import 'protect_pdf_screen.dart';
import 'watermark_screen.dart';
import 'compress_pdf_screen.dart';

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
        subtitle: 'ارسم توقيعك وضعه بأي مكان بملف PDF',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignatureScreen())),
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