import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

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
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('التعرف الصوتي غير متاح على هذا الجهاز')),
      );
      return;
    }

    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }

    setState(() => _listening = true);
    await _speech.listen(
      localeId: _localeId,
      onResult: (result) {
        setState(() {
          _textController.text = result.recognizedWords;
          _textController.selection = TextSelection.collapsed(offset: _textController.text.length);
        });
      },
    );
  }

  Future<void> _saveAsPdf() async {
    if (_textController.text.trim().isEmpty) return;
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text('نص مُملى صوتيًا', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text(_textController.text, style: const pw.TextStyle(fontSize: 13)),
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
          title: const Text('تم الحفظ'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
            ElevatedButton(onPressed: () => Share.shareXFiles([XFile(outPath)]), child: const Text('مشاركة')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PdfEditorScreen(filePath: outPath)));
              },
              child: const Text('فتح'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إملاء صوتي'),
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
                decoration: const InputDecoration(hintText: 'اضغط زر الميكروفون وابدأ الكلام...'),
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
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('...جارٍ الاستماع', textAlign: TextAlign.center),
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
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ')));
                          },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('نسخ'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _textController.text.isEmpty ? null : _saveAsPdf,
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('حفظ كـ PDF'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
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
