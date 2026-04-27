import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/maintenance_provider.dart';
import 'providers/alerts_provider.dart';
import 'providers/settings_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/root_layout.dart';

void main() {
  runApp(const SmartDriveCareApp());
}

class SmartDriveCareApp extends StatelessWidget {
  const SmartDriveCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MaintenanceProvider()),
        ChangeNotifierProvider(create: (_) => AlertsProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          title: 'نظام الصيانة التنبؤية',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              primary: AppColors.primary,
              secondary: AppColors.success,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              primary: AppColors.primary,
              secondary: AppColors.success,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
          home: const RootLayout(),
        ),
      ),
    );
  }
}
