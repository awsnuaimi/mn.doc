import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';

import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../services/gemini_service.dart';
import '../services/ai_settings.dart';
import '../theme/app_theme.dart';
import 'translate_screen.dart';
import 'summarize_screen.dart';
import 'ai_chat_screen.dart';
import 'ai_settings_screen.dart';

/// شاشة التعرف الضوئي على النصوص (OCR) — بوضعين:
/// 1) مجاني وبدون إنترنت (Google ML Kit) — يدعم الإنجليزي/الصيني/الياباني/الكوري فقط.
/// 2) بالذكاء الاصطناعي (Gemini) — يدعم العربية وكل اللغات، يحتاج إنترنت ومفتاح مجاني.
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
  bool _useAiMode = false;
  int _ocrGeneration = 0;

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
    if (file == null || !mounted) return;
    setState(() {
      _imagePath = file.path;
      _resultController.clear();
    });
    _runOcr();
  }

  Future<void> _runOcr() async {
    if (_imagePath == null || _processing) return;
    final generation = ++_ocrGeneration;
    final imagePath = _imagePath!;
    final useAiMode = _useAiMode;
    setState(() => _processing = true);
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    String tr(String key) => AppText.t(key, lang);

    try {
      if (useAiMode) {
        final hasKey = await AiSettings.hasApiKey();
        if (!hasKey) {
          if (!mounted) return;
          final ok = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AiSettingsScreen()));
          final hasKeyNow = await AiSettings.hasApiKey();
          if (!mounted || generation != _ocrGeneration) return;
          if (ok == null || !hasKeyNow) {
            setState(() => _processing = false);
            return;
          }
        }
        final bytes = await File(imagePath).readAsBytes();
        final result = await GeminiService.extractTextFromImage(bytes);
        if (!mounted || generation != _ocrGeneration) return;
        _resultController.text = result;
      } else {
        final inputImage = InputImage.fromFilePath(imagePath);
        final RecognizedText recognized = await _recognizer.processImage(inputImage);
        if (!mounted || generation != _ocrGeneration) return;
        _resultController.text = recognized.text;
      }
    } catch (e) {
      if (!mounted || generation != _ocrGeneration) return;
      _resultController.text = '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('ocr_error_prefix')} $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _copyText() async {
    await Clipboard.setData(ClipboardData(text: _resultController.text));
    if (!mounted) return;
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppText.t('copied', lang))),
    );
  }

  Future<void> _saveAsTxt() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/MN-Doc_OCR_${DateTime.now().millisecondsSinceEpoch}.txt';
    final file = File(path);
    await file.writeAsString(_resultController.text);
    if (!mounted) return;
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppText.t('ocr_saved_prefix', lang)} $path'),
        action: SnackBarAction(
          label: AppText.t('ed_share', lang),
          onPressed: () => Share.shareXFiles([XFile(path)]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final lang = settings.languageCode;
    String tr(String key) => AppText.t(key, lang);

    return Directionality(
      textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
      appBar: AppBar(title: Text(tr('ocr'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(tr('ocr_mode_free')), icon: const Icon(Icons.offline_bolt_rounded)),
                ButtonSegment(value: true, label: Text(tr('ocr_mode_ai')), icon: const Icon(Icons.smart_toy_rounded)),
              ],
              selected: {_useAiMode},
              onSelectionChanged: (s) => setState(() => _useAiMode = s.first),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (_useAiMode ? AppColors.accent : Colors.green).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _useAiMode ? tr('ocr_ai_note') : tr('ocr_free_note'),
                style: const TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: Text(tr('camera')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: Text(tr('gallery')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(File(_imagePath!), height: 160, fit: BoxFit.cover, width: double.infinity),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(tr('ocr_extracted_label'), style: Theme.of(context).textTheme.titleMedium),
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
                decoration: InputDecoration(hintText: tr('ocr_hint')),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resultController.text.isEmpty ? null : _copyText,
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(tr('copy')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _resultController.text.isEmpty ? null : _saveAsTxt,
                    icon: const Icon(Icons.save_rounded),
                    label: Text(tr('ocr_save_txt')),
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
                    label: Text(tr('btn_translate')),
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
                    label: Text(tr('btn_summarize')),
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
                                builder: (_) => AiChatScreen(documentText: _resultController.text, documentTitle: tr('ocr_ask_title')))),
                    icon: const Icon(Icons.smart_toy_rounded),
                    label: Text(tr('btn_ask')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}
