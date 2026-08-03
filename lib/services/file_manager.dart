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
  String? originalPath;

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

  static DocumentRecord? tryFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final path = json['path'];
    final name = json['name'];
    final addedAt = json['addedAt'];
    if (path is! String || path.isEmpty || name is! String || addedAt is! num) {
      return null;
    }
    return DocumentRecord(
      path: path,
      name: name,
      addedAt: addedAt.toInt(),
      isFavorite: json['isFavorite'] is bool ? json['isFavorite'] as bool : false,
      isDeleted: json['isDeleted'] is bool ? json['isDeleted'] as bool : false,
      deletedAt: json['deletedAt'] is num ? (json['deletedAt'] as num).toInt() : null,
      originalPath: json['originalPath'] is String ? json['originalPath'] as String : null,
    );
  }

  factory DocumentRecord.fromJson(Map<String, dynamic> json) {
    final record = tryFromJson(json);
    if (record == null) throw const FormatException('Invalid document record');
    return record;
  }
}

/// إدارة الملفات: الأخيرة، المفضلة، وسلة محذوفات آمنة قدر الإمكان.
class FileManagerService {
  static const _prefsKey = 'document_records_v1';

  static Future<List<DocumentRecord>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final records = <DocumentRecord>[];
      for (final item in decoded) {
        final record = DocumentRecord.tryFromJson(item);
        if (record != null) records.add(record);
      }
      return records;
    } catch (_) {
      // metadata تالفة يجب ألا تمنع التطبيق من العمل أو الوصول للملفات الفعلية.
      return [];
    }
  }

  static Future<void> _saveAll(List<DocumentRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(
      _prefsKey,
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
    if (!ok) throw const FileSystemException('Failed to save document metadata');
  }

  static Future<void> registerOpened(String path, String name) async {
    final records = await getAll();
    records.removeWhere((r) => r.path == path);
    records.insert(
      0,
      DocumentRecord(path: path, name: name, addedAt: DateTime.now().millisecondsSinceEpoch),
    );
    await _saveAll(records.take(200).toList());
  }

  static Future<void> toggleFavorite(String path) async {
    final records = await getAll();
    final record = records.firstWhere(
      (r) => r.path == path,
      orElse: () => throw Exception('غير موجود'),
    );
    record.isFavorite = !record.isFavorite;
    await _saveAll(records);
  }

  static Future<void> moveToTrash(String path) async {
    final records = await getAll();
    final record = records.firstWhere(
      (r) => r.path == path,
      orElse: () => throw Exception('غير موجود'),
    );

    final source = File(path);
    if (!await source.exists()) {
      throw FileSystemException('الملف غير موجود', path);
    }

    final dir = await getApplicationDocumentsDirectory();
    final trashDir = Directory('${dir.path}/trash');
    await trashDir.create(recursive: true);
    final safeName = _safeFileName(record.name);
    final targetPath = await _uniquePath(
      trashDir.path,
      '${DateTime.now().millisecondsSinceEpoch}_$safeName',
    );

    await _copyVerifyDelete(source, File(targetPath));

    final replacement = DocumentRecord(
      path: targetPath,
      name: record.name,
      addedAt: record.addedAt,
      isFavorite: record.isFavorite,
      isDeleted: true,
      deletedAt: DateTime.now().millisecondsSinceEpoch,
      originalPath: record.path,
    );
    final index = records.indexOf(record);
    records.removeAt(index);
    records.insert(0, replacement);

    try {
      await _saveAll(records);
    } catch (_) {
      // إذا فشل حفظ metadata نحاول إعادة الملف إلى مكانه حتى لا يصبح يتيمًا.
      await _rollbackMove(File(targetPath), File(path));
      rethrow;
    }
  }

  static Future<void> restoreFromTrash(String path) async {
    final records = await getAll();
    final record = records.firstWhere(
      (r) => r.path == path,
      orElse: () => throw Exception('غير موجود'),
    );

    final source = File(path);
    if (!await source.exists()) {
      throw FileSystemException('ملف سلة المحذوفات غير موجود', path);
    }

    String targetPath = record.originalPath ?? '';
    if (targetPath.isEmpty || await File(targetPath).exists()) {
      final dir = await getApplicationDocumentsDirectory();
      targetPath = await _uniquePath(dir.path, 'مستعاد_${_safeFileName(record.name)}');
    } else {
      await Directory(File(targetPath).parent.path).create(recursive: true);
    }

    await _copyVerifyDelete(source, File(targetPath));

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

    try {
      await _saveAll(records);
    } catch (_) {
      await _rollbackMove(File(targetPath), File(path));
      rethrow;
    }
  }

  static Future<void> permanentlyDelete(String path) async {
    final records = await getAll();
    final file = File(path);

    // نحذف الملف أولًا. إذا فشل، نبقي metadata حتى يستطيع المستخدم المحاولة مجددًا.
    if (await file.exists()) await file.delete();
    records.removeWhere((r) => r.path == path);
    await _saveAll(records);
  }

  static Future<void> purgeOldTrash({int days = 30}) async {
    final records = await getAll();
    final cutoff = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final toDelete = records
        .where((r) => r.isDeleted && (r.deletedAt ?? 0) < cutoff)
        .toList();

    final deletedPaths = <String>{};
    for (final record in toDelete) {
      final file = File(record.path);
      try {
        if (await file.exists()) await file.delete();
        deletedPaths.add(record.path);
      } catch (_) {
        // لا نحذف metadata لملف فشل حذفه فعليًا.
      }
    }
    records.removeWhere((r) => deletedPaths.contains(r.path));
    await _saveAll(records);
  }

  static Future<void> _copyVerifyDelete(File source, File target) async {
    await target.parent.create(recursive: true);
    try {
      final sourceLength = await source.length();
      await source.copy(target.path);
      if (!await target.exists()) {
        throw FileSystemException('فشل إنشاء النسخة', target.path);
      }
      final targetLength = await target.length();
      if (sourceLength != targetLength) {
        throw FileSystemException('حجم النسخة لا يطابق الملف الأصلي', target.path);
      }
      await source.delete();
    } catch (_) {
      try {
        if (await target.exists()) await target.delete();
      } catch (_) {}
      rethrow;
    }
  }

  static Future<void> _rollbackMove(File source, File target) async {
    try {
      if (!await source.exists()) return;
      if (await target.exists()) return;
      await _copyVerifyDelete(source, target);
    } catch (_) {
      // لا نخفي الخطأ الأصلي؛ rollback هو best-effort فقط.
    }
  }

  static Future<String> _uniquePath(String directory, String fileName) async {
    final safe = _safeFileName(fileName);
    final dot = safe.lastIndexOf('.');
    final base = dot > 0 ? safe.substring(0, dot) : safe;
    final ext = dot > 0 ? safe.substring(dot) : '';

    var candidate = '$directory/$safe';
    var index = 1;
    while (await File(candidate).exists()) {
      candidate = '$directory/$base ($index)$ext';
      index++;
    }
    return candidate;
  }

  static String _safeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'[\x00-\x1F]'), '')
        .trim();
    return cleaned.isEmpty ? 'document' : cleaned;
  }
}
