import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';
import 'translate_screen.dart';
import 'summarize_screen.dart';
import 'ai_chat_screen.dart';

/// شاشة "Text Erkennung" — التعرف الضوئي على النصوص (OCR).
/// تدعم التقاط صورة بالكاميرا أو اختيارها من المعرض، ثم استخراج
/// النص منها عبر Google ML Kit وتحرير النتيجة أو حفظها/مشاركتها.
class OcrScreen extends StatefulWidget {
  final String? initialImagePath;
  const OcrScreen({super.key, this.initialImagePath});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final TextEditingController _resultController = TextEditingController();
  String? _imagePath;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null) {
      _imagePath = widget.initialImagePath;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runOcr());
    }
  }

  @override
  void dispose() {
    _recognizer.close();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 95);
    if (file == null) return;
    setState(() {
      _imagePath = file.path;
      _resultController.clear();
    });
    _runOcr();
  }

  Future<void> _runOcr() async {
    if (_imagePath == null) return;
    setState(() => _processing = true);
    try {
      final inputImage = InputImage.fromFilePath(_imagePath!);
      final RecognizedText recognized = await _recognizer.processImage(inputImage);
      _resultController.text = recognized.text;
    } catch (e) {
      _resultController.text = '';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر التعرف على النص: $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _copyText() async {
    await Clipboard.setData(ClipboardData(text: _resultController.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ النص')),
    );
  }

  Future<void> _saveAsTxt() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/MN-Doc_OCR_${DateTime.now().millisecondsSinceEpoch}.txt';
    final file = File(path);
    await file.writeAsString(_resultController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم الحفظ: $path'),
        action: SnackBarAction(
          label: 'مشاركة',
          onPressed: () => Share.shareXFiles([XFile(path)]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التعرف الضوئي على النص (OCR)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('كاميرا'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('المعرض'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(File(_imagePath!), height: 180, fit: BoxFit.cover, width: double.infinity),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('النص المستخرج', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (_processing) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _resultController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'سيظهر النص المستخرج هنا، ويمكنك تعديله مباشرة...',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resultController.text.isEmpty ? null : _copyText,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('نسخ'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _resultController.text.isEmpty ? null : _saveAsTxt,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('حفظ كنص'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resultController.text.isEmpty
                        ? null
                        : () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => TranslateScreen(initialText: _resultController.text))),
                    icon: const Icon(Icons.translate_rounded),
                    label: const Text('ترجمة'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resultController.text.isEmpty
                        ? null
                        : () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => SummarizeScreen(initialText: _resultController.text))),
                    icon: const Icon(Icons.summarize_rounded),
                    label: const Text('تلخيص'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resultController.text.isEmpty
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => AiChatScreen(documentText: _resultController.text, documentTitle: 'اسأل عن هذا النص'))),
                    icon: const Icon(Icons.smart_toy_rounded),
                    label: const Text('اسأل'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
