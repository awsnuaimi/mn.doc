import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/image_annotation.dart';
import '../geometry/pdf_page_transform.dart';

/// وحدة الصور الخاصة بمحرر PDF.
///
/// مسؤولة عن:
/// - اختيار الصور
/// - إضافة الصور
/// - عرض الصور فوق صفحة PDF
/// - تحريك الصور
/// - تغيير حجم الصور
/// - حذف الصور
/// - إدارة الصورة المعلقة قبل وضعها
///
/// لا تقوم هذه الوحدة بالحفظ النهائي للـPDF.
/// الحفظ يبقى مسؤولية Save Module.
class ImageModule {
  ImageModule({
    required this.pageSizes,
    required this.getCurrentPage,
    required this.getTransform,
    required this.onBeforeMutation,
    required this.onChanged,
    required this.onScheduleAutoSave,
  });

  /// أبعاد صفحات PDF بالنقاط.
  final Map<int, Size> pageSizes;

  /// الصفحة الحالية.
  final int Function() getCurrentPage;

  /// تحويل PDF → Viewer.
  final PdfPageTransform? Function(int pageNumber) getTransform;

  /// يستدعى قبل أول تعديل فعلي حتى يستطيع المحرر تسجيل Undo.
  final VoidCallback onBeforeMutation;

  /// يستدعى عند تغير حالة الصور.
  final VoidCallback onChanged;

  /// يستدعى بعد انتهاء العملية لجدولة AutoSave.
  final VoidCallback onScheduleAutoSave;

  final List<ImageAnnotation> images = <ImageAnnotation>[];

  Uint8List? pendingImageBytes;

  ImageAnnotation? draggingImage;

  bool _dragChanged = false;
  bool _mutationRecorded = false;

  // ---------------------------------------------------------------------------
  // اختيار الصورة
  // ---------------------------------------------------------------------------

