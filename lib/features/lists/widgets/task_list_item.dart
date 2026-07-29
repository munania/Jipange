import 'package:flutter/material.dart';
import 'package:locallists/utils/theme.dart';

class TaskListItem extends StatelessWidget {
  final Map<String, dynamic> task;
  final Map<int, Map<String, dynamic>> categoriesMap;
  final bool isDarkMode;
  final Function(DismissDirection) onDismiss;
  final VoidCallback onTap;
  final VoidCallback onStatusToggle;
  final VoidCallback onEdit;

  const TaskListItem({
    super.key,
    required this.task,
    required this.categoriesMap,
    required this.isDarkMode,
    required this.onDismiss,
    required this.onTap,
    required this.onStatusToggle,
    required this.onEdit,
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
    return Dismissible(
      key: ValueKey(task['id']),
      background: Container(
        color: Colors.blue,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(Icons.edit, color: AppThemes.lightSecondary),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: AppThemes.lightSecondary),
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
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          key: ValueKey(task['id']),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['title'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          decoration: task['done']
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      if (task['category_id'] != null &&
                          categoriesMap.containsKey(task['category_id'])) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              IconData(
                                  categoriesMap[task['category_id']]!['icon'],
                                  fontFamily: 'MaterialIcons'),
                              size: 12,
                              color: Color(
                                  categoriesMap[task['category_id']]!['color']),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              categoriesMap[task['category_id']]!['name'],
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onStatusToggle,
                  child: Icon(
                    task['done']
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: task['done']
                        ? isDarkMode
                            ? AppThemes.lightSecondary
                            : AppThemes.darkSurface
                        : isDarkMode
                            ? AppThemes.lightSecondary
                            : AppThemes.darkPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
