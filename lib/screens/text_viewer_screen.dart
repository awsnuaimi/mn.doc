import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_settings.dart';
import '../services/app_text.dart';

class TextViewerScreen extends StatefulWidget {
  final String filePath;
  const TextViewerScreen({super.key, required this.filePath});

  @override
  State<TextViewerScreen> createState() => _TextViewerScreenState();
}

class _TextViewerScreenState extends State<TextViewerScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final content = await File(widget.filePath).readAsString();
    _controller.text = content;
    setState(() => _loaded = true);
  }

  Future<void> _save() async {
    await File(widget.filePath).writeAsString(_controller.text);
    if (!mounted) return;
    final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppText.t('saved', lang))));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    return Directionality(
      textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
      appBar: AppBar(
        title: Text(widget.filePath.split('/').last),
        actions: [
          IconButton(icon: const Icon(Icons.save_rounded), onPressed: _loaded ? _save : null),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
      ),
    );
  }
}
