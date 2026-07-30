import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../services/update_checker.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;
  bool _checkingUpdate = false;
  String? _currentVersion;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppSettingsController>();
    _nameController = TextEditingController(text: settings.displayName);
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _currentVersion = info.version);
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdate = true);
    final result = await UpdateChecker.check();
    if (!mounted) return;
    setState(() => _checkingUpdate = false);

    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }

    if (result.updateAvailable) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('يوجد تحديث جديد! 🎉'),
          content: Text('الإصدار الحالي: ${result.currentVersion}\nالإصدار الجديد: ${result.latestVersion}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('لاحقًا')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (result.downloadUrl != null) {
                  launchUrl(Uri.parse(result.downloadUrl!), mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('تنزيل التحديث'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('التطبيق محدَّث لآخر إصدار ✅')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final ar = settings.isArabic;

    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(AppText.t('settings', ar))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---------------- الملف الشخصي ----------------
            _SectionCard(
              title: AppText.t('profile', ar),
              icon: Icons.person_rounded,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: AppText.t('display_name', ar),
                    hintText: AppText.t('display_name_hint', ar),
                  ),
                  onSubmitted: (v) => settings.setDisplayName(v.trim()),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: ar ? Alignment.centerLeft : Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await settings.setDisplayName(_nameController.text.trim());
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppText.t('saved', ar))),
                      );
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: Text(AppText.t('save', ar)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ---------------- المظهر ----------------
            _SectionCard(
              title: AppText.t('appearance', ar),
              icon: Icons.palette_rounded,
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: settings.themeMode,
                  title: Text(AppText.t('theme_system', ar)),
                  onChanged: (v) => settings.setThemeMode(v!),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: settings.themeMode,
                  title: Text(AppText.t('theme_light', ar)),
                  onChanged: (v) => settings.setThemeMode(v!),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: settings.themeMode,
                  title: Text(AppText.t('theme_dark', ar)),
                  onChanged: (v) => settings.setThemeMode(v!),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ---------------- اللغة ----------------
            _SectionCard(
              title: AppText.t('language', ar),
              icon: Icons.language_rounded,
              children: [
                RadioListTile<String>(
                  value: 'ar',
                  groupValue: settings.locale.languageCode,
                  title: const Text('العربية'),
                  onChanged: (v) => settings.setLocale(const Locale('ar')),
                ),
                RadioListTile<String>(
                  value: 'en',
                  groupValue: settings.locale.languageCode,
                  title: const Text('English'),
                  onChanged: (v) => settings.setLocale(const Locale('en')),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    AppText.t('language_note', ar),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ---------------- التحديثات ----------------
            _SectionCard(
              title: 'التحديثات',
              icon: Icons.system_update_rounded,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    _currentVersion != null ? 'الإصدار الحالي: $_currentVersion' : 'جارٍ التحقق من رقم الإصدار...',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ElevatedButton.icon(
                    onPressed: _checkingUpdate ? null : _checkForUpdates,
                    icon: _checkingUpdate
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.refresh_rounded),
                    label: Text(_checkingUpdate ? 'جارٍ التحقق...' : 'التحقق من وجود تحديثات'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, minimumSize: const Size(double.infinity, 46)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primaryDark),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
}
