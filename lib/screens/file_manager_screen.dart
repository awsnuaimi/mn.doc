import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';

import '../services/file_manager.dart';
import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../theme/app_theme.dart';
import 'pdf_editor_screen.dart';
import 'text_viewer_screen.dart';

/// مدير الملفات: تبويبات "الكل"، "المفضلة"، "سلة المحذوفات"، مع بحث بالاسم.
class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<DocumentRecord> _all = [];
  final _searchController = TextEditingController();
  String _query = '';

  String get _lang => Provider.of<AppSettingsController>(context, listen: false).languageCode;
  String tr(String key) => AppText.t(key, _lang);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final records = await FileManagerService.getAll();
    if (mounted) setState(() => _all = records);
  }

  List<DocumentRecord> _filtered(List<DocumentRecord> list) {
    if (_query.trim().isEmpty) return list;
    final q = _query.toLowerCase();
    return list.where((r) => r.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _openRecord(DocumentRecord record) async {
    final path = record.path;
    if (path.toLowerCase().endsWith('.pdf')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PdfEditorScreen(filePath: path)));
    } else if (path.toLowerCase().endsWith('.txt')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => TextViewerScreen(filePath: path)));
    } else {
      OpenFilex.open(path);
    }
  }

  Future<void> _toggleFavorite(DocumentRecord record) async {
    await FileManagerService.toggleFavorite(record.path);
    _load();
  }

  Future<void> _moveToTrash(DocumentRecord record) async {
    await FileManagerService.moveToTrash(record.path);
    _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('fm_moved_to_trash'))));
  }

  Future<void> _restore(DocumentRecord record) async {
    await FileManagerService.restoreFromTrash(record.path);
    _load();
  }

  Future<void> _permanentDelete(DocumentRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('fm_delete_permanent_title')),
        content: Text('${tr('fm_delete_permanent_body_prefix')} "${record.name}" ${tr('fm_delete_permanent_body_suffix')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('fm_delete_permanent_title')),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FileManagerService.permanentlyDelete(record.path);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final activeRecords = _all.where((r) => !r.isDeleted).toList();
    final favoriteRecords = activeRecords.where((r) => r.isFavorite).toList();
    final trashRecords = _all.where((r) => r.isDeleted).toList();

    return Directionality(
      textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('fm_appbar')),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: tr('fm_tab_all')),
              Tab(text: tr('fm_tab_favorites')),
              Tab(text: tr('fm_tab_trash')),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: tr('fm_search_hint'),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(_filtered(activeRecords), isTrash: false),
                  _buildList(_filtered(favoriteRecords), isTrash: false),
                  _buildList(_filtered(trashRecords), isTrash: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<DocumentRecord> records, {required bool isTrash}) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTrash ? Icons.delete_outline_rounded : Icons.folder_open_rounded,
              size: 48,
              color: AppColors.textMuted.withOpacity(0.4),
            ),
            const SizedBox(height: 10),
            Text(
              isTrash ? tr('fm_trash_empty') : tr('fm_no_files'),
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: records.length,
      itemBuilder: (context, i) {
        final r = records[i];
        final exists = File(r.path).existsSync();
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryDark.withOpacity(0.1),
              child: Icon(
                r.path.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
                color: AppColors.primaryDark,
              ),
            ),
            title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              exists ? DateTime.fromMillisecondsSinceEpoch(r.addedAt).toString().split('.').first : tr('fm_file_missing'),
              style: TextStyle(fontSize: 11, color: exists ? null : Colors.red),
            ),
            onTap: exists && !isTrash ? () => _openRecord(r) : null,
            trailing: isTrash
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.restore_rounded, color: Colors.green), onPressed: () => _restore(r)),
                      IconButton(icon: const Icon(Icons.delete_forever_rounded, color: Colors.red), onPressed: () => _permanentDelete(r)),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(r.isFavorite ? Icons.star_rounded : Icons.star_border_rounded, color: r.isFavorite ? Colors.amber : null),
                        onPressed: () => _toggleFavorite(r),
                      ),
                      IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red), onPressed: () => _moveToTrash(r)),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
