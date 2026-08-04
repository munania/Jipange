import 'dart:async';

import 'package:flutter/material.dart';
import 'package:locallists/data/task_database_helper.dart';
import 'package:locallists/features/pomodoro/pomodoro_analytics_screen.dart';
import 'package:locallists/services/notification_service.dart';
import 'package:locallists/services/pomodoro_settings.dart';
import 'package:locallists/services/pomodoro_settings_notifier.dart';
import 'package:provider/provider.dart';

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

class _PomodoroScreenState extends State<PomodoroScreen>
    with SingleTickerProviderStateMixin {
  PomodoroSessionType _currentType = PomodoroSessionType.work;
  int _totalSeconds = 25 * 60;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  int _completedWorkSessions = 0;
  Timer? _timer;
  PomodoroSettings? _lastAppliedSettings;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  // Applies the latest settings from the notifier. Only touches the active
  // countdown when the timer is at rest, so a change never yanks time out
  // from under a session that's actively running.
  void _applySettings(PomodoroSettings settings) {
    final isFirstLoad = _lastAppliedSettings == null;
    _lastAppliedSettings = settings;
    if (_isRunning) return;

    final newDuration = _durationFor(_currentType, settings);
    if (isFirstLoad || newDuration != _totalSeconds) {
      setState(() {
        _totalSeconds = newDuration;
        _remainingSeconds = newDuration;
      });
    }
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

  Color _colorFor(PomodoroSessionType type) {
    switch (type) {
      case PomodoroSessionType.work:
        return const Color(0xFF7C86F5); // indigo - focus
      case PomodoroSessionType.shortBreak:
        return const Color(0xFF4CAF50); // green - short break
      case PomodoroSessionType.longBreak:
        return const Color(0xFF2196F3); // blue - long break
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
    _pulseController.repeat(reverse: true);
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
    _pulseController.stop();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    _pulseController.stop();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _totalSeconds;
    });
  }

  Future<void> _onSessionComplete() async {
    final completedType = _currentType;
    final completedDuration = _totalSeconds;
    final settings = _lastAppliedSettings ?? const PomodoroSettings();

    _pulseController.stop();

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
          nextCompletedWorkSessions % settings.sessionsBeforeLongBreak == 0;
      nextType = isLongBreakDue
          ? PomodoroSessionType.longBreak
          : PomodoroSessionType.shortBreak;
    } else {
      nextType = PomodoroSessionType.work;
    }

    final nextDuration = _durationFor(nextType, settings);
    final shouldAutoStart = completedType == PomodoroSessionType.work
        ? settings.autoStartBreaks
        : settings.autoStartWork;

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
    final settings = _lastAppliedSettings ?? const PomodoroSettings();
    setState(() {
      _currentType = type;
      _totalSeconds = _durationFor(type, settings);
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
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watching this rebuilds the timer live whenever settings change
    // elsewhere in the app - no restart needed.
    final settings = context.watch<PomodoroSettingsNotifier>().settings;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applySettings(settings);
    });

    final color = _colorFor(_currentType);
    final progress =
        _totalSeconds == 0 ? 0.0 : 1 - (_remainingSeconds / _totalSeconds);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
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
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Session type switcher - each option has a strongly
            // contrasted, distinctly colored selected state.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: PomodoroSessionType.values.map((type) {
                  final isSelected = type == _currentType;
                  final typeColor = _colorFor(type);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => _switchType(type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? typeColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? typeColor
                                  : Colors.grey.withValues(alpha: 0.4),
                              width: isSelected ? 0 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: typeColor.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                            child: Text(type.label, textAlign: TextAlign.center),
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
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final pulse = _isRunning
                        ? 1.0 + (_pulseController.value * 0.02)
                        : 1.0;
                    return Transform.scale(scale: pulse, child: child);
                  },
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOut,
                          builder: (context, value, _) => SizedBox(
                            width: 260,
                            height: 260,
                            child: CircularProgressIndicator(
                              value: value,
                              strokeWidth: 10,
                              backgroundColor: color.withValues(alpha: 0.15),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
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
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Text(
                                _currentType.label,
                                key: ValueKey(_currentType),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Text(
              'Session ${(_completedWorkSessions % (_lastAppliedSettings?.sessionsBeforeLongBreak ?? 4)) + (_currentType == PomodoroSessionType.work ? 1 : 0)} '
              'of ${_lastAppliedSettings?.sessionsBeforeLongBreak ?? 4}',
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
                AnimatedScale(
                  scale: _isRunning ? 1.0 : 1.05,
                  duration: const Duration(milliseconds: 200),
                  child: FloatingActionButton(
                    heroTag: 'pomodoro_toggle_fab',
                    backgroundColor: color,
                    onPressed: _toggleTimer,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        _isRunning ? Icons.pause : Icons.play_arrow,
                        key: ValueKey(_isRunning),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.skip_next),
                  tooltip: 'Skip',
                  onPressed: () {
                    _timer?.cancel();
                    _pulseController.stop();
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
    final settings = _lastAppliedSettings ?? const PomodoroSettings();
    PomodoroSessionType nextType;

    if (_currentType == PomodoroSessionType.work) {
      nextType = PomodoroSessionType.shortBreak;
    } else {
      nextType = PomodoroSessionType.work;
    }

    final nextDuration = _durationFor(nextType, settings);
    setState(() {
      _currentType = nextType;
      _totalSeconds = nextDuration;
      _remainingSeconds = nextDuration;
    });
  }
}
