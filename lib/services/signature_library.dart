import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نوع العلامة المحفوظة: توقيع مرسوم، أو ختم (صورة/شعار).
enum MarkType { signature, stamp }

class SavedMark {
  final String id;
  final String name;
  final MarkType type;
  final String filePath;
  final int createdAt;

  SavedMark({
    required this.id,
    required this.name,
    required this.type,
    required this.filePath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'filePath': filePath,
        'createdAt': createdAt,
      };

  factory SavedMark.fromJson(Map<String, dynamic> json) => SavedMark(
        id: json['id'],
        name: json['name'],
        type: json['type'] == 'stamp' ? MarkType.stamp : MarkType.signature,
        filePath: json['filePath'],
        createdAt: json['createdAt'],
      );
}

/// مكتبة محلية للتواقيع والأختام المحفوظة — تُخزَّن الصور كملفات على
/// الجهاز، وقائمة البيانات الوصفية (الاسم/النوع/المسار) بذاكرة التطبيق.
class SignatureLibrary {
  static const _prefsKey = 'saved_marks_v1';

  static Future<List<SavedMark>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.map((e) => SavedMark.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> _saveList(List<SavedMark> marks) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(marks.map((m) => m.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }

  /// يحفظ صورة (بايتات PNG) كملف جديد بمجلد التطبيق، ويضيفها لقائمة العلامات المحفوظة.
  static Future<SavedMark> addMark({
    required Uint8List bytes,
    required String name,
    required MarkType type,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final marksDir = Directory('${dir.path}/marks');
    if (!await marksDir.exists()) {
      await marksDir.create(recursive: true);
    }
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final filePath = '${marksDir.path}/$id.png';
    await File(filePath).writeAsBytes(bytes, flush: true);

    final mark = SavedMark(
      id: id,
      name: name.trim().isEmpty ? (type == MarkType.signature ? 'توقيع' : 'ختم') : name.trim(),
      type: type,
      filePath: filePath,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    final current = await list();
    current.insert(0, mark);
    await _saveList(current);
    return mark;
  }

  static Future<void> deleteMark(String id) async {
    final current = await list();
    final target = current.where((m) => m.id == id).toList();
    current.removeWhere((m) => m.id == id);
    await _saveList(current);
    for (final m in target) {
      final f = File(m.filePath);
      if (await f.exists()) await f.delete();
    }
  }
}
