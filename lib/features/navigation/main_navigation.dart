import 'package:flutter/material.dart';
import 'package:locallists/features/lists/homepage.dart';
import 'package:locallists/features/pomodoro/pomodoro_screen.dart';
import 'package:locallists/utils/theme.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  static const _pages = [
    Homepage(),
    PomodoroScreen(),
  ];

  static const _items = [
    (icon: Icons.checklist_rounded, label: 'Tasks'),
    (icon: Icons.timer_rounded, label: 'Pomodoro'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accent = AppThemes.accentFor(isDarkMode);
    final surface = isDarkMode ? AppThemes.darkSurface : AppThemes.lightSurface;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: _currentIndex,
        items: _items,
        accent: accent,
        surface: surface,
        isDarkMode: isDarkMode,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final List<({IconData icon, String label})> items;
  final Color accent;
  final Color surface;
  final bool isDarkMode;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.items,
    required this.accent,
    required this.surface,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: (isDarkMode ? Colors.black : Colors.black26)
                  .withValues(alpha: isDarkMode ? 0.4 : 0.15),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / items.length;
            return Stack(
              children: [
                // Sliding highlight behind the selected item
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: itemWidth * currentIndex + 8,
                  top: 8,
                  width: itemWidth - 16,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: List.generate(items.length, (index) {
                    final isSelected = index == currentIndex;
                    final item = items[index];
                    return Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => onTap(index),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : (isDarkMode
                                    ? AppThemes.darkTextSecondary
                                    : AppThemes.lightTextSecondary),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedScale(
                                duration: const Duration(milliseconds: 220),
                                scale: isSelected ? 1.1 : 1.0,
                                child: Icon(
                                  item.icon,
                                  size: 22,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDarkMode
                                          ? AppThemes.darkTextSecondary
                                          : AppThemes.lightTextSecondary),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(item.label),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
