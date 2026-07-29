import 'dart:async';

import 'package:flutter/material.dart';
import 'package:locallists/data/task_database_helper.dart';
import 'package:locallists/features/pomodoro/pomodoro_analytics_screen.dart';
import 'package:locallists/services/notification_service.dart';
import 'package:locallists/services/pomodoro_settings.dart';
import 'package:locallists/utils/theme.dart';

enum PomodoroSessionType { work, shortBreak, longBreak }

extension PomodoroSessionTypeX on PomodoroSessionType {
  String get label {
    switch (this) {
      case PomodoroSessionType.work:
        return 'Focus';
      case PomodoroSessionType.shortBreak:
        return 'Short Break';
      case PomodoroSessionType.longBreak:
        return 'Long Break';
    }
  }

  // Value stored in the database
  String get dbValue {
    switch (this) {
      case PomodoroSessionType.work:
        return 'work';
      case PomodoroSessionType.shortBreak:
        return 'short_break';
      case PomodoroSessionType.longBreak:
        return 'long_break';
    }
  }
}

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  PomodoroSettings _settings = const PomodoroSettings();
  PomodoroSessionType _currentType = PomodoroSessionType.work;
  int _totalSeconds = 25 * 60;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  int _completedWorkSessions = 0;
  Timer? _timer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await PomodoroSettings.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _totalSeconds = _durationFor(_currentType, settings);
      _remainingSeconds = _totalSeconds;
      _isLoading = false;
    });
  }

  int _durationFor(PomodoroSessionType type, PomodoroSettings settings) {
    switch (type) {
      case PomodoroSessionType.work:
        return settings.workMinutes * 60;
      case PomodoroSessionType.shortBreak:
        return settings.shortBreakMinutes * 60;
      case PomodoroSessionType.longBreak:
        return settings.longBreakMinutes * 60;
    }
  }

  Color _colorFor(PomodoroSessionType type, bool isDarkMode) {
    switch (type) {
      case PomodoroSessionType.work:
        return isDarkMode ? AppThemes.lightSecondary : AppThemes.darkPrimary;
      case PomodoroSessionType.shortBreak:
        return const Color(0xFF4CAF50);
      case PomodoroSessionType.longBreak:
        return const Color(0xFF2196F3);
    }
  }

  void _toggleTimer() {
    if (_isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _onSessionComplete();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _totalSeconds;
    });
  }

  Future<void> _onSessionComplete() async {
    final completedType = _currentType;
    final completedDuration = _totalSeconds;

    // Persist the completed session
    await TaskDatabaseHelper.instance.insertPomodoroSession(
      sessionType: completedType.dbValue,
      durationSeconds: completedDuration,
      completedAt: DateTime.now(),
    );

    await NotificationService.instance.showInstantNotification(
      id: 9000 + completedType.index,
      title: completedType == PomodoroSessionType.work
          ? 'Focus session complete!'
          : 'Break over!',
      body: completedType == PomodoroSessionType.work
          ? 'Nice work. Time for a break.'
          : 'Ready to get back to it?',
    );

    PomodoroSessionType nextType;
    int nextCompletedWorkSessions = _completedWorkSessions;

    if (completedType == PomodoroSessionType.work) {
      nextCompletedWorkSessions++;
      final isLongBreakDue =
          nextCompletedWorkSessions % _settings.sessionsBeforeLongBreak == 0;
      nextType = isLongBreakDue
          ? PomodoroSessionType.longBreak
          : PomodoroSessionType.shortBreak;
    } else {
      nextType = PomodoroSessionType.work;
    }

    final nextDuration = _durationFor(nextType, _settings);
    final shouldAutoStart = completedType == PomodoroSessionType.work
        ? _settings.autoStartBreaks
        : _settings.autoStartWork;

    if (!mounted) return;
    setState(() {
      _completedWorkSessions = nextCompletedWorkSessions;
      _currentType = nextType;
      _totalSeconds = nextDuration;
      _remainingSeconds = nextDuration;
      _isRunning = false;
    });

    if (shouldAutoStart) {
      _startTimer();
    }
  }

  void _switchType(PomodoroSessionType type) {
    if (_isRunning) return; // avoid switching mid-run to keep data clean
    setState(() {
      _currentType = type;
      _totalSeconds = _durationFor(type, _settings);
      _remainingSeconds = _totalSeconds;
    });
  }

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final color = _colorFor(_currentType, isDarkMode);
    final progress =
        _totalSeconds == 0 ? 0.0 : 1 - (_remainingSeconds / _totalSeconds);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Analytics',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PomodoroAnalyticsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Session type switcher
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: PomodoroSessionType.values.map((type) {
                        final isSelected = type == _currentType;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4),
                            child: GestureDetector(
                              onTap: () => _switchType(type),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? color
                                        : Colors.grey.withValues(alpha: 0.4),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  type.label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? color : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 260,
                        height: 260,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 260,
                              height: 260,
                              child: CircularProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                strokeWidth: 10,
                                backgroundColor:
                                    color.withValues(alpha: 0.15),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formattedTime,
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _currentType.label,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'Session ${(_completedWorkSessions % _settings.sessionsBeforeLongBreak) + (_currentType == PomodoroSessionType.work ? 1 : 0)} '
                    'of ${_settings.sessionsBeforeLongBreak}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 32,
                        icon: const Icon(Icons.replay),
                        tooltip: 'Reset',
                        onPressed: _resetTimer,
                      ),
                      const SizedBox(width: 24),
                      FloatingActionButton(
                        backgroundColor: color,
                        onPressed: _toggleTimer,
                        child: Icon(
                          _isRunning ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        iconSize: 32,
                        icon: const Icon(Icons.skip_next),
                        tooltip: 'Skip',
                        onPressed: () {
                          _timer?.cancel();
                          setState(() => _isRunning = false);
                          _onSessionSkipped();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  void _onSessionSkipped() {
    // Skipping doesn't record a completed session, just advances the cycle.
    PomodoroSessionType nextType;
    int nextCompletedWorkSessions = _completedWorkSessions;

    if (_currentType == PomodoroSessionType.work) {
      nextType = PomodoroSessionType.shortBreak;
    } else {
      nextType = PomodoroSessionType.work;
    }

    final nextDuration = _durationFor(nextType, _settings);
    setState(() {
      _completedWorkSessions = nextCompletedWorkSessions;
      _currentType = nextType;
      _totalSeconds = nextDuration;
      _remainingSeconds = nextDuration;
    });
  }
}
