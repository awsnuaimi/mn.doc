import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MnDocApp());
}

class MnDocApp extends StatelessWidget {
  const MnDocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MN-Doc',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // دعم اللغة العربية بشكل افتراضي (يمين لليسار)
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        // ملاحظة: أضف flutter_localizations في pubspec إذا رغبت بترجمة
        // نصوص المكوّنات الافتراضية (أزرار الحوار، إلخ) إلى العربية بالكامل.
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            top: false, // الشريط العلوي (AppBar) يتعامل مع هذا بنفسه
            bottom: true, // يمنع تغطية أزرار Navigation تبع أندرويد لمحتوى التطبيق
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const HomeScreen(),
    );
  }
}
