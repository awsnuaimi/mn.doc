import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../services/arabic_font_loader.dart';
import '../theme/app_theme.dart';

const double _mmToPoints = 72 / 25.4;

class _EnvelopeLayout {
  final String code;
  final double widthMm;
  final double heightMm;

  final double senderXmm;
  final double senderYmm;
  final double senderWidthMm;

  final double recipientXmm;
  final double recipientYmm;
  final double recipientWidthMm;
  final double recipientHeightMm;

  const _EnvelopeLayout({
    required this.code,
    required this.widthMm,
    required this.heightMm,
    required this.senderXmm,
    required this.senderYmm,
    required this.senderWidthMm,
    required this.recipientXmm,
    required this.recipientYmm,
    required this.recipientWidthMm,
    required this.recipientHeightMm,
  });

  String get label =>
      '$code (${widthMm.toInt()}×${heightMm.toInt()} مم)';

  /// المقاس الفيزيائي الحقيقي للظرف.
  ///
  /// مثال DL:
  /// 220mm عرض × 110mm ارتفاع.
  PdfPageFormat get pageFormat {
    return PdfPageFormat(
      widthMm * _mmToPoints,
      heightMm * _mmToPoints,
      marginAll: 0,
    );
  }
}

/// ===============================================================
/// تخطيطات الأظرف.
///
/// جميع الأظرف معرفة هنا بالشكل الأفقي المطلوب:
///
/// width > height
///
/// وهذه البيانات هي مصدر الحقيقة الوحيد لكل من:
/// - المعاينة
/// - إنشاء PDF
/// - مهمة الطباعة
/// ===============================================================
const List<_EnvelopeLayout> _envelopeLayouts = [
  _EnvelopeLayout(
    code: 'DL',
    widthMm: 220,
    heightMm: 110,
    senderXmm: 12,
    senderYmm: 9,
    senderWidthMm: 82,
    recipientXmm: 92,
    recipientYmm: 42,
    recipientWidthMm: 112,
    recipientHeightMm: 45,
  ),
  _EnvelopeLayout(
    code: 'C6',
    widthMm: 162,
    heightMm: 114,
    senderXmm: 10,
    senderYmm: 9,
    senderWidthMm: 65,
    recipientXmm: 67,
    recipientYmm: 45,
    recipientWidthMm: 85,
    recipientHeightMm: 45,
  ),
  _EnvelopeLayout(
    code: 'C6/C5',
    widthMm: 229,
    heightMm: 114,
    senderXmm: 12,
    senderYmm: 9,
    senderWidthMm: 85,
    recipientXmm: 96,
    recipientYmm: 45,
    recipientWidthMm: 117,
    recipientHeightMm: 45,
  ),
  _EnvelopeLayout(
    code: 'C5',
    widthMm: 229,
    heightMm: 162,
    senderXmm: 14,
    senderYmm: 12,
    senderWidthMm: 90,
    recipientXmm: 96,
    recipientYmm: 69,
    recipientWidthMm: 117,
    recipientHeightMm: 52,
  ),
  _EnvelopeLayout(
    code: 'C4',
    widthMm: 324,
    heightMm: 229,
    senderXmm: 16,
    senderYmm: 14,
    senderWidthMm: 120,
    recipientXmm: 136,
    recipientYmm: 98,
    recipientWidthMm: 166,
    recipientHeightMm: 65,
  ),
];

class EnvelopeScreen extends StatefulWidget {
  const EnvelopeScreen({super.key});

  @override
  State<EnvelopeScreen> createState() => _EnvelopeScreenState();
}

class _EnvelopeScreenState extends State<EnvelopeScreen> {
  _EnvelopeLayout _layout = _envelopeLayouts.first;

  final TextEditingController _senderController =
      TextEditingController();

  final TextEditingController _recipientController =
      TextEditingController();

  bool _showSender = true;
  bool _printing = false;

  double _offsetXmm = 0;
  double _offsetYmm = 0;

  Timer? _previewDebounce;

