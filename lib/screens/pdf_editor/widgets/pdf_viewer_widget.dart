import 'package:flutter/material.dart';

class PdfViewerWidget extends StatelessWidget {
  final List<Widget> children;

  const PdfViewerWidget({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: children,
    );
  }
}