/// قاموس ترجمة صغير يدوي (بدون مكتبات إضافية) — يغطي حاليًا
/// الشاشة الرئيسية وشاشة الإعدادات فقط. باقي شاشات التطبيق تبقى
/// بالعربية حتى تتم ترجمتها بمرحلة قادمة منفصلة.
class AppText {
  static const Map<String, Map<String, String>> _dict = {
    'app_name': {'ar': 'MN-Doc', 'en': 'MN-Doc'},
    'app_tagline': {'ar': 'محرر المستندات وأدوات PDF الذكية', 'en': 'Smart document editor & PDF tools'},
    'documents_section': {'ar': 'أدوات المستندات', 'en': 'Document Tools'},
    'ai_section': {'ar': 'الذكاء الاصطناعي', 'en': 'AI Features'},
    'recent_files': {'ar': 'الملفات الأخيرة', 'en': 'Recent Files'},
    'no_files_yet': {'ar': 'لا توجد ملفات بعد.\nاضغط "فتح ملف" للبدء.', 'en': 'No files yet.\nTap "Open File" to start.'},
    'open_file': {'ar': 'فتح ملف', 'en': 'Open File'},
    'edit_pdf': {'ar': 'تحرير PDF', 'en': 'Edit PDF'},
    'pdf_tools': {'ar': 'أدوات PDF (دمج/ترتيب/توقيع)', 'en': 'PDF Tools (Merge/Reorder/Sign)'},
    'ocr': {'ar': 'التعرف الضوئي (OCR)', 'en': 'Text Recognition (OCR)'},
    'scanner': {'ar': 'مسح ضوئي للمستندات (Scanner)', 'en': 'Document Scanner'},
    'create_document': {'ar': 'إنشاء مستند جديد', 'en': 'Create New Document'},
    'translate': {'ar': 'ترجمة (مجانية)', 'en': 'Translate (Free)'},
    'summarize': {'ar': 'تلخيص مستند', 'en': 'Summarize Document'},
    'ai_chat': {'ar': 'مساعد ذكي للدردشة', 'en': 'AI Chat Assistant'},
    'ai_settings': {'ar': 'إعدادات الذكاء الاصطناعي', 'en': 'AI Settings'},
    'settings': {'ar': 'الإعدادات', 'en': 'Settings'},
    'about_app': {'ar': 'حول التطبيق', 'en': 'About App'},
    'profile': {'ar': 'الملف الشخصي', 'en': 'Profile'},
    'display_name': {'ar': 'اسمك', 'en': 'Your name'},
    'display_name_hint': {'ar': 'اكتب اسمك (يُحفظ على جهازك فقط)', 'en': 'Enter your name (saved on this device only)'},
    'welcome': {'ar': 'مرحبًا', 'en': 'Welcome'},
    'appearance': {'ar': 'المظهر', 'en': 'Appearance'},
    'theme_light': {'ar': 'فاتح', 'en': 'Light'},
    'theme_dark': {'ar': 'ليلي', 'en': 'Dark'},
    'theme_system': {'ar': 'تلقائي (حسب الجهاز)', 'en': 'System default'},
    'language': {'ar': 'اللغة', 'en': 'Language'},
    'language_note': {
      'ar': 'ملاحظة: الترجمة حاليًا مفعّلة بالشاشة الرئيسية وهذه الشاشة فقط. باقي شاشات التطبيق ستُترجم بمرحلة قادمة.',
      'en': 'Note: translation currently applies to the Home and Settings screens only. Other screens will be translated in a future update.',
    },
    'save': {'ar': 'حفظ', 'en': 'Save'},
    'saved': {'ar': 'تم الحفظ', 'en': 'Saved'},
  };

  static String t(String key, bool isArabic) {
    return _dict[key]?[isArabic ? 'ar' : 'en'] ?? key;
  }
}
