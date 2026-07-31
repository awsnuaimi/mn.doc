/// تلخيص استخراجي (Extractive Summarization) يعمل بالكامل على الجهاز
/// بدون إنترنت وبدون أي مفتاح API — مجاني للأبد.
///
/// الفكرة: تُقسَّم الفقرة إلى جمل، وتُحسب "أهمية" كل جملة بناءً على
/// تكرار الكلمات المهمة فيها (خوارزمية تشبه TF مبسّطة)، ثم تُختار
/// أعلى الجمل أهمية بترتيبها الأصلي لتكوين ملخص متماسك.
///
/// هذه الطريقة لا تصل لجودة نموذج لغوي كبير، لكنها فورية ومجانية
/// ولا تحتاج اتصال إنترنت إطلاقًا — مناسبة كخيار افتراضي أو احتياطي
/// عند عدم توفر مفتاح Gemini API.
class LocalSummarizer {
  static final RegExp _sentenceSplitter = RegExp(r'(?<=[\.\!\?؟\n])\s+');
  static final RegExp _wordSplitter = RegExp(r'''[\s،,\.:;"' \(\)\[\]\{\}/\\—–…]+''');
  static final RegExp _pureNumber = RegExp(r'^[0-9.,%٠-٩]+$');

  // حد أقصى لطول النص المُعالَج لتفادي استهلاك وقت/ذاكرة زائد مع
  // مستندات ضخمة جدًا (يُعالَج أول 300 ألف حرف فقط تقريبًا)
  static const int _maxInputLength = 300000;

  static final Set<String> _stopWords = {
    'من', 'إلى', 'على', 'في', 'عن', 'مع', 'هذا', 'هذه', 'ذلك', 'التي', 'الذي',
    'و', 'أو', 'ثم', 'كما', 'قد', 'لا', 'لم', 'لن', 'ما', 'هو', 'هي', 'كان',
    'كانت', 'إن', 'أن', 'هناك', 'أي', 'أيضا', 'أيضًا', 'إذ', 'بعد', 'قبل',
    'حتى', 'كل', 'جميع', 'بعض', 'أكثر', 'أقل', 'بين', 'ضمن', 'حول', 'عند',
    'عندما', 'حيث', 'لدى', 'دون', 'بدون', 'نحو', 'إذا', 'لو', 'لكن', 'بل',
    'the', 'a', 'an', 'of', 'to', 'in', 'on', 'and', 'or', 'is', 'are',
    'was', 'were', 'for', 'with', 'that', 'this', 'it', 'as', 'by', 'at',
    'be', 'been', 'has', 'have', 'had', 'not', 'but', 'if', 'so', 'than',
  };

  /// يطبّع الحروف العربية المختلفة الأشكال لنفس الحرف الأساسي (مثل
  /// أ/إ/آ/ٱ → ا)، ويزيل التشكيل — بدونها تُحسب كلمات متطابقة معنويًا
  /// (زي "إدارة" و"ادارة") كأنها كلمات مختلفة تمامًا، مما يضعف دقة التلخيص.
  static String _normalizeArabic(String input) {
    var result = input;
    result = result.replaceAll(RegExp('[أإآٱ]'), 'ا');
    result = result.replaceAll(RegExp('[ًٌٍَُِّْـ]'), ''); // إزالة التشكيل والتطويل
    return result;
  }

  /// يلخّص [text] ويعيد أهم [sentenceCount] جملة (افتراضيًا 5).
  static String summarize(String text, {int sentenceCount = 5}) {
    final limitedText = text.length > _maxInputLength ? text.substring(0, _maxInputLength) : text;

    final sentences = limitedText
        .split(_sentenceSplitter)
        .map((s) => s.trim())
        .where((s) => s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length >= 2)
        .toList();

    if (sentences.length <= sentenceCount) return sentences.join(' ');

    // حساب تكرار الكلمات (باستثناء كلمات الوقف الشائعة والأرقام المجردة)
    final wordFreq = <String, int>{};
    for (final sentence in sentences) {
      for (final rawWord in _normalizeArabic(sentence.toLowerCase()).split(_wordSplitter)) {
        final word = rawWord.trim();
        if (word.isEmpty || _stopWords.contains(word) || _pureNumber.hasMatch(word)) continue;
        wordFreq[word] = (wordFreq[word] ?? 0) + 1;
      }
    }

    // حساب درجة أهمية كل جملة
    final scores = <int, double>{};
    for (var i = 0; i < sentences.length; i++) {
      final words = _normalizeArabic(sentences[i].toLowerCase()).split(_wordSplitter).where((w) => w.isNotEmpty).toList();
      double score = 0;
      for (final w in words) {
        score += (wordFreq[w] ?? 0).toDouble();
      }
      // تطبيع حسب طول الجملة لتفادي تفضيل الجمل الطويلة فقط
      var sentenceScore = words.isEmpty ? 0.0 : score / words.length;
      // وزن إضافي بسيط للجمل الأولى والأخيرة (غالبًا تحمل مقدمة/خلاصة)
      if (i < 2 || i >= sentences.length - 2) sentenceScore *= 1.15;
      scores[i] = sentenceScore;
    }

    final topIndices = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final selected = topIndices.take(sentenceCount).map((e) => e.key).toList()..sort();

    return selected.map((i) => sentences[i]).join(' ');
  }
}
