/// نوع التغيير بين كلمة بملف ونظيرتها بالملف الآخر.
enum DiffType { equal, added, removed }

class DiffToken {
  final String text;
  final DiffType type;
  const DiffToken(this.text, this.type);
}

/// مقارنة نصية على مستوى الكلمات باستخدام Hirschberg LCS.
///
/// بخلاف جدول LCS التقليدي الذي يستهلك O(n*m) من الذاكرة، هذه النسخة
/// تعيد بناء نفس نوع المقارنة تقريبًا بذاكرة O(min(n,m)) مع بقاء الزمن
/// O(n*m). هذا مهم على الهواتف عند مقارنة مستندات طويلة.
class TextDiff {
  static List<DiffToken> compare(String oldText, String newText) {
    final oldWords = _words(oldText);
    final newWords = _words(newText);
    final common = _hirschberg(oldWords, newWords);

    final result = <DiffToken>[];
    var i = 0;
    var j = 0;

    for (final word in common) {
      while (i < oldWords.length && oldWords[i] != word) {
        result.add(DiffToken(oldWords[i++], DiffType.removed));
      }
      while (j < newWords.length && newWords[j] != word) {
        result.add(DiffToken(newWords[j++], DiffType.added));
      }
      if (i < oldWords.length && j < newWords.length) {
        result.add(DiffToken(word, DiffType.equal));
        i++;
        j++;
      }
    }

    while (i < oldWords.length) {
      result.add(DiffToken(oldWords[i++], DiffType.removed));
    }
    while (j < newWords.length) {
      result.add(DiffToken(newWords[j++], DiffType.added));
    }
    return result;
  }

  static List<String> _words(String text) =>
      text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList(growable: false);

  static List<String> _hirschberg(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return const [];
    if (a.length == 1) return b.contains(a.first) ? <String>[a.first] : const [];
    if (b.length == 1) return a.contains(b.first) ? <String>[b.first] : const [];

    // إبقاء صفوف DP على القائمة الأقصر يخفض ذروة الذاكرة أكثر.
    if (b.length > a.length) {
      return _hirschberg(b, a);
    }

    final splitA = a.length ~/ 2;
    final leftA = a.sublist(0, splitA);
    final rightA = a.sublist(splitA);

    final leftScores = _lcsLengths(leftA, b);
    final rightScores = _lcsLengths(
      rightA.reversed.toList(growable: false),
      b.reversed.toList(growable: false),
    );

    var splitB = 0;
    var best = -1;
    for (var j = 0; j <= b.length; j++) {
      final score = leftScores[j] + rightScores[b.length - j];
      if (score > best) {
        best = score;
        splitB = j;
      }
    }

    final left = _hirschberg(leftA, b.sublist(0, splitB));
    final right = _hirschberg(rightA, b.sublist(splitB));
    return <String>[...left, ...right];
  }

  static List<int> _lcsLengths(List<String> a, List<String> b) {
    var previous = List<int>.filled(b.length + 1, 0);
    var current = List<int>.filled(b.length + 1, 0);

    for (final aw in a) {
      current[0] = 0;
      for (var j = 1; j <= b.length; j++) {
        if (aw == b[j - 1]) {
          current[j] = previous[j - 1] + 1;
        } else {
          current[j] = previous[j] >= current[j - 1]
              ? previous[j]
              : current[j - 1];
        }
      }
      final tmp = previous;
      previous = current;
      current = tmp;
    }
    return previous;
  }
}

/// مدخل isolate للمقارنة. نعيد بنية بسيطة قابلة للنقل بين isolates بدل
/// إرسال كائنات واجهة أو State.
List<List<Object>> textDiffIsolate(Map<String, String> input) {
  final diff = TextDiff.compare(input['old'] ?? '', input['new'] ?? '');
  return diff
      .map((token) => <Object>[token.text, token.type.index])
      .toList(growable: false);
}
