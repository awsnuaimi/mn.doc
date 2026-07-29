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
  static final RegExp _wordSplitter = RegExp(r'[\s،,\.]+');

  static final Set<String> _stopWords = {
    'من', 'إلى', 'على', 'في', 'عن', 'مع', 'هذا', 'هذه', 'ذلك', 'التي', 'الذي',
    'و', 'أو', 'ثم', 'كما', 'قد', 'لا', 'لم', 'لن', 'ما', 'هو', 'هي', 'كان',
    'كانت', 'the', 'a', 'an', 'of', 'to', 'in', 'on', 'and', 'or', 'is', 'are',
    'was', 'were', 'for', 'with', 'that', 'this',
  };

  /// يلخّص [text] ويعيد أهم [sentenceCount] جملة (افتراضيًا 5).
  static String summarize(String text, {int sentenceCount = 5}) {
    final sentences = text
        .split(_sentenceSplitter)
        .map((s) => s.trim())
        .where((s) => s.length > 8)
        .toList();

    if (sentences.length <= sentenceCount) return sentences.join(' ');

    // حساب تكرار الكلمات (باستثناء كلمات الوقف الشائعة)
    final wordFreq = <String, int>{};
    for (final sentence in sentences) {
      for (final word in sentence.toLowerCase().split(_wordSplitter)) {
        if (word.isEmpty || _stopWords.contains(word)) continue;
        wordFreq[word] = (wordFreq[word] ?? 0) + 1;
      }
    }

    // حساب درجة أهمية كل جملة
    final scores = <int, double>{};
    for (var i = 0; i < sentences.length; i++) {
      final words = sentences[i].toLowerCase().split(_wordSplitter);
      double score = 0;
      for (final w in words) {
        score += (wordFreq[w] ?? 0).toDouble();
      }
      // تطبيع حسب طول الجملة لتفادي تفضيل الجمل الطويلة فقط
      scores[i] = words.isEmpty ? 0 : score / words.length;
    }

    final topIndices = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final selected = topIndices.take(sentenceCount).map((e) => e.key).toList()..sort();

    return selected.map((i) => sentences[i]).join(' ');
  }
}
