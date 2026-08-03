import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../services/arabic_font_loader.dart';
import '../theme/app_theme.dart';
import 'pdf_editor_screen.dart';

/// إملاء صوتي: تحويل الكلام إلى نص مباشرة (يعمل بمحرك التعرف الصوتي
/// المدمج بالموبايل)، مع إمكانية تعديل النص وحفظه كمستند PDF أو نسخه.
class VoiceDictationScreen extends StatefulWidget {
  const VoiceDictationScreen({super.key});

  @override
  State<VoiceDictationScreen> createState() => _VoiceDictationScreenState();
}

class _VoiceDictationScreenState extends State<VoiceDictationScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final _textController = TextEditingController();
  bool _speechAvailable = false;
  bool _listening = false;
  String _localeId = 'ar_SA';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          if (mounted) setState(() => _listening = false);
        }
      },
      onError: (error) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (mounted) setState(() => _speechAvailable = available);
  }

  Future<void> _toggleListening() async {
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    String tr(String key) => AppText.t(key, lang);

    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('dict_unavailable'))));
      return;
    }

    if (_listening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _listening = false);
      return;
    }

    setState(() => _listening = true);
    await _speech.listen(
      localeId: _localeId,
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _textController.text = result.recognizedWords;
          _textController.selection = TextSelection.collapsed(offset: _textController.text.length);
        });
      },
    );
  }

  Future<void> _saveAsPdf() async {
    if (_textController.text.trim().isEmpty) return;
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    String tr(String key) => AppText.t(key, lang);

    try {
      final arabicFont = await ArabicFontLoader.loadPwFont();
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(tr('dict_default_title'), style: pw.TextStyle(font: arabicFont, fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text(_textController.text, style: pw.TextStyle(font: arabicFont, fontSize: 13)),
          ],
        ),
      );

      final bytes = await doc.save();
      final dir = await getApplicationDocumentsDirectory();
      final outPath = '${dir.path}/MN-Doc_إملاء_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await File(outPath).writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('saved')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('ed_close'))),
            ElevatedButton(onPressed: () => Share.shareXFiles([XFile(outPath)]), child: Text(tr('ed_share'))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PdfEditorScreen(filePath: outPath)));
              },
              child: Text(tr('scanner_open_file')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('error_prefix')} $e')));
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final lang = settings.languageCode;
    String tr(String key) => AppText.t(key, lang);

    return Directionality(
      textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
      appBar: AppBar(
        title: Text(tr('tool_dictation_t')),
        actions: [
          DropdownButton<String>(
            value: _localeId,
            underline: const SizedBox.shrink(),
            dropdownColor: AppColors.primaryDark,
            style: const TextStyle(color: Colors.white),
            items: const [
              DropdownMenuItem(value: 'ar_SA', child: Text('عربي', style: TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 'en_US', child: Text('English', style: TextStyle(color: Colors.white))),
            ],
            onChanged: (v) => setState(() => _localeId = v ?? 'ar_SA'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(hintText: tr('dict_hint')),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _listening ? Colors.red : AppColors.primaryDark,
                  ),
                  child: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 32),
                ),
              ),
            ),
            if (_listening)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(tr('dict_listening'), textAlign: TextAlign.center),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _textController.text.isEmpty
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: _textController.text));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('copied'))));
                          },
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(tr('copy')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _textController.text.isEmpty ? null : _saveAsPdf,
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: Text(tr('scanner_save_tooltip')),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
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
