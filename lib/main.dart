import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';
import 'services/app_settings.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------------
  // كاشف أخطاء مؤقت: يعرض تفاصيل أي خطأ مباشرة على الشاشة (حتى بنسخة
  // release) بدل ما تطلع شاشة فاضية بدون أي تفسير. مفيد للتشخيص فقط.
  // ------------------------------------------------------------------
  ErrorWidget.builder = (FlutterErrorDetails details) {
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
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: settings.isArabic ? TextDirection.rtl : TextDirection.ltr,
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