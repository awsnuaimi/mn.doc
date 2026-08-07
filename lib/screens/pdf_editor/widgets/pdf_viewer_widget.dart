import 'package:flutter/material.dart';

class PdfViewerWidget extends StatelessWidget {
  final Widget child;

  const PdfViewerWidget({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}