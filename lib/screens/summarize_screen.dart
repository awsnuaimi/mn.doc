import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/ai_settings.dart';
import '../services/gemini_service.dart';
import '../services/local_summarizer.dart';
import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../theme/app_theme.dart';
import 'ai_settings_screen.dart';

/// تلخيص المستندات تلقائيًا.
/// - بدون مفتاح API: تلخيص استخراجي فوري يعمل بالكامل على الجهاز (مجاني للأبد).
/// - بمفتاح Gemini المجاني: تلخيص أذكى وأكثر تماسكًا (يحتاج إنترنت).
class SummarizeScreen extends StatefulWidget {
  final String? initialText;
  const SummarizeScreen({super.key, this.initialText});

  @override
  State<SummarizeScreen> createState() => _SummarizeScreenState();
}

class _SummarizeScreenState extends State<SummarizeScreen> {
  final _inputController = TextEditingController();
  final _resultController = TextEditingController();
  bool _loading = false;
  bool _hasKey = false;
  bool _useAiIfAvailable = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) _inputController.text = widget.initialText!;
    _checkKey();
  }

  Future<void> _checkKey() async {
    final has = await AiSettings.hasApiKey();
    setState(() => _hasKey = has);
  }

  Future<void> _summarize() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() => _loading = true);
    try {
      if (_hasKey && _useAiIfAvailable) {
        final result = await GeminiService.summarize(text);
        _resultController.text = result;
      } else {
        _resultController.text = LocalSummarizer.summarize(text, sentenceCount: 5);
      }
    } catch (e) {
      // في حال فشل الاتصال بالنموذج الذكي، ارجع تلقائيًا للتلخيص المحلي المجاني
      _resultController.text = LocalSummarizer.summarize(text, sentenceCount: 5);
      if (!mounted) return;
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppText.t('sm_error_prefix', lang)}\n$e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _resultController.dispose();
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
        title: Text(tr('summarize')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: tr('ai_settings'),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AiSettingsScreen()));
              _checkKey();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_hasKey ? Colors.green : Colors.orange).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(_hasKey ? Icons.smart_toy_rounded : Icons.offline_bolt_rounded,
                      color: _hasKey ? Colors.green : Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _hasKey ? tr('sm_ai_note') : tr('sm_local_note'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (_hasKey)
                    Switch(
                      value: _useAiIfAvailable,
                      onChanged: (v) => setState(() => _useAiIfAvailable = v),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(tr('sm_original_label'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Expanded(
              child: TextField(
                controller: _inputController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(hintText: tr('sm_hint_input')),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : _summarize,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.summarize_rounded),
              label: Text(_loading ? tr('sm_summarizing') : tr('btn_summarize')),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
            ),
            const SizedBox(height: 12),
            Text(tr('sm_summary_label'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Expanded(
              child: Stack(
                children: [
                  TextField(
                    controller: _resultController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: tr('sm_hint_result'),
                      fillColor: AppColors.accent.withOpacity(0.05),
                      filled: true,
                    ),
                  ),
                  if (_resultController.text.isNotEmpty)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _resultController.text));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('copied'))));
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
