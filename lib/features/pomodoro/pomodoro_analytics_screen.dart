import 'package:flutter/material.dart';
import 'package:locallists/data/task_database_helper.dart';

enum _Period { daily, weekly, monthly, yearly }

extension on _Period {
  String get label {
    switch (this) {
      case _Period.daily:
        return 'Daily';
      case _Period.weekly:
        return 'Weekly';
      case _Period.monthly:
        return 'Monthly';
      case _Period.yearly:
        return 'Yearly';
    }
  }
}

class _Bucket {
  final String label;
  final double minutes;
  final bool isCurrent;

  _Bucket({required this.label, required this.minutes, this.isCurrent = false});
}

class PomodoroAnalyticsScreen extends StatefulWidget {
  const PomodoroAnalyticsScreen({super.key});

  @override
  State<PomodoroAnalyticsScreen> createState() =>
      _PomodoroAnalyticsScreenState();
}

class _PomodoroAnalyticsScreenState extends State<PomodoroAnalyticsScreen> {
  final PageController _pageController = PageController();
  _Period _selectedPeriod = _Period.daily;

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  void _onChipTapped(_Period period) {
    setState(() => _selectedPeriod = period);
    _pageController.animateToPage(
      _Period.values.indexOf(period),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Analytics'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _Period.values.map((period) {
                final isSelected = period == _selectedPeriod;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(period.label),
                      selected: isSelected,
                      onSelected: (_) => _onChipTapped(period),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _selectedPeriod = _Period.values[index]);
              },
              children: [
                _PeriodStatsView(
                  key: const ValueKey('daily'),
                  loader: _loadDailyBuckets,
                  totalLabel: "Today's focus time",
                  totalMinutes: _todayTotalMinutesLoader,
                ),
                _PeriodStatsView(
                  key: const ValueKey('weekly'),
                  loader: _loadWeeklyBuckets,
                  totalLabel: "This week's focus time",
                  totalMinutes: _weekTotalMinutesLoader,
                ),
                _PeriodStatsView(
                  key: const ValueKey('monthly'),
                  loader: _loadMonthlyBuckets,
                  totalLabel: "This month's focus time",
                  totalMinutes: _monthTotalMinutesLoader,
                ),
                _PeriodStatsView(
                  key: const ValueKey('yearly'),
                  loader: _loadYearlyBuckets,
                  totalLabel: "This year's focus time",
                  totalMinutes: _yearTotalMinutesLoader,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Fetch raw completed 'work' sessions between two dates
  Future<List<Map<String, dynamic>>> _fetchWorkSessions(
      DateTime start, DateTime end) {
    return TaskDatabaseHelper.instance.getPomodoroSessions(
      start: start,
      end: end,
      sessionType: 'work',
    );
  }

  double _sumMinutes(List<Map<String, dynamic>> sessions) {
    final totalSeconds = sessions.fold<int>(
        0, (sum, s) => sum + (s['duration_seconds'] as int));
    return totalSeconds / 60;
  }

  // Last 7 days, bucketed by day
  Future<List<_Bucket>> _loadDailyBuckets() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    final end = today.add(const Duration(days: 1));
    final sessions = await _fetchWorkSessions(start, end);

    final buckets = <_Bucket>[];
    for (int i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      final daySessions = sessions.where((s) {
        final dt = DateTime.parse(s['completed_at']);
        return !dt.isBefore(day) && dt.isBefore(nextDay);
      }).toList();
      buckets.add(_Bucket(
        label: _weekdayNames[day.weekday - 1],
        minutes: _sumMinutes(daySessions),
        isCurrent: day == today,
      ));
    }
    return buckets;
  }

  Future<double> _todayTotalMinutesLoader() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final sessions = await _fetchWorkSessions(today, tomorrow);
    return _sumMinutes(sessions);
  }

  // Current week (Mon-Sun), bucketed by day
  Future<List<_Bucket>> _loadWeeklyBuckets() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    final sessions = await _fetchWorkSessions(monday, nextMonday);

