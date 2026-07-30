import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// استخراج تقريبي للجداول من صفحات PDF بالاعتماد على تجميع مواقع
/// الكلمات (X/Y) لتخمين الصفوف والأعمدة — وليس تحليلًا حقيقيًا لبنية
/// جدول PDF (PDF لا يخزّن مفهوم "جدول" رسميًا في أغلب الأحيان).
/// يعمل بشكل جيد مع جداول بسيطة وواضحة المحاذاة، وقد لا يعطي نتيجة
/// دقيقة 100% مع كل أنواع الملفات.
class TableExtractor {
  /// يرجع قائمة صفوف (كل صف = قائمة نصوص أعمدة) لصفحة واحدة.
  static List<List<String>> extractPageAsRows(Uint8List bytes, int pageIndex, {double columnGap = 18}) {
    final doc = sf.PdfDocument(inputBytes: bytes);
    if (pageIndex < 0 || pageIndex >= doc.pages.count) {
      doc.dispose();
      return [];
    }

    final lines = sf.PdfTextExtractor(doc).extractTextLines(startPageIndex: pageIndex, endPageIndex: pageIndex);
    doc.dispose();

    if (lines.isEmpty) return [];

    // اجمع كل مواضع بداية الكلمات (X) بالصفحة لتحديد حدود الأعمدة
    final allStartXs = <double>[];
    for (final line in lines) {
      for (final word in line.wordCollection) {
        allStartXs.add(word.bounds.left);
      }
    }
    if (allStartXs.isEmpty) return [];
    allStartXs.sort();

    // تجميع المواضع القريبة من بعضها بنفس "عمود" واحد
    final columnStarts = <double>[allStartXs.first];
    for (final x in allStartXs.skip(1)) {
      if (x - columnStarts.last > columnGap) {
        columnStarts.add(x);
      }
    }

    int columnIndexFor(double x) {
      int best = 0;
      double bestDist = (x - columnStarts[0]).abs();
      for (int i = 1; i < columnStarts.length; i++) {
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
    final count = doc.pages.count;
    doc.dispose();
    return count;
  }
}
