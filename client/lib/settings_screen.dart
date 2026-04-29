import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _changeLocale(BuildContext context, Locale locale) async {
    if (context.locale == locale) return;
    await context.setLocale(locale);
  }

  @override
  Widget build(BuildContext context) {
    final localization = EasyLocalization.of(context);
    final currentLocale = localization?.locale ?? const Locale('vi');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'nav.settings'.tr(),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F8F4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'settings.language'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: [
                        ChoiceChip(
                          label: Text('settings.language_vi'.tr()),
                          selected: currentLocale.languageCode == 'vi',
                          onSelected: (selected) {
                            if (!selected) return;
                            _changeLocale(context, const Locale('vi'));
                          },
                        ),
                        ChoiceChip(
                          label: Text('settings.language_en'.tr()),
                          selected: currentLocale.languageCode == 'en',
                          onSelected: (selected) {
                            if (!selected) return;
                            _changeLocale(context, const Locale('en'));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'settings.coming_soon'.tr(),
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
