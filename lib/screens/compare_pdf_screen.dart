import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../services/text_diff.dart';
import '../theme/app_theme.dart';

/// مقارنة ملفي PDF نصيًا وإظهار الإضافات والحذف بينهما.
/// ملاحظة: المقارنة على مستوى النص المستخرج فقط (لا تقارن التصميم أو الصور).
class ComparePdfScreen extends StatefulWidget {
  const ComparePdfScreen({super.key});

  @override
  State<ComparePdfScreen> createState() => _ComparePdfScreenState();
}

class _ComparePdfScreenState extends State<ComparePdfScreen> {
  String? _fileA;
  String? _fileB;
  bool _comparing = false;
  List<DiffToken>? _diffResult;

  // حد أقصى لعدد الكلمات لتفادي بطء شديد بالخوارزمية مع مستندات ضخمة جدًا
  static const int _maxWords = 6000;

  Future<void> _pickFile(bool isA) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;
    setState(() {
      if (isA) {
        _fileA = result.files.single.path!;
      } else {
        _fileB = result.files.single.path!;
      }
      _diffResult = null;
    });
  }

  String _extractText(String path) {
    final bytes = File(path).readAsBytesSync();
    final document = sf.PdfDocument(inputBytes: bytes);
    final text = sf.PdfTextExtractor(document).extractText();
    document.dispose();
    return text;
  }

  Future<void> _compare() async {
    if (_fileA == null || _fileB == null) return;
    setState(() => _comparing = true);
    try {
      var textA = _extractText(_fileA!);
      var textB = _extractText(_fileB!);

      final wordsA = textA.split(RegExp(r'\s+')).length;
      final wordsB = textB.split(RegExp(r'\s+')).length;
      bool truncated = false;
      if (wordsA > _maxWords || wordsB > _maxWords) {
        truncated = true;
        textA = textA.split(RegExp(r'\s+')).take(_maxWords).join(' ');
        textB = textB.split(RegExp(r'\s+')).take(_maxWords).join(' ');
      }

      final diff = TextDiff.compare(textA, textB);

      if (!mounted) return;
      setState(() {
        _diffResult = diff;
        _comparing = false;
      });

      if (truncated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الملفات طويلة جدًا — تمت مقارنة أول جزء منها فقط لتفادي البطء الشديد')),
        );
      }
    } catch (e) {
      setState(() => _comparing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء المقارنة: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مقارنة ملفي PDF')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickFile(true),
                  icon: const Icon(Icons.filter_1_rounded),
                  label: Text(_fileA == null ? 'اختيار الملف الأول' : _fileA!.split('/').last, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _pickFile(false),
                  icon: const Icon(Icons.filter_2_rounded),
                  label: Text(_fileB == null ? 'اختيار الملف الثاني' : _fileB!.split('/').last, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: (_fileA == null || _fileB == null || _comparing) ? null : _compare,
                  icon: _comparing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.compare_arrows_rounded),
                  label: Text(_comparing ? 'جارٍ المقارنة...' : 'قارن الملفين'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
                ),
              ],
            ),
          ),
          if (_diffResult != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _legendDot(Colors.red.shade100, 'حُذف (من الملف الأول)'),
                  const SizedBox(width: 12),
                  _legendDot(Colors.green.shade100, 'أُضيف (بالملف الثاني)'),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  children: _diffResult!.map((token) {
                    Color? bg;
                    TextDecoration? decoration;
                    if (token.type == DiffType.removed) {
                      bg = Colors.red.shade100;
                      decoration = TextDecoration.lineThrough;
                    } else if (token.type == DiffType.added) {
                      bg = Colors.green.shade100;
                    }
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      color: bg,
                      child: Text('${token.text} ', style: TextStyle(decoration: decoration)),
                    );
                  }).toList(),
                ),
              ),
            ),
          ] else
            Expanded(
              child: Center(
                child: Text(
                  'اختر ملفين PDF لمقارنة محتواهما النصي',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
