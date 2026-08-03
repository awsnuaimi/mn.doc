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
const double _carrierWidthMm = 297.0;
const double _carrierHeightMm = 210.0;

class _EnvelopeLayout {
  final String code;
  final double widthMm, heightMm;
  final double senderXmm, senderYmm, senderWidthMm, senderHeightMm;
  final double recipientXmm, recipientYmm, recipientWidthMm, recipientHeightMm;

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

  String get label => '$code (${widthMm.toInt()}×${heightMm.toInt()} مم)';
}

const _envelopeLayouts = <_EnvelopeLayout>[
  _EnvelopeLayout(code:'DL', widthMm:220, heightMm:110, senderXmm:12, senderYmm:10, senderWidthMm:82, senderHeightMm:27, recipientXmm:105, recipientYmm:46, recipientWidthMm:100, recipientHeightMm:43),
  _EnvelopeLayout(code:'C6', widthMm:162, heightMm:114, senderXmm:10, senderYmm:10, senderWidthMm:64, senderHeightMm:28, recipientXmm:70, recipientYmm:48, recipientWidthMm:80, recipientHeightMm:44),
  _EnvelopeLayout(code:'C6/C5', widthMm:229, heightMm:114, senderXmm:12, senderYmm:10, senderWidthMm:86, senderHeightMm:28, recipientXmm:108, recipientYmm:48, recipientWidthMm:105, recipientHeightMm:44),
  _EnvelopeLayout(code:'C5', widthMm:229, heightMm:162, senderXmm:14, senderYmm:12, senderWidthMm:90, senderHeightMm:32, recipientXmm:108, recipientYmm:73, recipientWidthMm:105, recipientHeightMm:50),
  _EnvelopeLayout(code:'C4', widthMm:324, heightMm:229, senderXmm:16, senderYmm:14, senderWidthMm:120, senderHeightMm:38, recipientXmm:150, recipientYmm:105, recipientWidthMm:155, recipientHeightMm:62),
];

class EnvelopeScreen extends StatefulWidget {
  const EnvelopeScreen({super.key});
  @override
  State<EnvelopeScreen> createState() => _EnvelopeScreenState();
}

class _EnvelopeScreenState extends State<EnvelopeScreen> {
  _EnvelopeLayout _layout = _envelopeLayouts.first;
  final _senderController = TextEditingController();
  final _recipientController = TextEditingController();

  bool _showSender = true, _printing = false, _showGuides = false;
  double _senderDx = 0, _senderDy = 0, _recipientDx = 0, _recipientDy = 0;
  double _printerDx = 0, _printerDy = 0;
  double? _carrierXmm;
  double? _carrierYmm;
  double _senderFont = 7.0, _recipientFont = 9.5;
  Timer? _debounce;

  static final _rtl = RegExp(r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]');

