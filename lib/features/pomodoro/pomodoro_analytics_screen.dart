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

  IconData get icon {
    switch (this) {
      case _Period.daily:
        return Icons.today_rounded;
      case _Period.weekly:
        return Icons.view_week_rounded;
      case _Period.monthly:
        return Icons.calendar_month_rounded;
      case _Period.yearly:
        return Icons.auto_graph_rounded;
    }
  }

  // Each period gets its own signature color so switching tabs feels
  // distinct and high-contrast rather than a single flat accent everywhere.
  Color get color {
    switch (this) {
      case _Period.daily:
        return const Color(0xFF7C86F5); // indigo
      case _Period.weekly:
        return const Color(0xFF19B3A6); // teal
      case _Period.monthly:
        return const Color(0xFFEF8B3B); // orange
      case _Period.yearly:
        return const Color(0xFFE5548C); // pink
    }
  }
}

class _Bucket {
  final String label;
  final double minutes;
  final int sessionCount;
  final bool isCurrent;

  _Bucket({
    required this.label,
    required this.minutes,
    required this.sessionCount,
    this.isCurrent = false,
  });
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

  void _onTabTapped(_Period period) {
    setState(() => _selectedPeriod = period);
    _pageController.animateToPage(
      _Period.values.indexOf(period),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Analytics'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _PeriodTabBar(
              selected: _selectedPeriod,
              isDarkMode: isDarkMode,
              onSelected: _onTabTapped,
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
                  period: _Period.daily,
                  loader: _loadDailyBuckets,
                  totalLabel: "Today's focus time",
                ),
                _PeriodStatsView(
                  key: const ValueKey('weekly'),
                  period: _Period.weekly,
                  loader: _loadWeeklyBuckets,
                  totalLabel: "This week's focus time",
                ),
                _PeriodStatsView(
                  key: const ValueKey('monthly'),
                  period: _Period.monthly,
                  loader: _loadMonthlyBuckets,
                  totalLabel: "This month's focus time",
                ),
                _PeriodStatsView(
                  key: const ValueKey('yearly'),
                  period: _Period.yearly,
                  loader: _loadYearlyBuckets,
                  totalLabel: "This year's focus time",
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
        sessionCount: daySessions.length,
        isCurrent: day == today,
      ));
    }
    return buckets;
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
        sessionCount: daySessions.length,
        isCurrent: day == today,
      ));
    }
    return buckets;
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
        sessionCount: weekSessions.length,
        isCurrent: isCurrentWeek,
      ));
    }
    return buckets;
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
        sessionCount: monthSessions.length,
        isCurrent: m == now.month,
      ));
    }
    return buckets;
  }
}

/// Segmented control across the top with a sliding, brightly colored
/// indicator so the active period is unmistakable against the others.
class _PeriodTabBar extends StatelessWidget {
  final _Period selected;
  final bool isDarkMode;
  final ValueChanged<_Period> onSelected;

  const _PeriodTabBar({
    required this.selected,
    required this.isDarkMode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final trackColor =
        isDarkMode ? const Color(0xFF22252C) : const Color(0xFFE9EAF0);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / _Period.values.length;
          final selectedIndex = _Period.values.indexOf(selected);
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: tabWidth * selectedIndex,
                width: tabWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: selected.color,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: selected.color.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: _Period.values.map((period) {
                  final isSelected = period == selected;
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onSelected(period),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              period.icon,
                              size: 18,
                              color: isSelected
                                  ? Colors.white
                                  : (isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600]),
                            ),
                            const SizedBox(height: 3),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : (isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600]),
                              ),
                              child: Text(period.label),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A single swipeable page showing a gradient summary card + bar chart for
/// one period, colored with that period's signature color.
class _PeriodStatsView extends StatelessWidget {
  final _Period period;
  final Future<List<_Bucket>> Function() loader;
  final String totalLabel;

  const _PeriodStatsView({
    super.key,
    required this.period,
    required this.loader,
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
    final color = period.color;

    return FutureBuilder<List<_Bucket>>(
      future: loader(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: color),
          );
        }

        final buckets = snapshot.data!;
        final totalMinutes =
            buckets.fold<double>(0, (sum, b) => sum + b.minutes);
        final totalSessions =
            buckets.fold<int>(0, (sum, b) => sum + b.sessionCount);
        final maxMinutes = buckets.isEmpty
            ? 1.0
            : buckets
                .map((b) => b.minutes)
                .fold<double>(1.0, (a, b) => b > a ? b : a);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gradient summary card
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 400),
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 12),
                    child: child,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withValues(alpha: 0.7)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            totalLabel,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatMinutes(totalMinutes),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalSessions session${totalSessions == 1 ? '' : 's'} completed',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(period.icon, color: Colors.white, size: 28),
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
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: bucket.isCurrent
                                    ? color
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: barHeight.clamp(4.0, 160.0),
                              ),
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutCubic,
                              builder: (context, height, child) => Container(
                                height: height,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: bucket.isCurrent
                                        ? [
                                            color,
                                            color.withValues(alpha: 0.7),
                                          ]
                                        : [
                                            color.withValues(alpha: 0.35),
                                            color.withValues(alpha: 0.2),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
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
                                color: bucket.isCurrent ? color : null,
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
