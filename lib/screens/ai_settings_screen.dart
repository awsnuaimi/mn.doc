import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ai_settings.dart';
import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../theme/app_theme.dart';

/// شاشة إعدادات الذكاء الاصطناعي: إدخال مفتاح Gemini API المجاني
/// (اختياري) لتفعيل التلخيص الذكي والمحادثة حول المستندات.
/// الترجمة والتعرف الضوئي (OCR) لا يحتاجان هذا المفتاح إطلاقًا.
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = await AiSettings.getApiKey();
    _controller.text = key ?? '';
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    await AiSettings.setApiKey(_controller.text);
    if (!mounted) return;
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppText.t('aisettings_saved_msg', lang))));
  }

  Future<void> _clear() async {
    await AiSettings.clearApiKey();
    _controller.clear();
    if (!mounted) return;
    setState(() {});
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppText.t('aisettings_deleted_msg', lang))));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final lang = settings.languageCode;
    String tr(String key) => AppText.t(key, lang);

    return Directionality(
      textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
      appBar: AppBar(title: Text(tr('ai_settings'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.smart_toy_rounded, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Text(tr('aisettings_card_title'),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          tr('aisettings_desc1'),
                          style: TextStyle(color: AppColors.textMuted, height: 1.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr('aisettings_desc2'),
                          style: TextStyle(color: AppColors.textMuted, height: 1.6),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _controller,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: tr('aisettings_field_label'),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _save,
                                child: Text(tr('save')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _clear,
                                child: Text(tr('delete')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
