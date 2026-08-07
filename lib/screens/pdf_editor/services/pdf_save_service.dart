import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../models/text_annotation.dart';
import '../models/image_annotation.dart';
import '../models/shape_annotation.dart';
import '../models/drawing_stroke.dart';

class PdfSaveService {
  Future<String> export({
    required String sourceFile,
    required List<_TextAnnotation> textAnnotations,
    required List<_ImageAnnotation> imageAnnotations,
    required List<_DrawingStroke> drawingStrokes,
    required List<_ShapeAnnotation> shapeAnnotations,
    required bool flattenForms,
    required Future<sf.PdfFont> Function(double) loadArabicFont,
  }) async {
    throw UnimplementedError();
  }
}