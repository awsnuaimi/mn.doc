import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// يستخرج النص الخام فقط من ملف Word (.docx) — بدون أي تنسيق
/// (لا خطوط، لا صور، لا جداول). ملفات .docx هي أرشيف مضغوط (zip)
/// يحوي ملفات XML؛ النص الفعلي موجود داخل word/document.xml.
class DocxTextExtractor {
  static String extractText(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final documentFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => throw Exception('هذا الملف لا يبدو ملف Word صالح (.docx)'),
    );

    final xmlContent = String.fromCharCodes(documentFile.content as List<int>);
    final document = XmlDocument.parse(xmlContent);

    final buffer = StringBuffer();
    // كل فقرة <w:p> نطبعها بسطر منفصل؛ وكل نص <w:t> بداخلها نلصقه متتاليًا
    for (final paragraph in document.findAllElements('w:p')) {
      final textRuns = paragraph.findAllElements('w:t');
      final paragraphText = textRuns.map((t) => t.innerText).join();
      buffer.writeln(paragraphText);
    }

    return buffer.toString().trim();
  }
}
