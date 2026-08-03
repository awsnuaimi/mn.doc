import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// استخراج تقريبي للجداول من صفحات PDF بالاعتماد على تجميع مواقع
/// الكلمات (X/Y) لتخمين الصفوف والأعمدة — وليس تحليلًا حقيقيًا لبنية
/// جدول PDF (PDF لا يخزّن مفهوم "جدول" رسميًا في أغلب الأحيان).
class TableExtractor {
  /// استخراج صفحة واحدة. هذا المسار مناسب للمعاينة السريعة.
  static List<List<String>> extractPageAsRows(
    Uint8List bytes,
    int pageIndex, {
    double columnGap = 18,
  }) {
    final doc = sf.PdfDocument(inputBytes: bytes);
    try {
      return _extractPageFromDocument(doc, pageIndex, columnGap: columnGap);
    } finally {
      doc.dispose();
    }
  }

  /// استخراج عدة صفحات مع فتح PdfDocument مرة واحدة فقط.
  /// مهم عند تصدير "كل الصفحات" حتى لا نعيد تحليل نفس PDF لكل صفحة.
  static Map<int, List<List<String>>> extractPagesAsRows(
    Uint8List bytes,
    Iterable<int> pageIndices, {
    double columnGap = 18,
  }) {
    final doc = sf.PdfDocument(inputBytes: bytes);
    try {
      final result = <int, List<List<String>>>{};
      for (final pageIndex in pageIndices) {
        result[pageIndex] = _extractPageFromDocument(
          doc,
          pageIndex,
          columnGap: columnGap,
        );
      }
      return result;
    } finally {
      doc.dispose();
    }
  }

  static List<List<String>> _extractPageFromDocument(
    sf.PdfDocument doc,
    int pageIndex, {
    required double columnGap,
  }) {
    if (pageIndex < 0 || pageIndex >= doc.pages.count) return [];

    final lines = sf.PdfTextExtractor(doc).extractTextLines(
      startPageIndex: pageIndex,
      endPageIndex: pageIndex,
    );
    if (lines.isEmpty) return [];

    final allStartXs = <double>[];
    for (final line in lines) {
      for (final word in line.wordCollection) {
        allStartXs.add(word.bounds.left);
      }
    }
    if (allStartXs.isEmpty) return [];
    allStartXs.sort();

    // Clustering تدريجي بدل مقارنة كل X مع أول نقطة في العمود فقط.
    // تحديث مركز العنقود يقلل إنشاء أعمدة وهمية بسبب انحرافات بسيطة.
    final columnStarts = <double>[];
    final columnCounts = <int>[];
    for (final x in allStartXs) {
      if (columnStarts.isEmpty || (x - columnStarts.last).abs() > columnGap) {
        columnStarts.add(x);
        columnCounts.add(1);
      } else {
        final i = columnStarts.length - 1;
        final count = columnCounts[i];
        columnStarts[i] = ((columnStarts[i] * count) + x) / (count + 1);
        columnCounts[i] = count + 1;
      }
    }

    int columnIndexFor(double x) {
      var best = 0;
      var bestDist = (x - columnStarts[0]).abs();
      for (var i = 1; i < columnStarts.length; i++) {
        final d = (x - columnStarts[i]).abs();
        if (d < bestDist) {
          bestDist = d;
          best = i;
        }
      }
      return best;
    }

    final rows = <List<String>>[];
    for (final line in lines) {
      final row = List<String>.filled(columnStarts.length, '');
      for (final word in line.wordCollection) {
        final col = columnIndexFor(word.bounds.left);
        row[col] = row[col].isEmpty ? word.text : '${row[col]} ${word.text}';
      }
      rows.add(row);
    }
    return rows;
  }

  static int countPages(Uint8List bytes) {
    final doc = sf.PdfDocument(inputBytes: bytes);
    try {
      return doc.pages.count;
    } finally {
      doc.dispose();
    }
  }
}