    final buckets = <_Bucket>[];
    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      final daySessions = sessions.where((s) {
        final dt = DateTime.parse(s['completed_at']);
        return !dt.isBefore(day) && dt.isBefore(nextDay);
      }).toList();
      buckets.add(_Bucket(
        label: _weekdayNames[i],
        minutes: _sumMinutes(daySessions),
        isCurrent: day == today,
      ));
    }
    return buckets;
  }

  Future<double> _weekTotalMinutesLoader() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    final sessions = await _fetchWorkSessions(monday, nextMonday);
    return _sumMinutes(sessions);
  }

  // Current month, bucketed by week-of-month (up to 5 buckets)
  Future<List<_Bucket>> _loadMonthlyBuckets() async {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final firstOfNextMonth = DateTime(now.year, now.month + 1, 1);
    final sessions = await _fetchWorkSessions(firstOfMonth, firstOfNextMonth);

    final daysInMonth = firstOfNextMonth.difference(firstOfMonth).inDays;
    final weekCount = ((daysInMonth) / 7).ceil();
    final today = DateTime(now.year, now.month, now.day);

    final buckets = <_Bucket>[];
    for (int w = 0; w < weekCount; w++) {
      final weekStart = firstOfMonth.add(Duration(days: w * 7));
      var weekEnd = weekStart.add(const Duration(days: 7));
      if (weekEnd.isAfter(firstOfNextMonth)) weekEnd = firstOfNextMonth;

      final weekSessions = sessions.where((s) {
        final dt = DateTime.parse(s['completed_at']);
        return !dt.isBefore(weekStart) && dt.isBefore(weekEnd);
      }).toList();

      final isCurrentWeek =
          !today.isBefore(weekStart) && today.isBefore(weekEnd);

      buckets.add(_Bucket(
        label: 'W${w + 1}',
        minutes: _sumMinutes(weekSessions),
        isCurrent: isCurrentWeek,
      ));
    }
    return buckets;
  }

  Future<double> _monthTotalMinutesLoader() async {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final firstOfNextMonth = DateTime(now.year, now.month + 1, 1);
    final sessions = await _fetchWorkSessions(firstOfMonth, firstOfNextMonth);
    return _sumMinutes(sessions);
  }

  // Current year, bucketed by month
  Future<List<_Bucket>> _loadYearlyBuckets() async {
    final now = DateTime.now();
    final firstOfYear = DateTime(now.year, 1, 1);
    final firstOfNextYear = DateTime(now.year + 1, 1, 1);
    final sessions = await _fetchWorkSessions(firstOfYear, firstOfNextYear);

    final buckets = <_Bucket>[];
    for (int m = 1; m <= 12; m++) {
      final monthStart = DateTime(now.year, m, 1);
      final monthEnd = DateTime(now.year, m + 1, 1);
      final monthSessions = sessions.where((s) {
        final dt = DateTime.parse(s['completed_at']);
        return !dt.isBefore(monthStart) && dt.isBefore(monthEnd);
      }).toList();
      buckets.add(_Bucket(
        label: _monthNames[m - 1],
        minutes: _sumMinutes(monthSessions),
        isCurrent: m == now.month,
      ));
    }
    return buckets;
  }

  Future<double> _yearTotalMinutesLoader() async {
    final now = DateTime.now();
    final firstOfYear = DateTime(now.year, 1, 1);
    final firstOfNextYear = DateTime(now.year + 1, 1, 1);
    final sessions = await _fetchWorkSessions(firstOfYear, firstOfNextYear);
    return _sumMinutes(sessions);
  }
}

/// A single swipeable page showing a bar chart + summary for one period.
class _PeriodStatsView extends StatelessWidget {
  final Future<List<_Bucket>> Function() loader;
  final Future<double> Function() totalMinutes;
  final String totalLabel;

  const _PeriodStatsView({
    super.key,
    required this.loader,
    required this.totalMinutes,
    required this.totalLabel,
  });

  String _formatMinutes(double minutes) {
    final totalMins = minutes.round();
    final hours = totalMins ~/ 60;
    final mins = totalMins % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([loader(), totalMinutes()]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final buckets = snapshot.data![0] as List<_Bucket>;
        final total = snapshot.data![1] as double;
        final maxMinutes = buckets.isEmpty
            ? 1.0
            : buckets
                .map((b) => b.minutes)
                .fold<double>(1.0, (a, b) => b > a ? b : a);

        final primaryColor = Theme.of(context).colorScheme.primary;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        totalLabel,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatMinutes(total),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 200,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: buckets.map((bucket) {
                    final barHeight = maxMinutes == 0
                        ? 4.0
                        : (bucket.minutes / maxMinutes) * 160;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              bucket.minutes > 0
                                  ? bucket.minutes.round().toString()
                                  : '',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: barHeight.clamp(4.0, 160.0),
                              decoration: BoxDecoration(
                                color: bucket.isCurrent
                                    ? primaryColor
                                    : primaryColor.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              bucket.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: bucket.isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
