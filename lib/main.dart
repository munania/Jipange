import 'package:flutter/material.dart';
import 'package:flutter_state_notifier/flutter_state_notifier.dart';
import 'package:locallists/features/splash_screen/splash_screen.dart';
import 'package:locallists/services/notification_service.dart';
import 'package:locallists/services/theme_notifier.dart';
import 'package:locallists/utils/theme.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        StateNotifierProvider<ThemeNotifier, ThemeMode>(
          create: (context) => ThemeNotifier(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeMode>();
    return MaterialApp(
      title: 'Jipange',
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
