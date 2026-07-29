import 'package:flutter/material.dart';
import '../services/ai_settings.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المفتاح على جهازك')));
  }

  Future<void> _clear() async {
    await AiSettings.clearApiKey();
    _controller.clear();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المفتاح')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الذكاء الاصطناعي')),
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
                            Text('مفتاح Gemini API (مجاني)',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'يُستخدم فقط لميزتيّ "التلخيص الذكي" و"المساعد الذكي للدردشة"، '
                          'وتحتاج فيهما اتصال إنترنت. أما الترجمة والتعرف الضوئي على النصوص '
                          'فيعملان بالكامل بدون إنترنت وبدون أي مفتاح.',
                          style: TextStyle(color: AppColors.textMuted, height: 1.5),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'للحصول على مفتاح مجاني (بدون بطاقة ائتمان):\n'
                          '1) افتح aistudio.google.com/apikey\n'
                          '2) سجّل الدخول بحساب Google\n'
                          '3) اضغط "Create API key" وانسخه هنا',
                          style: TextStyle(color: AppColors.textMuted, height: 1.6),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _controller,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'الصق مفتاح API هنا',
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
                                child: const Text('حفظ'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _clear,
                                child: const Text('حذف'),
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
    );
  }
}
