import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';
import 'services/app_settings.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------------
  // كاشف أخطاء: بنسخة Debug يعرض تفاصيل الخطأ كاملة (مفيد أثناء التطوير).
  // بنسخة Release يعرض شاشة ودّية للمستخدم بدل تفاصيل تقنية مخيفة.
  // ------------------------------------------------------------------
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kDebugMode) {
      return Material(
        color: Colors.white,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text(
              'حدث خطأ أثناء تشغيل التطبيق:\n\n${details.exceptionAsString()}\n\n${details.stack}',
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ),
      );
    }
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 56, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('حدث خطأ غير متوقع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'نعتذر عن الإزعاج. جرّب إعادة فتح التطبيق.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                // مخفي افتراضيًا حتى لا يخيف المستخدم العادي، لكنه يسمح
                // بمعرفة الاستثناء الحقيقي (ونسخه) بدون الحاجة لبناء Debug
                // أو أدوات مطورين، عند الحاجة لتشخيص خطأ متكرر.
                // نستخدم Builder لأن ErrorWidget.builder لا يمرّر BuildContext
                // مباشرة، وExpansionTile/Theme.of يحتاجانه.
                Builder(
                  builder: (context) => Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text(
                        'تفاصيل تقنية',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SelectableText(
                            '${details.exceptionAsString()}\n\n${details.stack}',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  runZonedGuarded(() {
    final settings = AppSettingsController();
    settings.load();

    runApp(
      ChangeNotifierProvider.value(
        value: settings,
        child: const MnDocApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('خطأ غير متوقع: $error');
    debugPrint('$stack');
  });
}

class MnDocApp extends StatelessWidget {
  const MnDocApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();

    return MaterialApp(
      title: 'MN-Doc',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: const [
        Locale('ar'), Locale('en'), Locale('de'), Locale('fr'), Locale('tr'), Locale('pl'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: SafeArea(
            top: false, // الشريط العلوي (AppBar) يتعامل مع هذا بنفسه
            bottom: true, // يمنع تغطية أزرار Navigation تبع أندرويد لمحتوى التطبيق
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}
