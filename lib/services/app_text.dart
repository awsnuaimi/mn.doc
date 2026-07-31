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
      'ar': 'ملاحظة: الترجمة حاليًا مفعّلة بالشاشة الرئيسية وهذه الشاشة فقط. باقي شاشات التطبيق ستُترجم بمرحلة قادمة.',
      'en': 'Note: translation currently applies to the Home and Settings screens only. Other screens will be translated in a future update.',
      'de': 'Hinweis: Die Übersetzung gilt derzeit nur für Start- und Einstellungsbildschirm. Andere Bildschirme werden in einem zukünftigen Update übersetzt.',
      'fr': "Remarque : la traduction s'applique actuellement uniquement à l'écran d'accueil et aux paramètres. Les autres écrans seront traduits lors d'une future mise à jour.",
      'tr': 'Not: Çeviri şu anda yalnızca Ana Sayfa ve Ayarlar ekranlarında geçerlidir. Diğer ekranlar gelecekteki bir güncellemede çevrilecektir.',
      'pl': 'Uwaga: tłumaczenie dotyczy obecnie tylko ekranu głównego i ustawień. Pozostałe ekrany zostaną przetłumaczone w przyszłej aktualizacji.',
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
  };

  /// يرجع نص الترجمة المطابق لـ [languageCode]، ويعود تلقائيًا
  /// للإنجليزية إذا كانت الترجمة غير متوفرة لتلك اللغة، وأخيرًا للمفتاح نفسه.
  static String t(String key, String languageCode) {
    final entry = _dict[key];
    if (entry == null) return key;
    return entry[languageCode] ?? entry['en'] ?? key;
  }
}