  Future<void> pickImage() async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );

    if (picked == null) return;

    final bytes = await File(picked.path).readAsBytes();

    pendingImageBytes = bytes;

    onChanged();
  }

  // ---------------------------------------------------------------------------
  // إضافة الصورة إلى الصفحة
  // ---------------------------------------------------------------------------

  bool addPendingImage(Offset pagePosition) {
    final bytes = pendingImageBytes;
    if (bytes == null) return false;

    final pageNumber = getCurrentPage();
    final pageSize = pageSizes[pageNumber];

    if (pageSize == null) return false;

    const defaultWidth = 140.0;
    const defaultHeight = 100.0;

    _recordMutation();

    final maxX = (pageSize.width - defaultWidth)
        .clamp(0.0, pageSize.width)
        .toDouble();

    final maxY = (pageSize.height - defaultHeight)
        .clamp(0.0, pageSize.height)
        .toDouble();

    final annotation = ImageAnnotation(
      pageNumber: pageNumber,
      dx: pagePosition.dx.clamp(0.0, maxX).toDouble(),
      dy: pagePosition.dy.clamp(0.0, maxY).toDouble(),
      width: defaultWidth,
      height: defaultHeight,
      bytes: Uint8List.fromList(bytes),
    );

    images.add(annotation);

    pendingImageBytes = null;

    onChanged();
    onScheduleAutoSave();

    return true;
  }

  // ---------------------------------------------------------------------------
  // حالة إضافة الصورة
  // ---------------------------------------------------------------------------

  bool get isAddingImage => pendingImageBytes != null;

  void cancelPendingImage() {
    if (pendingImageBytes == null) return;

    pendingImageBytes = null;
    onChanged();
  }

  // ---------------------------------------------------------------------------
  // تحريك الصورة
  // ---------------------------------------------------------------------------

  void startDrag(ImageAnnotation image) {
    draggingImage = image;
    _dragChanged = false;
    _mutationRecorded = false;
  }

  void updateDrag(
    ImageAnnotation image,
    Offset viewerDelta,
  ) {
    final pageSize = pageSizes[image.pageNumber];

    final transform = getTransform(image.pageNumber);

    if (pageSize == null ||
        transform == null ||
        transform.scale <= 0) {
      return;
    }

    final pdfDelta = viewerDelta / transform.scale;

    if (pdfDelta.distanceSquared <= 0.0001) {
      return;
    }

    final nextX = (image.dx + pdfDelta.dx)
        .clamp(
          0.0,
          (pageSize.width - image.width)
              .clamp(0.0, pageSize.width),
        )
        .toDouble();

    final nextY = (image.dy + pdfDelta.dy)
        .clamp(
          0.0,
          (pageSize.height - image.height)
              .clamp(0.0, pageSize.height),
        )
        .toDouble();

    if ((nextX - image.dx).abs() < 0.001 &&
        (nextY - image.dy).abs() < 0.001) {
      return;
    }

    // نسجل Undo فقط عند أول حركة حقيقية.
    _recordMutation();

    image.dx = nextX;
    image.dy = nextY;

    _dragChanged = true;

    onChanged();
  }

  void finishDrag(ImageAnnotation image) {
    if (!identical(draggingImage, image)) return;

    final changed = _dragChanged;

    draggingImage = null;
    _dragChanged = false;
    _mutationRecorded = false;

    if (changed) {
      onScheduleAutoSave();
    }

    onChanged();
  }

  // ---------------------------------------------------------------------------
  // تغيير حجم الصورة
  // ---------------------------------------------------------------------------

  void resize(ImageAnnotation image, double factor) {
    final pageSize = pageSizes[image.pageNumber];

    if (pageSize == null) return;

    _recordMutation();

    image.width = (image.width * factor)
        .clamp(30.0, pageSize.width)
        .toDouble();

    image.height = (image.height * factor)
        .clamp(30.0, pageSize.height)
        .toDouble();

    _clampImagePosition(image, pageSize);

    onChanged();
    onScheduleAutoSave();
  }

  void _clampImagePosition(
    ImageAnnotation image,
    Size pageSize,
  ) {
    image.dx = image.dx
        .clamp(
          0.0,
          (pageSize.width - image.width)
              .clamp(0.0, pageSize.width),
        )
        .toDouble();

    image.dy = image.dy
        .clamp(
          0.0,
          (pageSize.height - image.height)
              .clamp(0.0, pageSize.height),
        )
        .toDouble();
  }

  // ---------------------------------------------------------------------------
  // حذف الصورة
  // ---------------------------------------------------------------------------

  void delete(ImageAnnotation image) {
    if (!images.contains(image)) return;

    _recordMutation();

    images.remove(image);

    onChanged();
    onScheduleAutoSave();
  }

  // ---------------------------------------------------------------------------
  // تسجيل تعديل واحد
  // ---------------------------------------------------------------------------

  void _recordMutation() {
    if (_mutationRecorded) return;

    onBeforeMutation();
    _mutationRecorded = true;
  }

  // ---------------------------------------------------------------------------
  // واجهة الصورة فوق PDF
  // ---------------------------------------------------------------------------

  Widget buildOverlay(
    BuildContext context,
    ImageAnnotation image,
  ) {
    final transform = getTransform(image.pageNumber);

    if (transform == null) {
      return const SizedBox.shrink();
    }

    final point = transform.pdfToViewer(
      Offset(image.dx, image.dy),
    );

    return Positioned(
      left: point.dx,
      top: point.dy,
      width: image.width * transform.scale,
      height: image.height * transform.scale,
      child: GestureDetector(
        onPanStart: (_) {
          startDrag(image);
        },
        onPanUpdate: (details) {
          updateDrag(
            image,
            details.delta,
          );
        },
        onPanEnd: (_) {
          finishDrag(image);
        },
        onPanCancel: () {
          finishDrag(image);
        },
        onTap: () {
          showActions(
            context,
            image,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.blue,
              width: 1,
            ),
          ),
          child: Image.memory(
            image.bytes,
            fit: BoxFit.fill,
            errorBuilder: (_, __, ___) {
              return const Center(
                child: Icon(
                  Icons.broken_image_rounded,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // قائمة عمليات الصورة
  // ---------------------------------------------------------------------------

  Future<void> showActions(
    BuildContext context,
    ImageAnnotation image,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.zoom_in_rounded,
                ),
                title: const Text(
                  'تكبير الصورة',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  resize(
                    image,
                    1.2,
                  );
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.zoom_out_rounded,
                ),
                title: const Text(
                  'تصغير الصورة',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  resize(
                    image,
                    0.8,
                  );
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                title: const Text(
                  'حذف الصورة',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  delete(image);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // نسخ الصورة
  // ---------------------------------------------------------------------------

  ImageAnnotation copy(ImageAnnotation image) {
    return image.copy();
  }

  // ---------------------------------------------------------------------------
  // تنظيف
  // ---------------------------------------------------------------------------

  void dispose() {
    images.clear();
    pendingImageBytes = null;
    draggingImage = null;
  }
}