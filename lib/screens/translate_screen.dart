import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../theme/app_theme.dart';
import '../services/app_settings.dart';
import '../services/app_text.dart';

/// ترجمة نصوص على الجهاز مباشرة عبر Google ML Kit — مجانية بالكامل
/// وتعمل بدون إنترنت بعد تحميل حزمة اللغة مرة واحدة فقط.
class TranslateScreen extends StatefulWidget {
  final String? initialText;
  const TranslateScreen({super.key, this.initialText});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final _sourceController = TextEditingController();
  final _resultController = TextEditingController();

  TranslateLanguage _sourceLang = TranslateLanguage.english;
  TranslateLanguage _targetLang = TranslateLanguage.arabic;

  bool _translating = false;
  bool _downloadingModel = false;

  // أشهر اللغات المدعومة لعرضها في القائمة (يدعم ML Kit أكثر من ذلك بكثير)
  final Map<TranslateLanguage, String> _languages = const {
    TranslateLanguage.arabic: 'العربية',
    TranslateLanguage.english: 'الإنجليزية',
    TranslateLanguage.french: 'الفرنسية',
    TranslateLanguage.german: 'الألمانية',
    TranslateLanguage.spanish: 'الإسبانية',
    TranslateLanguage.turkish: 'التركية',
    TranslateLanguage.urdu: 'الأردية',
    TranslateLanguage.persian: 'الفارسية',
    TranslateLanguage.russian: 'الروسية',
    TranslateLanguage.chinese: 'الصينية',
    TranslateLanguage.hindi: 'الهندية',
    TranslateLanguage.italian: 'الإيطالية',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) {
      _sourceController.text = widget.initialText!;
    }
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _ensureModelsAndTranslate() async {
    if (_translating) return;
    final sourceText = _sourceController.text.trim();
    if (sourceText.isEmpty) return;
    final sourceLang = _sourceLang;
    final targetLang = _targetLang;

    setState(() => _translating = true);
    final modelManager = OnDeviceTranslatorModelManager();
    OnDeviceTranslator? translator;

    try {
      for (final lang in [sourceLang, targetLang]) {
        final downloaded = await modelManager.isModelDownloaded(lang.bcpCode);
        if (!mounted) return;
        if (!downloaded) {
          setState(() => _downloadingModel = true);
          await modelManager.downloadModel(lang.bcpCode, isWifiRequired: false);
          if (!mounted) return;
        }
      }
      if (!mounted) return;
      setState(() => _downloadingModel = false);

      translator = OnDeviceTranslator(sourceLanguage: sourceLang, targetLanguage: targetLang);
      final result = await translator.translateText(sourceText);
      if (!mounted) return;
      setState(() => _resultController.text = result);
    } catch (e) {
      if (!mounted) return;
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppText.t('tr_error_prefix', lang)} $e')),
      );
    } finally {
      if (translator != null) await translator.close();
      if (mounted) {
        setState(() {
          _translating = false;
          _downloadingModel = false;
        });
      }
    }
  }

  void _swapLanguages() {
    setState(() {
      final tmp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = tmp;
      final tmpText = _sourceController.text;
      _sourceController.text = _resultController.text;
      _resultController.text = tmpText;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final lang = settings.languageCode;
    String tr(String key) => AppText.t(key, lang);

    return Directionality(
      textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
      appBar: AppBar(title: Text(tr('tr_appbar'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _langDropdown(_sourceLang, (v) => setState(() => _sourceLang = v!))),
                IconButton(
                  icon: const Icon(Icons.swap_horiz_rounded),
                  onPressed: _swapLanguages,
                ),
                Expanded(child: _langDropdown(_targetLang, (v) => setState(() => _targetLang = v!))),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _sourceController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(hintText: tr('tr_hint_source')),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _translating ? null : _ensureModelsAndTranslate,
              icon: _translating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.translate_rounded),
              label: Text(_downloadingModel
                  ? tr('tr_downloading')
                  : (_translating ? tr('tr_translating') : tr('btn_translate'))),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _resultController,
                readOnly: true,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: tr('tr_hint_result'),
                  fillColor: AppColors.accent.withOpacity(0.05),
                  filled: true,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _langDropdown(TranslateLanguage value, ValueChanged<TranslateLanguage?> onChanged) {
    return DropdownButtonFormField<TranslateLanguage>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10)),
      items: _languages.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
