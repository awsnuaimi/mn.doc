import 'dart:typed_data';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// إشارة لصفحة معيّنة داخل ملف PDF مصدر، تُستخدم كوحدة بناء أساسية
/// لكل ميزات تحرير الصفحات (الدمج، الحذف، إعادة الترتيب، التدوير).
class PageRef {
  final String sourceLabel;
  final Uint8List sourceBytes;
  final int pageIndex;
  final int rotation; // 0, 90, 180, 270

  PageRef({
    required this.sourceLabel,
    required this.sourceBytes,
    required this.pageIndex,
    this.rotation = 0,
  });
}

/// محرّك عام لبناء PDF جديد من صفحات مصدر مع الحفاظ على أبعاد كل صفحة.
class PdfPageOps {
  static Future<Uint8List> buildFromPages(List<PageRef> pageRefs) async {
    final outDoc = sf.PdfDocument();

    // المفتاح هو نفس Uint8List الذي تحمله PageRef. هذا cache داخل عملية البناء
    // فقط، ويمنع إعادة فتح المصدر نفسه عندما تشترك PageRefs بنفس الـbytes instance.
    final Map<Uint8List, sf.PdfDocument> openDocs = {};

    try {
      for (final ref in pageRefs) {
        final srcDoc = openDocs.putIfAbsent(
          ref.sourceBytes,
          () => sf.PdfDocument(inputBytes: ref.sourceBytes),
        );
        if (ref.pageIndex < 0 || ref.pageIndex >= srcDoc.pages.count) continue;

        final srcPage = srcDoc.pages[ref.pageIndex];
        final srcSize = srcPage.getClientSize();
        final template = srcPage.createTemplate();
        final rotation = _normalizeRotation(ref.rotation);

        // Section مستقلة لكل صفحة تسمح بالحفاظ على الحجم الأصلي حتى عند دمج
        // ملفات ذات A4/Letter/Landscape/custom sizes في مستند واحد.
        final section = outDoc.sections!.add();
        section.pageSettings.size = Size(srcSize.width, srcSize.height);
        section.pageSettings.margins.all = 0;
        section.pageSettings.rotate = _toPdfRotation(rotation);

        final newPage = section.pages.add();
        newPage.graphics.drawPdfTemplate(
          template,
          const Offset(0, 0),
          Size(srcSize.width, srcSize.height),
        );
      }

      final bytes = await outDoc.save();
      return Uint8List.fromList(bytes);
    } finally {
      outDoc.dispose();
      for (final document in openDocs.values) {
        document.dispose();
      }
    }
  }

  static int countPages(Uint8List bytes) {
    final doc = sf.PdfDocument(inputBytes: bytes);
    try {
      return doc.pages.count;
    } finally {
      doc.dispose();
    }
  }

  /// يفحص فقط غياب النص القابل للاستخراج.
  ///
  /// مهم: true لا تعني أن الصفحة فارغة بصريًا؛ قد تكون Scan أو صورة أو رسمًا.
  /// لذلك لا يجوز استخدام هذه النتيجة للحذف التلقائي.
  static bool hasNoExtractableText(Uint8List bytes, int pageIndex) {
    final doc = sf.PdfDocument(inputBytes: bytes);
    try {
      if (pageIndex < 0 || pageIndex >= doc.pages.count) return false;
      final text = sf.PdfTextExtractor(doc).extractText(
        startPageIndex: pageIndex,
        endPageIndex: pageIndex,
      );
      return text.trim().isEmpty;
    } finally {
      doc.dispose();
    }
  }

  static int _normalizeRotation(int rotation) {
    final normalized = ((rotation % 360) + 360) % 360;
    if (normalized == 90 || normalized == 180 || normalized == 270) {
      return normalized;
    }
    return 0;
  }

  static sf.PdfPageRotateAngle _toPdfRotation(int rotation) {
    switch (rotation) {
      case 90:
        return sf.PdfPageRotateAngle.rotateAngle90;
      case 180:
        return sf.PdfPageRotateAngle.rotateAngle180;
      case 270:
        return sf.PdfPageRotateAngle.rotateAngle270;
      default:
        return sf.PdfPageRotateAngle.rotateAngle0;
    }
  }
}
