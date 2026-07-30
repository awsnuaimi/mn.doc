import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../models/document_item.dart';
import '../theme/app_theme.dart';
import 'pdf_editor_screen.dart';
import 'ocr_screen.dart';
import 'create_document_screen.dart';
import 'text_viewer_screen.dart';
import 'translate_screen.dart';
import 'summarize_screen.dart';
import 'ai_chat_screen.dart';
import 'ai_settings_screen.dart';
import 'pdf_tools_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<DocumentItem> _recent = [];

  Future<void> _pickAndOpen() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'txt', 'doc', 'docx'],
    );
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final item = await DocumentItem.fromFile(file);

    setState(() {
      _recent.removeWhere((d) => d.path == item.path);
      _recent.insert(0, item);
    });

    if (!mounted) return;
    _openDocument(item);
  }

  void _openDocument(DocumentItem item) {
    switch (item.type) {
      case DocType.pdf:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PdfEditorScreen(filePath: item.path)),
        );
        break;
      case DocType.image:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OcrScreen(initialImagePath: item.path)),
        );
        break;
      case DocType.text:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TextViewerScreen(filePath: item.path)),
        );
        break;
      default:
        OpenFilex.open(item.path);
    }
  }

  IconData _iconFor(DocType t) {
    switch (t) {
      case DocType.pdf:
        return Icons.picture_as_pdf_rounded;
      case DocType.image:
        return Icons.image_rounded;
      case DocType.text:
        return Icons.notes_rounded;
      case DocType.word:
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {},
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 150,
              backgroundColor: AppColors.primaryDark,
              actions: [
                IconButton(
                  tooltip: 'حول التطبيق',
                  icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
                  onPressed: () => showAboutDialog(
                    context: context,
                    applicationName: 'MN-Doc',
                    applicationVersion: '1.0.0',
                    children: const [
                      Text('محرر مستندات احترافي: عرض وتحرير PDF، كتابة نصوص، وتعرف ضوئي على النصوص (OCR).'),
                    ],
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
                title: const Text(
                  'MN-Doc',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [AppColors.primaryDark, AppColors.primary],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 50, 16, 0),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'محرر المستندات وأدوات PDF الذكية',
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _SectionTitle(title: 'أدوات المستندات', icon: Icons.description_rounded),
                  const SizedBox(height: 12),
                  _quickActionsGrid(context, _documentActions(context)),
                  const SizedBox(height: 28),
                  _SectionTitle(title: 'الذكاء الاصطناعي', icon: Icons.auto_awesome_rounded),
                  const SizedBox(height: 12),
                  _quickActionsGrid(context, _aiActions(context)),
                  const SizedBox(height: 28),
                  Text(
                    'الملفات الأخيرة',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textDark,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (_recent.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text(
                          'لا توجد ملفات بعد.\nاضغط "فتح ملف" للبدء.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  else
                    ..._recent.map((item) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryDark.withOpacity(0.1),
                              child: Icon(_iconFor(item.type), color: AppColors.primaryDark),
                            ),
                            title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${item.sizeLabel} • ${item.modified.toString().split('.').first}'),
                            trailing: const Icon(Icons.chevron_left_rounded),
                            onTap: () => _openDocument(item),
                          ),
                        )),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ActionData> _documentActions(BuildContext context) => [
        _ActionData(
          icon: Icons.folder_open_rounded,
          label: 'فتح ملف',
          onTap: _pickAndOpen,
        ),
        _ActionData(
          icon: Icons.picture_as_pdf_rounded,
          label: 'تحرير PDF',
          onTap: _pickAndOpen,
        ),
        _ActionData(
          icon: Icons.construction_rounded,
          label: 'أدوات PDF (دمج/ترتيب/توقيع)',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfToolsScreen())),
        ),
        _ActionData(
          icon: Icons.document_scanner_rounded,
          label: 'التعرف الضوئي (OCR)',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OcrScreen())),
        ),
        _ActionData(
          icon: Icons.note_add_rounded,
          label: 'إنشاء مستند جديد',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateDocumentScreen())),
        ),
      ];

  List<_ActionData> _aiActions(BuildContext context) => [
        _ActionData(
          icon: Icons.translate_rounded,
          label: 'ترجمة (مجانية)',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TranslateScreen())),
        ),
        _ActionData(
          icon: Icons.summarize_rounded,
          label: 'تلخيص مستند',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SummarizeScreen())),
        ),
        _ActionData(
          icon: Icons.smart_toy_rounded,
          label: 'مساعد ذكي للدردشة',
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const AiChatScreen(documentText: '', documentTitle: 'مساعد MN-Doc الذكي'))),
        ),
        _ActionData(
          icon: Icons.settings_rounded,
          label: 'إعدادات الذكاء الاصطناعي',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiSettingsScreen())),
        ),
      ];

  Widget _quickActionsGrid(BuildContext context, List<_ActionData> actions) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: actions.map((a) => _ActionCard(data: a)).toList(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryDark),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
        ),
      ],
    );
  }
}

class _ActionData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _ActionData({required this.icon, required this.label, required this.onTap});
}

class _ActionCard extends StatelessWidget {
  final _ActionData data;
  const _ActionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(18),
      elevation: 1.5,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(data.icon, color: AppColors.primaryDark, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                data.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}