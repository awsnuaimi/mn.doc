import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DocumentRecord {
  final String path;
  final String name;
  final int addedAt;
  bool isFavorite;
  bool isDeleted;
  int? deletedAt;
  String? originalPath; // المسار الأصلي قبل النقل لسلة المحذوفات (لإعادة التسمية عند الاستعادة)

  DocumentRecord({
    required this.path,
    required this.name,
    required this.addedAt,
    this.isFavorite = false,
    this.isDeleted = false,
    this.deletedAt,
    this.originalPath,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'addedAt': addedAt,
        'isFavorite': isFavorite,
        'isDeleted': isDeleted,
        'deletedAt': deletedAt,
        'originalPath': originalPath,
      };

  factory DocumentRecord.fromJson(Map<String, dynamic> json) => DocumentRecord(
        path: json['path'],
        name: json['name'],
        addedAt: json['addedAt'],
        isFavorite: json['isFavorite'] ?? false,
        isDeleted: json['isDeleted'] ?? false,
        deletedAt: json['deletedAt'],
        originalPath: json['originalPath'],
      );
}

/// إدارة الملفات: قائمة الأخيرة، المفضلة، وسلة المحذوفات (حذف مؤقت
/// يمكن التراجع عنه، بدل الحذف النهائي المباشر).
class FileManagerService {
  static const _prefsKey = 'document_records_v1';

  static Future<List<DocumentRecord>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.map((e) => DocumentRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> _saveAll(List<DocumentRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(records.map((r) => r.toJson()).toList()));
  }

  /// يسجّل ملفًا كـ"مفتوح مؤخرًا" (يُضاف بالأعلى، بدون تكرار).
  static Future<void> registerOpened(String path, String name) async {
    final records = await getAll();
    records.removeWhere((r) => r.path == path);
    records.insert(0, DocumentRecord(path: path, name: name, addedAt: DateTime.now().millisecondsSinceEpoch));
    // نحتفظ بحد أقصى معقول من السجلات لتفادي تضخم التخزين
    final trimmed = records.take(200).toList();
    await _saveAll(trimmed);
  }

  static Future<void> toggleFavorite(String path) async {
    final records = await getAll();
    final record = records.firstWhere((r) => r.path == path, orElse: () => throw Exception('غير موجود'));
    record.isFavorite = !record.isFavorite;
    await _saveAll(records);
  }

  /// نقل الملف لسلة المحذوفات: ينقل الملف الفعلي لمجلد trash/، ويُبقي سجلًا قابلاً للاستعادة.
  static Future<void> moveToTrash(String path) async {
    final records = await getAll();
    final record = records.firstWhere((r) => r.path == path, orElse: () => throw Exception('غير موجود'));

    final file = File(path);
    if (await file.exists()) {
      final dir = await getApplicationDocumentsDirectory();
      final trashDir = Directory('${dir.path}/trash');
      if (!await trashDir.exists()) await trashDir.create(recursive: true);

      final newPath = '${trashDir.path}/${DateTime.now().millisecondsSinceEpoch}_${record.name}';
      await file.copy(newPath);
      await file.delete();

      record.originalPath = record.path;
      // تحديث المسار الفعلي بعد النقل — نستبدل السجل بمسار جديد
      records.remove(record);
      records.insert(
        0,
        DocumentRecord(
          path: newPath,
          name: record.name,
          addedAt: record.addedAt,
          isFavorite: record.isFavorite,
          isDeleted: true,
          deletedAt: DateTime.now().millisecondsSinceEpoch,
          originalPath: record.originalPath,
        ),
      );
    }
    await _saveAll(records);
  }

  /// استعادة ملف من سلة المحذوفات لمكانه الأصلي (أو لمجلد المستندات إذا تعذّر).
  static Future<void> restoreFromTrash(String path) async {
    final records = await getAll();
    final record = records.firstWhere((r) => r.path == path, orElse: () => throw Exception('غير موجود'));

    final file = File(path);
    if (await file.exists()) {
      String targetPath = record.originalPath ?? path;
      if (await File(targetPath).exists()) {
        // إذا الملف بمكانه الأصلي محجوز، نستعيده باسم جديد لتفادي الكتابة فوق شي آخر
        final dir = await getApplicationDocumentsDirectory();
        targetPath = '${dir.path}/مستعاد_${record.name}';
      }
      await file.copy(targetPath);
      await file.delete();

      records.remove(record);
      records.insert(
        0,
        DocumentRecord(
          path: targetPath,
          name: record.name,
          addedAt: record.addedAt,
          isFavorite: record.isFavorite,
        ),
      );
    }
    await _saveAll(records);
  }

  static Future<void> permanentlyDelete(String path) async {
    final records = await getAll();
    records.removeWhere((r) => r.path == path);
    final file = File(path);
    if (await file.exists()) await file.delete();
    await _saveAll(records);
  }

  /// يحذف نهائيًا أي ملف بسلة المحذوفات أقدم من [days] يومًا.
  static Future<void> purgeOldTrash({int days = 30}) async {
    final records = await getAll();
    final cutoff = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final toDelete = records.where((r) => r.isDeleted && (r.deletedAt ?? 0) < cutoff).toList();
    for (final r in toDelete) {
      final file = File(r.path);
      if (await file.exists()) await file.delete();
    }
    records.removeWhere((r) => toDelete.contains(r));
    await _saveAll(records);
  }
}
