import 'package:shared_preferences/shared_preferences.dart';

/// Holds and persists the user's Pomodoro timer preferences.
class PomodoroSettings {
  final int workMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int sessionsBeforeLongBreak;
  final bool autoStartBreaks;
  final bool autoStartWork;

  const PomodoroSettings({
    this.workMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.sessionsBeforeLongBreak = 4,
    this.autoStartBreaks = false,
    this.autoStartWork = false,
  });

  static const _workKey = 'pomodoro_work_minutes';
  static const _shortBreakKey = 'pomodoro_short_break_minutes';
  static const _longBreakKey = 'pomodoro_long_break_minutes';
  static const _sessionsBeforeLongBreakKey =
      'pomodoro_sessions_before_long_break';
  static const _autoStartBreaksKey = 'pomodoro_auto_start_breaks';
  static const _autoStartWorkKey = 'pomodoro_auto_start_work';

  static Future<PomodoroSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PomodoroSettings(
      workMinutes: prefs.getInt(_workKey) ?? 25,
      shortBreakMinutes: prefs.getInt(_shortBreakKey) ?? 5,
      longBreakMinutes: prefs.getInt(_longBreakKey) ?? 15,
      sessionsBeforeLongBreak: prefs.getInt(_sessionsBeforeLongBreakKey) ?? 4,
      autoStartBreaks: prefs.getBool(_autoStartBreaksKey) ?? false,
      autoStartWork: prefs.getBool(_autoStartWorkKey) ?? false,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_workKey, workMinutes);
    await prefs.setInt(_shortBreakKey, shortBreakMinutes);
    await prefs.setInt(_longBreakKey, longBreakMinutes);
    await prefs.setInt(_sessionsBeforeLongBreakKey, sessionsBeforeLongBreak);
    await prefs.setBool(_autoStartBreaksKey, autoStartBreaks);
    await prefs.setBool(_autoStartWorkKey, autoStartWork);
  }

  PomodoroSettings copyWith({
    int? workMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? sessionsBeforeLongBreak,
    bool? autoStartBreaks,
    bool? autoStartWork,
  }) {
    return PomodoroSettings(
      workMinutes: workMinutes ?? this.workMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      sessionsBeforeLongBreak:
          sessionsBeforeLongBreak ?? this.sessionsBeforeLongBreak,
      autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
      autoStartWork: autoStartWork ?? this.autoStartWork,
    );
  }
}
