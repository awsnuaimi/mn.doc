part of '../../pdf_editor_screen.dart';

/// اكتشاف حقول النماذج (Form Fields) داخل المستند عند تحميله، وإشعار
/// المستخدم بعددها. نُقل من pdf_editor_screen.dart لتقليل حجمها.
mixin FormModule on State<PdfEditorScreen> {
  bool _hasFormFields = false;

  void _handleFormFieldsDetected(int count) {
    if (count == 0) return;
    setState(() => _hasFormFields = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lang = Provider.of<AppSettingsController>(context, listen: false).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppText.t('ed_form_fields_detected', lang)} ($count)'),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }
}
