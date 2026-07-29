import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:locallists/features/categories/category_management_screen.dart';
import 'package:locallists/features/settings/pomodoro_settings_screen.dart';
import 'package:locallists/services/theme_notifier.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeMode>();
    final themeNotifier = context.read<ThemeNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          // Categories in card with icon and title and padding left and right for card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(Icons.category_rounded),
              title: Text('Manage Categories'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CategoryManagementScreen(),
                  ),
                );
              },
            ),
          ),
          // Pomodoro timer settings
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(Icons.timer_outlined),
              title: Text('Pomodoro Timer'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PomodoroSettingsScreen(),
                  ),
                );
              },
            ),
          ),
          // Dark mode in card with icon and title and padding left and right for card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(Icons.brightness_6),
              title: Text('Theme'),
              subtitle: Text(_getThemeLabel(themeMode)),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text('Theme'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: Icon(Icons.brightness_2),
                            title: Text('Dark'),
                            trailing: themeMode == ThemeMode.dark
                                ? Icon(Icons.check)
                                : null,
                            onTap: () {
                              themeNotifier.setTheme(ThemeMode.dark);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.brightness_5),
                            title: Text('Light'),
                            trailing: themeMode == ThemeMode.light
                                ? Icon(Icons.check)
                                : null,
                            onTap: () {
                              themeNotifier.setTheme(ThemeMode.light);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.brightness_auto),
                            title: Text('System default'),
                            trailing: themeMode == ThemeMode.system
                                ? Icon(Icons.check)
                                : null,
                            onTap: () {
                              themeNotifier.setTheme(ThemeMode.system);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Notification in card with icon and title and padding left and right for card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(Icons.notifications),
              title: Text('Notifications'),
              onTap: () {
                // Open app settings for notifications
                AppSettings.openAppSettings(type: AppSettingsType.notification);
              },
            ),
          ),
        ],
      ),
    );
  }
}
