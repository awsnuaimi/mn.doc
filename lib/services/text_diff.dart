/// نوع التغيير بين كلمة بملف ونظيرتها بالملف الآخر.
enum DiffType { equal, added, removed }

class DiffToken {
  final String text;
  final DiffType type;
  DiffToken(this.text, this.type);
}

/// خوارزمية مقارنة نصوص بسيطة (Longest Common Subsequence) على مستوى الكلمات.
/// لا تحتاج أي مكتبة خارجية — مناسبة لمقارنة حجم النصوص المتوسط (مستندات عادية).
class TextDiff {
  static List<DiffToken> compare(String oldText, String newText) {
    final oldWords = oldText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final newWords = newText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    final n = oldWords.length;
    final m = newWords.length;

    // جدول LCS القياسي
    final lcs = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (int i = n - 1; i >= 0; i--) {
      for (int j = m - 1; j >= 0; j--) {
        if (oldWords[i] == newWords[j]) {
          lcs[i][j] = lcs[i + 1][j + 1] + 1;
        } else {
          lcs[i][j] = lcs[i + 1][j] > lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1];
        }
      }
    }

    final result = <DiffToken>[];
    int i = 0, j = 0;
    while (i < n && j < m) {
      if (oldWords[i] == newWords[j]) {
        result.add(DiffToken(oldWords[i], DiffType.equal));
        i++;
        j++;
      } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
        result.add(DiffToken(oldWords[i], DiffType.removed));
        i++;
      } else {
        result.add(DiffToken(newWords[j], DiffType.added));
        j++;
      }
    }
    while (i < n) {
      result.add(DiffToken(oldWords[i], DiffType.removed));
      i++;
    }
    while (j < m) {
      result.add(DiffToken(newWords[j], DiffType.added));
      j++;
    }
    return result;
  }
}
