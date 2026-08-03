import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../theme/app_theme.dart';

/// قراءة نص المستند بصوت عالٍ (Text-to-Speech) — يعمل بمحرك القراءة
/// المدمج بالموبايل (مجاني وبدون إنترنت).
class TtsReaderScreen extends StatefulWidget {
  final String initialText;
  final String? title;
  const TtsReaderScreen({super.key, required this.initialText, this.title});

  @override
  State<TtsReaderScreen> createState() => _TtsReaderScreenState();
}

class _TtsReaderScreenState extends State<TtsReaderScreen> {
  late final FlutterTts _tts;
  late final TextEditingController _textController;
  double _rate = 0.5;
  double _pitch = 1.0;
  bool _isPlaying = false;
  String _language = 'ar-SA';

  final Map<String, String> _languages = const {
    'ar-SA': 'العربية',
    'en-US': 'الإنجليزية',
    'fr-FR': 'الفرنسية',
    'es-ES': 'الإسبانية',
    'tr-TR': 'التركية',
  };

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    _tts = FlutterTts();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlaying = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (_textController.text.trim().isEmpty) return;
    await _tts.setLanguage(_language);
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(_pitch);
    if (!mounted) return;
    setState(() => _isPlaying = true);
    await _tts.speak(_textController.text);
  }

  Future<void> _pause() async {
    await _tts.pause();
    if (!mounted) return;
    setState(() => _isPlaying = false);
  }

  Future<void> _stop() async {
    await _tts.stop();
    if (!mounted) return;
    setState(() => _isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final lang = settings.languageCode;
    String tr(String key) => AppText.t(key, lang);

    return Directionality(
      textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
      appBar: AppBar(title: Text(widget.title ?? tr('tool_tts_t'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _language,
              decoration: InputDecoration(labelText: tr('tts_lang_label')),
              items: _languages.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setState(() => _language = v!),
            ),
            const SizedBox(height: 12),
            Text('${tr('tts_rate_label')} ${(_rate * 2).toStringAsFixed(1)}x'),
            Slider(value: _rate, min: 0.1, max: 1.0, onChanged: (v) => setState(() => _rate = v)),
            Text('${tr('tts_pitch_label')} ${_pitch.toStringAsFixed(1)}'),
            Slider(value: _pitch, min: 0.5, max: 2.0, onChanged: (v) => setState(() => _pitch = v)),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(hintText: tr('tts_hint')),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isPlaying ? _pause : _play,
                    icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    label: Text(_isPlaying ? tr('tts_pause') : tr('tts_play_btn')),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, minimumSize: const Size(0, 50)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop_rounded),
                    label: Text(tr('tts_stop')),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
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
