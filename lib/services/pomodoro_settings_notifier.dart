import 'package:flutter/foundation.dart';
import 'package:locallists/services/pomodoro_settings.dart';

/// Wraps [PomodoroSettings] in a ChangeNotifier so any screen watching it
/// (the timer, the settings screen) reacts immediately to changes instead of
/// requiring an app restart to pick up the new values.
class PomodoroSettingsNotifier extends ChangeNotifier {
  PomodoroSettings _settings = const PomodoroSettings();
  bool _isLoaded = false;

  PomodoroSettingsNotifier() {
    _load();
  }

  PomodoroSettings get settings => _settings;
  bool get isLoaded => _isLoaded;

  Future<void> _load() async {
    _settings = await PomodoroSettings.load();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> update(PomodoroSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();
    await newSettings.save();
  }
}
