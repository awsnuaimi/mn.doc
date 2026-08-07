import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerWidget extends StatelessWidget {
  final String filePath;
  final PdfViewerController controller;
  final GlobalKey<SfPdfViewerState> pdfViewerStateKey;

  final PdfPageLayoutMode pageLayoutMode;
  final PdfGestureTapCallback? onTap;
  final PdfPageChangedCallback? onPageChanged;
  final PdfZoomLevelChangedCallback? onZoomLevelChanged;
  final PdfDocumentLoadedCallback? onDocumentLoaded;
  final PdfAnnotationAddedCallback? onAnnotationAdded;
  final PdfAnnotationEditedCallback? onAnnotationEdited;
  final PdfAnnotationRemovedCallback? onAnnotationRemoved;
  final PdfFormFieldValueChangedCallback? onFormFieldValueChanged;

  const PdfViewerWidget({
    super.key,
    required this.filePath,
    required this.controller,
    required this.pdfViewerStateKey,
    required this.pageLayoutMode,
    this.onTap,
    this.onPageChanged,
    this.onZoomLevelChanged,
    this.onDocumentLoaded,
    this.onAnnotationAdded,
    this.onAnnotationEdited,
    this.onAnnotationRemoved,
    this.onFormFieldValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SfPdfViewer.file(
      File(filePath),
      key: pdfViewerStateKey,
      controller: controller,
      pageLayoutMode: pageLayoutMode,
      onTap: onTap,
      onPageChanged: onPageChanged,
      onZoomLevelChanged: onZoomLevelChanged,
      onDocumentLoaded: onDocumentLoaded,
      onAnnotationAdded: onAnnotationAdded,
      onAnnotationEdited: onAnnotationEdited,
      onAnnotationRemoved: onAnnotationRemoved,
      onFormFieldValueChanged: onFormFieldValueChanged,
    );
  }
}