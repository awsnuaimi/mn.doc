import 'package:flutter/material.dart';

import '../services/ai_settings.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';
import 'ai_settings_screen.dart';

class _ChatMessage {
  final String role; // 'user' or 'model'
  final String text;
  _ChatMessage(this.role, this.text);
}

/// مساعد ذكي للدردشة حول محتوى مستند معيّن (نص مستخرج من PDF أو OCR).
/// يعتمد على Gemini API (الفئة المجانية) — يتطلب مفتاحًا مجانيًا وإنترنت.
class AiChatScreen extends StatefulWidget {
  final String documentText;
  final String? documentTitle;
  const AiChatScreen({super.key, required this.documentText, this.documentTitle});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;
  bool _hasKey = true;

  @override
  void initState() {
    super.initState();
    _checkKey();
  }

  Future<void> _checkKey() async {
    final has = await AiSettings.hasApiKey();
    setState(() => _hasKey = has);
  }

  Future<void> _send() async {
    final question = _inputController.text.trim();
    if (question.isEmpty) return;

    if (!_hasKey) {
      final ok = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
      );
      await _checkKey();
      if (ok == null) return;
      if (!_hasKey) return;
    }

    setState(() {
      _messages.add(_ChatMessage('user', question));
      _inputController.clear();
      _sending = true;
    });
    _scrollToBottom();

    try {
      final history = _messages
          .take(_messages.length - 1)
          .map((m) => {'role': m.role, 'text': m.text})
          .toList();

      final answer = await GeminiService.askAboutDocument(
        documentText: widget.documentText,
        question: question,
        history: history,
      );

      setState(() => _messages.add(_ChatMessage('model', answer)));
    } catch (e) {
      setState(() => _messages.add(_ChatMessage('model', 'حدث خطأ: $e')));
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.documentTitle ?? 'اسأل عن هذا المستند'),
      ),
      body: Column(
        children: [
          if (widget.documentText.trim().isEmpty)
            Container(
              width: double.infinity,
              color: Colors.orange.withOpacity(0.1),
              padding: const EdgeInsets.all(10),
              child: const Text(
                'لم يتم العثور على نص داخل هذا المستند بعد — قد تحتاج لاستخراج النص أولًا.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'اسأل أي سؤال عن محتوى هذا المستند، مثل:\n"لخّص لي الفكرة الرئيسية"\n"ما أهم الأرقام المذكورة؟"',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final isUser = m.role == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.grey.shade200 : AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            m.text,
                            style: TextStyle(color: isUser ? AppColors.textDark : Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_sending) const LinearProgressIndicator(minHeight: 2),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(hintText: 'اكتب سؤالك...'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppColors.accent),
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
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
