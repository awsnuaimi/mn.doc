import 'dart:io';
import 'package:flutter/material.dart';

import '../services/signature_library.dart';
import '../theme/app_theme.dart';

/// إدارة التواقيع والأختام المحفوظة: عرض، حذف.
class ManageSignaturesScreen extends StatefulWidget {
  const ManageSignaturesScreen({super.key});

  @override
  State<ManageSignaturesScreen> createState() => _ManageSignaturesScreenState();
}

class _ManageSignaturesScreenState extends State<ManageSignaturesScreen> {
  List<SavedMark> _marks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final marks = await SignatureLibrary.list();
    if (!mounted) return;
    setState(() {
      _marks = marks;
      _loading = false;
    });
  }

  Future<void> _delete(SavedMark mark) async {
    await SignatureLibrary.deleteMark(mark.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التواقيع والأختام المحفوظة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _marks.isEmpty
              ? Center(
                  child: Text(
                    'لا يوجد توقيعات أو أختام محفوظة بعد.\nاحفظ واحدًا من شاشة "توقيع إلكتروني".',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _marks.length,
                  itemBuilder: (context, index) {
                    final mark = _marks[index];
                    return Card(
                      child: Column(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Image.file(File(mark.filePath), fit: BoxFit.contain),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(mark.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text(mark.type == MarkType.signature ? 'توقيع' : 'ختم', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                  onPressed: () => _delete(mark),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