  @override
  void dispose() {
    _debounce?.cancel();
    _senderController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  bool _isRtl(String s) => _rtl.hasMatch(s);

  void _refresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() {});
    });
  }

  double get _carrierX => _carrierXmm ?? ((_carrierWidthMm - _layout.widthMm) / 2.0);
  double get _carrierY => _carrierYmm ?? ((_carrierHeightMm - _layout.heightMm) / 2.0);
  double _maxCarrierX() => (_carrierWidthMm - _layout.widthMm).clamp(0.0, _carrierWidthMm).toDouble();
  double _maxCarrierY() => (_carrierHeightMm - _layout.heightMm).clamp(0.0, _carrierHeightMm).toDouble();

  pw.Widget _pdfText(String text, pw.Font font, double size) {
    final rtl = _isRtl(text);
    return pw.Directionality(
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Text(
        text,
        textAlign: rtl ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(font: font, fontSize: size, lineSpacing: 1.5),
      ),
    );
  }

  Future<Uint8List> _buildPdf() async {
    final l = _layout;
    final sender = _senderController.text.trim();
    final recipient = _recipientController.text.trim();
    final font = await ArabicFontLoader.loadPwFont();
    final doc = pw.Document();
    double mm(double v) => v * _mmToPoints;

    final format = PdfPageFormat(mm(_carrierWidthMm), mm(_carrierHeightMm), marginAll: 0);

    doc.addPage(pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Stack(children: [
        if (_showGuides)
          pw.Positioned(
            left:mm(_carrierX + 3), top:mm(_carrierY + 3),
            child:pw.Container(
              width:mm(l.widthMm-6), height:mm(l.heightMm-6),
              decoration:pw.BoxDecoration(border:pw.Border.all(width:.5)),
            ),
          ),
        if (_showSender && sender.isNotEmpty)
          pw.Positioned(
            left:mm(_carrierX + l.senderXmm + _senderDx + _printerDx),
            top:mm(_carrierY + l.senderYmm + _senderDy + _printerDy),
            child:pw.Container(
              width:mm(l.senderWidthMm), height:mm(l.senderHeightMm),
              decoration:_showGuides ? pw.BoxDecoration(border:pw.Border.all(width:.35)) : null,
              child:_pdfText(sender,font,_senderFont),
            ),
          ),
        if (recipient.isNotEmpty)
          pw.Positioned(
            left:mm(_carrierX + l.recipientXmm + _recipientDx + _printerDx),
            top:mm(_carrierY + l.recipientYmm + _recipientDy + _printerDy),
            child:pw.Container(
              width:mm(l.recipientWidthMm), height:mm(l.recipientHeightMm),
              decoration:_showGuides ? pw.BoxDecoration(border:pw.Border.all(width:.35)) : null,
              child:_pdfText(recipient,font,_recipientFont),
            ),
          ),
      ]),
    ));

    return Uint8List.fromList(await doc.save());
  }

  Future<void> _print(String errorPrefix) async {
    if (_printing || _recipientController.text.trim().isEmpty) return;
    setState(() => _printing = true);
    try {
      final bytes = await _buildPdf();
      if (!mounted) return;
      final format = PdfPageFormat(
        _carrierWidthMm * _mmToPoints,
        _carrierHeightMm * _mmToPoints,
        marginAll: 0,
      );
      await Printing.layoutPdf(
        name:'MN-Doc_Envelope_${_layout.code}.pdf',
        format:format,
        dynamicLayout:false,
        forceCustomPrintPaper:true,
        onLayout:(_) async => bytes,
      );
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text('$errorPrefix $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Widget _slider(String label, double value, double min, double max, int divisions,
      ValueChanged<double> changed, {String suffix=''}) {
    return Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
      Text('$label: ${value.toStringAsFixed(1)}$suffix'),
      Slider(
        value:value.clamp(min,max),
        min:min, max:max, divisions:divisions,
        label:'${value.toStringAsFixed(1)}$suffix',
        onChanged:changed,
      ),
    ]);
  }

  Widget _dragPreview() {
    final l = _layout;
    return LayoutBuilder(builder:(context,c) {
      final sx = c.maxWidth / l.widthMm;
      final sy = c.maxHeight / l.heightMm;
      final scale = sx < sy ? sx : sy;

      Widget box(bool sender, String text, double x, double y, double w, double h) {
        if (text.trim().isEmpty) return const SizedBox.shrink();
        final rtl = _isRtl(text);
        return Positioned(
          left:x*scale, top:y*scale, width:w*scale, height:h*scale,
          child:GestureDetector(
            behavior:HitTestBehavior.opaque,
            onPanUpdate:(d) {
              setState(() {
                if (sender) {
                  _senderDx += d.delta.dx/scale;
                  _senderDy += d.delta.dy/scale;
                } else {
                  _recipientDx += d.delta.dx/scale;
                  _recipientDy += d.delta.dy/scale;
                }
              });
            },
            child:Container(
              padding:const EdgeInsets.all(3),
              decoration:BoxDecoration(
                border:Border.all(
                  color:sender
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.primary,
                  width:1.3,
                ),
                borderRadius:BorderRadius.circular(4),
              ),
              child:Align(
                alignment:rtl ? Alignment.topRight : Alignment.topLeft,
                child:Text(
                  text,
                  textDirection:rtl ? TextDirection.rtl : TextDirection.ltr,
                  textAlign:rtl ? TextAlign.right : TextAlign.left,
                  overflow:TextOverflow.clip,
                  style:TextStyle(
                    color:Colors.black,
                    fontSize:sender ? 10 : 12,
                    height:1.15,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      return Center(child:Container(
        width:l.widthMm*scale,
        height:l.heightMm*scale,
        decoration:BoxDecoration(
          color:Colors.white,
          border:Border.all(color:Colors.black54),
          boxShadow:const [BoxShadow(blurRadius:6, offset:Offset(0,2), color:Color(0x33000000))],
        ),
        child:Stack(clipBehavior:Clip.hardEdge, children:[
          if (_showSender)
            box(true,_senderController.text,l.senderXmm+_senderDx,l.senderYmm+_senderDy,l.senderWidthMm,l.senderHeightMm),
          box(false,_recipientController.text,l.recipientXmm+_recipientDx,l.recipientYmm+_recipientDy,l.recipientWidthMm,l.recipientHeightMm),
        ]),
      ));
    });
  }

  void _reset() {
    setState(() {
      _senderDx=0; _senderDy=0; _recipientDx=0; _recipientDy=0;
      _printerDx=0; _printerDy=0;
      _carrierXmm=null; _carrierYmm=null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings=context.watch<AppSettingsController>();
    final lang=settings.languageCode;
    String tr(String key)=>AppText.t(key,lang);

    return Directionality(
      textDirection:settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child:Scaffold(
        appBar:AppBar(title:Text(tr('tool_envelope_t'))),
        body:Column(children:[
          Expanded(child:ListView(
            padding:const EdgeInsets.fromLTRB(16,16,16,8),
            children:[
              DropdownButtonFormField<_EnvelopeLayout>(
                initialValue:_layout,
                decoration:InputDecoration(labelText:tr('env_size_label'),border:const OutlineInputBorder()),
                items:_envelopeLayouts.map((s)=>DropdownMenuItem(value:s,child:Text(s.label))).toList(),
                onChanged:(v) {
                  if(v!=null) setState(() {
                    _layout=v;
                    _carrierXmm=null; _carrierYmm=null;
                    _senderDx=0; _senderDy=0; _recipientDx=0; _recipientDy=0;
                  });
                },
              ),
              const SizedBox(height:10),
              SwitchListTile(
                contentPadding:EdgeInsets.zero,
                value:_showSender,
                onChanged:(v)=>setState(()=>_showSender=v),
                title:Text(tr('env_show_sender')),
                activeThumbColor:AppColors.primaryDark,
              ),
              if(_showSender) TextField(
                controller:_senderController,maxLines:3,
                textDirection:_isRtl(_senderController.text)?TextDirection.rtl:TextDirection.ltr,
                decoration:InputDecoration(labelText:tr('env_sender_label'),border:const OutlineInputBorder()),
                onChanged:(_)=>_refresh(),
              ),
              const SizedBox(height:12),
              TextField(
                controller:_recipientController,maxLines:4,
                textDirection:_isRtl(_recipientController.text)?TextDirection.rtl:TextDirection.ltr,
                decoration:InputDecoration(labelText:tr('env_recipient_label'),border:const OutlineInputBorder()),
                onChanged:(_)=>_refresh(),
              ),
              const SizedBox(height:14),
              const Text('المعاينة المباشرة — اسحب صندوق المرسل أو المستلم بإصبعك إلى المكان المطلوب.'),
              const SizedBox(height:8),
              SizedBox(height:260,child:_dragPreview()),
              const SizedBox(height:10),
              ExpansionTile(
                tilePadding:EdgeInsets.zero,
                title:const Text('حجم الخط والموضع الدقيق'),
                children:[
                  if(_showSender) _slider('حجم خط المرسل',_senderFont,5,12,28,(v)=>setState(()=>_senderFont=v),suffix:' pt'),
                  _slider('حجم خط المستلم',_recipientFont,6,16,40,(v)=>setState(()=>_recipientFont=v),suffix:' pt'),
                  if(_showSender) ...[
                    _slider('المرسل أفقيًا',_senderDx,-40,40,160,(v)=>setState(()=>_senderDx=v),suffix:' mm'),
                    _slider('المرسل عموديًا',_senderDy,-30,30,120,(v)=>setState(()=>_senderDy=v),suffix:' mm'),
                  ],
                  _slider('المستلم أفقيًا',_recipientDx,-60,60,240,(v)=>setState(()=>_recipientDx=v),suffix:' mm'),
                  _slider('المستلم عموديًا',_recipientDy,-40,40,160,(v)=>setState(()=>_recipientDy=v),suffix:' mm'),
                ],
              ),
              ExpansionTile(
                tilePadding:EdgeInsets.zero,
                title:Text(tr('env_calibration')),
                subtitle:Text(tr('env_calibration_note')),
                children:[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('وضع الظرف داخل A4: حرّك X و Y حتى يطابق مكان الظرف الفعلي في درج Brother.'),
                  ),
                  _slider('الظرف أفقيًا داخل A4',_carrierX,0,_maxCarrierX(),(_maxCarrierX()*2).round().clamp(1,600),(v)=>setState(()=>_carrierXmm=v),suffix:' mm'),
                  _slider('الظرف عموديًا داخل A4',_carrierY,0,_maxCarrierY(),(_maxCarrierY()*2).round().clamp(1,500),(v)=>setState(()=>_carrierYmm=v),suffix:' mm'),
                  _slider(tr('env_offset_x'),_printerDx,-15,15,60,(v)=>setState(()=>_printerDx=v),suffix:' mm'),
                  _slider(tr('env_offset_y'),_printerDy,-15,15,60,(v)=>setState(()=>_printerDy=v),suffix:' mm'),
                  SwitchListTile(
                    contentPadding:EdgeInsets.zero,
                    value:_showGuides,
                    onChanged:(v)=>setState(()=>_showGuides=v),
                    title:const Text('طباعة حدود اختبارية'),
                    subtitle:const Text('فعّلها مؤقتًا لفحص حدود الطباعة الفعلية، ثم عطّلها قبل الطباعة النهائية.'),
                  ),
                  Align(
                    alignment:AlignmentDirectional.centerEnd,
                    child:TextButton.icon(
                      onPressed:_reset,
                      icon:const Icon(Icons.restart_alt_rounded),
                      label:Text(tr('env_reset_offsets')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height:8),
              Text(tr('env_preview_note'),style:Theme.of(context).textTheme.bodySmall),
              const SizedBox(height:8),
              SizedBox(
                height:300,
                child:ClipRRect(
                  borderRadius:BorderRadius.circular(12),
                  child:PdfPreview(
                    key:ValueKey('${_layout.code}|$_showSender|$_carrierX|$_carrierY|$_senderDx|$_senderDy|$_recipientDx|$_recipientDy|$_printerDx|$_printerDy|$_senderFont|$_recipientFont|$_showGuides|${_senderController.text}|${_recipientController.text}'),
                    build:(_)=>_buildPdf(),
                    canDebug:false,
                    canChangeOrientation:false,
                    canChangePageFormat:false,
                    allowPrinting:false,
                    allowSharing:false,
                    useActions:false,
                  ),
                ),
              ),
            ],
          )),
          SafeArea(
            top:false,
            child:Padding(
              padding:const EdgeInsets.fromLTRB(16,8,16,16),
              child:ElevatedButton.icon(
                onPressed:_printing||_recipientController.text.trim().isEmpty?null:()=>_print(tr('error_prefix')),
                icon:_printing
                    ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2))
                    : const Icon(Icons.print_rounded),
                label:Text(_printing?tr('env_preparing_print'):tr('print_btn')),
                style:ElevatedButton.styleFrom(
                  backgroundColor:AppColors.primaryDark,
                  minimumSize:const Size(double.infinity,50),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
