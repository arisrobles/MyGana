import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

class ThemeSettingsTile extends StatelessWidget {
  const ThemeSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = Theme.of(context);

    return Column(
      children: [
        RadioListTile<AppThemeMode>(
          value: AppThemeMode.system,
          groupValue: themeProvider.appThemeMode,
          onChanged: (value) {
            if (value != null) themeProvider.setAppTheme(value);
          },
          title: const Text('System Default'),
          subtitle: const Text('Follow device theme settings'),
          secondary: Icon(Icons.phone_android, color: currentTheme.colorScheme.primary),
        ),
        RadioListTile<AppThemeMode>(
          value: AppThemeMode.light,
          groupValue: themeProvider.appThemeMode,
          onChanged: (value) {
            if (value != null) themeProvider.setAppTheme(value);
          },
          title: const Text('Light Theme'),
          secondary: Icon(Icons.light_mode, color: currentTheme.colorScheme.primary),
        ),
        RadioListTile<AppThemeMode>(
          value: AppThemeMode.dark,
          groupValue: themeProvider.appThemeMode,
          onChanged: (value) {
            if (value != null) themeProvider.setAppTheme(value);
          },
          title: const Text('Dark Theme'),
          secondary: Icon(Icons.dark_mode, color: currentTheme.colorScheme.primary),
        ),
        RadioListTile<AppThemeMode>(
          value: AppThemeMode.sakura,
          groupValue: themeProvider.appThemeMode,
          onChanged: (value) {
            if (value != null) themeProvider.setAppTheme(value);
          },
          title: const Text('Sakura Theme'),
          secondary: Icon(Icons.spa, color: currentTheme.colorScheme.primary),
        ),
        RadioListTile<AppThemeMode>(
          value: AppThemeMode.matcha,
          groupValue: themeProvider.appThemeMode,
          onChanged: (value) {
            if (value != null) themeProvider.setAppTheme(value);
          },
          title: const Text('Matcha Theme'),
          secondary: Icon(Icons.eco, color: currentTheme.colorScheme.primary),
        ),
        RadioListTile<AppThemeMode>(
          value: AppThemeMode.sunset,
          groupValue: themeProvider.appThemeMode,
          onChanged: (value) {
            if (value != null) themeProvider.setAppTheme(value);
          },
          title: const Text('Sunset Theme'),
          secondary: Icon(Icons.wb_sunny, color: currentTheme.colorScheme.primary),
        ),
        RadioListTile<AppThemeMode>(
          value: AppThemeMode.ocean,
          groupValue: themeProvider.appThemeMode,
          onChanged: (value) {
            if (value != null) themeProvider.setAppTheme(value);
          },
          title: const Text('Ocean Theme'),
          secondary: Icon(Icons.water, color: currentTheme.colorScheme.primary),
        ),
        RadioListTile<AppThemeMode>(
          value: AppThemeMode.lavender,
          groupValue: themeProvider.appThemeMode,
          onChanged: (value) {
            if (value != null) themeProvider.setAppTheme(value);
          },
          title: const Text('Lavender Theme'),
          secondary: Icon(Icons.color_lens, color: currentTheme.colorScheme.primary),
        ),
        RadioListTile<AppThemeMode>(
          value: AppThemeMode.autumn,
          groupValue: themeProvider.appThemeMode,
          onChanged: (value) {
            if (value != null) themeProvider.setAppTheme(value);
          },
          title: const Text('Autumn Theme'),
          secondary: Icon(Icons.forest, color: currentTheme.colorScheme.primary),
        ),
        RadioListTile<AppThemeMode>(
          value: AppThemeMode.fuji,
          groupValue: themeProvider.appThemeMode,
          onChanged: (value) {
            if (value != null) themeProvider.setAppTheme(value);
          },
          title: const Text('Fuji Theme'),
          secondary: Icon(Icons.landscape, color: currentTheme.colorScheme.primary),
        ),
        RadioListTile<AppThemeMode>(
          value: AppThemeMode.blueLight,
          groupValue: themeProvider.appThemeMode,
          onChanged: (value) {
            if (value != null) themeProvider.setAppTheme(value);
          },
          title: const Text('Blue Light Theme'),
          secondary: Icon(Icons.palette, color: currentTheme.colorScheme.primary),
        ),
      ],
    );
  }
}