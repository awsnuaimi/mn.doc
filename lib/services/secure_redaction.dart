import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import 'arabic_font_loader.dart';

/// منطقة حجب بإحداثيات نسبية إلى الصفحة (0..1).
class SecureRedactionRegion {
  final int pageIndex;
  final double x;
  final double y;
  final double width;
  final double height;
  final String replacementText;

  const SecureRedactionRegion({
    required this.pageIndex,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.replacementText = '',
  });
}

/// حجب آمن لمحتوى PDF.
///
/// مكتبة Syncfusion Flutter PDF لا تعرض حاليًا API redaction دائم مماثلًا
/// لنسخة .NET. لذلك لا نرسم مستطيلاً فوق المحتوى الأصلي؛ الصفحة التي تحتوي
/// مناطق حجب تُحوّل أولًا إلى bitmap، ثم تُمسح البكسلات الحساسة *قبل* تضمين
/// الصورة في PDF جديد. بهذا لا يبقى النص/الصورة الأصلية تحت طبقة تغطية يمكن
/// إزالتها لاحقًا.
///
/// الصفحات غير المعدلة تُنسخ كـPDF templates للحفاظ على النص والوضوح فيها.
/// الصفحات المحجوبة تصبح flattened/rasterized عمدًا كجزء من ضمان الحجب.
class SecureRedactionService {
  static const double _rasterDpi = 200;

  static Future<Uint8List> apply({
    required Uint8List inputBytes,
    required List<SecureRedactionRegion> regions,
  }) async {
    if (regions.isEmpty) return inputBytes;

    final source = sf.PdfDocument(inputBytes: inputBytes);
    final output = sf.PdfDocument();
    final byPage = <int, List<SecureRedactionRegion>>{};

    for (final region in regions) {
      if (region.pageIndex < 0 || region.pageIndex >= source.pages.count) {
        continue;
      }
      byPage.putIfAbsent(region.pageIndex, () => []).add(region);
    }

    try {
      for (var pageIndex = 0; pageIndex < source.pages.count; pageIndex++) {
        final sourcePage = source.pages[pageIndex];
        final pageSize = sourcePage.getClientSize();
        final section = output.sections!.add();
        section.pageSettings.size = Size(pageSize.width, pageSize.height);
        section.pageSettings.margins.all = 0;
        final outPage = section.pages.add();

        final pageRegions = byPage[pageIndex];
        if (pageRegions == null || pageRegions.isEmpty) {
          final template = sourcePage.createTemplate();
          outPage.graphics.drawPdfTemplate(
            template,
            Offset.zero,
            Size(pageSize.width, pageSize.height),
          );
          continue;
        }

        final rasterPng = await _rasterizePage(inputBytes, pageIndex);
        final decoded = img.decodePng(rasterPng);
        if (decoded == null) {
          throw StateError('تعذر معالجة صورة الصفحة ${pageIndex + 1} للحجب الآمن.');
        }

        // نمسح البكسلات داخل الصورة نفسها. لا توجد طبقة أصلية مخفية أسفلها.
        for (final region in pageRegions) {
          final x1 = (region.x.clamp(0.0, 1.0) * decoded.width).round();
          final y1 = (region.y.clamp(0.0, 1.0) * decoded.height).round();
          final x2 = ((region.x + region.width).clamp(0.0, 1.0) * decoded.width).round();
          final y2 = ((region.y + region.height).clamp(0.0, 1.0) * decoded.height).round();

          if (x2 <= x1 || y2 <= y1) continue;
          img.fillRect(
            decoded,
            x1: x1,
            y1: y1,
            x2: x2 - 1,
            y2: y2 - 1,
            color: img.ColorRgb8(255, 255, 255),
          );
        }

        final sanitizedPng = Uint8List.fromList(img.encodePng(decoded));
        final bitmap = sf.PdfBitmap(sanitizedPng);
        outPage.graphics.drawImage(
          bitmap,
          Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
        );

        // النص البديل يُضاف بعد إزالة المحتوى الأصلي، لذلك هو المحتوى النصي
        // الوحيد الذي نضيفه إلى الصفحة المحجوبة.
        for (final region in pageRegions) {
          final text = region.replacementText.trim();
          if (text.isEmpty) continue;

          final rect = Rect.fromLTWH(
            region.x.clamp(0.0, 1.0).toDouble() * pageSize.width,
            region.y.clamp(0.0, 1.0).toDouble() * pageSize.height,
            region.width.clamp(0.0, 1.0).toDouble() * pageSize.width,
            region.height.clamp(0.0, 1.0).toDouble() * pageSize.height,
          );
          final font = await ArabicFontLoader.loadSyncfusionFont(
            (rect.height * 0.6).clamp(8.0, 24.0).toDouble(),
          );
          outPage.graphics.drawString(
            text,
            font,
            brush: sf.PdfSolidBrush(sf.PdfColor(0, 0, 0)),
            bounds: rect,
          );
        }
      }

      return Uint8List.fromList(await output.save());
    } finally {
      output.dispose();
      source.dispose();
    }
  }

  static Future<Uint8List> _rasterizePage(
    Uint8List inputBytes,
    int pageIndex,
  ) async {
    await for (final page in Printing.raster(
      inputBytes,
      pages: [pageIndex],
      dpi: _rasterDpi,
    )) {
      return Uint8List.fromList(await page.toPng());
    }
    throw StateError('تعذر تحويل الصفحة ${pageIndex + 1} إلى صورة.');
  }
}