  static final RegExp _rtlChars = RegExp(
    r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]',
  );

  @override
  void dispose() {
    _previewDebounce?.cancel();

    _senderController.dispose();
    _recipientController.dispose();

    super.dispose();
  }

  bool _isRtlText(String text) {
    return _rtlChars.hasMatch(text);
  }

  void _schedulePreview() {
    _previewDebounce?.cancel();

    _previewDebounce = Timer(
      const Duration(milliseconds: 220),
      () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  pw.Widget _addressText({
    required String text,
    required pw.Font font,
    required double fontSize,
  }) {
    final bool rtl = _isRtlText(text);

    return pw.Directionality(
      textDirection:
          rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Text(
        text,
        textAlign:
            rtl ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          font: font,
          fontSize: fontSize,
          lineSpacing: 1.5,
        ),
      ),
    );
  }

  /// =============================================================
  /// إنشاء PDF الظرف.
  ///
  /// نفس الدالة تستخدم للمعاينة والطباعة.
  ///
  /// لا نقوم هنا بتدوير الصفحة.
  /// المقاس نفسه محدد أصلًا أفقيًا:
  ///
  /// DL = 220 × 110 mm
  /// =============================================================
  Future<Uint8List> _buildPdf({
    _EnvelopeLayout? layoutOverride,
  }) async {
    final _EnvelopeLayout layout =
        layoutOverride ?? _layout;

    // Snapshot للقيم الحالية.
    final String sender =
        _senderController.text.trim();

    final String recipient =
        _recipientController.text.trim();

    final bool showSender = _showSender;

    final double offsetX = _offsetXmm;
    final double offsetY = _offsetYmm;

    final pw.Font arabicFont =
        await ArabicFontLoader.loadPwFont();

    final pw.Document doc = pw.Document();

    final PdfPageFormat pageFormat =
        layout.pageFormat;

    double mm(double value) {
      return value * _mmToPoints;
    }

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) {
          return pw.Stack(
            children: [
              // =====================================================
              // عنوان المرسل
              // =====================================================
              if (showSender && sender.isNotEmpty)
                pw.Positioned(
                  left: mm(
                    layout.senderXmm + offsetX,
                  ),
                  top: mm(
                    layout.senderYmm + offsetY,
                  ),
                  child: pw.SizedBox(
                    width: mm(
                      layout.senderWidthMm,
                    ),
                    child: _addressText(
                      text: sender,
                      font: arabicFont,
                      fontSize: 8.5,
                    ),
                  ),
                ),

              // =====================================================
              // عنوان المستلم
              // =====================================================
              if (recipient.isNotEmpty)
                pw.Positioned(
                  left: mm(
                    layout.recipientXmm + offsetX,
                  ),
                  top: mm(
                    layout.recipientYmm + offsetY,
                  ),
                  child: pw.SizedBox(
                    width: mm(
                      layout.recipientWidthMm,
                    ),
                    height: mm(
                      layout.recipientHeightMm,
                    ),
                    child: _addressText(
                      text: recipient,
                      font: arabicFont,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    final List<int> savedBytes =
        await doc.save();

    return Uint8List.fromList(savedBytes);
  }

  /// =============================================================
  /// طباعة الظرف.
  ///
  /// هنا التعديل المهم:
  ///
  /// 1. format = المقاس الحقيقي للظرف.
  /// 2. dynamicLayout = false
  /// 3. forceCustomPrintPaper = true
  ///
  /// الهدف هو عدم ترك مهمة الطباعة تبدأ بمقاس ورق عام ثم
  /// تحاول إعادة تفسير ملف الظرف.
  /// =============================================================
  Future<void> _print(
    String errorPrefix,
  ) async {
    if (_printing) {
      return;
    }

    if (_recipientController.text.trim().isEmpty) {
      return;
    }

    // Snapshot مهم حتى لا يتغير المقاس أثناء فتح نافذة الطباعة.
    final _EnvelopeLayout printLayout =
        _layout;

    final PdfPageFormat envelopeFormat =
        printLayout.pageFormat;

    setState(() {
      _printing = true;
    });

    try {
      await Printing.layoutPdf(
        name:
            'MN-Doc_Envelope_${printLayout.code}.pdf',

        // -----------------------------------------------------------
        // مهم جدًا:
        // نفرض على Print Job نفس المقاس الفيزيائي للظرف.
        // -----------------------------------------------------------
        format: envelopeFormat,

        // لا نسمح بإعادة بناء المستند وفق مقاس مختلف
        // ترسله نافذة الطباعة.
        dynamicLayout: false,

        // طلب استخدام المقاس المخصص للورقة.
        forceCustomPrintPaper: true,

        onLayout: (_) async {
          return _buildPdf(
            layoutOverride: printLayout,
          );
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$errorPrefix $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _printing = false;
        });
      }
    }
  }

  Widget _calibrationSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$label: ${value.toStringAsFixed(1)} mm',
          ),
        ),
        Expanded(
          flex: 2,
          child: Slider(
            value: value,
            min: -10,
            max: 10,
            divisions: 40,
            label:
                '${value.toStringAsFixed(1)} mm',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        context.watch<AppSettingsController>();

    final lang =
        settings.languageCode;

    String tr(String key) {
      return AppText.t(key, lang);
    }

    return Directionality(
      textDirection:
          settings.isRtl
              ? TextDirection.rtl
              : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            tr('tool_envelope_t'),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  8,
                ),
                children: [
                  // =================================================
                  // اختيار مقاس الظرف
                  // =================================================
                  DropdownButtonFormField<
                      _EnvelopeLayout>(
                    initialValue: _layout,
                    decoration:
                        InputDecoration(
                      labelText:
                          tr('env_size_label'),
                      border:
                          const OutlineInputBorder(),
                    ),
                    items: _envelopeLayouts
                        .map(
                          (s) =>
                              DropdownMenuItem<
                                  _EnvelopeLayout>(
                            value: s,
                            child:
                                Text(s.label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) {
                        return;
                      }

                      setState(() {
                        _layout = v;

                        // كل مقاس يبدأ بمعايرة صفرية.
                        _offsetXmm = 0;
                        _offsetYmm = 0;
                      });
                    },
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  // =================================================
                  // إظهار عنوان المرسل
                  // =================================================
                  SwitchListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    value: _showSender,
                    onChanged: (v) {
                      setState(() {
                        _showSender = v;
                      });
                    },
                    title: Text(
                      tr('env_show_sender'),
                    ),
                    activeThumbColor:
                        AppColors.primaryDark,
                  ),

                  // =================================================
                  // عنوان المرسل
                  // =================================================
                  if (_showSender)
                    TextField(
                      controller:
                          _senderController,
                      maxLines: 3,
                      textDirection:
                          _isRtlText(
                            _senderController
                                .text,
                          )
                              ? TextDirection
                                  .rtl
                              : TextDirection
                                  .ltr,
                      decoration:
                          InputDecoration(
                        labelText:
                            tr(
                          'env_sender_label',
                        ),
                        border:
                            const OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        _schedulePreview();
                      },
                    ),

                  const SizedBox(
                    height: 12,
                  ),

                  // =================================================
                  // عنوان المستلم
                  // =================================================
                  TextField(
                    controller:
                        _recipientController,
                    maxLines: 4,
                    textDirection:
                        _isRtlText(
                          _recipientController
                              .text,
                        )
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                    decoration:
                        InputDecoration(
                      labelText:
                          tr(
                        'env_recipient_label',
                      ),
                      border:
                          const OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      _schedulePreview();
                    },
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  // =================================================
                  // معايرة موضع الطباعة
                  // =================================================
                  ExpansionTile(
                    tilePadding:
                        EdgeInsets.zero,
                    title: Text(
                      tr('env_calibration'),
                    ),
                    subtitle: Text(
                      tr(
                        'env_calibration_note',
                      ),
                    ),
                    children: [
                      _calibrationSlider(
                        label:
                            tr('env_offset_x'),
                        value:
                            _offsetXmm,
                        onChanged: (v) {
                          setState(() {
                            _offsetXmm = v;
                          });
                        },
                      ),
                      _calibrationSlider(
                        label:
                            tr('env_offset_y'),
                        value:
                            _offsetYmm,
                        onChanged: (v) {
                          setState(() {
                            _offsetYmm = v;
                          });
                        },
                      ),
                      Align(
                        alignment:
                            AlignmentDirectional
                                .centerEnd,
                        child:
                            TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _offsetXmm = 0;
                              _offsetYmm = 0;
                            });
                          },
                          icon: const Icon(
                            Icons
                                .restart_alt_rounded,
                          ),
                          label: Text(
                            tr(
                              'env_reset_offsets',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    tr(
                      'env_preview_note',
                    ),
                    style:
                        Theme.of(context)
                            .textTheme
                            .bodySmall,
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  // =================================================
                  // المعاينة الحية
                  // =================================================
                  SizedBox(
                    height: 330,
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                      child: PdfPreview(
                        key: ValueKey(
                          '${_layout.code}|'
                          '$_showSender|'
                          '$_offsetXmm|'
                          '$_offsetYmm|'
                          '${_senderController.text}|'
                          '${_recipientController.text}',
                        ),

                        // نفس مولد PDF المستخدم في الطباعة.
                        build: (_) {
                          return _buildPdf(
                            layoutOverride:
                                _layout,
                          );
                        },

                        // المقاس الأولي للمعاينة مطابق تمامًا للظرف.
                        initialPageFormat:
                            _layout.pageFormat,

                        canDebug: false,
                        canChangeOrientation:
                            false,
                        canChangePageFormat:
                            false,
                        allowPrinting: false,
                        allowSharing: false,
                        useActions: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // =======================================================
            // زر الطباعة
            // =======================================================
            SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  16,
                ),
                child:
                    ElevatedButton.icon(
                  onPressed:
                      _printing ||
                              _recipientController
                                  .text
                                  .trim()
                                  .isEmpty
                          ? null
                          : () => _print(
                                tr(
                                  'error_prefix',
                                ),
                              ),
                  icon: _printing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.print_rounded,
                        ),
                  label: Text(
                    _printing
                        ? tr(
                            'env_preparing_print',
                          )
                        : tr(
                            'print_btn',
                          ),
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        AppColors.primaryDark,
                    minimumSize:
                        const Size(
                      double.infinity,
                      50,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}