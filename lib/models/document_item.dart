import 'dart:io';

enum DocType { pdf, image, text, word, other }

class DocumentItem {
  final String path;
  final String name;
  final DateTime modified;
  final int sizeBytes;
  final DocType type;

  DocumentItem({
    required this.path,
    required this.name,
    required this.modified,
    required this.sizeBytes,
    required this.type,
  });

  static DocType typeFromExtension(String ext) {
    final e = ext.toLowerCase().replaceAll('.', '');
    switch (e) {
      case 'pdf':
        return DocType.pdf;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
      case 'bmp':
        return DocType.image;
      case 'txt':
      case 'md':
        return DocType.text;
      case 'doc':
      case 'docx':
        return DocType.word;
      default:
        return DocType.other;
    }
  }

  static Future<DocumentItem> fromFile(File file) async {
    final stat = await file.stat();
    final name = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : file.path;
    final ext = name.contains('.') ? name.split('.').last : '';
    return DocumentItem(
      path: file.path,
      name: name,
      modified: stat.modified,
      sizeBytes: stat.size,
      type: typeFromExtension(ext),
    );
  }

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
