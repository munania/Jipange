import 'package:flutter/material.dart';
import 'package:locallists/services/pomodoro_settings.dart';
import 'package:locallists/services/pomodoro_settings_notifier.dart';
import 'package:locallists/utils/theme.dart';
import 'package:provider/provider.dart';

class PomodoroSettingsScreen extends StatelessWidget {
  const PomodoroSettingsScreen({super.key});

  Widget _buildStepperTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.15),
          child: Icon(icon, color: accent),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: value > min ? () => onChanged(value - 1) : null,
            ),
            SizedBox(
              width: 28,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Text(
                  '$value',
                  key: ValueKey(value),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, color: accent),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accent = AppThemes.accentFor(isDarkMode);
    final notifier = context.watch<PomodoroSettingsNotifier>();

    if (!notifier.isLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pomodoro Timer')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final settings = notifier.settings;

    void update(PomodoroSettings newSettings) {
      context.read<PomodoroSettingsNotifier>().update(newSettings);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro Timer'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          _buildStepperTile(
            context: context,
            title: 'Focus duration',
            subtitle: 'Length of a work session (minutes)',
            icon: Icons.bolt,
            accent: const Color(0xFF7C86F5),
            value: settings.workMinutes,
            min: 1,
            max: 120,
            onChanged: (v) => update(settings.copyWith(workMinutes: v)),
          ),
          _buildStepperTile(
            context: context,
            title: 'Short break duration',
            subtitle: 'Length of a short break (minutes)',
            icon: Icons.local_cafe_outlined,
            accent: const Color(0xFF4CAF50),
            value: settings.shortBreakMinutes,
            min: 1,
            max: 60,
            onChanged: (v) => update(settings.copyWith(shortBreakMinutes: v)),
          ),
          _buildStepperTile(
            context: context,
            title: 'Long break duration',
            subtitle: 'Length of a long break (minutes)',
            icon: Icons.weekend_outlined,
            accent: const Color(0xFF2196F3),
            value: settings.longBreakMinutes,
            min: 1,
            max: 90,
            onChanged: (v) => update(settings.copyWith(longBreakMinutes: v)),
          ),
          _buildStepperTile(
            context: context,
            title: 'Sessions before long break',
            subtitle: 'Number of focus sessions per cycle',
            icon: Icons.repeat,
            accent: const Color(0xFFE91E63),
            value: settings.sessionsBeforeLongBreak,
            min: 1,
            max: 12,
            onChanged: (v) =>
                update(settings.copyWith(sessionsBeforeLongBreak: v)),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SwitchListTile(
              secondary: Icon(Icons.play_circle_outline, color: accent),
              title: const Text('Auto-start breaks'),
              subtitle: const Text(
                  'Automatically start the break after a focus session'),
              value: settings.autoStartBreaks,
              onChanged: (v) => update(settings.copyWith(autoStartBreaks: v)),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SwitchListTile(
              secondary: Icon(Icons.play_circle_outline, color: accent),
              title: const Text('Auto-start focus sessions'),
              subtitle:
                  const Text('Automatically start work after a break ends'),
              value: settings.autoStartWork,
              onChanged: (v) => update(settings.copyWith(autoStartWork: v)),
            ),
          ),
        ],
      ),
    );
  }
}
