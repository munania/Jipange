import 'package:flutter/material.dart';
import 'package:locallists/services/pomodoro_settings.dart';

class PomodoroSettingsScreen extends StatefulWidget {
  const PomodoroSettingsScreen({super.key});

  @override
  State<PomodoroSettingsScreen> createState() =>
      _PomodoroSettingsScreenState();
}

class _PomodoroSettingsScreenState extends State<PomodoroSettingsScreen> {
  PomodoroSettings _settings = const PomodoroSettings();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await PomodoroSettings.load();
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  Future<void> _update(PomodoroSettings newSettings) async {
    setState(() => _settings = newSettings);
    await newSettings.save();
  }

  Widget _buildStepperTile({
    required String title,
    required String subtitle,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed:
                  value > min ? () => onChanged(value - 1) : null,
            ),
            SizedBox(
              width: 28,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed:
                  value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pomodoro Timer')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro Timer'),
      ),
      body: ListView(
        children: [
          _buildStepperTile(
            title: 'Focus duration',
            subtitle: 'Length of a work session (minutes)',
            value: _settings.workMinutes,
            min: 1,
            max: 120,
            onChanged: (v) => _update(_settings.copyWith(workMinutes: v)),
          ),
          _buildStepperTile(
            title: 'Short break duration',
            subtitle: 'Length of a short break (minutes)',
            value: _settings.shortBreakMinutes,
            min: 1,
            max: 60,
            onChanged: (v) =>
                _update(_settings.copyWith(shortBreakMinutes: v)),
          ),
          _buildStepperTile(
            title: 'Long break duration',
            subtitle: 'Length of a long break (minutes)',
            value: _settings.longBreakMinutes,
            min: 1,
            max: 90,
            onChanged: (v) =>
                _update(_settings.copyWith(longBreakMinutes: v)),
          ),
          _buildStepperTile(
            title: 'Sessions before long break',
            subtitle: 'Number of focus sessions per cycle',
            value: _settings.sessionsBeforeLongBreak,
            min: 1,
            max: 12,
            onChanged: (v) =>
                _update(_settings.copyWith(sessionsBeforeLongBreak: v)),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SwitchListTile(
              title: const Text('Auto-start breaks'),
              subtitle: const Text(
                  'Automatically start the break after a focus session'),
              value: _settings.autoStartBreaks,
              onChanged: (v) =>
                  _update(_settings.copyWith(autoStartBreaks: v)),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SwitchListTile(
              title: const Text('Auto-start focus sessions'),
              subtitle:
                  const Text('Automatically start work after a break ends'),
              value: _settings.autoStartWork,
              onChanged: (v) =>
                  _update(_settings.copyWith(autoStartWork: v)),
            ),
          ),
        ],
      ),
    );
  }
}
