/// قاموس ترجمة يدوي (بدون مكتبات إضافية) — يدعم عدة لغات، مطبَّق
/// حاليًا على الشاشة الرئيسية وشاشة الإعدادات فقط. باقي شاشات
/// التطبيق تبقى بالعربية حتى تتم ترجمتها بمرحلة قادمة منفصلة.
class AppLanguage {
  final String code;
  final String nativeName;
  const AppLanguage(this.code, this.nativeName);
}

class AppText {
  /// اللغات المدعومة حاليًا بواجهة الإعدادات.
  static const List<AppLanguage> supportedLanguages = [
    AppLanguage('ar', 'العربية'),
    AppLanguage('en', 'English'),
    AppLanguage('de', 'Deutsch'),
    AppLanguage('fr', 'Français'),
    AppLanguage('tr', 'Türkçe'),
    AppLanguage('pl', 'Polski'),
  ];

  static const Map<String, Map<String, String>> _dict = {
    'app_name': {
      'ar': 'MN-Doc', 'en': 'MN-Doc', 'de': 'MN-Doc', 'fr': 'MN-Doc', 'tr': 'MN-Doc', 'pl': 'MN-Doc',
    },
    'app_tagline': {
      'ar': 'محرر المستندات وأدوات PDF الذكية',
      'en': 'Smart document editor & PDF tools',
      'de': 'Intelligenter Dokumenteneditor & PDF-Tools',
      'fr': 'Éditeur de documents et outils PDF intelligents',
      'tr': 'Akıllı belge düzenleyici ve PDF araçları',
      'pl': 'Inteligentny edytor dokumentów i narzędzia PDF',
    },
    'documents_section': {
      'ar': 'أدوات المستندات', 'en': 'Document Tools', 'de': 'Dokumenten-Tools',
      'fr': 'Outils de documents', 'tr': 'Belge Araçları', 'pl': 'Narzędzia do dokumentów',
    },
    'ai_section': {
      'ar': 'الذكاء الاصطناعي', 'en': 'AI Features', 'de': 'KI-Funktionen',
      'fr': 'Fonctionnalités IA', 'tr': 'Yapay Zeka Özellikleri', 'pl': 'Funkcje AI',
    },
    'recent_files': {
      'ar': 'الملفات الأخيرة', 'en': 'Recent Files', 'de': 'Zuletzt verwendete Dateien',
      'fr': 'Fichiers récents', 'tr': 'Son Dosyalar', 'pl': 'Ostatnie pliki',
    },
    'no_files_yet': {
      'ar': 'لا توجد ملفات بعد.\nاضغط "فتح ملف" للبدء.',
      'en': 'No files yet.\nTap "Open File" to start.',
      'de': 'Noch keine Dateien.\nTippen Sie auf „Datei öffnen“, um zu beginnen.',
      'fr': 'Aucun fichier pour le moment.\nAppuyez sur « Ouvrir un fichier » pour commencer.',
      'tr': 'Henüz dosya yok.\nBaşlamak için "Dosya Aç"a dokunun.',
      'pl': 'Brak plików.\nNaciśnij „Otwórz plik”, aby zacząć.',
    },
    'open_file': {
      'ar': 'فتح ملف', 'en': 'Open File', 'de': 'Datei öffnen',
      'fr': 'Ouvrir un fichier', 'tr': 'Dosya Aç', 'pl': 'Otwórz plik',
    },
    'edit_pdf': {
      'ar': 'تحرير PDF', 'en': 'Edit PDF', 'de': 'PDF bearbeiten',
      'fr': 'Modifier le PDF', 'tr': 'PDF Düzenle', 'pl': 'Edytuj PDF',
    },
    'pdf_tools': {
      'ar': 'أدوات PDF (دمج/ترتيب/توقيع)',
      'en': 'PDF Tools (Merge/Reorder/Sign)',
      'de': 'PDF-Werkzeuge (Zusammenführen/Sortieren/Signieren)',
      'fr': 'Outils PDF (Fusionner/Réorganiser/Signer)',
      'tr': 'PDF Araçları (Birleştir/Sırala/İmzala)',
      'pl': 'Narzędzia PDF (Scal/Sortuj/Podpisz)',
    },
    'ocr': {
      'ar': 'التعرف الضوئي (OCR)', 'en': 'Text Recognition (OCR)', 'de': 'Texterkennung (OCR)',
      'fr': 'Reconnaissance de texte (OCR)', 'tr': 'Metin Tanıma (OCR)', 'pl': 'Rozpoznawanie tekstu (OCR)',
    },
    'scanner': {
      'ar': 'مسح ضوئي للمستندات (Scanner)', 'en': 'Document Scanner', 'de': 'Dokumentenscanner',
      'fr': 'Scanner de documents', 'tr': 'Belge Tarayıcı', 'pl': 'Skaner dokumentów',
    },
    'create_document': {
      'ar': 'إنشاء مستند جديد', 'en': 'Create New Document', 'de': 'Neues Dokument erstellen',
      'fr': 'Créer un nouveau document', 'tr': 'Yeni Belge Oluştur', 'pl': 'Utwórz nowy dokument',
    },
    'translate': {
      'ar': 'ترجمة (مجانية)', 'en': 'Translate (Free)', 'de': 'Übersetzen (kostenlos)',
      'fr': 'Traduire (gratuit)', 'tr': 'Çevir (Ücretsiz)', 'pl': 'Tłumacz (bezpłatnie)',
    },
    'summarize': {
      'ar': 'تلخيص مستند', 'en': 'Summarize Document', 'de': 'Dokument zusammenfassen',
      'fr': 'Résumer le document', 'tr': 'Belgeyi Özetle', 'pl': 'Podsumuj dokument',
    },
    'ai_chat': {
      'ar': 'مساعد ذكي للدردشة', 'en': 'AI Chat Assistant', 'de': 'KI-Chat-Assistent',
      'fr': 'Assistant de chat IA', 'tr': 'Yapay Zeka Sohbet Asistanı', 'pl': 'Asystent czatu AI',
    },
    'ai_settings': {
      'ar': 'إعدادات الذكاء الاصطناعي', 'en': 'AI Settings', 'de': 'KI-Einstellungen',
      'fr': 'Paramètres IA', 'tr': 'Yapay Zeka Ayarları', 'pl': 'Ustawienia AI',
    },
    'settings': {
      'ar': 'الإعدادات', 'en': 'Settings', 'de': 'Einstellungen',
      'fr': 'Paramètres', 'tr': 'Ayarlar', 'pl': 'Ustawienia',
    },
    'about_app': {
      'ar': 'حول التطبيق', 'en': 'About App', 'de': 'Über die App',
      'fr': "À propos de l'application", 'tr': 'Uygulama Hakkında', 'pl': 'O aplikacji',
    },
    'profile': {
      'ar': 'الملف الشخصي', 'en': 'Profile', 'de': 'Profil',
      'fr': 'Profil', 'tr': 'Profil', 'pl': 'Profil',
    },
    'display_name': {
      'ar': 'اسمك', 'en': 'Your name', 'de': 'Ihr Name',
      'fr': 'Votre nom', 'tr': 'Adınız', 'pl': 'Twoje imię',
    },
    'display_name_hint': {
      'ar': 'اكتب اسمك (يُحفظ على جهازك فقط)',
      'en': 'Enter your name (saved on this device only)',
      'de': 'Namen eingeben (nur lokal gespeichert)',
      'fr': 'Entrez votre nom (enregistré uniquement sur cet appareil)',
      'tr': 'Adınızı yazın (yalnızca bu cihazda saklanır)',
      'pl': 'Wpisz swoje imię (zapisywane tylko lokalnie)',
    },
    'welcome': {
      'ar': 'مرحبًا', 'en': 'Welcome', 'de': 'Willkommen',
      'fr': 'Bienvenue', 'tr': 'Hoş geldiniz', 'pl': 'Witamy',
    },
    'appearance': {
      'ar': 'المظهر', 'en': 'Appearance', 'de': 'Erscheinungsbild',
      'fr': 'Apparence', 'tr': 'Görünüm', 'pl': 'Wygląd',
    },
    'theme_light': {
      'ar': 'فاتح', 'en': 'Light', 'de': 'Hell', 'fr': 'Clair', 'tr': 'Açık', 'pl': 'Jasny',
    },
    'theme_dark': {
      'ar': 'ليلي', 'en': 'Dark', 'de': 'Dunkel', 'fr': 'Sombre', 'tr': 'Koyu', 'pl': 'Ciemny',
    },
    'theme_system': {
      'ar': 'تلقائي (حسب الجهاز)', 'en': 'System default', 'de': 'Systemstandard',
      'fr': 'Par défaut du système', 'tr': 'Sistem varsayılanı', 'pl': 'Domyślne systemowe',
    },
    'language': {
      'ar': 'اللغة', 'en': 'Language', 'de': 'Sprache', 'fr': 'Langue', 'tr': 'Dil', 'pl': 'Język',
    },
    'language_note': {
      'ar': 'التطبيق مترجم بالكامل لكل اللغات المدعومة.',
      'en': 'The app is fully translated into all supported languages.',
      'de': 'Die App ist vollständig in alle unterstützten Sprachen übersetzt.',
      'fr': "L'application est entièrement traduite dans toutes les langues prises en charge.",
      'tr': 'Uygulama, desteklenen tüm dillere tam olarak çevrilmiştir.',
      'pl': 'Aplikacja jest w pełni przetłumaczona na wszystkie obsługiwane języki.',
    },
    'save': {
      'ar': 'حفظ', 'en': 'Save', 'de': 'Speichern', 'fr': 'Enregistrer', 'tr': 'Kaydet', 'pl': 'Zapisz',
    },
    'saved': {
      'ar': 'تم الحفظ', 'en': 'Saved', 'de': 'Gespeichert', 'fr': 'Enregistré', 'tr': 'Kaydedildi', 'pl': 'Zapisano',
    },

    // ---------------- مركز أدوات PDF ----------------
    'pdf_tools_appbar': {
      'ar': 'أدوات PDF المتقدمة', 'en': 'Advanced PDF Tools', 'de': 'Erweiterte PDF-Werkzeuge',
      'fr': 'Outils PDF avancés', 'tr': 'Gelişmiş PDF Araçları', 'pl': 'Zaawansowane narzędzia PDF',
    },
    'tool_merge_t': {
      'ar': 'دمج ملفات PDF', 'en': 'Merge PDF Files', 'de': 'PDF-Dateien zusammenführen',
      'fr': 'Fusionner des fichiers PDF', 'tr': 'PDF Dosyalarını Birleştir', 'pl': 'Scal pliki PDF',
    },
    'tool_merge_s': {
      'ar': 'اجمع عدة ملفات بملف واحد بالترتيب اللي تحدده',
      'en': 'Combine multiple files into one, in the order you choose',
      'de': 'Mehrere Dateien in der gewünschten Reihenfolge zu einer zusammenfassen',
      'fr': "Combinez plusieurs fichiers en un seul, dans l'ordre de votre choix",
      'tr': 'Birden fazla dosyayı istediğiniz sırayla tek dosyada birleştirin',
      'pl': 'Połącz wiele plików w jeden, w wybranej kolejności',
    },
    'tool_pages_t': {
      'ar': 'حذف وإعادة ترتيب الصفحات', 'en': 'Delete & Reorder Pages', 'de': 'Seiten löschen & neu anordnen',
      'fr': 'Supprimer et réorganiser les pages', 'tr': 'Sayfaları Sil ve Yeniden Sırala', 'pl': 'Usuń i zmień kolejność stron',
    },
    'tool_pages_s': {
      'ar': 'احذف صفحات معينة أو رتّب صفحات الملف بالسحب',
      'en': 'Delete specific pages or reorder them by dragging',
      'de': 'Bestimmte Seiten löschen oder per Ziehen neu anordnen',
      'fr': 'Supprimez des pages ou réorganisez-les par glisser-déposer',
      'tr': 'Belirli sayfaları silin veya sürükleyerek yeniden sıralayın',
      'pl': 'Usuń wybrane strony lub zmień ich kolejność przeciągając',
    },
    'tool_sign_t': {
      'ar': 'توقيع إلكتروني', 'en': 'E-Signature', 'de': 'Elektronische Signatur',
      'fr': 'Signature électronique', 'tr': 'Elektronik İmza', 'pl': 'Podpis elektroniczny',
    },
    'tool_sign_s': {
      'ar': 'اختر توقيع/ختم محفوظ، أو ارسم جديدًا، وضعه بالملف',
      'en': 'Choose a saved signature/stamp, or draw a new one, and place it on the file',
      'de': 'Wählen Sie eine gespeicherte Signatur/einen Stempel oder zeichnen Sie eine neue und platzieren Sie sie in der Datei',
      'fr': "Choisissez une signature/tampon enregistré, ou dessinez-en un nouveau, et placez-le sur le fichier",
      'tr': 'Kayıtlı bir imza/kaşe seçin veya yeni bir tane çizin ve dosyaya yerleştirin',
      'pl': 'Wybierz zapisany podpis/pieczątkę lub narysuj nowy i umieść go w pliku',
    },
    'tool_signmanage_t': {
      'ar': 'إدارة التواقيع والأختام', 'en': 'Manage Signatures & Stamps', 'de': 'Signaturen & Stempel verwalten',
      'fr': 'Gérer les signatures et tampons', 'tr': 'İmza ve Kaşeleri Yönet', 'pl': 'Zarządzaj podpisami i pieczątkami',
    },
    'tool_signmanage_s': {
      'ar': 'عرض وحذف التواقيع والأختام المحفوظة',
      'en': 'View and delete saved signatures and stamps',
      'de': 'Gespeicherte Signaturen und Stempel anzeigen und löschen',
      'fr': 'Afficher et supprimer les signatures et tampons enregistrés',
      'tr': 'Kayıtlı imza ve kaşeleri görüntüleyin ve silin',
      'pl': 'Wyświetl i usuń zapisane podpisy i pieczątki',
    },
    'tool_protect_t': {
      'ar': 'حماية بكلمة مرور', 'en': 'Password Protection', 'de': 'Passwortschutz',
      'fr': 'Protection par mot de passe', 'tr': 'Parola Koruması', 'pl': 'Ochrona hasłem',
    },
    'tool_protect_s': {
      'ar': 'أضف أو أزل كلمة مرور من ملف PDF',
      'en': 'Add or remove a password from a PDF file',
      'de': 'Passwort zu einer PDF-Datei hinzufügen oder entfernen',
      'fr': "Ajouter ou supprimer un mot de passe d'un fichier PDF",
      'tr': 'Bir PDF dosyasına parola ekleyin veya kaldırın',
      'pl': 'Dodaj lub usuń hasło z pliku PDF',
    },
    'tool_watermark_t': {
      'ar': 'علامة مائية', 'en': 'Watermark', 'de': 'Wasserzeichen',
      'fr': 'Filigrane', 'tr': 'Filigran', 'pl': 'Znak wodny',
    },
    'tool_watermark_s': {
      'ar': 'أضف نص علامة مائية بأي زاوية وشفافية',
      'en': 'Add a text watermark at any angle and opacity',
      'de': 'Textwasserzeichen in beliebigem Winkel und Deckkraft hinzufügen',
      'fr': "Ajoutez un filigrane texte à n'importe quel angle et opacité",
      'tr': 'Herhangi bir açı ve saydamlıkta metin filigranı ekleyin',
      'pl': 'Dodaj tekstowy znak wodny pod dowolnym kątem i przezroczystością',
    },
    'tool_compress_t': {
      'ar': 'ضغط حجم PDF', 'en': 'Compress PDF', 'de': 'PDF komprimieren',
      'fr': 'Compresser le PDF', 'tr': 'PDF Sıkıştır', 'pl': 'Kompresuj PDF',
    },
    'tool_compress_s': {
      'ar': 'قلّل حجم الملف قدر الإمكان',
      'en': 'Reduce the file size as much as possible',
      'de': 'Dateigröße so weit wie möglich reduzieren',
      'fr': 'Réduisez la taille du fichier autant que possible',
      'tr': 'Dosya boyutunu mümkün olduğunca küçültün',
      'pl': 'Zmniejsz rozmiar pliku, jak to możliwe',
    },
    'tool_compare_t': {
      'ar': 'مقارنة ملفين PDF', 'en': 'Compare Two PDFs', 'de': 'Zwei PDFs vergleichen',
      'fr': 'Comparer deux PDF', 'tr': "İki PDF'i Karşılaştır", 'pl': 'Porównaj dwa pliki PDF',
    },
    'tool_compare_s': {
      'ar': 'أظهر الفروقات النصية بين ملفين',
      'en': 'Show text differences between two files',
      'de': 'Textunterschiede zwischen zwei Dateien anzeigen',
      'fr': 'Afficher les différences de texte entre deux fichiers',
      'tr': 'İki dosya arasındaki metin farklarını gösterin',
      'pl': 'Pokaż różnice tekstowe między dwoma plikami',
    },
    'tool_rotate_t': {
      'ar': 'تدوير وإزالة الصفحات الفارغة', 'en': 'Rotate & Remove Blank Pages', 'de': 'Seiten drehen & leere entfernen',
      'fr': 'Pivoter et supprimer les pages vides', 'tr': 'Sayfaları Döndür ve Boşları Kaldır', 'pl': 'Obróć i usuń puste strony',
    },
    'tool_rotate_s': {
      'ar': 'دوّر أي صفحة واكتشف الصفحات الفارغة تلقائيًا',
      'en': 'Rotate any page and auto-detect blank pages',
      'de': 'Beliebige Seite drehen und leere Seiten automatisch erkennen',
      'fr': 'Faites pivoter une page et détectez automatiquement les pages vides',
      'tr': 'Herhangi bir sayfayı döndürün ve boş sayfaları otomatik tespit edin',
      'pl': 'Obróć dowolną stronę i automatycznie wykryj puste strony',
    },
    'tool_tts_t': {
      'ar': 'قراءة المستند بصوت', 'en': 'Read Document Aloud', 'de': 'Dokument vorlesen',
      'fr': 'Lire le document à voix haute', 'tr': 'Belgeyi Sesli Oku', 'pl': 'Czytaj dokument na głos',
    },
    'tool_tts_s': {
      'ar': 'اختر ملف PDF واستمع لمحتواه',
      'en': 'Choose a PDF file and listen to its content',
      'de': 'PDF-Datei auswählen und Inhalt anhören',
      'fr': 'Choisissez un fichier PDF et écoutez son contenu',
      'tr': 'Bir PDF dosyası seçin ve içeriğini dinleyin',
      'pl': 'Wybierz plik PDF i posłuchaj jego treści',
    },
    'tool_table_t': {
      'ar': 'استخراج جداول PDF إلى Excel', 'en': 'Extract PDF Tables to Excel', 'de': 'PDF-Tabellen nach Excel extrahieren',
      'fr': 'Extraire les tableaux PDF vers Excel', 'tr': "PDF Tablolarını Excel'e Aktar", 'pl': 'Eksportuj tabele PDF do Excela',
    },
    'tool_table_s': {
      'ar': 'تصدير تقريبي للجداول (طريقة تخمينية)',
      'en': 'Approximate table export (heuristic method)',
      'de': 'Ungefährer Tabellenexport (heuristische Methode)',
      'fr': 'Exportation approximative des tableaux (méthode heuristique)',
      'tr': 'Yaklaşık tablo dışa aktarma (sezgisel yöntem)',
      'pl': 'Przybliżony eksport tabel (metoda heurystyczna)',
    },
    'tool_word_t': {
      'ar': 'تحويل Word إلى PDF', 'en': 'Convert Word to PDF', 'de': 'Word in PDF umwandeln',
      'fr': 'Convertir Word en PDF', 'tr': "Word'ü PDF'e Dönüştür", 'pl': 'Konwertuj Word na PDF',
    },
    'tool_word_s': {
      'ar': 'استخراج نص .docx وتحويله لملف PDF (بدون تنسيق)',
      'en': 'Extract .docx text and convert it to PDF (no formatting)',
      'de': '.docx-Text extrahieren und in PDF umwandeln (ohne Formatierung)',
      'fr': 'Extraire le texte .docx et le convertir en PDF (sans mise en forme)',
      'tr': ".docx metnini çıkarıp PDF'e dönüştürün (biçimlendirmesiz)",
      'pl': 'Wyodrębnij tekst .docx i przekonwertuj na PDF (bez formatowania)',
    },
    'tool_img2pdf_t': {
      'ar': 'تحويل صور إلى PDF', 'en': 'Convert Images to PDF', 'de': 'Bilder in PDF umwandeln',
      'fr': 'Convertir des images en PDF', 'tr': "Görselleri PDF'e Dönüştür", 'pl': 'Konwertuj obrazy na PDF',
    },
    'tool_img2pdf_s': {
      'ar': 'اجمع عدة صور بملف PDF واحد',
      'en': 'Combine multiple images into one PDF file',
      'de': 'Mehrere Bilder zu einer PDF-Datei zusammenfassen',
      'fr': 'Combinez plusieurs images en un seul fichier PDF',
      'tr': 'Birden fazla görseli tek bir PDF dosyasında birleştirin',
      'pl': 'Połącz wiele obrazów w jeden plik PDF',
    },
    'tool_pdf2img_t': {
      'ar': 'تحويل PDF إلى صور', 'en': 'Convert PDF to Images', 'de': 'PDF in Bilder umwandeln',
      'fr': 'Convertir le PDF en images', 'tr': "PDF'i Görsellere Dönüştür", 'pl': 'Konwertuj PDF na obrazy',
    },
    'tool_pdf2img_s': {
      'ar': 'صدّر أي صفحة (أو كل الصفحات) كصورة PNG',
      'en': 'Export any page (or all pages) as a PNG image',
      'de': 'Beliebige Seite (oder alle Seiten) als PNG-Bild exportieren',
      'fr': "Exportez n'importe quelle page (ou toutes) en image PNG",
      'tr': 'Herhangi bir sayfayı (veya tüm sayfaları) PNG olarak dışa aktarın',
      'pl': 'Eksportuj dowolną stronę (lub wszystkie) jako obraz PNG',
    },
    'tool_print_t': {
      'ar': 'طباعة PDF', 'en': 'Print PDF', 'de': 'PDF drucken',
      'fr': 'Imprimer le PDF', 'tr': 'PDF Yazdır', 'pl': 'Drukuj PDF',
    },
    'tool_print_s': {
      'ar': 'اطبع مباشرة عبر طابعة لاسلكية أو احفظ كملف',
      'en': 'Print directly via a wireless printer or save as a file',
      'de': 'Direkt über einen WLAN-Drucker drucken oder als Datei speichern',
      'fr': 'Imprimez directement via une imprimante sans fil ou enregistrez en fichier',
      'tr': 'Kablosuz yazıcı ile doğrudan yazdırın veya dosya olarak kaydedin',
      'pl': 'Drukuj bezpośrednio przez drukarkę bezprzewodową lub zapisz jako plik',
    },
    'tool_barcode_t': {
      'ar': 'التعرف على QR والباركود', 'en': 'QR & Barcode Recognition', 'de': 'QR- & Barcode-Erkennung',
      'fr': 'Reconnaissance QR et codes-barres', 'tr': 'QR ve Barkod Tanıma', 'pl': 'Rozpoznawanie kodów QR i kreskowych',
    },
    'tool_barcode_s': {
      'ar': 'من صورة أو من صفحة داخل ملف PDF',
      'en': 'From an image or from a page inside a PDF file',
      'de': 'Aus einem Bild oder einer Seite innerhalb einer PDF-Datei',
      'fr': "À partir d'une image ou d'une page dans un fichier PDF",
      'tr': 'Bir görselden veya PDF dosyasındaki bir sayfadan',
      'pl': 'Ze zdjęcia lub strony wewnątrz pliku PDF',
    },
    'tool_redact_t': {
      'ar': 'تعديل/حذف نص موجود بالملف', 'en': 'Edit/Remove Existing Text', 'de': 'Vorhandenen Text bearbeiten/entfernen',
      'fr': 'Modifier/supprimer le texte existant', 'tr': 'Mevcut Metni Düzenle/Kaldır', 'pl': 'Edytuj/usuń istniejący tekst',
    },
    'tool_redact_s': {
      'ar': 'اسحب فوق أي نص لتغطيته أو استبداله (طريقة عملية تقريبية)',
      'en': 'Drag over any text to cover or replace it (practical approximate method)',
      'de': 'Über beliebigen Text ziehen, um ihn zu überdecken oder zu ersetzen',
      'fr': 'Faites glisser sur du texte pour le masquer ou le remplacer',
      'tr': 'Herhangi bir metnin üzerine sürükleyerek kapatın veya değiştirin',
      'pl': 'Przeciągnij nad dowolnym tekstem, aby go zakryć lub zastąpić',
    },
    'tool_dictation_t': {
      'ar': 'إملاء صوتي', 'en': 'Voice Dictation', 'de': 'Spracherkennung',
      'fr': 'Dictée vocale', 'tr': 'Sesli Yazdırma', 'pl': 'Dyktowanie głosowe',
    },
    'tool_dictation_s': {
      'ar': 'حوّل كلامك لنص مباشرة واحفظه كملف PDF',
      'en': 'Convert your speech to text directly and save it as a PDF file',
      'de': 'Ihre Sprache direkt in Text umwandeln und als PDF-Datei speichern',
      'fr': 'Convertissez votre voix en texte directement et enregistrez-le en PDF',
      'tr': 'Konuşmanızı doğrudan metne dönüştürün ve PDF olarak kaydedin',
      'pl': 'Zamień mowę bezpośrednio na tekst i zapisz jako plik PDF',
    },
    'tool_repair_t': {
      'ar': 'إصلاح ملف PDF تالف', 'en': 'Repair Corrupted PDF', 'de': 'Beschädigte PDF reparieren',
      'fr': 'Réparer un PDF endommagé', 'tr': "Bozuk PDF'i Onar", 'pl': 'Napraw uszkodzony plik PDF',
    },
    'tool_repair_s': {
      'ar': 'محاولة إصلاح مشاكل الفهرسة الداخلية الشائعة',
      'en': 'Attempt to fix common internal indexing issues',
      'de': 'Versuch, häufige interne Indexierungsprobleme zu beheben',
      'fr': "Tenter de corriger les problèmes d'indexation interne courants",
      'tr': 'Yaygın dahili dizinleme sorunlarını gidermeyi dener',
      'pl': 'Próba naprawienia typowych problemów z indeksowaniem wewnętrznym',
    },

    // ---------------- محرر PDF ----------------
    'ed_search_tooltip': {
      'ar': 'بحث داخل المستند', 'en': 'Search in document', 'de': 'Im Dokument suchen',
      'fr': 'Rechercher dans le document', 'tr': 'Belgede ara', 'pl': 'Szukaj w dokumencie',
    },
    'ed_bookmarks_tooltip': {
      'ar': 'الفهرس (Bookmarks)', 'en': 'Bookmarks', 'de': 'Lesezeichen',
      'fr': 'Signets', 'tr': 'Yer İmleri', 'pl': 'Zakładki',
    },
    'ed_addtext_tooltip': {
      'ar': 'وضع إضافة نص', 'en': 'Add text mode', 'de': 'Textmodus',
      'fr': 'Mode ajout de texte', 'tr': 'Metin ekleme modu', 'pl': 'Tryb dodawania tekstu',
    },
    'ed_ai_tooltip': {
      'ar': 'ميزات الذكاء الاصطناعي', 'en': 'AI Features', 'de': 'KI-Funktionen',
      'fr': 'Fonctionnalités IA', 'tr': 'Yapay Zeka Özellikleri', 'pl': 'Funkcje AI',
    },
    'ed_ai_summarize': {
      'ar': 'تلخيص هذا المستند', 'en': 'Summarize this document', 'de': 'Dieses Dokument zusammenfassen',
      'fr': 'Résumer ce document', 'tr': 'Bu belgeyi özetle', 'pl': 'Podsumuj ten dokument',
    },
    'ed_ai_chat': {
      'ar': 'اسأل عن هذا المستند', 'en': 'Ask about this document', 'de': 'Fragen zu diesem Dokument stellen',
      'fr': 'Poser une question sur ce document', 'tr': 'Bu belge hakkında soru sor', 'pl': 'Zapytaj o ten dokument',
    },
    'ed_ai_translate': {
      'ar': 'ترجمة نص من المستند', 'en': 'Translate text from the document', 'de': 'Text aus dem Dokument übersetzen',
      'fr': 'Traduire du texte du document', 'tr': 'Belgeden metin çevir', 'pl': 'Przetłumacz tekst z dokumentu',
    },
    'ed_search_hint': {
      'ar': 'ابحث داخل المستند...', 'en': 'Search in document...', 'de': 'Im Dokument suchen...',
      'fr': 'Rechercher dans le document...', 'tr': 'Belgede ara...', 'pl': 'Szukaj w dokumencie...',
    },
    'ed_highlight': {
      'ar': 'تظليل', 'en': 'Highlight', 'de': 'Hervorheben', 'fr': 'Surligner', 'tr': 'Vurgula', 'pl': 'Zaznacz',
    },
    'ed_underline': {
      'ar': 'تسطير', 'en': 'Underline', 'de': 'Unterstreichen', 'fr': 'Souligner', 'tr': 'Altını çiz', 'pl': 'Podkreśl',
    },
    'ed_strikethrough': {
      'ar': 'شطب', 'en': 'Strikethrough', 'de': 'Durchstreichen', 'fr': 'Barrer', 'tr': 'Üstünü çiz', 'pl': 'Przekreśl',
    },
    'ed_stickynote': {
      'ar': 'ملاحظة', 'en': 'Note', 'de': 'Notiz', 'fr': 'Note', 'tr': 'Not', 'pl': 'Notatka',
    },
    'ed_form_banner': {
      'ar': 'هذا الملف يحتوي نموذجًا قابلاً للتعبئة',
      'en': 'This file contains a fillable form',
      'de': 'Diese Datei enthält ein ausfüllbares Formular',
      'fr': 'Ce fichier contient un formulaire à remplir',
      'tr': 'Bu dosya doldurulabilir bir form içeriyor',
      'pl': 'Ten plik zawiera formularz do wypełnienia',
    },
    'ed_form_flatten': {
      'ar': 'تثبيت عند الحفظ', 'en': 'Lock when saving', 'de': 'Beim Speichern sperren',
      'fr': "Verrouiller à l'enregistrement", 'tr': 'Kaydederken kilitle', 'pl': 'Zablokuj przy zapisie',
    },
    'ed_addtext_banner': {
      'ar': 'وضع إضافة النص مفعّل — اضغط في أي مكان على الصفحة لإدراج نص',
      'en': 'Add-text mode is on — tap anywhere on the page to insert text',
      'de': 'Textmodus aktiv — tippen Sie auf die Seite, um Text einzufügen',
      'fr': 'Mode ajout de texte activé — touchez la page pour insérer du texte',
      'tr': 'Metin ekleme modu açık — metin eklemek için sayfaya dokunun',
      'pl': 'Tryb dodawania tekstu włączony — dotknij strony, aby wstawić tekst',
    },
    'ed_dialog_title': {
      'ar': 'إضافة نص', 'en': 'Add Text', 'de': 'Text hinzufügen',
      'fr': 'Ajouter du texte', 'tr': 'Metin Ekle', 'pl': 'Dodaj tekst',
    },
    'ed_dialog_hint': {
      'ar': 'اكتب النص هنا...', 'en': 'Type your text here...', 'de': 'Text hier eingeben...',
      'fr': 'Tapez votre texte ici...', 'tr': 'Metninizi buraya yazın...', 'pl': 'Wpisz tekst tutaj...',
    },
    'ed_dialog_fontsize': {
      'ar': 'حجم الخط:', 'en': 'Font size:', 'de': 'Schriftgröße:',
      'fr': 'Taille de police :', 'tr': 'Yazı boyutu:', 'pl': 'Rozmiar czcionki:',
    },
    'ed_dialog_color': {
      'ar': 'اللون:', 'en': 'Color:', 'de': 'Farbe:', 'fr': 'Couleur :', 'tr': 'Renk:', 'pl': 'Kolor:',
    },
    'ed_dialog_add': {
      'ar': 'إضافة', 'en': 'Add', 'de': 'Hinzufügen', 'fr': 'Ajouter', 'tr': 'Ekle', 'pl': 'Dodaj',
    },
    'ed_saved_title': {
      'ar': 'تم الحفظ بنجاح', 'en': 'Saved successfully', 'de': 'Erfolgreich gespeichert',
      'fr': 'Enregistré avec succès', 'tr': 'Başarıyla kaydedildi', 'pl': 'Zapisano pomyślnie',
    },
    'ed_saved_path_prefix': {
      'ar': 'تم حفظ الملف في:', 'en': 'File saved to:', 'de': 'Datei gespeichert unter:',
      'fr': 'Fichier enregistré dans :', 'tr': 'Dosya şuraya kaydedildi:', 'pl': 'Plik zapisano w:',
    },
    'ed_close': {
      'ar': 'إغلاق', 'en': 'Close', 'de': 'Schließen', 'fr': 'Fermer', 'tr': 'Kapat', 'pl': 'Zamknij',
    },
    'ed_share': {
      'ar': 'مشاركة', 'en': 'Share', 'de': 'Teilen', 'fr': 'Partager', 'tr': 'Paylaş', 'pl': 'Udostępnij',
    },
    'ed_save_error_prefix': {
      'ar': 'حدث خطأ أثناء الحفظ:', 'en': 'An error occurred while saving:', 'de': 'Beim Speichern ist ein Fehler aufgetreten:',
      'fr': "Une erreur s'est produite lors de l'enregistrement :", 'tr': 'Kaydedilirken bir hata oluştu:', 'pl': 'Wystąpił błąd podczas zapisywania:',
    },

    // ---------------- عناصر مشتركة ----------------
    'camera': {
      'ar': 'كاميرا', 'en': 'Camera', 'de': 'Kamera', 'fr': 'Appareil photo', 'tr': 'Kamera', 'pl': 'Aparat',
    },
    'gallery': {
      'ar': 'المعرض', 'en': 'Gallery', 'de': 'Galerie', 'fr': 'Galerie', 'tr': 'Galeri', 'pl': 'Galeria',
    },
    'copy': {
      'ar': 'نسخ', 'en': 'Copy', 'de': 'Kopieren', 'fr': 'Copier', 'tr': 'Kopyala', 'pl': 'Kopiuj',
    },
    'copied': {
      'ar': 'تم النسخ', 'en': 'Copied', 'de': 'Kopiert', 'fr': 'Copié', 'tr': 'Kopyalandı', 'pl': 'Skopiowano',
    },
    'btn_translate': {
      'ar': 'ترجمة', 'en': 'Translate', 'de': 'Übersetzen', 'fr': 'Traduire', 'tr': 'Çevir', 'pl': 'Tłumacz',
    },
    'btn_summarize': {
      'ar': 'تلخيص', 'en': 'Summarize', 'de': 'Zusammenfassen', 'fr': 'Résumer', 'tr': 'Özetle', 'pl': 'Podsumuj',
    },
    'btn_ask': {
      'ar': 'اسأل', 'en': 'Ask', 'de': 'Fragen', 'fr': 'Demander', 'tr': 'Sor', 'pl': 'Zapytaj',
    },

    // ---------------- شاشة OCR ----------------
    'ocr_extracted_label': {
      'ar': 'النص المستخرج', 'en': 'Extracted Text', 'de': 'Extrahierter Text',
      'fr': 'Texte extrait', 'tr': 'Çıkarılan Metin', 'pl': 'Wyodrębniony tekst',
    },
    'ocr_hint': {
      'ar': 'سيظهر النص المستخرج هنا، ويمكنك تعديله مباشرة...',
      'en': 'The extracted text will appear here, and you can edit it directly...',
      'de': 'Der extrahierte Text erscheint hier und kann direkt bearbeitet werden...',
      'fr': 'Le texte extrait apparaîtra ici, et vous pouvez le modifier directement...',
      'tr': 'Çıkarılan metin burada görünecek, doğrudan düzenleyebilirsiniz...',
      'pl': 'Wyodrębniony tekst pojawi się tutaj i można go bezpośrednio edytować...',
    },
    'ocr_save_txt': {
      'ar': 'حفظ كنص', 'en': 'Save as Text', 'de': 'Als Text speichern',
      'fr': 'Enregistrer en texte', 'tr': 'Metin Olarak Kaydet', 'pl': 'Zapisz jako tekst',
    },
    'ocr_error_prefix': {
      'ar': 'تعذّر التعرف على النص:', 'en': 'Could not recognize text:', 'de': 'Text konnte nicht erkannt werden:',
      'fr': 'Impossible de reconnaître le texte :', 'tr': 'Metin tanınamadı:', 'pl': 'Nie można rozpoznać tekstu:',
    },
    'ocr_saved_prefix': {
      'ar': 'تم الحفظ:', 'en': 'Saved:', 'de': 'Gespeichert:', 'fr': 'Enregistré :', 'tr': 'Kaydedildi:', 'pl': 'Zapisano:',
    },
    'ocr_ask_title': {
      'ar': 'اسأل عن هذا النص', 'en': 'Ask about this text', 'de': 'Fragen zu diesem Text stellen',
      'fr': 'Poser une question sur ce texte', 'tr': 'Bu metin hakkında soru sor', 'pl': 'Zapytaj o ten tekst',
    },
    'ocr_mode_free': {
      'ar': 'مجاني (بدون إنترنت)', 'en': 'Free (Offline)', 'de': 'Kostenlos (Offline)',
      'fr': 'Gratuit (Hors ligne)', 'tr': 'Ücretsiz (Çevrimdışı)', 'pl': 'Bezpłatnie (Offline)',
    },
    'ocr_mode_ai': {
      'ar': 'بالذكاء الاصطناعي (يدعم العربية)', 'en': 'AI-Powered (Supports Arabic)', 'de': 'KI-gestützt (unterstützt Arabisch)',
      'fr': "Propulsé par l'IA (prend en charge l'arabe)", 'tr': 'Yapay Zeka Destekli (Arapça Destekler)', 'pl': 'Wspomagane AI (obsługuje arabski)',
    },
    'ocr_script_label': {
      'ar': 'لغة/نص التعرف', 'en': 'Recognition Script', 'de': 'Erkennungsschrift',
      'fr': 'Script de reconnaissance', 'tr': 'Tanıma Yazısı', 'pl': 'Skrypt rozpoznawania',
    },
    'ocr_free_note': {
      'ar': 'مجاني تمامًا وبدون إنترنت — يدعم الإنجليزي والصيني والياباني والكوري فقط (لا يدعم العربية).',
      'en': 'Completely free and offline — supports English, Chinese, Japanese, and Korean only (does not support Arabic).',
      'de': 'Völlig kostenlos und offline — unterstützt nur Englisch, Chinesisch, Japanisch und Koreanisch (kein Arabisch).',
      'fr': "Entièrement gratuit et hors ligne — prend en charge uniquement l'anglais, le chinois, le japonais et le coréen (pas l'arabe).",
      'tr': 'Tamamen ücretsiz ve çevrimdışı — yalnızca İngilizce, Çince, Japonca ve Korece destekler (Arapça desteklemez).',
      'pl': 'Całkowicie bezpłatne i offline — obsługuje tylko angielski, chiński, japoński i koreański (nie obsługuje arabskiego).',
    },
    'ocr_ai_note': {
      'ar': 'يحتاج مفتاح Gemini المجاني واتصال إنترنت — يدعم العربية وكل اللغات.',
      'en': 'Requires a free Gemini key and internet connection — supports Arabic and all languages.',
      'de': 'Benötigt einen kostenlosen Gemini-Schlüssel und eine Internetverbindung — unterstützt Arabisch und alle Sprachen.',
      'fr': "Nécessite une clé Gemini gratuite et une connexion internet — prend en charge l'arabe et toutes les langues.",
      'tr': 'Ücretsiz bir Gemini anahtarı ve internet bağlantısı gerektirir — Arapça ve tüm dilleri destekler.',
      'pl': 'Wymaga bezpłatnego klucza Gemini i połączenia internetowego — obsługuje arabski i wszystkie języki.',
    },

    // ---------------- شاشة الترجمة ----------------
    'tr_appbar': {
      'ar': 'الترجمة (مجانية وبدون إنترنت)', 'en': 'Translate (Free & Offline)', 'de': 'Übersetzen (kostenlos & offline)',
      'fr': 'Traduire (gratuit et hors ligne)', 'tr': 'Çevir (Ücretsiz ve Çevrimdışı)', 'pl': 'Tłumacz (bezpłatnie i offline)',
    },
    'tr_hint_source': {
      'ar': 'اكتب أو الصق النص هنا...', 'en': 'Type or paste text here...', 'de': 'Text hier eingeben oder einfügen...',
      'fr': 'Tapez ou collez le texte ici...', 'tr': 'Metni buraya yazın veya yapıştırın...', 'pl': 'Wpisz lub wklej tekst tutaj...',
    },
    'tr_downloading': {
      'ar': 'جارٍ تحميل حزمة اللغة (مرة واحدة فقط)...', 'en': 'Downloading language pack (one time only)...',
      'de': 'Sprachpaket wird heruntergeladen (einmalig)...', 'fr': 'Téléchargement du pack de langue (une seule fois)...',
      'tr': 'Dil paketi indiriliyor (yalnızca bir kez)...', 'pl': 'Pobieranie pakietu językowego (jednorazowo)...',
    },
    'tr_translating': {
      'ar': 'جارٍ الترجمة...', 'en': 'Translating...', 'de': 'Wird übersetzt...',
      'fr': 'Traduction en cours...', 'tr': 'Çevriliyor...', 'pl': 'Tłumaczenie...',
    },
    'tr_hint_result': {
      'ar': 'ستظهر الترجمة هنا...', 'en': 'The translation will appear here...', 'de': 'Die Übersetzung erscheint hier...',
      'fr': 'La traduction apparaîtra ici...', 'tr': 'Çeviri burada görünecek...', 'pl': 'Tłumaczenie pojawi się tutaj...',
    },
    'tr_error_prefix': {
      'ar': 'تعذّرت الترجمة:', 'en': 'Translation failed:', 'de': 'Übersetzung fehlgeschlagen:',
      'fr': 'Échec de la traduction :', 'tr': 'Çeviri başarısız oldu:', 'pl': 'Tłumaczenie nie powiodło się:',
    },

    // ---------------- شاشة التلخيص ----------------
    'sm_ai_note': {
      'ar': 'سيتم استخدام تلخيص ذكي (Gemini) — يحتاج إنترنت',
      'en': 'Smart summary (Gemini) will be used — requires internet',
      'de': 'Intelligente Zusammenfassung (Gemini) wird verwendet — benötigt Internet',
      'fr': 'Un résumé intelligent (Gemini) sera utilisé — nécessite internet',
      'tr': 'Akıllı özet (Gemini) kullanılacak — internet gerektirir',
      'pl': 'Zostanie użyte inteligentne podsumowanie (Gemini) — wymaga internetu',
    },
    'sm_local_note': {
      'ar': 'سيتم استخدام التلخيص المحلي المجاني (بدون إنترنت)',
      'en': 'Free local summarization will be used (offline)',
      'de': 'Kostenlose lokale Zusammenfassung wird verwendet (offline)',
      'fr': 'Un résumé local gratuit sera utilisé (hors ligne)',
      'tr': 'Ücretsiz yerel özetleme kullanılacak (çevrimdışı)',
      'pl': 'Zostanie użyte bezpłatne lokalne podsumowanie (offline)',
    },
    'sm_original_label': {
      'ar': 'النص الأصلي', 'en': 'Original Text', 'de': 'Originaltext',
      'fr': 'Texte original', 'tr': 'Orijinal Metin', 'pl': 'Tekst oryginalny',
    },
    'sm_hint_input': {
      'ar': 'الصق نص المستند هنا، أو افتحه من محرر PDF مباشرة...',
      'en': 'Paste the document text here, or open it directly from the PDF editor...',
      'de': 'Fügen Sie den Dokumenttext hier ein oder öffnen Sie ihn direkt aus dem PDF-Editor...',
      'fr': "Collez le texte du document ici, ou ouvrez-le directement depuis l'éditeur PDF...",
      'tr': 'Belge metnini buraya yapıştırın veya PDF düzenleyiciden doğrudan açın...',
      'pl': 'Wklej tekst dokumentu tutaj lub otwórz go bezpośrednio z edytora PDF...',
    },
    'sm_summarizing': {
      'ar': 'جارٍ التلخيص...', 'en': 'Summarizing...', 'de': 'Wird zusammengefasst...',
      'fr': 'Résumé en cours...', 'tr': 'Özetleniyor...', 'pl': 'Podsumowywanie...',
    },
    'sm_summary_label': {
      'ar': 'الملخص', 'en': 'Summary', 'de': 'Zusammenfassung', 'fr': 'Résumé', 'tr': 'Özet', 'pl': 'Podsumowanie',
    },
    'sm_hint_result': {
      'ar': 'سيظهر الملخص هنا...', 'en': 'The summary will appear here...', 'de': 'Die Zusammenfassung erscheint hier...',
      'fr': 'Le résumé apparaîtra ici...', 'tr': 'Özet burada görünecek...', 'pl': 'Podsumowanie pojawi się tutaj...',
    },
    'sm_error_prefix': {
      'ar': 'تعذّر الاتصال بالتلخيص الذكي، تم استخدام التلخيص المحلي بدلاً منه.',
      'en': 'Could not connect to smart summarization; local summarization was used instead.',
      'de': 'Verbindung zur intelligenten Zusammenfassung fehlgeschlagen; stattdessen wurde die lokale Zusammenfassung verwendet.',
      'fr': "Impossible de se connecter au résumé intelligent ; le résumé local a été utilisé à la place.",
      'tr': 'Akıllı özetlemeye bağlanılamadı; bunun yerine yerel özetleme kullanıldı.',
      'pl': 'Nie można połączyć się z inteligentnym podsumowaniem; zamiast tego użyto podsumowania lokalnego.',
    },

    // ---------------- المساعد الذكي للدردشة ----------------
    'chat_error_prefix': {
      'ar': 'حدث خطأ:', 'en': 'An error occurred:', 'de': 'Ein Fehler ist aufgetreten:',
      'fr': "Une erreur s'est produite :", 'tr': 'Bir hata oluştu:', 'pl': 'Wystąpił błąd:',
    },
    'chat_no_text': {
      'ar': 'لم يتم العثور على نص داخل هذا المستند بعد — قد تحتاج لاستخراج النص أولًا.',
      'en': 'No text found in this document yet — you may need to extract the text first.',
      'de': 'Noch kein Text in diesem Dokument gefunden — Sie müssen den Text möglicherweise zuerst extrahieren.',
      'fr': "Aucun texte trouvé dans ce document pour l'instant — vous devrez peut-être d'abord extraire le texte.",
      'tr': 'Bu belgede henüz metin bulunamadı — önce metni çıkarmanız gerekebilir.',
      'pl': 'Nie znaleziono jeszcze tekstu w tym dokumencie — może być konieczne najpierw wyodrębnienie tekstu.',
    },
    'chat_empty_hint': {
      'ar': 'اسأل أي سؤال عن محتوى هذا المستند، مثل:\n"لخّص لي الفكرة الرئيسية"\n"ما أهم الأرقام المذكورة؟"',
      'en': 'Ask any question about this document\'s content, such as:\n"Summarize the main idea"\n"What are the key figures mentioned?"',
      'de': 'Stellen Sie eine beliebige Frage zum Inhalt dieses Dokuments, z. B.:\n„Fasse die Hauptidee zusammen"\n„Welche wichtigen Zahlen werden genannt?"',
      'fr': "Posez n'importe quelle question sur le contenu de ce document, par exemple :\n« Résume l'idée principale »\n« Quels sont les chiffres clés mentionnés ? »",
      'tr': 'Bu belgenin içeriği hakkında herhangi bir soru sorun, örneğin:\n"Ana fikri özetle"\n"Bahsedilen önemli rakamlar neler?"',
      'pl': 'Zadaj dowolne pytanie dotyczące treści tego dokumentu, na przykład:\n"Podsumuj główną myśl"\n"Jakie są kluczowe liczby wymienione w dokumencie?"',
    },
    'chat_input_hint': {
      'ar': 'اكتب سؤالك...', 'en': 'Type your question...', 'de': 'Stellen Sie Ihre Frage...',
      'fr': 'Tapez votre question...', 'tr': 'Sorunuzu yazın...', 'pl': 'Wpisz swoje pytanie...',
    },

    // ---------------- إعدادات الذكاء الاصطناعي ----------------
    'aisettings_card_title': {
      'ar': 'مفتاح Gemini API (مجاني)', 'en': 'Gemini API Key (Free)', 'de': 'Gemini-API-Schlüssel (kostenlos)',
      'fr': 'Clé API Gemini (gratuite)', 'tr': 'Gemini API Anahtarı (Ücretsiz)', 'pl': 'Klucz API Gemini (bezpłatny)',
    },
    'aisettings_desc1': {
      'ar': 'يُستخدم فقط لميزتيّ "التلخيص الذكي" و"المساعد الذكي للدردشة"، وتحتاج فيهما اتصال إنترنت. أما الترجمة والتعرف الضوئي على النصوص فيعملان بالكامل بدون إنترنت وبدون أي مفتاح.',
      'en': 'Used only for "Smart Summary" and "AI Chat Assistant", both of which need internet. Translation and OCR work fully offline without any key.',
      'de': 'Wird nur für „Intelligente Zusammenfassung" und „KI-Chat-Assistent" verwendet, die beide Internet benötigen. Übersetzung und Texterkennung funktionieren vollständig offline ohne Schlüssel.',
      'fr': "Utilisé uniquement pour le « Résumé intelligent » et l'« Assistant de chat IA », qui nécessitent tous deux internet. La traduction et l'OCR fonctionnent entièrement hors ligne sans clé.",
      'tr': '"Akıllı Özet" ve "Yapay Zeka Sohbet Asistanı" için kullanılır, ikisi de internet gerektirir. Çeviri ve OCR herhangi bir anahtar olmadan tamamen çevrimdışı çalışır.',
      'pl': 'Używany tylko dla funkcji "Inteligentne podsumowanie" i "Asystent czatu AI", które wymagają internetu. Tłumaczenie i OCR działają całkowicie offline bez klucza.',
    },
    'aisettings_desc2': {
      'ar': 'للحصول على مفتاح مجاني (بدون بطاقة ائتمان):\n1) افتح aistudio.google.com/apikey\n2) سجّل الدخول بحساب Google\n3) اضغط "Create API key" وانسخه هنا',
      'en': 'To get a free key (no credit card required):\n1) Open aistudio.google.com/apikey\n2) Sign in with your Google account\n3) Click "Create API key" and paste it here',
      'de': 'So erhalten Sie einen kostenlosen Schlüssel (keine Kreditkarte erforderlich):\n1) Öffnen Sie aistudio.google.com/apikey\n2) Melden Sie sich mit Ihrem Google-Konto an\n3) Klicken Sie auf „Create API key" und fügen Sie ihn hier ein',
      'fr': 'Pour obtenir une clé gratuite (aucune carte de crédit requise) :\n1) Ouvrez aistudio.google.com/apikey\n2) Connectez-vous avec votre compte Google\n3) Cliquez sur « Create API key » et collez-la ici',
      'tr': 'Ücretsiz anahtar almak için (kredi kartı gerekmez):\n1) aistudio.google.com/apikey adresini açın\n2) Google hesabınızla giriş yapın\n3) "Create API key"e tıklayın ve buraya yapıştırın',
      'pl': 'Aby uzyskać bezpłatny klucz (bez karty kredytowej):\n1) Otwórz aistudio.google.com/apikey\n2) Zaloguj się swoim kontem Google\n3) Kliknij "Create API key" i wklej go tutaj',
    },
    'aisettings_field_label': {
      'ar': 'الصق مفتاح API هنا', 'en': 'Paste your API key here', 'de': 'Fügen Sie Ihren API-Schlüssel hier ein',
      'fr': 'Collez votre clé API ici', 'tr': 'API anahtarınızı buraya yapıştırın', 'pl': 'Wklej tutaj swój klucz API',
    },
    'delete': {
      'ar': 'حذف', 'en': 'Delete', 'de': 'Löschen', 'fr': 'Supprimer', 'tr': 'Sil', 'pl': 'Usuń',
    },
    'aisettings_saved_msg': {
      'ar': 'تم حفظ المفتاح على جهازك', 'en': 'Key saved on your device', 'de': 'Schlüssel auf Ihrem Gerät gespeichert',
      'fr': 'Clé enregistrée sur votre appareil', 'tr': 'Anahtar cihazınıza kaydedildi', 'pl': 'Klucz zapisany na Twoim urządzeniu',
    },
    'aisettings_deleted_msg': {
      'ar': 'تم حذف المفتاح', 'en': 'Key deleted', 'de': 'Schlüssel gelöscht',
      'fr': 'Clé supprimée', 'tr': 'Anahtar silindi', 'pl': 'Klucz usunięty',
    },

    // ---------------- إنشاء مستند ----------------
    'create_doc_default_title': {
      'ar': 'مستند بدون عنوان', 'en': 'Untitled Document', 'de': 'Unbenanntes Dokument',
      'fr': 'Document sans titre', 'tr': 'Adsız Belge', 'pl': 'Dokument bez tytułu',
    },
    'create_doc_title_label': {
      'ar': 'عنوان المستند', 'en': 'Document Title', 'de': 'Dokumenttitel',
      'fr': 'Titre du document', 'tr': 'Belge Başlığı', 'pl': 'Tytuł dokumentu',
    },
    'create_doc_body_label': {
      'ar': 'المحتوى', 'en': 'Content', 'de': 'Inhalt', 'fr': 'Contenu', 'tr': 'İçerik', 'pl': 'Zawartość',
    },
    'create_doc_creating': {
      'ar': 'جارٍ الإنشاء...', 'en': 'Creating...', 'de': 'Wird erstellt...',
      'fr': 'Création en cours...', 'tr': 'Oluşturuluyor...', 'pl': 'Tworzenie...',
    },
    'create_doc_button': {
      'ar': 'إنشاء ملف PDF', 'en': 'Create PDF File', 'de': 'PDF-Datei erstellen',
      'fr': 'Créer un fichier PDF', 'tr': 'PDF Dosyası Oluştur', 'pl': 'Utwórz plik PDF',
    },
    'create_doc_success_title': {
      'ar': 'تم إنشاء المستند', 'en': 'Document Created', 'de': 'Dokument erstellt',
      'fr': 'Document créé', 'tr': 'Belge Oluşturuldu', 'pl': 'Utworzono dokument',
    },
    'create_doc_success_body': {
      'ar': 'ماذا تريد أن تفعل الآن؟', 'en': 'What would you like to do now?', 'de': 'Was möchten Sie jetzt tun?',
      'fr': 'Que souhaitez-vous faire maintenant ?', 'tr': 'Şimdi ne yapmak istersiniz?', 'pl': 'Co chcesz teraz zrobić?',
    },
    'create_doc_open_edit': {
      'ar': 'فتح للتحرير', 'en': 'Open to Edit', 'de': 'Zum Bearbeiten öffnen',
      'fr': 'Ouvrir pour modifier', 'tr': 'Düzenlemek için Aç', 'pl': 'Otwórz do edycji',
    },
    'error_prefix': {
      'ar': 'خطأ:', 'en': 'Error:', 'de': 'Fehler:', 'fr': 'Erreur :', 'tr': 'Hata:', 'pl': 'Błąd:',
    },

    // ---------------- المسح الضوئي ----------------
    'scanner_save_tooltip': {
      'ar': 'حفظ كـ PDF', 'en': 'Save as PDF', 'de': 'Als PDF speichern',
      'fr': 'Enregistrer en PDF', 'tr': 'PDF Olarak Kaydet', 'pl': 'Zapisz jako PDF',
    },
    'scanner_enhance_title': {
      'ar': 'تحسين تلقائي (أبيض وأسود بوضوح أعلى)', 'en': 'Auto Enhance (Higher-Contrast B&W)', 'de': 'Automatische Verbesserung (Schwarz-Weiß)',
      'fr': 'Amélioration automatique (Noir et blanc)', 'tr': 'Otomatik İyileştirme (Siyah Beyaz)', 'pl': 'Automatyczne ulepszanie (czarno-białe)',
    },
    'scanner_enhance_subtitle': {
      'ar': 'يُطبَّق على الصفحات الجديدة فقط', 'en': 'Applied to new pages only', 'de': 'Wird nur auf neue Seiten angewendet',
      'fr': 'Appliqué uniquement aux nouvelles pages', 'tr': 'Yalnızca yeni sayfalara uygulanır', 'pl': 'Stosowane tylko do nowych stron',
    },
    'scanner_empty_hint': {
      'ar': 'اضغط الزر بالأسفل لالتقاط أول صفحة بالكاميرا',
      'en': 'Tap the button below to capture your first page with the camera',
      'de': 'Tippen Sie unten, um Ihre erste Seite mit der Kamera aufzunehmen',
      'fr': "Appuyez sur le bouton ci-dessous pour capturer votre première page",
      'tr': 'Kamerayla ilk sayfanızı yakalamak için aşağıdaki düğmeye dokunun',
      'pl': 'Dotknij przycisku poniżej, aby uchwycić pierwszą stronę aparatem',
    },
    'scanner_page_label': {
      'ar': 'صفحة', 'en': 'Page', 'de': 'Seite', 'fr': 'Page', 'tr': 'Sayfa', 'pl': 'Strona',
    },
    'scanner_enhanced': {
      'ar': 'محسّنة (أبيض وأسود)', 'en': 'Enhanced (B&W)', 'de': 'Verbessert (Schwarz-Weiß)',
      'fr': 'Améliorée (Noir et blanc)', 'tr': 'İyileştirildi (Siyah Beyaz)', 'pl': 'Ulepszona (czarno-biała)',
    },
    'scanner_original': {
      'ar': 'أصلية بالألوان', 'en': 'Original (Color)', 'de': 'Original (Farbe)',
      'fr': 'Originale (Couleur)', 'tr': 'Orijinal (Renkli)', 'pl': 'Oryginalna (kolor)',
    },
    'scanner_capturing': {
      'ar': 'جارٍ الالتقاط...', 'en': 'Capturing...', 'de': 'Wird aufgenommen...',
      'fr': 'Capture en cours...', 'tr': 'Yakalanıyor...', 'pl': 'Przechwytywanie...',
    },
    'scanner_capture_btn': {
      'ar': 'مسح المستند', 'en': 'Scan Document', 'de': 'Dokument scannen',
      'fr': 'Numériser le document', 'tr': 'Belgeyi Tara', 'pl': 'Skanuj dokument',
    },
    'scanner_success_title': {
      'ar': 'تم إنشاء الملف بنجاح', 'en': 'File created successfully', 'de': 'Datei erfolgreich erstellt',
      'fr': 'Fichier créé avec succès', 'tr': 'Dosya başarıyla oluşturuldu', 'pl': 'Plik utworzony pomyślnie',
    },
    'scanner_pagecount_label': {
      'ar': 'عدد الصفحات:', 'en': 'Number of pages:', 'de': 'Anzahl der Seiten:',
      'fr': 'Nombre de pages :', 'tr': 'Sayfa sayısı:', 'pl': 'Liczba stron:',
    },
    'scanner_open_file': {
      'ar': 'فتح الملف', 'en': 'Open File', 'de': 'Datei öffnen',
      'fr': 'Ouvrir le fichier', 'tr': 'Dosyayı Aç', 'pl': 'Otwórz plik',
    },
    'scanner_capture_error': {
      'ar': 'تعذّر التقاط الصورة:', 'en': 'Could not capture the image:', 'de': 'Bild konnte nicht aufgenommen werden:',
      'fr': "Impossible de capturer l'image :", 'tr': 'Görüntü yakalanamadı:', 'pl': 'Nie można przechwycić obrazu:',
    },
    'scanner_contrast_label': {
      'ar': 'التباين:', 'en': 'Contrast:', 'de': 'Kontrast:', 'fr': 'Contraste :', 'tr': 'Kontrast:', 'pl': 'Kontrast:',
    },
    'scanner_brightness_label': {
      'ar': 'السطوع:', 'en': 'Brightness:', 'de': 'Helligkeit:', 'fr': 'Luminosité :', 'tr': 'Parlaklık:', 'pl': 'Jasność:',
    },
    'undo': {
      'ar': 'تراجع', 'en': 'Undo', 'de': 'Rückgängig', 'fr': 'Annuler', 'tr': 'Geri Al', 'pl': 'Cofnij',
    },
    'redo': {
      'ar': 'إعادة', 'en': 'Redo', 'de': 'Wiederholen', 'fr': 'Rétablir', 'tr': 'Yinele', 'pl': 'Ponów',
    },
    'file_from_app_prefix': {
      'ar': 'ملف من', 'en': 'A file from', 'de': 'Eine Datei von', 'fr': 'Un fichier de', 'tr': "Şuradan bir dosya:", 'pl': 'Plik z',
    },
    'ed_dialog_alignment': {
      'ar': 'المحاذاة:', 'en': 'Alignment:', 'de': 'Ausrichtung:', 'fr': 'Alignement :', 'tr': 'Hizalama:', 'pl': 'Wyrównanie:',
    },
    'ed_open_saved_file': {
      'ar': 'فتح الملف المحفوظ', 'en': 'Open Saved File', 'de': 'Gespeicherte Datei öffnen',
      'fr': 'Ouvrir le fichier enregistré', 'tr': 'Kaydedilen Dosyayı Aç', 'pl': 'Otwórz zapisany plik',
    },
    'ed_autosaved': {
      'ar': '✓ تم الحفظ تلقائيًا', 'en': '✓ Auto-saved', 'de': '✓ Automatisch gespeichert',
      'fr': '✓ Enregistré automatiquement', 'tr': '✓ Otomatik kaydedildi', 'pl': '✓ Zapisano automatycznie',
    },
    'ed_zoom_reset_needed': {
      'ar': 'أعد التكبير لـ 100% أولًا لضمان دقة إضافة النص (اضغط زر التصفير 🎯)',
      'en': 'Reset zoom to 100% first for accurate text placement (tap the reset button 🎯)',
      'de': 'Setzen Sie den Zoom zuerst auf 100% für eine genaue Textplatzierung (Reset-Taste 🎯)',
      'fr': "Réinitialisez d'abord le zoom à 100% pour un placement précis du texte (bouton de réinitialisation 🎯)",
      'tr': 'Doğru metin yerleşimi için önce yakınlaştırmayı %100\'e sıfırlayın (sıfırlama düğmesi 🎯)',
      'pl': 'Najpierw zresetuj powiększenie do 100%, aby dokładnie umieścić tekst (przycisk resetowania 🎯)',
    },
    'ed_form_fields_detected': {
      'ar': 'هذا الملف يحتوي حقول قابلة للتعبئة — اضغط عليها مباشرة لملئها',
      'en': 'This file contains fillable fields — tap them directly to fill in',
      'de': 'Diese Datei enthält ausfüllbare Felder — tippen Sie direkt darauf, um sie auszufüllen',
      'fr': "Ce fichier contient des champs à remplir — appuyez dessus directement pour les remplir",
      'tr': 'Bu dosya doldurulabilir alanlar içeriyor — doldurmak için doğrudan onlara dokunun',
      'pl': 'Ten plik zawiera pola do wypełnienia — dotknij ich bezpośrednio, aby je wypełnić',
    },
    'ed_action_edit': {
      'ar': 'تعديل', 'en': 'Edit', 'de': 'Bearbeiten', 'fr': 'Modifier', 'tr': 'Düzenle', 'pl': 'Edytuj',
    },
    'ed_action_move': {
      'ar': 'نقل لمكان تاني', 'en': 'Move to another spot', 'de': 'An eine andere Stelle verschieben',
      'fr': 'Déplacer ailleurs', 'tr': 'Başka bir yere taşı', 'pl': 'Przenieś w inne miejsce',
    },
    'ed_action_delete': {
      'ar': 'حذف', 'en': 'Delete', 'de': 'Löschen', 'fr': 'Supprimer', 'tr': 'Sil', 'pl': 'Usuń',
    },
    'ed_tap_new_location': {
      'ar': 'اضغط على المكان الجديد بالصفحة لنقل النص إليه',
      'en': 'Tap the new spot on the page to move the text there',
      'de': 'Tippen Sie auf die neue Stelle auf der Seite, um den Text dorthin zu verschieben',
      'fr': "Appuyez sur le nouvel emplacement de la page pour y déplacer le texte",
      'tr': 'Metni oraya taşımak için sayfadaki yeni konuma dokunun',
      'pl': 'Dotknij nowego miejsca na stronie, aby przenieść tam tekst',
    },
    'ed_extract_failed': {
      'ar': 'تعذّر استخراج النص من هذا الملف. قد يكون محميًا أو تالفًا أو صورة ممسوحة بدون نص فعلي.',
      'en': 'Could not extract text from this file. It may be protected, damaged, or a scanned image without real text.',
      'de': 'Text konnte aus dieser Datei nicht extrahiert werden. Sie ist möglicherweise geschützt, beschädigt oder ein gescanntes Bild ohne echten Text.',
      'fr': "Impossible d'extraire le texte de ce fichier. Il peut être protégé, endommagé, ou être une image scannée sans texte réel.",
      'tr': 'Bu dosyadan metin çıkarılamadı. Korumalı, hasarlı veya gerçek metin içermeyen taranmış bir görüntü olabilir.',
      'pl': 'Nie można wyodrębnić tekstu z tego pliku. Może być chroniony, uszkodzony lub być zeskanowanym obrazem bez rzeczywistego tekstu.',
    },
    'unsaved_title': {
      'ar': 'تعديلات غير محفوظة', 'en': 'Unsaved Changes', 'de': 'Nicht gespeicherte Änderungen',
      'fr': 'Modifications non enregistrées', 'tr': 'Kaydedilmemiş Değişiklikler', 'pl': 'Niezapisane zmiany',
    },
    'unsaved_body': {
      'ar': 'هل تريد الخروج بدون حفظ التعديلات؟', 'en': 'Do you want to exit without saving your changes?',
      'de': 'Möchten Sie beenden, ohne Ihre Änderungen zu speichern?', 'fr': 'Voulez-vous quitter sans enregistrer vos modifications ?',
      'tr': 'Değişikliklerinizi kaydetmeden çıkmak istiyor musunuz?', 'pl': 'Czy chcesz wyjść bez zapisywania zmian?',
    },
    'discard_exit': {
      'ar': 'تجاهل والخروج', 'en': 'Discard & Exit', 'de': 'Verwerfen & Beenden',
      'fr': 'Ignorer et quitter', 'tr': 'Yoksay ve Çık', 'pl': 'Odrzuć i wyjdź',
    },

    // ---------------- عناصر مشتركة إضافية ----------------
    'select_pdf_btn': {
      'ar': 'اختيار ملف PDF', 'en': 'Select PDF File', 'de': 'PDF-Datei auswählen',
      'fr': 'Sélectionner un fichier PDF', 'tr': 'PDF Dosyası Seç', 'pl': 'Wybierz plik PDF',
    },
    'processing': {
      'ar': 'جارٍ المعالجة...', 'en': 'Processing...', 'de': 'Wird verarbeitet...',
      'fr': 'Traitement en cours...', 'tr': 'İşleniyor...', 'pl': 'Przetwarzanie...',
    },
    'read_error_prefix': {
      'ar': 'تعذّر قراءة الملف:', 'en': 'Could not read the file:', 'de': 'Datei konnte nicht gelesen werden:',
      'fr': 'Impossible de lire le fichier :', 'tr': 'Dosya okunamadı:', 'pl': 'Nie można odczytać pliku:',
    },
    'path_label': {
      'ar': 'المسار:', 'en': 'Path:', 'de': 'Pfad:', 'fr': 'Chemin :', 'tr': 'Konum:', 'pl': 'Ścieżka:',
    },
    'pages_word': {
      'ar': 'صفحة', 'en': 'page', 'de': 'Seite', 'fr': 'page', 'tr': 'sayfa', 'pl': 'strona',
    },

    // ---------------- دمج الملفات ----------------
    'merge_add_files': {
      'ar': 'إضافة ملفات PDF', 'en': 'Add PDF Files', 'de': 'PDF-Dateien hinzufügen',
      'fr': 'Ajouter des fichiers PDF', 'tr': 'PDF Dosyaları Ekle', 'pl': 'Dodaj pliki PDF',
    },
    'merge_hint': {
      'ar': 'أضف ملفين أو أكثر، ورتّبهم بالسحب حسب الترتيب المطلوب بالدمج',
      'en': 'Add two or more files, and reorder them by dragging in the order you want them merged',
      'de': 'Fügen Sie zwei oder mehr Dateien hinzu und ordnen Sie sie per Ziehen in der gewünschten Reihenfolge an',
      'fr': "Ajoutez deux fichiers ou plus, et réorganisez-les par glisser-déposer dans l'ordre souhaité pour la fusion",
      'tr': 'İki veya daha fazla dosya ekleyin ve birleştirmek istediğiniz sırayla sürükleyerek düzenleyin',
      'pl': 'Dodaj dwa lub więcej plików i zmień ich kolejność przeciągając w wybranej kolejności scalania',
    },
    'merge_min2': {
      'ar': 'أضف ملفين على الأقل للدمج', 'en': 'Add at least two files to merge', 'de': 'Fügen Sie mindestens zwei Dateien zum Zusammenführen hinzu',
      'fr': 'Ajoutez au moins deux fichiers à fusionner', 'tr': 'Birleştirmek için en az iki dosya ekleyin', 'pl': 'Dodaj co najmniej dwa pliki do scalenia',
    },
    'merge_success_title': {
      'ar': 'تم الدمج بنجاح', 'en': 'Merged Successfully', 'de': 'Erfolgreich zusammengeführt',
      'fr': 'Fusionné avec succès', 'tr': 'Başarıyla Birleştirildi', 'pl': 'Pomyślnie scalono',
    },
    'merge_error_prefix': {
      'ar': 'خطأ أثناء الدمج:', 'en': 'Error while merging:', 'de': 'Fehler beim Zusammenführen:',
      'fr': 'Erreur lors de la fusion :', 'tr': 'Birleştirme sırasında hata:', 'pl': 'Błąd podczas scalania:',
    },
    'merge_button': {
      'ar': 'دمج الملفات', 'en': 'Merge Files', 'de': 'Dateien zusammenführen',
      'fr': 'Fusionner les fichiers', 'tr': 'Dosyaları Birleştir', 'pl': 'Scal pliki',
    },
    'merge_merging': {
      'ar': 'جارٍ الدمج...', 'en': 'Merging...', 'de': 'Wird zusammengeführt...',
      'fr': 'Fusion en cours...', 'tr': 'Birleştiriliyor...', 'pl': 'Scalanie...',
    },

    // ---------------- حذف/ترتيب الصفحات ----------------
    'pages_pick_hint': {
      'ar': 'اختر ملف PDF للبدء بحذف أو إعادة ترتيب صفحاته',
      'en': 'Choose a PDF file to start deleting or reordering its pages',
      'de': 'Wählen Sie eine PDF-Datei aus, um deren Seiten zu löschen oder neu anzuordnen',
      'fr': 'Choisissez un fichier PDF pour commencer à supprimer ou réorganiser ses pages',
      'tr': 'Sayfalarını silmeye veya yeniden sıralamaya başlamak için bir PDF dosyası seçin',
      'pl': 'Wybierz plik PDF, aby zacząć usuwać lub zmieniać kolejność jego stron',
    },
    'pages_summary_suffix': {
      'ar': '(اسحب لإعادة الترتيب، اضغط 🗑️ للحذف)',
      'en': '(Drag to reorder, tap 🗑️ to delete)',
      'de': '(Ziehen zum Neuanordnen, 🗑️ zum Löschen antippen)',
      'fr': '(Glissez pour réorganiser, appuyez sur 🗑️ pour supprimer)',
      'tr': '(Yeniden sıralamak için sürükleyin, silmek için 🗑️\'e dokunun)',
      'pl': '(Przeciągnij, aby zmienić kolejność, dotknij 🗑️, aby usunąć)',
    },
    'pages_original_label': {
      'ar': 'بالملف الأصلي', 'en': 'in the original file', 'de': 'in der Originaldatei',
      'fr': 'dans le fichier original', 'tr': 'orijinal dosyada', 'pl': 'w oryginalnym pliku',
    },
    'pages_save_new': {
      'ar': 'حفظ التعديلات كملف جديد', 'en': 'Save Changes as New File', 'de': 'Änderungen als neue Datei speichern',
      'fr': 'Enregistrer les modifications dans un nouveau fichier', 'tr': 'Değişiklikleri Yeni Dosya Olarak Kaydet', 'pl': 'Zapisz zmiany jako nowy plik',
    },
    'pages_final_count': {
      'ar': 'عدد الصفحات النهائي:', 'en': 'Final page count:', 'de': 'Endgültige Seitenzahl:',
      'fr': 'Nombre de pages final :', 'tr': 'Son sayfa sayısı:', 'pl': 'Ostateczna liczba stron:',
    },

    // ---------------- التدوير وإزالة الفارغة ----------------
    'rotate_detect_tooltip': {
      'ar': 'اكتشاف الصفحات الفارغة', 'en': 'Detect Blank Pages', 'de': 'Leere Seiten erkennen',
      'fr': 'Détecter les pages vides', 'tr': 'Boş Sayfaları Tespit Et', 'pl': 'Wykryj puste strony',
    },
    'rotate_no_blanks': {
      'ar': 'لم يتم العثور على صفحات فارغة', 'en': 'No blank pages found', 'de': 'Keine leeren Seiten gefunden',
      'fr': 'Aucune page vide trouvée', 'tr': 'Boş sayfa bulunamadı', 'pl': 'Nie znaleziono pustych stron',
    },
    'rotate_found_blanks_prefix': {
      'ar': 'وُجدت', 'en': 'Found', 'de': 'Gefunden:', 'fr': 'Trouvé', 'tr': 'Bulundu:', 'pl': 'Znaleziono',
    },
    'rotate_found_blanks_suffix': {
      'ar': 'صفحة فارغة — حدّدت للحذف تلقائيًا',
      'en': 'blank page(s) — automatically selected for deletion',
      'de': 'leere Seite(n) — automatisch zum Löschen ausgewählt',
      'fr': 'page(s) vide(s) — sélectionnée(s) automatiquement pour suppression',
      'tr': 'boş sayfa — otomatik olarak silinmek üzere seçildi',
      'pl': 'pustą/-e stronę/-y — automatycznie wybrano do usunięcia',
    },
    'rotate_min1': {
      'ar': 'لازم يبقى صفحة واحدة على الأقل', 'en': 'At least one page must remain', 'de': 'Mindestens eine Seite muss übrig bleiben',
      'fr': 'Au moins une page doit rester', 'tr': 'En az bir sayfa kalmalıdır', 'pl': 'Musi pozostać co najmniej jedna strona',
    },
    'rotate_removed_label': {
      'ar': 'محذوفة', 'en': 'Deleted', 'de': 'Gelöscht', 'fr': 'Supprimée', 'tr': 'Silindi', 'pl': 'Usunięto',
    },
    'rotate_rotation_label': {
      'ar': 'دوران:', 'en': 'Rotation:', 'de': 'Drehung:', 'fr': 'Rotation :', 'tr': 'Döndürme:', 'pl': 'Obrót:',
    },
    'rotate_blank_suffix': {
      'ar': '(فارغة)', 'en': '(blank)', 'de': '(leer)', 'fr': '(vide)', 'tr': '(boş)', 'pl': '(pusta)',
    },

    // ---------------- الحماية بكلمة مرور ----------------
    'protect_add_mode': {
      'ar': 'إضافة كلمة مرور', 'en': 'Add Password', 'de': 'Passwort hinzufügen',
      'fr': 'Ajouter un mot de passe', 'tr': 'Parola Ekle', 'pl': 'Dodaj hasło',
    },
    'protect_remove_mode': {
      'ar': 'إزالة كلمة مرور', 'en': 'Remove Password', 'de': 'Passwort entfernen',
      'fr': 'Supprimer le mot de passe', 'tr': 'Parolayı Kaldır', 'pl': 'Usuń hasło',
    },
    'protect_current_pw': {
      'ar': 'كلمة المرور الحالية للملف', 'en': "File's Current Password", 'de': 'Aktuelles Passwort der Datei',
      'fr': 'Mot de passe actuel du fichier', 'tr': 'Dosyanın Mevcut Parolası', 'pl': 'Obecne hasło pliku',
    },
    'protect_new_pw': {
      'ar': 'كلمة المرور الجديدة', 'en': 'New Password', 'de': 'Neues Passwort',
      'fr': 'Nouveau mot de passe', 'tr': 'Yeni Parola', 'pl': 'Nowe hasło',
    },
    'protect_encrypt_btn': {
      'ar': 'تشفير الملف', 'en': 'Encrypt File', 'de': 'Datei verschlüsseln',
      'fr': 'Chiffrer le fichier', 'tr': 'Dosyayı Şifrele', 'pl': 'Zaszyfruj plik',
    },
    'protect_encrypted_title': {
      'ar': 'تم تشفير الملف بكلمة مرور', 'en': 'File encrypted with password', 'de': 'Datei mit Passwort verschlüsselt',
      'fr': 'Fichier chiffré avec mot de passe', 'tr': 'Dosya parolayla şifrelendi', 'pl': 'Plik zaszyfrowany hasłem',
    },
    'protect_removed_title': {
      'ar': 'تمت إزالة كلمة المرور', 'en': 'Password Removed', 'de': 'Passwort entfernt',
      'fr': 'Mot de passe supprimé', 'tr': 'Parola Kaldırıldı', 'pl': 'Hasło usunięte',
    },
    'protect_wrong_pw_error': {
      'ar': 'كلمة المرور الحالية غير صحيحة أو خطأ آخر:',
      'en': 'The current password is incorrect, or another error occurred:',
      'de': 'Das aktuelle Passwort ist falsch oder ein anderer Fehler ist aufgetreten:',
      'fr': "Le mot de passe actuel est incorrect, ou une autre erreur s'est produite :",
      'tr': 'Mevcut parola yanlış veya başka bir hata oluştu:',
      'pl': 'Obecne hasło jest nieprawidłowe lub wystąpił inny błąd:',
    },

    // ---------------- العلامة المائية ----------------
    'watermark_text_label': {
      'ar': 'نص العلامة المائية', 'en': 'Watermark Text', 'de': 'Wasserzeichentext',
      'fr': 'Texte du filigrane', 'tr': 'Filigran Metni', 'pl': 'Tekst znaku wodnego',
    },
    'watermark_opacity_label': {
      'ar': 'الشفافية:', 'en': 'Opacity:', 'de': 'Deckkraft:', 'fr': 'Opacité :', 'tr': 'Saydamlık:', 'pl': 'Przezroczystość:',
    },
    'watermark_rotation_label': {
      'ar': 'زاوية الدوران:', 'en': 'Rotation Angle:', 'de': 'Drehwinkel:', 'fr': 'Angle de rotation :', 'tr': 'Döndürme Açısı:', 'pl': 'Kąt obrotu:',
    },
    'watermark_added_title': {
      'ar': 'تمت إضافة العلامة المائية', 'en': 'Watermark Added', 'de': 'Wasserzeichen hinzugefügt',
      'fr': 'Filigrane ajouté', 'tr': 'Filigran Eklendi', 'pl': 'Dodano znak wodny',
    },
    'watermark_apply_btn': {
      'ar': 'تطبيق العلامة المائية', 'en': 'Apply Watermark', 'de': 'Wasserzeichen anwenden',
      'fr': 'Appliquer le filigrane', 'tr': 'Filigranı Uygula', 'pl': 'Zastosuj znak wodny',
    },

    // ---------------- الضغط ----------------
    'compress_current_size': {
      'ar': 'الحجم الحالي:', 'en': 'Current size:', 'de': 'Aktuelle Größe:',
      'fr': 'Taille actuelle :', 'tr': 'Mevcut boyut:', 'pl': 'Bieżący rozmiar:',
    },
    'compress_after_size': {
      'ar': 'الحجم بعد الضغط:', 'en': 'Size after compression:', 'de': 'Größe nach Komprimierung:',
      'fr': 'Taille après compression :', 'tr': 'Sıkıştırma sonrası boyut:', 'pl': 'Rozmiar po kompresji:',
    },
    'compress_note': {
      'ar': 'ملاحظة: الضغط يعمل بشكل أفضل مع الملفات النصية أو التي أُعيد حفظها عدة مرات. الملفات المليئة بالصور عالية الدقة قد تنخفض بنسبة أقل.',
      'en': 'Note: Compression works better with text-based files or files that have been re-saved multiple times. Files full of high-resolution images may shrink less.',
      'de': 'Hinweis: Die Komprimierung funktioniert besser bei textbasierten Dateien oder mehrfach neu gespeicherten Dateien. Dateien mit vielen hochauflösenden Bildern verkleinern sich möglicherweise weniger.',
      'fr': "Remarque : la compression fonctionne mieux avec les fichiers texte ou ceux réenregistrés plusieurs fois. Les fichiers pleins d'images haute résolution peuvent se réduire moins.",
      'tr': 'Not: Sıkıştırma, metin tabanlı veya birden çok kez yeniden kaydedilmiş dosyalarda daha iyi çalışır. Yüksek çözünürlüklü görsellerle dolu dosyalar daha az küçülebilir.',
      'pl': 'Uwaga: kompresja działa lepiej w przypadku plików tekstowych lub wielokrotnie zapisywanych. Pliki pełne obrazów w wysokiej rozdzielczości mogą zmniejszyć się mniej.',
    },
    'compress_done_title': {
      'ar': 'تم الضغط', 'en': 'Compression Complete', 'de': 'Komprimierung abgeschlossen',
      'fr': 'Compression terminée', 'tr': 'Sıkıştırma Tamamlandı', 'pl': 'Kompresja zakończona',
    },
    'compress_button': {
      'ar': 'ضغط الملف', 'en': 'Compress File', 'de': 'Datei komprimieren',
      'fr': 'Compresser le fichier', 'tr': 'Dosyayı Sıkıştır', 'pl': 'Kompresuj plik',
    },

    // ---------------- مقارنة ملفين PDF ----------------
    'compare_file1': {
      'ar': 'اختيار الملف الأول', 'en': 'Select First File', 'de': 'Erste Datei auswählen',
      'fr': 'Sélectionner le premier fichier', 'tr': 'İlk Dosyayı Seç', 'pl': 'Wybierz pierwszy plik',
    },
    'compare_file2': {
      'ar': 'اختيار الملف الثاني', 'en': 'Select Second File', 'de': 'Zweite Datei auswählen',
      'fr': 'Sélectionner le deuxième fichier', 'tr': 'İkinci Dosyayı Seç', 'pl': 'Wybierz drugi plik',
    },
    'compare_comparing': {
      'ar': 'جارٍ المقارنة...', 'en': 'Comparing...', 'de': 'Wird verglichen...',
      'fr': 'Comparaison en cours...', 'tr': 'Karşılaştırılıyor...', 'pl': 'Porównywanie...',
    },
    'compare_btn': {
      'ar': 'قارن الملفين', 'en': 'Compare Files', 'de': 'Dateien vergleichen',
      'fr': 'Comparer les fichiers', 'tr': 'Dosyaları Karşılaştır', 'pl': 'Porównaj pliki',
    },
    'compare_legend_removed': {
      'ar': 'حُذف (من الملف الأول)', 'en': 'Removed (from first file)', 'de': 'Entfernt (aus erster Datei)',
      'fr': 'Supprimé (du premier fichier)', 'tr': 'Kaldırıldı (ilk dosyadan)', 'pl': 'Usunięto (z pierwszego pliku)',
    },
    'compare_legend_added': {
      'ar': 'أُضيف (بالملف الثاني)', 'en': 'Added (in second file)', 'de': 'Hinzugefügt (in zweiter Datei)',
      'fr': 'Ajouté (dans le deuxième fichier)', 'tr': 'Eklendi (ikinci dosyada)', 'pl': 'Dodano (w drugim pliku)',
    },
    'compare_empty_hint': {
      'ar': 'اختر ملفين PDF لمقارنة محتواهما النصي',
      'en': 'Choose two PDF files to compare their text content',
      'de': 'Wählen Sie zwei PDF-Dateien aus, um deren Textinhalt zu vergleichen',
      'fr': 'Choisissez deux fichiers PDF pour comparer leur contenu textuel',
      'tr': 'Metin içeriğini karşılaştırmak için iki PDF dosyası seçin',
      'pl': 'Wybierz dwa pliki PDF, aby porównać ich zawartość tekstową',
    },
    'compare_truncated_msg': {
      'ar': 'الملفات طويلة جدًا — تمت مقارنة أول جزء منها فقط لتفادي البطء الشديد',
      'en': 'The files are too long — only the first part was compared to avoid severe slowness',
      'de': 'Die Dateien sind zu lang — nur der erste Teil wurde verglichen, um starke Verlangsamung zu vermeiden',
      'fr': "Les fichiers sont trop longs — seule la première partie a été comparée pour éviter une lenteur importante",
      'tr': 'Dosyalar çok uzun — aşırı yavaşlığı önlemek için yalnızca ilk kısım karşılaştırıldı',
      'pl': 'Pliki są zbyt długie — porównano tylko pierwszą część, aby uniknąć znacznego spowolnienia',
    },
    'compare_error_prefix': {
      'ar': 'خطأ أثناء المقارنة:', 'en': 'Error while comparing:', 'de': 'Fehler beim Vergleichen:',
      'fr': 'Erreur lors de la comparaison :', 'tr': 'Karşılaştırma sırasında hata:', 'pl': 'Błąd podczas porównywania:',
    },

    // ---------------- استخراج الجداول ----------------
    'table_note': {
      'ar': 'ملاحظة: الاستخراج تقريبي بالاعتماد على مواقع النصوص، وقد لا يكون دقيقًا 100% مع كل الجداول.',
      'en': 'Note: extraction is approximate, based on text positions, and may not be 100% accurate with every table.',
      'de': 'Hinweis: Die Extraktion ist ungefähr und basiert auf Textpositionen; sie ist möglicherweise nicht bei jeder Tabelle 100% genau.',
      'fr': "Remarque : l'extraction est approximative, basée sur les positions du texte, et peut ne pas être précise à 100 % pour chaque tableau.",
      'tr': 'Not: çıkarma, metin konumlarına dayalı yaklaşık bir işlemdir ve her tabloda %100 doğru olmayabilir.',
      'pl': 'Uwaga: ekstrakcja jest przybliżona, oparta na pozycjach tekstu, i może nie być w 100% dokładna dla każdej tabeli.',
    },
    'page_field_label': {
      'ar': 'الصفحة', 'en': 'Page', 'de': 'Seite', 'fr': 'Page', 'tr': 'Sayfa', 'pl': 'Strona',
    },
    'table_all_pages': {
      'ar': 'كل الصفحات', 'en': 'All Pages', 'de': 'Alle Seiten', 'fr': 'Toutes les pages', 'tr': 'Tüm Sayfalar', 'pl': 'Wszystkie strony',
    },
    'table_preview_btn': {
      'ar': 'معاينة الجدول', 'en': 'Preview Table', 'de': 'Tabelle in Vorschau anzeigen',
      'fr': 'Aperçu du tableau', 'tr': 'Tabloyu Önizle', 'pl': 'Podgląd tabeli',
    },
    'table_column_label': {
      'ar': 'عمود', 'en': 'Column', 'de': 'Spalte', 'fr': 'Colonne', 'tr': 'Sütun', 'pl': 'Kolumna',
    },
    'table_exporting': {
      'ar': 'جارٍ التصدير...', 'en': 'Exporting...', 'de': 'Wird exportiert...',
      'fr': "Exportation en cours...", 'tr': 'Dışa aktarılıyor...', 'pl': 'Eksportowanie...',
    },
    'table_export_btn': {
      'ar': 'تصدير إلى Excel', 'en': 'Export to Excel', 'de': 'Nach Excel exportieren',
      'fr': 'Exporter vers Excel', 'tr': "Excel'e Aktar", 'pl': 'Eksportuj do Excela',
    },
    'table_exported_title': {
      'ar': 'تم التصدير', 'en': 'Exported', 'de': 'Exportiert', 'fr': 'Exporté', 'tr': 'Dışa Aktarıldı', 'pl': 'Wyeksportowano',
    },
    'table_create_error': {
      'ar': 'تعذّر إنشاء ملف Excel', 'en': 'Could not create Excel file', 'de': 'Excel-Datei konnte nicht erstellt werden',
      'fr': 'Impossible de créer le fichier Excel', 'tr': 'Excel dosyası oluşturulamadı', 'pl': 'Nie można utworzyć pliku Excel',
    },

    // ---------------- القراءة الصوتية ----------------
    'tts_lang_label': {
      'ar': 'لغة القراءة', 'en': 'Reading Language', 'de': 'Vorlesesprache',
      'fr': 'Langue de lecture', 'tr': 'Okuma Dili', 'pl': 'Język czytania',
    },
    'tts_rate_label': {
      'ar': 'سرعة القراءة:', 'en': 'Reading speed:', 'de': 'Lesegeschwindigkeit:',
      'fr': 'Vitesse de lecture :', 'tr': 'Okuma hızı:', 'pl': 'Szybkość czytania:',
    },
    'tts_pitch_label': {
      'ar': 'طبقة الصوت:', 'en': 'Voice pitch:', 'de': 'Tonhöhe:',
      'fr': 'Hauteur de la voix :', 'tr': 'Ses tonu:', 'pl': 'Wysokość głosu:',
    },
    'tts_hint': {
      'ar': 'الصق أو اكتب النص المطلوب قراءته...', 'en': 'Paste or type the text to read...', 'de': 'Text zum Vorlesen einfügen oder eingeben...',
      'fr': 'Collez ou tapez le texte à lire...', 'tr': 'Okunacak metni yapıştırın veya yazın...', 'pl': 'Wklej lub wpisz tekst do przeczytania...',
    },
    'tts_pause': {
      'ar': 'إيقاف مؤقت', 'en': 'Pause', 'de': 'Pause', 'fr': 'Pause', 'tr': 'Duraklat', 'pl': 'Pauza',
    },
    'tts_play_btn': {
      'ar': 'قراءة', 'en': 'Read', 'de': 'Vorlesen', 'fr': 'Lire', 'tr': 'Oku', 'pl': 'Czytaj',
    },
    'tts_stop': {
      'ar': 'إيقاف', 'en': 'Stop', 'de': 'Stopp', 'fr': 'Arrêter', 'tr': 'Durdur', 'pl': 'Zatrzymaj',
    },

    // ---------------- الطباعة ----------------
    'print_preview_hint': {
      'ar': 'اختر ملف PDF لمعاينته وطباعته', 'en': 'Choose a PDF file to preview and print',
      'de': 'Wählen Sie eine PDF-Datei zur Vorschau und zum Drucken aus',
      'fr': 'Choisissez un fichier PDF à prévisualiser et à imprimer',
      'tr': 'Önizlemek ve yazdırmak için bir PDF dosyası seçin',
      'pl': 'Wybierz plik PDF, aby go podejrzeć i wydrukować',
    },
    'print_btn': {
      'ar': 'طباعة', 'en': 'Print', 'de': 'Drucken', 'fr': 'Imprimer', 'tr': 'Yazdır', 'pl': 'Drukuj',
    },

    // ---------------- إصلاح PDF ----------------
    'repair_note': {
      'ar': 'ملاحظة: هذه الأداة تحاول إصلاح مشاكل الفهرسة الداخلية الشائعة عبر إعادة بناء الملف. لا يمكنها إصلاح كل أنواع التلف — بعض الملفات التالفة بشدة لن يمكن فتحها إطلاقًا.',
      'en': 'Note: this tool tries to fix common internal indexing issues by rebuilding the file. It cannot fix every type of corruption — severely damaged files may not open at all.',
      'de': 'Hinweis: Dieses Tool versucht, häufige interne Indexierungsprobleme durch Neuaufbau der Datei zu beheben. Es kann nicht jede Art von Beschädigung beheben — stark beschädigte Dateien lassen sich möglicherweise gar nicht öffnen.',
      'fr': "Remarque : cet outil tente de corriger les problèmes d'indexation interne courants en reconstruisant le fichier. Il ne peut pas corriger tous les types de corruption — les fichiers gravement endommagés peuvent ne pas s'ouvrir du tout.",
      'tr': 'Not: bu araç, dosyayı yeniden oluşturarak yaygın dahili dizinleme sorunlarını gidermeye çalışır. Her türlü bozulmayı düzeltemez — ciddi şekilde hasarlı dosyalar hiç açılmayabilir.',
      'pl': 'Uwaga: to narzędzie próbuje naprawić typowe problemy z indeksowaniem wewnętrznym poprzez odbudowę pliku. Nie może naprawić każdego rodzaju uszkodzenia — poważnie uszkodzone pliki mogą się w ogóle nie otworzyć.',
    },
    'repair_open_fail': {
      'ar': 'تعذّر فتح الملف إطلاقًا — التلف شديد جدًا ولا يمكن إصلاحه بهذه الطريقة.',
      'en': 'Could not open the file at all — the damage is too severe to fix this way.',
      'de': 'Die Datei konnte überhaupt nicht geöffnet werden — der Schaden ist zu schwerwiegend, um ihn auf diese Weise zu beheben.',
      'fr': "Impossible d'ouvrir le fichier du tout — les dommages sont trop importants pour être réparés de cette façon.",
      'tr': 'Dosya hiç açılamadı — hasar bu şekilde onarılamayacak kadar ciddi.',
      'pl': 'Nie można było w ogóle otworzyć pliku — uszkodzenie jest zbyt poważne, aby naprawić je w ten sposób.',
    },
    'repair_success_prefix': {
      'ar': 'تم فتح الملف وإعادة بناء هيكله بنجاح',
      'en': 'The file was successfully opened and its structure rebuilt',
      'de': 'Die Datei wurde erfolgreich geöffnet und ihre Struktur neu aufgebaut',
      'fr': 'Le fichier a été ouvert avec succès et sa structure reconstruite',
      'tr': 'Dosya başarıyla açıldı ve yapısı yeniden oluşturuldu',
      'pl': 'Plik został pomyślnie otwarty, a jego struktura odbudowana',
    },
    'repair_success_suffix': {
      'ar': 'إذا كان الملف الأصلي يحتوي تلفًا بسيطًا بالفهرسة الداخلية، فالنسخة الجديدة يجب أن تعمل بشكل طبيعي.',
      'en': 'If the original file had minor internal indexing damage, the new copy should work normally.',
      'de': 'Wenn die Originaldatei nur geringfügige interne Indexierungsschäden hatte, sollte die neue Kopie normal funktionieren.',
      'fr': "Si le fichier original avait des dommages mineurs d'indexation interne, la nouvelle copie devrait fonctionner normalement.",
      'tr': 'Orijinal dosyada küçük dahili dizinleme hasarı varsa, yeni kopya normal şekilde çalışmalıdır.',
      'pl': 'Jeśli oryginalny plik miał niewielkie uszkodzenia indeksowania wewnętrznego, nowa kopia powinna działać normalnie.',
    },
    'repair_attempt_error': {
      'ar': 'تعذّرت المحاولة:', 'en': 'The attempt failed:', 'de': 'Der Versuch ist fehlgeschlagen:',
      'fr': "La tentative a échoué :", 'tr': 'Deneme başarısız oldu:', 'pl': 'Próba nie powiodła się:',
    },
    'repair_attempted_title': {
      'ar': 'تمت المحاولة', 'en': 'Attempt Completed', 'de': 'Versuch abgeschlossen',
      'fr': 'Tentative terminée', 'tr': 'Deneme Tamamlandı', 'pl': 'Próba zakończona',
    },
    'repair_attempt_btn': {
      'ar': 'محاولة الإصلاح', 'en': 'Attempt Repair', 'de': 'Reparatur versuchen',
      'fr': 'Tenter la réparation', 'tr': 'Onarmayı Dene', 'pl': 'Spróbuj naprawić',
    },
    'repair_attempting': {
      'ar': 'جارٍ المحاولة...', 'en': 'Attempting...', 'de': 'Wird versucht...',
      'fr': 'Tentative en cours...', 'tr': 'Deneniyor...', 'pl': 'Próbowanie...',
    },
    'repair_open_for_check': {
      'ar': 'فتح للتأكد', 'en': 'Open to Verify', 'de': 'Zur Überprüfung öffnen',
      'fr': 'Ouvrir pour vérifier', 'tr': 'Doğrulamak için Aç', 'pl': 'Otwórz, aby sprawdzić',
    },

    // ---------------- تعديل/حذف النص ----------------
    'redact_appbar_initial': {
      'ar': 'تعديل/حذف نص PDF', 'en': 'Edit/Remove PDF Text', 'de': 'PDF-Text bearbeiten/entfernen',
      'fr': 'Modifier/supprimer le texte PDF', 'tr': 'PDF Metnini Düzenle/Kaldır', 'pl': 'Edytuj/usuń tekst PDF',
    },
    'redact_appbar_active': {
      'ar': 'اسحب فوق النص لتعديله/حذفه', 'en': 'Drag over text to edit/remove it', 'de': 'Über Text ziehen, um ihn zu bearbeiten/entfernen',
      'fr': 'Faites glisser sur le texte pour le modifier/supprimer', 'tr': 'Düzenlemek/kaldırmak için metnin üzerine sürükleyin', 'pl': 'Przeciągnij nad tekstem, aby go edytować/usunąć',
    },
    'redact_dialog_title': {
      'ar': 'تعديل هذا الجزء', 'en': 'Edit This Section', 'de': 'Diesen Abschnitt bearbeiten',
      'fr': 'Modifier cette section', 'tr': 'Bu Bölümü Düzenle', 'pl': 'Edytuj tę sekcję',
    },
    'redact_dialog_desc': {
      'ar': 'اترك الحقل فارغًا للحذف فقط، أو اكتب نصًا بديلاً:',
      'en': 'Leave the field empty to just delete, or type replacement text:',
      'de': 'Lassen Sie das Feld leer, um nur zu löschen, oder geben Sie einen Ersatztext ein:',
      'fr': 'Laissez le champ vide pour supprimer uniquement, ou saisissez un texte de remplacement :',
      'tr': 'Sadece silmek için alanı boş bırakın veya değiştirme metni yazın:',
      'pl': 'Pozostaw pole puste, aby tylko usunąć, lub wpisz tekst zastępczy:',
    },
    'redact_field_hint': {
      'ar': 'نص بديل (اختياري)', 'en': 'Replacement text (optional)', 'de': 'Ersatztext (optional)',
      'fr': 'Texte de remplacement (facultatif)', 'tr': 'Değiştirme metni (isteğe bağlı)', 'pl': 'Tekst zastępczy (opcjonalnie)',
    },
    'redact_done_btn': {
      'ar': 'تم', 'en': 'Done', 'de': 'Fertig', 'fr': 'Terminé', 'tr': 'Tamam', 'pl': 'Gotowe',
    },
    'redact_note': {
      'ar': 'ملاحظة: هذه الأداة "تغطي" النص القديم بمستطيل أبيض وتكتب فوقه نصًا بديلًا اختياريًا — نفس طريقة أغلب برامج تحرير PDF لتعديل محتوى موجود.',
      'en': 'Note: this tool "covers" the old text with a white rectangle and optionally writes replacement text over it — the same approach most PDF editors use to modify existing content.',
      'de': 'Hinweis: Dieses Tool „überdeckt" den alten Text mit einem weißen Rechteck und schreibt optional Ersatztext darüber — der gleiche Ansatz, den die meisten PDF-Editoren zum Ändern vorhandener Inhalte verwenden.',
      'fr': "Remarque : cet outil « recouvre » l'ancien texte avec un rectangle blanc et écrit éventuellement un texte de remplacement par-dessus — la même approche utilisée par la plupart des éditeurs PDF pour modifier le contenu existant.",
      'tr': 'Not: bu araç eski metni beyaz bir dikdörtgenle "kapatır" ve isteğe bağlı olarak üzerine değiştirme metni yazar — çoğu PDF düzenleyicinin mevcut içeriği değiştirmek için kullandığı aynı yaklaşım.',
      'pl': 'Uwaga: to narzędzie „zakrywa" stary tekst białym prostokątem i opcjonalnie zapisuje na nim tekst zastępczy — takie samo podejście stosuje większość edytorów PDF do modyfikowania istniejącej zawartości.',
    },

    // ---------------- التوقيع الإلكتروني ----------------
    'sig_stamp_default_name': {
      'ar': 'ختم', 'en': 'Stamp', 'de': 'Stempel', 'fr': 'Tampon', 'tr': 'Kaşe', 'pl': 'Pieczątka',
    },
    'sig_saved_prefix': {
      'ar': 'تم حفظ', 'en': 'Saved', 'de': 'Gespeichert:', 'fr': 'Enregistré :', 'tr': 'Kaydedildi:', 'pl': 'Zapisano:',
    },
    'sig_saved_suffix': {
      'ar': 'بمكتبة الأختام', 'en': 'to the stamp library', 'de': 'in der Stempelbibliothek',
      'fr': 'dans la bibliothèque de tampons', 'tr': 'kaşe kitaplığına', 'pl': 'w bibliotece pieczątek',
    },
    'sig_name_dialog_title': {
      'ar': 'اسم للحفظ (اختياري)', 'en': 'Name to save (optional)', 'de': 'Name zum Speichern (optional)',
      'fr': 'Nom à enregistrer (facultatif)', 'tr': 'Kaydedilecek isim (isteğe bağlı)', 'pl': 'Nazwa do zapisania (opcjonalnie)',
    },
    'cancel': {
      'ar': 'إلغاء', 'en': 'Cancel', 'de': 'Abbrechen', 'fr': 'Annuler', 'tr': 'İptal', 'pl': 'Anuluj',
    },
    'sig_draw_first': {
      'ar': 'ارسم توقيعك أولًا', 'en': 'Draw your signature first', 'de': 'Zeichnen Sie zuerst Ihre Unterschrift',
      'fr': "Dessinez d'abord votre signature", 'tr': 'Önce imzanızı çizin', 'pl': 'Najpierw narysuj swój podpis',
    },
    'sig_save_question_title': {
      'ar': 'حفظ التوقيع؟', 'en': 'Save Signature?', 'de': 'Unterschrift speichern?',
      'fr': 'Enregistrer la signature ?', 'tr': 'İmza Kaydedilsin mi?', 'pl': 'Zapisać podpis?',
    },
    'sig_save_question_body': {
      'ar': 'هل تريد حفظ هذا التوقيع لاستخدامه لاحقًا بدون رسمه من جديد؟',
      'en': 'Do you want to save this signature to use it later without drawing it again?',
      'de': 'Möchten Sie diese Unterschrift speichern, um sie später zu verwenden, ohne sie erneut zu zeichnen?',
      'fr': 'Voulez-vous enregistrer cette signature pour l\'utiliser plus tard sans la redessiner ?',
      'tr': 'Bu imzayı tekrar çizmeden daha sonra kullanmak için kaydetmek ister misiniz?',
      'pl': 'Czy chcesz zapisać ten podpis, aby użyć go później bez ponownego rysowania?',
    },
    'sig_use_once': {
      'ar': 'استخدام مرة واحدة فقط', 'en': 'Use Once Only', 'de': 'Nur einmal verwenden',
      'fr': 'Utiliser une seule fois', 'tr': 'Sadece Bir Kez Kullan', 'pl': 'Użyj tylko raz',
    },
    'sig_save_future': {
      'ar': 'حفظ للمستقبل', 'en': 'Save for Later', 'de': 'Für später speichern',
      'fr': 'Enregistrer pour plus tard', 'tr': 'Sonrası İçin Kaydet', 'pl': 'Zapisz na później',
    },
    'sig_default_name': {
      'ar': 'توقيعي', 'en': 'My Signature', 'de': 'Meine Unterschrift',
      'fr': 'Ma signature', 'tr': 'İmzam', 'pl': 'Mój podpis',
    },
    'sig_place_first': {
      'ar': 'اضغط على مكان العلامة بالصفحة أولًا', 'en': 'Tap the placement location on the page first', 'de': 'Tippen Sie zuerst auf die Platzierungsstelle auf der Seite',
      'fr': "Appuyez d'abord sur l'emplacement sur la page", 'tr': 'Önce sayfadaki yerleştirme konumuna dokunun', 'pl': 'Najpierw dotknij miejsca umieszczenia na stronie',
    },
    'sig_invalid_page': {
      'ar': 'رقم صفحة غير صالح', 'en': 'Invalid page number', 'de': 'Ungültige Seitenzahl',
      'fr': 'Numéro de page invalide', 'tr': 'Geçersiz sayfa numarası', 'pl': 'Nieprawidłowy numer strony',
    },
    'sig_signed_title': {
      'ar': 'تم التوقيع بنجاح', 'en': 'Signed Successfully', 'de': 'Erfolgreich signiert',
      'fr': 'Signé avec succès', 'tr': 'Başarıyla İmzalandı', 'pl': 'Pomyślnie podpisano',
    },
    'sig_draw_new': {
      'ar': 'رسم توقيع جديد', 'en': 'Draw New Signature', 'de': 'Neue Unterschrift zeichnen',
      'fr': 'Dessiner une nouvelle signature', 'tr': 'Yeni İmza Çiz', 'pl': 'Narysuj nowy podpis',
    },
    'sig_add_stamp_image': {
      'ar': 'إضافة ختم من صورة', 'en': 'Add Stamp from Image', 'de': 'Stempel aus Bild hinzufügen',
      'fr': "Ajouter un tampon depuis une image", 'tr': 'Görselden Kaşe Ekle', 'pl': 'Dodaj pieczątkę ze zdjęcia',
    },
    'sig_saved_marks_title': {
      'ar': 'التواقيع والأختام المحفوظة', 'en': 'Saved Signatures & Stamps', 'de': 'Gespeicherte Unterschriften & Stempel',
      'fr': 'Signatures et tampons enregistrés', 'tr': 'Kayıtlı İmzalar ve Kaşeler', 'pl': 'Zapisane podpisy i pieczątki',
    },
    'sig_no_marks': {
      'ar': 'ما في توقيعات أو أختام محفوظة بعد', 'en': 'No saved signatures or stamps yet', 'de': 'Noch keine gespeicherten Unterschriften oder Stempel',
      'fr': 'Aucune signature ou tampon enregistré pour le moment', 'tr': 'Henüz kayıtlı imza veya kaşe yok', 'pl': 'Brak zapisanych podpisów lub pieczątek',
    },
    'sig_draw_appbar': {
      'ar': 'ارسم توقيعك', 'en': 'Draw Your Signature', 'de': 'Zeichnen Sie Ihre Unterschrift',
      'fr': 'Dessinez votre signature', 'tr': 'İmzanızı Çizin', 'pl': 'Narysuj swój podpis',
    },
    'clear': {
      'ar': 'مسح', 'en': 'Clear', 'de': 'Löschen', 'fr': 'Effacer', 'tr': 'Temizle', 'pl': 'Wyczyść',
    },
    'continue_btn': {
      'ar': 'متابعة', 'en': 'Continue', 'de': 'Weiter', 'fr': 'Continuer', 'tr': 'Devam Et', 'pl': 'Kontynuuj',
    },
    'sig_place_appbar': {
      'ar': 'اضغط لتحديد مكان العلامة', 'en': 'Tap to Set Mark Position', 'de': 'Tippen, um die Position der Markierung festzulegen',
      'fr': "Appuyez pour définir l'emplacement de la marque", 'tr': 'İşaretin Konumunu Belirlemek İçin Dokunun', 'pl': 'Dotknij, aby ustawić pozycję znaku',
    },

    // ---------------- إدارة التواقيع ----------------
    'manage_sig_empty': {
      'ar': 'لا يوجد توقيعات أو أختام محفوظة بعد.\nاحفظ واحدًا من شاشة "توقيع إلكتروني".',
      'en': 'No saved signatures or stamps yet.\nSave one from the "E-Signature" screen.',
      'de': 'Noch keine gespeicherten Unterschriften oder Stempel.\nSpeichern Sie eine über den Bildschirm „Elektronische Signatur".',
      'fr': 'Aucune signature ou tampon enregistré pour le moment.\nEnregistrez-en un depuis l\'écran « Signature électronique ».',
      'tr': 'Henüz kayıtlı imza veya kaşe yok.\n"Elektronik İmza" ekranından bir tane kaydedin.',
      'pl': 'Brak zapisanych podpisów lub pieczątek.\nZapisz jeden na ekranie "Podpis elektroniczny".',
    },
    'mark_type_signature': {
      'ar': 'توقيع', 'en': 'Signature', 'de': 'Unterschrift', 'fr': 'Signature', 'tr': 'İmza', 'pl': 'Podpis',
    },
    'mark_type_stamp': {
      'ar': 'ختم', 'en': 'Stamp', 'de': 'Stempel', 'fr': 'Tampon', 'tr': 'Kaşe', 'pl': 'Pieczątka',
    },

    // ---------------- تحويل Word ----------------
    'word_note': {
      'ar': 'ملاحظة: يستخرج النص فقط من ملف Word، بدون تنسيق أو صور أو جداول من الملف الأصلي.',
      'en': 'Note: extracts text only from the Word file, without formatting, images, or tables from the original.',
      'de': 'Hinweis: extrahiert nur den Text aus der Word-Datei, ohne Formatierung, Bilder oder Tabellen aus dem Original.',
      'fr': "Remarque : extrait uniquement le texte du fichier Word, sans mise en forme, images ou tableaux de l'original.",
      'tr': 'Not: yalnızca Word dosyasından metni çıkarır, orijinaldeki biçimlendirme, görsel veya tablolar olmadan.',
      'pl': 'Uwaga: wyodrębnia tylko tekst z pliku Word, bez formatowania, obrazów lub tabel z oryginału.',
    },
    'word_pick_hint': {
      'ar': 'اختيار ملف Word (.docx)', 'en': 'Select Word File (.docx)', 'de': 'Word-Datei auswählen (.docx)',
      'fr': 'Sélectionner un fichier Word (.docx)', 'tr': 'Word Dosyası Seç (.docx)', 'pl': 'Wybierz plik Word (.docx)',
    },
    'word_exporting': {
      'ar': 'جارٍ التصدير...', 'en': 'Exporting...', 'de': 'Wird exportiert...',
      'fr': "Exportation en cours...", 'tr': 'Dışa aktarılıyor...', 'pl': 'Eksportowanie...',
    },
    'word_export_btn': {
      'ar': 'تصدير كـ PDF', 'en': 'Export as PDF', 'de': 'Als PDF exportieren',
      'fr': 'Exporter en PDF', 'tr': 'PDF Olarak Dışa Aktar', 'pl': 'Eksportuj jako PDF',
    },
    'word_converted_title': {
      'ar': 'تم التحويل بنجاح', 'en': 'Converted Successfully', 'de': 'Erfolgreich konvertiert',
      'fr': 'Converti avec succès', 'tr': 'Başarıyla Dönüştürüldü', 'pl': 'Pomyślnie przekonwertowano',
    },
    'word_converted_note': {
      'ar': 'تذكير: النص فقط تم تحويله، بدون تنسيق أو صور من الملف الأصلي.',
      'en': 'Reminder: only the text was converted, without formatting or images from the original file.',
      'de': 'Hinweis: Nur der Text wurde konvertiert, ohne Formatierung oder Bilder aus der Originaldatei.',
      'fr': "Rappel : seul le texte a été converti, sans mise en forme ni images du fichier original.",
      'tr': 'Hatırlatma: yalnızca metin dönüştürüldü, orijinal dosyadaki biçimlendirme veya görseller olmadan.',
      'pl': 'Przypomnienie: przekonwertowano tylko tekst, bez formatowania lub obrazów z oryginalnego pliku.',
    },

    // ---------------- صور ↔ PDF ----------------
    'img2pdf_add_images': {
      'ar': 'إضافة صور', 'en': 'Add Images', 'de': 'Bilder hinzufügen',
      'fr': 'Ajouter des images', 'tr': 'Görsel Ekle', 'pl': 'Dodaj obrazy',
    },
    'img2pdf_hint': {
      'ar': 'أضف صورة أو أكثر، ورتّبهم بالسحب حسب ترتيب صفحات PDF',
      'en': 'Add one or more images, and reorder them by dragging to set the PDF page order',
      'de': 'Fügen Sie ein oder mehrere Bilder hinzu und ordnen Sie sie per Ziehen für die PDF-Seitenreihenfolge an',
      'fr': "Ajoutez une ou plusieurs images, et réorganisez-les par glisser-déposer pour définir l'ordre des pages PDF",
      'tr': 'Bir veya daha fazla görsel ekleyin ve PDF sayfa sırasını ayarlamak için sürükleyerek düzenleyin',
      'pl': 'Dodaj jeden lub więcej obrazów i zmień ich kolejność, przeciągając, aby ustawić kolejność stron PDF',
    },
    'img2pdf_creating': {
      'ar': 'جارٍ الإنشاء...', 'en': 'Creating...', 'de': 'Wird erstellt...',
      'fr': 'Création en cours...', 'tr': 'Oluşturuluyor...', 'pl': 'Tworzenie...',
    },
    'img2pdf_create_btn': {
      'ar': 'إنشاء PDF', 'en': 'Create PDF', 'de': 'PDF erstellen',
      'fr': 'Créer un PDF', 'tr': 'PDF Oluştur', 'pl': 'Utwórz PDF',
    },

    // ---------------- PDF إلى صور ----------------
    'pdf2img_convert_error': {
      'ar': 'خطأ أثناء التحويل:', 'en': 'Error during conversion:', 'de': 'Fehler bei der Konvertierung:',
      'fr': 'Erreur lors de la conversion :', 'tr': 'Dönüştürme sırasında hata:', 'pl': 'Błąd podczas konwersji:',
    },
    'pdf2img_converting': {
      'ar': 'جارٍ التحويل...', 'en': 'Converting...', 'de': 'Wird konvertiert...',
      'fr': 'Conversion en cours...', 'tr': 'Dönüştürülüyor...', 'pl': 'Konwertowanie...',
    },
    'pdf2img_convert_btn': {
      'ar': 'تحويل إلى صور', 'en': 'Convert to Images', 'de': 'In Bilder konvertieren',
      'fr': 'Convertir en images', 'tr': "Görsellere Dönüştür", 'pl': 'Konwertuj na obrazy',
    },
    'pdf2img_ready_suffix': {
      'ar': 'صورة جاهزة', 'en': 'image(s) ready', 'de': 'Bild(er) fertig',
      'fr': 'image(s) prête(s)', 'tr': 'görsel hazır', 'pl': 'obraz(y) gotowe',
    },
    'pdf2img_share_btn': {
      'ar': 'مشاركة/حفظ الصور', 'en': 'Share/Save Images', 'de': 'Bilder teilen/speichern',
      'fr': 'Partager/enregistrer les images', 'tr': 'Görselleri Paylaş/Kaydet', 'pl': 'Udostępnij/zapisz obrazy',
    },

    // ---------------- الباركود ----------------
    'barcode_none_found': {
      'ar': 'لم يتم العثور على أي رمز بالصورة', 'en': 'No code found in the image', 'de': 'Kein Code im Bild gefunden',
      'fr': "Aucun code trouvé dans l'image", 'tr': 'Görselde kod bulunamadı', 'pl': 'Nie znaleziono kodu na obrazie',
    },
    'barcode_scan_error': {
      'ar': 'خطأ أثناء المسح:', 'en': 'Error while scanning:', 'de': 'Fehler beim Scannen:',
      'fr': 'Erreur lors du scan :', 'tr': 'Tarama sırasında hata:', 'pl': 'Błąd podczas skanowania:',
    },
    'barcode_scan_from_pdf': {
      'ar': 'مسح من صفحة PDF', 'en': 'Scan from PDF Page', 'de': 'Von PDF-Seite scannen',
      'fr': 'Scanner depuis une page PDF', 'tr': 'PDF Sayfasından Tara', 'pl': 'Skanuj ze strony PDF',
    },
    'barcode_pick_page_title': {
      'ar': 'اختر صفحة للمسح', 'en': 'Choose a Page to Scan', 'de': 'Wählen Sie eine zu scannende Seite',
      'fr': 'Choisissez une page à scanner', 'tr': 'Taranacak Sayfayı Seçin', 'pl': 'Wybierz stronę do zeskanowania',
    },

    // ---------------- الإملاء الصوتي ----------------
    'dict_unavailable': {
      'ar': 'التعرف الصوتي غير متاح على هذا الجهاز', 'en': 'Speech recognition is not available on this device',
      'de': 'Spracherkennung ist auf diesem Gerät nicht verfügbar', 'fr': "La reconnaissance vocale n'est pas disponible sur cet appareil",
      'tr': 'Ses tanıma bu cihazda mevcut değil', 'pl': 'Rozpoznawanie mowy nie jest dostępne na tym urządzeniu',
    },
    'dict_hint': {
      'ar': 'اضغط زر الميكروفون وابدأ الكلام...', 'en': 'Tap the microphone button and start speaking...',
      'de': 'Tippen Sie auf die Mikrofontaste und beginnen Sie zu sprechen...',
      'fr': 'Appuyez sur le bouton du microphone et commencez à parler...',
      'tr': 'Mikrofon düğmesine dokunun ve konuşmaya başlayın...',
      'pl': 'Dotknij przycisku mikrofonu i zacznij mówić...',
    },
    'dict_listening': {
      'ar': '...جارٍ الاستماع', 'en': 'Listening...', 'de': 'Wird zugehört...',
      'fr': 'Écoute en cours...', 'tr': 'Dinleniyor...', 'pl': 'Słuchanie...',
    },
    'dict_default_title': {
      'ar': 'نص مُملى صوتيًا', 'en': 'Voice-Dictated Text', 'de': 'Sprachdiktierter Text',
      'fr': 'Texte dicté vocalement', 'tr': 'Sesli Dikte Edilen Metin', 'pl': 'Tekst dyktowany głosowo',
    },

    // ---------------- كاميرا المستندات ----------------
    'cam_permission_needed': {
      'ar': 'التطبيق يحتاج إذن الوصول للكاميرا لاستخدام هذه الميزة',
      'en': 'The app needs camera access permission to use this feature',
      'de': 'Die App benötigt die Kameraberechtigung, um diese Funktion zu nutzen',
      'fr': "L'application a besoin de l'autorisation d'accès à la caméra pour utiliser cette fonctionnalité",
      'tr': 'Uygulamanın bu özelliği kullanabilmesi için kamera erişim izni gerekir',
      'pl': 'Aplikacja potrzebuje uprawnień dostępu do aparatu, aby korzystać z tej funkcji',
    },
    'cam_no_camera': {
      'ar': 'لا توجد كاميرا متاحة على هذا الجهاز', 'en': 'No camera available on this device',
      'de': 'Keine Kamera auf diesem Gerät verfügbar', 'fr': "Aucune caméra disponible sur cet appareil",
      'tr': 'Bu cihazda kullanılabilir kamera yok', 'pl': 'Brak dostępnego aparatu na tym urządzeniu',
    },
    'cam_open_error': {
      'ar': 'تعذّر فتح الكاميرا:', 'en': 'Could not open the camera:', 'de': 'Kamera konnte nicht geöffnet werden:',
      'fr': "Impossible d'ouvrir la caméra :", 'tr': 'Kamera açılamadı:', 'pl': 'Nie można otworzyć aparatu:',
    },
    'cam_capture_error': {
      'ar': 'تعذّر الالتقاط:', 'en': 'Could not capture:', 'de': 'Aufnahme fehlgeschlagen:',
      'fr': 'Impossible de capturer :', 'tr': 'Yakalama başarısız:', 'pl': 'Nie można przechwycić:',
    },
    'cam_appbar': {
      'ar': 'صوّر المستند', 'en': 'Photograph the Document', 'de': 'Dokument fotografieren',
      'fr': 'Photographier le document', 'tr': 'Belgeyi Fotoğrafla', 'pl': 'Sfotografuj dokument',
    },
    'cam_align_hint': {
      'ar': 'حاذِ حواف الورقة مع الإطار', 'en': 'Align the paper edges with the frame', 'de': 'Richten Sie die Papierkanten am Rahmen aus',
      'fr': 'Alignez les bords du papier avec le cadre', 'tr': 'Kağıt kenarlarını çerçeveyle hizalayın', 'pl': 'Wyrównaj krawędzie papieru z ramką',
    },

    // ---------------- مدير الملفات ----------------
    'fm_appbar': {
      'ar': 'مدير الملفات', 'en': 'File Manager', 'de': 'Dateimanager',
      'fr': 'Gestionnaire de fichiers', 'tr': 'Dosya Yöneticisi', 'pl': 'Menedżer plików',
    },
    'fm_tab_all': {
      'ar': 'الكل', 'en': 'All', 'de': 'Alle', 'fr': 'Tous', 'tr': 'Tümü', 'pl': 'Wszystkie',
    },
    'fm_tab_favorites': {
      'ar': 'المفضلة', 'en': 'Favorites', 'de': 'Favoriten', 'fr': 'Favoris', 'tr': 'Favoriler', 'pl': 'Ulubione',
    },
    'fm_tab_trash': {
      'ar': 'سلة المحذوفات', 'en': 'Trash', 'de': 'Papierkorb', 'fr': 'Corbeille', 'tr': 'Çöp Kutusu', 'pl': 'Kosz',
    },
    'fm_search_hint': {
      'ar': 'ابحث باسم الملف...', 'en': 'Search by file name...', 'de': 'Nach Dateiname suchen...',
      'fr': 'Rechercher par nom de fichier...', 'tr': 'Dosya adına göre ara...', 'pl': 'Szukaj według nazwy pliku...',
    },
    'fm_trash_empty': {
      'ar': 'سلة المحذوفات فارغة', 'en': 'Trash is empty', 'de': 'Papierkorb ist leer',
      'fr': 'La corbeille est vide', 'tr': 'Çöp kutusu boş', 'pl': 'Kosz jest pusty',
    },
    'fm_no_files': {
      'ar': 'لا توجد ملفات هنا بعد', 'en': 'No files here yet', 'de': 'Noch keine Dateien hier',
      'fr': "Pas encore de fichiers ici", 'tr': 'Burada henüz dosya yok', 'pl': 'Brak plików tutaj',
    },
    'fm_file_missing': {
      'ar': 'الملف غير موجود على الجهاز', 'en': 'File not found on device', 'de': 'Datei nicht auf dem Gerät gefunden',
      'fr': "Fichier introuvable sur l'appareil", 'tr': 'Dosya cihazda bulunamadı', 'pl': 'Nie znaleziono pliku na urządzeniu',
    },
    'fm_moved_to_trash': {
      'ar': 'انتقل لسلة المحذوفات', 'en': 'Moved to trash', 'de': 'In den Papierkorb verschoben',
      'fr': 'Déplacé vers la corbeille', 'tr': 'Çöp kutusuna taşındı', 'pl': 'Przeniesiono do kosza',
    },
    'fm_delete_permanent_title': {
      'ar': 'حذف نهائي', 'en': 'Permanent Delete', 'de': 'Endgültig löschen',
      'fr': 'Suppression définitive', 'tr': 'Kalıcı Silme', 'pl': 'Trwałe usunięcie',
    },
    'fm_delete_permanent_body_prefix': {
      'ar': 'هل تريد حذف', 'en': 'Do you want to delete', 'de': 'Möchten Sie',
      'fr': 'Voulez-vous supprimer', 'tr': 'Silmek istiyor musunuz:', 'pl': 'Czy chcesz usunąć',
    },
    'fm_delete_permanent_body_suffix': {
      'ar': 'نهائيًا؟ لا يمكن التراجع عن هذا.', 'en': 'permanently? This cannot be undone.', 'de': 'endgültig löschen? Dies kann nicht rückgängig gemacht werden.',
      'fr': 'définitivement ? Cette action est irréversible.', 'tr': 'kalıcı olarak? Bu geri alınamaz.', 'pl': 'trwale? Tego nie można cofnąć.',
    },

    // ---------------- التحقق من التحديثات ----------------
    'updates_section_title': {
      'ar': 'التحديثات', 'en': 'Updates', 'de': 'Updates', 'fr': 'Mises à jour', 'tr': 'Güncellemeler', 'pl': 'Aktualizacje',
    },
    'current_version_label': {
      'ar': 'الإصدار الحالي:', 'en': 'Current version:', 'de': 'Aktuelle Version:',
      'fr': 'Version actuelle :', 'tr': 'Mevcut sürüm:', 'pl': 'Bieżąca wersja:',
    },
    'new_version_label': {
      'ar': 'الإصدار الجديد:', 'en': 'New version:', 'de': 'Neue Version:',
      'fr': 'Nouvelle version :', 'tr': 'Yeni sürüm:', 'pl': 'Nowa wersja:',
    },
    'checking_version': {
      'ar': 'جارٍ التحقق من رقم الإصدار...', 'en': 'Checking version number...', 'de': 'Versionsnummer wird geprüft...',
      'fr': 'Vérification du numéro de version...', 'tr': 'Sürüm numarası kontrol ediliyor...', 'pl': 'Sprawdzanie numeru wersji...',
    },
    'checking_updates': {
      'ar': 'جارٍ التحقق...', 'en': 'Checking...', 'de': 'Wird geprüft...',
      'fr': 'Vérification...', 'tr': 'Kontrol ediliyor...', 'pl': 'Sprawdzanie...',
    },
    'check_updates_btn': {
      'ar': 'التحقق من وجود تحديثات', 'en': 'Check for Updates', 'de': 'Nach Updates suchen',
      'fr': 'Rechercher des mises à jour', 'tr': 'Güncellemeleri Kontrol Et', 'pl': 'Sprawdź aktualizacje',
    },
    'update_available_title': {
      'ar': 'يوجد تحديث جديد! 🎉', 'en': 'A new update is available! 🎉', 'de': 'Ein neues Update ist verfügbar! 🎉',
      'fr': 'Une nouvelle mise à jour est disponible ! 🎉', 'tr': 'Yeni bir güncelleme mevcut! 🎉', 'pl': 'Dostępna jest nowa aktualizacja! 🎉',
    },
    'later': {
      'ar': 'لاحقًا', 'en': 'Later', 'de': 'Später', 'fr': 'Plus tard', 'tr': 'Daha Sonra', 'pl': 'Później',
    },
    'download_update_btn': {
      'ar': 'تنزيل التحديث', 'en': 'Download Update', 'de': 'Update herunterladen',
      'fr': 'Télécharger la mise à jour', 'tr': 'Güncellemeyi İndir', 'pl': 'Pobierz aktualizację',
    },
    'update_uptodate_msg': {
      'ar': 'التطبيق محدَّث لآخر إصدار ✅', 'en': 'The app is up to date ✅', 'de': 'Die App ist auf dem neuesten Stand ✅',
      'fr': "L'application est à jour ✅", 'tr': 'Uygulama güncel ✅', 'pl': 'Aplikacja jest aktualna ✅',
    },

    // ---------------- فئات مركز أدوات PDF ----------------
    'cat_editing': {
      'ar': 'تحرير ومحتوى', 'en': 'Editing & Content', 'de': 'Bearbeitung & Inhalt',
      'fr': 'Édition et contenu', 'tr': 'Düzenleme ve İçerik', 'pl': 'Edycja i zawartość',
    },
    'cat_security': {
      'ar': 'الحماية والأمان', 'en': 'Security & Protection', 'de': 'Sicherheit & Schutz',
      'fr': 'Sécurité et protection', 'tr': 'Güvenlik ve Koruma', 'pl': 'Bezpieczeństwo i ochrona',
    },
    'cat_signing': {
      'ar': 'التوقيع', 'en': 'Signing', 'de': 'Signieren', 'fr': 'Signature', 'tr': 'İmzalama', 'pl': 'Podpisywanie',
    },
    'cat_conversion': {
      'ar': 'تحويل الصيغ', 'en': 'Format Conversion', 'de': 'Formatkonvertierung',
      'fr': 'Conversion de format', 'tr': 'Format Dönüştürme', 'pl': 'Konwersja formatu',
    },
    'cat_utilities': {
      'ar': 'أدوات إضافية', 'en': 'Additional Tools', 'de': 'Zusätzliche Werkzeuge',
      'fr': 'Outils supplémentaires', 'tr': 'Ek Araçlar', 'pl': 'Dodatkowe narzędzia',
    },
  };

  /// يرجع نص الترجمة المطابق لـ [languageCode]، ويعود تلقائيًا
  /// للإنجليزية إذا كانت الترجمة غير متوفرة لتلك اللغة، وأخيرًا للمفتاح نفسه.
  static String t(String key, String languageCode) {
    final entry = _dict[key];
    if (entry == null) return key;
    return entry[languageCode] ?? entry['en'] ?? key;
  }
}
