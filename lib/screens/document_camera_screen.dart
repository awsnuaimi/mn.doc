import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../theme/app_theme.dart';

/// شاشة كاميرا مخصّصة لمسح المستندات — تعرض إطار إرشادي (خطوط زوايا)
/// فوق معاينة الكاميرا الحيّة لمساعدة المستخدم على محاذاة الورقة
/// بشكل صحيح قبل الالتقاط، زي تطبيقات المسح الضوئي الاحترافية.
class DocumentCameraScreen extends StatefulWidget {
  const DocumentCameraScreen({super.key});

  @override
  State<DocumentCameraScreen> createState() => _DocumentCameraScreenState();
}

class _DocumentCameraScreenState extends State<DocumentCameraScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _capturing = false;
  String? _error;

  String get _lang => Provider.of<AppSettingsController>(context, listen: false).languageCode;
  String tr(String key) => AppText.t(key, _lang);

  @override
  void initState() {
    super.initState();
    _initFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!mounted) return;
      if (!status.isGranted) {
        setState(() => _error = tr('cam_permission_needed'));
        return;
      }

      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() => _error = tr('cam_no_camera'));
        return;
      }
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(backCamera, ResolutionPreset.high, enableAudio: false);
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '${tr('cam_open_error')} $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await _controller!.takePicture();
      if (!mounted) return;
      Navigator.pop(context, file.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('cam_capture_error')} $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    return Directionality(
      textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(tr('cam_appbar')),
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              ),
            );
          }
          if (_controller == null || !_controller!.value.isInitialized) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(_controller!),
              // الإطار الإرشادي (خطوط الزوايا) لمحاذاة الورقة
              IgnorePointer(
                child: CustomPaint(
                  painter: _FrameGuidePainter(),
                  size: Size.infinite,
                ),
              ),
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: Text(tr('cam_align_hint'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ),
              ),
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _capturing ? null : _capture,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: _capturing
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Container(
                                width: 58,
                                height: 58,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}

/// يرسم إطارًا إرشاديًا بأربع زوايا (بدل مستطيل كامل) — شكل مألوف
/// بتطبيقات المسح الضوئي الاحترافية، يساعد بمحاذاة الورقة بدون حجب الرؤية.
class _FrameGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // إطار المستند: هامش 8% من الجوانب، و6% من الأعلى/الأسفل
    final left = size.width * 0.08;
    final right = size.width * 0.92;
    final top = size.height * 0.14;
    final bottom = size.height * 0.82;
    const cornerLen = 32.0;

    void drawCorner(Offset corner, Offset horizontal, Offset vertical) {
      canvas.drawLine(corner, horizontal, paint);
      canvas.drawLine(corner, vertical, paint);
    }

    // أعلى يسار
    drawCorner(
      Offset(left, top),
      Offset(left + cornerLen, top),
      Offset(left, top + cornerLen),
    );
    // أعلى يمين
    drawCorner(
      Offset(right, top),
      Offset(right - cornerLen, top),
      Offset(right, top + cornerLen),
    );
    // أسفل يسار
    drawCorner(
      Offset(left, bottom),
      Offset(left + cornerLen, bottom),
      Offset(left, bottom - cornerLen),
    );
    // أسفل يمين
    drawCorner(
      Offset(right, bottom),
      Offset(right - cornerLen, bottom),
      Offset(right, bottom - cornerLen),
    );

    // تظليل خفيف خارج منطقة المستند لتوضيح منطقة المسح
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.35);
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addRect(Rect.fromLTRB(left, top, right, bottom));
    final overlayPath = Path.combine(PathOperation.difference, fullPath, holePath);
    canvas.drawPath(overlayPath, overlayPaint);
  }

  @override
  bool shouldRepaint(covariant _FrameGuidePainter oldDelegate) => false;
}
