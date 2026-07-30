import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateCheckResult {
  final bool updateAvailable;
  final String currentVersion;
  final String? latestVersion;
  final String? downloadUrl;
  final String? error;

  UpdateCheckResult({
    required this.updateAvailable,
    required this.currentVersion,
    this.latestVersion,
    this.downloadUrl,
    this.error,
  });
}

/// يتحقق من وجود تحديث جديد عبر مقارنة إصدار التطبيق الحالي بآخر
/// "إصدار عام" (Release) منشور على مستودع GitHub الخاص بالمشروع.
///
/// ملاحظة: هذا يعتمد على نشر إصدارات (Releases) فعلية على GitHub —
/// راجع ملف .github/workflows/build-apk.yml؛ كل ما تدفع "تاغ" مثل
/// v1.0.1 (عبر: git tag v1.0.1 && git push origin v1.0.1)، ينشر
/// تلقائيًا إصدار عام جديد يقارن التطبيق نفسه معه.
class UpdateChecker {
  // عدّل هذين السطرين إذا غيّرت اسم المستخدم أو المستودع على GitHub
  static const String _githubOwner = 'awsnuaimi';
  static const String _githubRepo = 'mn.doc';

  static Future<UpdateCheckResult> check() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'},
      );

      if (response.statusCode == 404) {
        return UpdateCheckResult(
          updateAvailable: false,
          currentVersion: currentVersion,
          error: 'لا يوجد أي إصدار عام منشور بعد على GitHub',
        );
      }
      if (response.statusCode != 200) {
        return UpdateCheckResult(
          updateAvailable: false,
          currentVersion: currentVersion,
          error: 'تعذّر الاتصال بخادم التحديثات (${response.statusCode})',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String?) ?? '';
      final latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      final htmlUrl = data['html_url'] as String?;

      final isNewer = _isVersionNewer(latestVersion, currentVersion);

      return UpdateCheckResult(
        updateAvailable: isNewer,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        downloadUrl: htmlUrl,
      );
    } catch (e) {
      return UpdateCheckResult(
        updateAvailable: false,
        currentVersion: currentVersion,
        error: 'تعذّر التحقق من التحديثات: $e',
      );
    }
  }

  /// يقارن رقمين بصيغة "1.2.3" — يرجع true إذا كان [latest] أحدث من [current].
  static bool _isVersionNewer(String latest, String current) {
    final latestParts = latest.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final currentParts = current.split(RegExp(r'[.+]')).map((p) => int.tryParse(p) ?? 0).toList();

    for (int i = 0; i < latestParts.length; i++) {
      final l = latestParts[i];
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }
}
