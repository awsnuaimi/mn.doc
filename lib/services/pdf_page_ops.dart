import 'dart:typed_data';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// إشارة لصفحة معيّنة داخل ملف PDF مصدر، تُستخدم كوحدة بناء أساسية
/// لكل ميزات تحرير الصفحات (الدمج، الحذف، إعادة الترتيب، التدوير).
class PageRef {
  final String sourceLabel; // اسم الملف الأصلي (للعرض فقط)
  final Uint8List sourceBytes;
  final int pageIndex; // يبدأ من 0
  final int rotation; // 0, 90, 180, 270 (اتجاه دوران إضافي عند البناء)

  PageRef({
    required this.sourceLabel,
    required this.sourceBytes,
    required this.pageIndex,
    this.rotation = 0,
  });
}

/// محرّك عام: يبني ملف PDF جديد من قائمة صفحات (بأي ترتيب، من أي عدد ملفات).
/// يُستخدم لدمج الملفات، حذف صفحات، أو إعادة ترتيبها — بنفس الآلية.
class PdfPageOps {
  static Future<Uint8List> buildFromPages(List<PageRef> pageRefs) async {
    final outDoc = sf.PdfDocument();
    // تخزين مؤقت للمستندات المفتوحة لتفادي إعادة فتح نفس الملف لكل صفحة
    final Map<Uint8List, sf.PdfDocument> openDocs = {};

    try {
      for (final ref in pageRefs) {
        final srcDoc = openDocs.putIfAbsent(
          ref.sourceBytes,
          () => sf.PdfDocument(inputBytes: ref.sourceBytes),
        );
        if (ref.pageIndex < 0 || ref.pageIndex >= srcDoc.pages.count) continue;

        final srcPage = srcDoc.pages[ref.pageIndex];
        final template = srcPage.createTemplate();
        final newPage = outDoc.pages.add();
        final graphics = newPage.graphics;

        if (ref.rotation % 360 == 0) {
          graphics.drawPdfTemplate(
            template,
            const Offset(0, 0),
            Size(newPage.size.width, newPage.size.height),
          );
        } else {
          // دوران حول مركز الصفحة بالزاوية المطلوبة
          graphics.save();
          graphics.translateTransform(newPage.size.width / 2, newPage.size.height / 2);
          graphics.rotateTransform(ref.rotation.toDouble());
          graphics.translateTransform(-newPage.size.width / 2, -newPage.size.height / 2);
          graphics.drawPdfTemplate(
            template,
            const Offset(0, 0),
            Size(newPage.size.width, newPage.size.height),
          );
          graphics.restore();
        }
      }

      final bytes = await outDoc.save();
      return Uint8List.fromList(bytes);
    } finally {
      outDoc.dispose();
      for (final d in openDocs.values) {
        d.dispose();
      }
    }
  }

  /// يرجع عدد صفحات ملف PDF بدون تحميله بالكامل بالذاكرة لفترة طويلة.
  static int countPages(Uint8List bytes) {
    final doc = sf.PdfDocument(inputBytes: bytes);
    final count = doc.pages.count;
    doc.dispose();
    return count;
  }

  /// يفحص إذا كانت صفحة معيّنة "فارغة" — بالاعتماد على غياب أي نص مستخرج
  /// منها. ملاحظة: هذا فحص تقريبي؛ صفحة فيها صورة فقط بدون نص ستُعتبر
  /// فارغة أيضًا حسب هذا المعيار.
  static bool isPageBlank(Uint8List bytes, int pageIndex) {
    final doc = sf.PdfDocument(inputBytes: bytes);
    if (pageIndex < 0 || pageIndex >= doc.pages.count) {
      doc.dispose();
      return false;
    }
    final text = sf.PdfTextExtractor(doc).extractText(startPageIndex: pageIndex, endPageIndex: pageIndex);
    doc.dispose();
    return text.trim().isEmpty;
  }
}