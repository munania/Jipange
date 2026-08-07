import 'package:flutter/material.dart';
import 'package:locallists/features/task/task.dart';
import 'package:locallists/utils/theme.dart';

class TaskListItem extends StatelessWidget {
  final Map<String, dynamic> task;
  final Map<int, Map<String, dynamic>> categoriesMap;
  final bool isDarkMode;
  final Function(DismissDirection) onDismiss;
  final VoidCallback onTap;
  final VoidCallback onStatusToggle;
  final VoidCallback onEdit;

  // Bulk-selection support. When [selectionMode] is true, tapping the card
  // toggles selection instead of opening task details, swipe actions are
  // disabled, and a checkbox + highlighted border reflect [isSelected].
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelectToggle;

  const TaskListItem({
    super.key,
    required this.task,
    required this.categoriesMap,
    required this.isDarkMode,
    required this.onDismiss,
    required this.onTap,
    required this.onStatusToggle,
    required this.onEdit,
    this.selectionMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onSelectToggle,
  });

  String _formatDate(DateTime date, BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final dateToCheck = DateTime(date.year, date.month, date.day);

    String timePart = '';
    if (date.hour != 0 || date.minute != 0) {
      timePart = ' at ${TimeOfDay.fromDateTime(date).format(context)}';
    }

    if (dateToCheck == today) {
      return 'Today$timePart';
    } else if (dateToCheck == tomorrow) {
      return 'Tomorrow$timePart';
    } else {
      return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year.toString().substring(2)}$timePart';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppThemes.accentFor(isDarkMode);
    final isDone = task['done'] == true;
    final priority = TaskPriority.fromValue(task['priority']);

    final card = Card(
      key: selectionMode ? null : ValueKey(task['id']),
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isSelected
            ? BorderSide(color: accent, width: 2)
            : BorderSide.none,
      ),
      color: isSelected ? accent.withValues(alpha: 0.08) : null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Priority stripe - only shown when a priority is actually set
            if (priority != TaskPriority.none && !selectionMode)
              Container(width: 4, color: priority.color),
            Expanded(
              child: InkWell(
                onTap: selectionMode ? onSelectToggle : onTap,
                onLongPress: onLongPress,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Selection checkbox
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, animation) =>
                            SizeTransition(
                          sizeFactor: animation,
                          axis: Axis.horizontal,
                          child: FadeTransition(
                              opacity: animation, child: child),
                        ),
                        child: selectionMode
                            ? Padding(
                                key: const ValueKey('checkbox'),
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isSelected ? accent : Colors.grey,
                                  size: 24,
                                ),
                              )
                            : const SizedBox(
                                key: ValueKey('no-checkbox'), width: 0),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDone
                                    ? (isDarkMode
                                        ? AppThemes.darkTextSecondary
                                        : AppThemes.lightTextSecondary)
                                    : (isDarkMode
                                        ? AppThemes.darkTextPrimary
                                        : AppThemes.lightTextPrimary),
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                              child: Text(task['title']),
                            ),
                            if (task['category_id'] != null &&
                                categoriesMap
                                    .containsKey(task['category_id'])) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    IconData(
                                        categoriesMap[task['category_id']]![
                                            'icon'],
                                        fontFamily: 'MaterialIcons'),
                                    size: 12,
                                    color: Color(categoriesMap[
                                        task['category_id']]!['color']),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    categoriesMap[
                                        task['category_id']]!['name'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(categoriesMap[
                                          task['category_id']]!['color']),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (task['due_date'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Due: ${_formatDate(DateTime.parse(task['due_date']), context)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode
                                      ? AppThemes.darkTextSecondary
                                      : AppThemes.lightTextSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!selectionMode)
                        GestureDetector(
                          onTap: onStatusToggle,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(
                              scale: animation,
                              child: child,
                            ),
                            child: Icon(
                              isDone
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              key: ValueKey(isDone),
                              color:
                                  isDone ? const Color(0xFF4CAF50) : accent,
                              size: 26,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Swipe actions (edit/delete) are only meaningful outside selection mode
    if (selectionMode) {
      return KeyedSubtree(key: ValueKey(task['id']), child: card);
    }

    return Dismissible(
      key: ValueKey(task['id']),
      background: Container(
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Row(
          children: [
            Icon(Icons.edit, color: Colors.white),
            SizedBox(width: 8),
            Text('Edit',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE24C4C),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.white),
          ],
        ),
      ),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit();
          return false; // Do not dismiss
        } else if (direction == DismissDirection.endToStart) {
          return await onDismiss(direction);
        }
        return false;
      },
      child: card,
    );
  }
}
