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
  final double senderHeightMm;

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
    required this.senderHeightMm,
    required this.recipientXmm,
    required this.recipientYmm,
    required this.recipientWidthMm,
    required this.recipientHeightMm,
  });

  String get label =>
      '$code (${widthMm.toInt()}×${heightMm.toInt()} مم)';

  PdfPageFormat get pageFormat {
    return PdfPageFormat(
      widthMm * _mmToPoints,
      heightMm * _mmToPoints,
      marginAll: 0,
    );
  }
}

/// جميع المقاسات معرفة بوضع أفقي.
///
/// القيم الافتراضية موضوعة داخل منطقة آمنة نسبيًا بعيدًا عن حواف الظرف.
/// يمكن بعد ذلك معايرة كل عنوان بصورة مستقلة.
const List<_EnvelopeLayout> _envelopeLayouts = [
  _EnvelopeLayout(
    code: 'DL',
    widthMm: 220,
    heightMm: 110,

    // المرسل: أعلى اليسار لكن بعيد عن حافة الطابعة.
    senderXmm: 20,
    senderYmm: 16,
    senderWidthMm: 78,
    senderHeightMm: 24,

    // المستلم: يمين/أسفل الوسط.
    recipientXmm: 105,
    recipientYmm: 53,
    recipientWidthMm: 95,
    recipientHeightMm: 38,
  ),
  _EnvelopeLayout(
    code: 'C6',
    widthMm: 162,
    heightMm: 114,
    senderXmm: 16,
    senderYmm: 16,
    senderWidthMm: 62,
    senderHeightMm: 24,
    recipientXmm: 72,
    recipientYmm: 55,
    recipientWidthMm: 76,
    recipientHeightMm: 38,
  ),
  _EnvelopeLayout(
    code: 'C6/C5',
    widthMm: 229,
    heightMm: 114,
    senderXmm: 20,
    senderYmm: 16,
    senderWidthMm: 82,
    senderHeightMm: 24,
    recipientXmm: 108,
    recipientYmm: 55,
    recipientWidthMm: 100,
    recipientHeightMm: 38,
  ),
  _EnvelopeLayout(
    code: 'C5',
    widthMm: 229,
    heightMm: 162,
    senderXmm: 20,
    senderYmm: 18,
    senderWidthMm: 85,
    senderHeightMm: 28,
    recipientXmm: 108,
    recipientYmm: 78,
    recipientWidthMm: 100,
    recipientHeightMm: 46,
  ),
  _EnvelopeLayout(
    code: 'C4',
    widthMm: 324,
    heightMm: 229,
    senderXmm: 24,
    senderYmm: 22,
    senderWidthMm: 115,
    senderHeightMm: 32,
    recipientXmm: 150,
    recipientYmm: 112,
    recipientWidthMm: 145,
    recipientHeightMm: 58,
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

  // ================================================================
  // معايرة مستقلة لكل عنوان.
  // ================================================================

  double _senderOffsetXmm = 0;
  double _senderOffsetYmm = 0;

  double _recipientOffsetXmm = 0;
  double _recipientOffsetYmm = 0;

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

  void _resetCalibration() {
    setState(() {
      _senderOffsetXmm = 0;
      _senderOffsetYmm = 0;

      _recipientOffsetXmm = 0;
      _recipientOffsetYmm = 0;
    });
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

  /// ===============================================================
  /// PDF النهائي.
  ///
  /// مهم:
  /// لا نرسم أي حدود أو علامات معايرة هنا.
  /// هذا الملف هو الذي يذهب فعليًا إلى الطابعة.
  /// ===============================================================
  Future<Uint8List> _buildPdf({
    _EnvelopeLayout? layoutOverride,
  }) async {
    final _EnvelopeLayout layout =
        layoutOverride ?? _layout;

    // Snapshot.
    final String sender =
        _senderController.text.trim();

    final String recipient =
        _recipientController.text.trim();

    final bool showSender = _showSender;

    final double senderOffsetX =
        _senderOffsetXmm;

    final double senderOffsetY =
        _senderOffsetYmm;

    final double recipientOffsetX =
        _recipientOffsetXmm;

    final double recipientOffsetY =
        _recipientOffsetYmm;

    final pw.Font arabicFont =
        await ArabicFontLoader.loadPwFont();

    final pw.Document doc =
        pw.Document();

    double mm(double value) {
      return value * _mmToPoints;
    }

    doc.addPage(
      pw.Page(
        pageFormat: layout.pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) {
          return pw.Stack(
            children: [
              // =====================================================
              // المرسل
              // =====================================================
              if (showSender && sender.isNotEmpty)
                pw.Positioned(
                  left: mm(
                    layout.senderXmm +
                        senderOffsetX,
                  ),
                  top: mm(
                    layout.senderYmm +
                        senderOffsetY,
                  ),
                  child: pw.SizedBox(
                    width:
                        mm(layout.senderWidthMm),
                    height:
                        mm(layout.senderHeightMm),
                    child: _addressText(
                      text: sender,
                      font: arabicFont,
                      fontSize: 8.5,
                    ),
                  ),
                ),

              // =====================================================
              // المستلم
              // =====================================================
              if (recipient.isNotEmpty)
                pw.Positioned(
                  left: mm(
                    layout.recipientXmm +
                        recipientOffsetX,
                  ),
                  top: mm(
                    layout.recipientYmm +
                        recipientOffsetY,
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

    return Uint8List.fromList(
      savedBytes,
    );
  }

  /// ===============================================================
  /// الطباعة.
  ///
  /// هذا الجزء يحافظ على الإصلاح الذي جعل الظرف يطبع أفقيًا.
  /// ===============================================================
  Future<void> _print(
    String errorPrefix,
  ) async {
    if (_printing) {
      return;
    }

    if (_recipientController.text
        .trim()
        .isEmpty) {
      return;
    }

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

        format: envelopeFormat,

        // مهم:
        // هذان الخياران هما اللذان نحافظ عليهما
        // لأنهما نجحا في تثبيت الطباعة العرضية.
        dynamicLayout: false,
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

      ScaffoldMessenger.of(context)
          .showSnackBar(
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

  /// Slider بدقة نصف ميليمتر.
  Widget _positionSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${value >= 0 ? '+' : ''}'
          '${value.toStringAsFixed(1)} mm',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Slider(
          value: value,
          min: -30,
          max: 30,

          // 60mm / 0.5mm = 120 خطوة.
          divisions: 120,

          label:
              '${value.toStringAsFixed(1)} mm',

          onChanged: onChanged,
        ),
      ],
    );
  }

  /// ===============================================================
  /// معاينة هندسية خاصة بالتطبيق.
  ///
  /// هذه ليست PDF المطبوعة.
  ///
  /// الحدود الملونة هنا إرشادية فقط ولا تصل إلى الطابعة.
  /// ===============================================================
  Widget _buildEnvelopeGuidePreview() {
    final layout = _layout;

    final senderX =
        layout.senderXmm +
            _senderOffsetXmm;

    final senderY =
        layout.senderYmm +
            _senderOffsetYmm;

    final recipientX =
        layout.recipientXmm +
            _recipientOffsetXmm;

    final recipientY =
        layout.recipientYmm +
            _recipientOffsetYmm;

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final double availableWidth =
            constraints.maxWidth;

        final double scale =
            availableWidth /
                layout.widthMm;

        final double previewHeight =
            layout.heightMm * scale;

        double px(double mm) {
          return mm * scale;
        }

        return Center(
          child: SizedBox(
            width: availableWidth,
            height: previewHeight,
            child: Stack(
              children: [
                // الظرف.
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.black26,
                      ),
                    ),
                  ),
                ),

                // منطقة آمنة تقريبية.
                Positioned(
                  left: px(8),
                  top: px(8),
                  right: px(8),
                  bottom: px(8),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                            Colors.grey.shade300,
                      ),
                    ),
                  ),
                ),

                // ---------------------------------------------------
                // المرسل.
                // ---------------------------------------------------
                if (_showSender)
                  Positioned(
                    left: px(senderX),
                    top: px(senderY),
                    width: px(
                      layout.senderWidthMm,
                    ),
                    height: px(
                      layout.senderHeightMm,
                    ),
                    child: Container(
                      padding:
                          const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue
                            .withOpacity(0.04),
                        border: Border.all(
                          color: Colors.blue
                              .withOpacity(0.65),
                        ),
                      ),
                      child: Align(
                        alignment:
                            _isRtlText(
                              _senderController
                                  .text,
                            )
                                ? Alignment
                                    .topRight
                                : Alignment
                                    .topLeft,
                        child: Text(
                          _senderController
                                  .text
                                  .trim()
                                  .isEmpty
                              ? 'Sender'
                              : _senderController
                                  .text
                                  .trim(),
                          textDirection:
                              _isRtlText(
                                _senderController
                                    .text,
                              )
                                  ? TextDirection
                                      .rtl
                                  : TextDirection
                                      .ltr,
                          overflow:
                              TextOverflow.clip,
                          style:
                              const TextStyle(
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                  ),

                // ---------------------------------------------------
                // المستلم.
                // ---------------------------------------------------
                Positioned(
                  left: px(recipientX),
                  top: px(recipientY),
                  width: px(
                    layout.recipientWidthMm,
                  ),
                  height: px(
                    layout.recipientHeightMm,
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.green
                          .withOpacity(0.04),
                      border: Border.all(
                        color: Colors.green
                            .withOpacity(0.70),
                      ),
                    ),
                    child: Align(
                      alignment:
                          _isRtlText(
                            _recipientController
                                .text,
                          )
                              ? Alignment.topRight
                              : Alignment.topLeft,
                      child: Text(
                        _recipientController
                                .text
                                .trim()
                                .isEmpty
                            ? 'Recipient'
                            : _recipientController
                                .text
                                .trim(),
                        textDirection:
                            _isRtlText(
                              _recipientController
                                  .text,
                            )
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                        overflow:
                            TextOverflow.clip,
                        style:
                            const TextStyle(
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        context.watch<AppSettingsController>();

    final lang =
        settings.languageCode;

    String tr(String key) {
      return AppText.t(
        key,
        lang,
      );
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
                  // المقاس.
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
                          (layout) =>
                              DropdownMenuItem<
                                  _EnvelopeLayout>(
                            value: layout,
                            child: Text(
                              layout.label,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _layout = value;

                        // كل مقاس له نقطة بداية مستقلة.
                        _senderOffsetXmm = 0;
                        _senderOffsetYmm = 0;

                        _recipientOffsetXmm =
                            0;
                        _recipientOffsetYmm =
                            0;
                      });
                    },
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  SwitchListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    value: _showSender,
                    onChanged: (value) {
                      setState(() {
                        _showSender = value;
                      });
                    },
                    title: Text(
                      tr('env_show_sender'),
                    ),
                    activeThumbColor:
                        AppColors.primaryDark,
                  ),

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
                    height: 16,
                  ),

                  // =================================================
                  // معاينة هندسية.
                  // =================================================
                  Text(
                    'معاينة موضع العناوين',
                    style:
                        Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  _buildEnvelopeGuidePreview(),

                  const SizedBox(
                    height: 16,
                  ),

                  // =================================================
                  // معايرة المرسل.
                  // =================================================
                  if (_showSender)
                    ExpansionTile(
                      tilePadding:
                          EdgeInsets.zero,
                      initiallyExpanded: false,
                      leading: const Icon(
                        Icons
                            .person_outline_rounded,
                      ),
                      title: const Text(
                        'موضع المرسل',
                      ),
                      subtitle: const Text(
                        'تحريك عنوان المرسل بشكل مستقل',
                      ),
                      children: [
                        _positionSlider(
                          label:
                              'أفقي X',
                          value:
                              _senderOffsetXmm,
                          onChanged: (value) {
                            setState(() {
                              _senderOffsetXmm =
                                  value;
                            });
                          },
                        ),
                        _positionSlider(
                          label:
                              'عمودي Y',
                          value:
                              _senderOffsetYmm,
                          onChanged: (value) {
                            setState(() {
                              _senderOffsetYmm =
                                  value;
                            });
                          },
                        ),
                      ],
                    ),

                  // =================================================
                  // معايرة المستلم.
                  // =================================================
                  ExpansionTile(
                    tilePadding:
                        EdgeInsets.zero,
                    initiallyExpanded: false,
                    leading: const Icon(
                      Icons
                          .location_on_outlined,
                    ),
                    title: const Text(
                      'موضع المستلم',
                    ),
                    subtitle: const Text(
                      'تحريك عنوان المستلم بشكل مستقل',
                    ),
                    children: [
                      _positionSlider(
                        label:
                            'أفقي X',
                        value:
                            _recipientOffsetXmm,
                        onChanged: (value) {
                          setState(() {
                            _recipientOffsetXmm =
                                value;
                          });
                        },
                      ),
                      _positionSlider(
                        label:
                            'عمودي Y',
                        value:
                            _recipientOffsetYmm,
                        onChanged: (value) {
                          setState(() {
                            _recipientOffsetYmm =
                                value;
                          });
                        },
                      ),
                    ],
                  ),

                  Align(
                    alignment:
                        AlignmentDirectional
                            .centerEnd,
                    child: TextButton.icon(
                      onPressed:
                          _resetCalibration,
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

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    tr('env_preview_note'),
                    style:
                        Theme.of(context)
                            .textTheme
                            .bodySmall,
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  // =================================================
                  // المعاينة الحقيقية للـPDF.
                  //
                  // لا تحتوي الحدود الإرشادية الموجودة أعلاه.
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
                          '$_senderOffsetXmm|'
                          '$_senderOffsetYmm|'
                          '$_recipientOffsetXmm|'
                          '$_recipientOffsetYmm|'
                          '${_senderController.text}|'
                          '${_recipientController.text}',
                        ),
                        build: (_) {
                          return _buildPdf(
                            layoutOverride:
                                _layout,
                          );
                        },
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