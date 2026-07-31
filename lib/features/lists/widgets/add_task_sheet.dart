import 'package:flutter/material.dart';
import 'package:locallists/utils/theme.dart';

class AddTaskSheet extends StatefulWidget {
  final Map<String, dynamic>? task;
  final Map<int, Map<String, dynamic>> categoriesMap;
  final Function(Map<String, dynamic> taskData) onSave;
  final bool isDarkMode;

  const AddTaskSheet({
    super.key,
    this.task,
    required this.categoriesMap,
    required this.onSave,
    required this.isDarkMode,
  });

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final TextEditingController _taskController = TextEditingController();
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  int? selectedCategoryId;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _taskController.text = widget.task!['title'];
      if (widget.task!['due_date'] != null) {
        final dt = DateTime.parse(widget.task!['due_date']);
        selectedDate = dt;
        if (dt.hour != 0 || dt.minute != 0) {
          selectedTime = TimeOfDay.fromDateTime(dt);
        }
      }
      selectedCategoryId = widget.task!['category_id'];
    } else {
      _taskController.clear();
      selectedCategoryId = null;
    }
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  // Format date
  String _formatDate(DateTime date) {
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

  Future<DateTime?> _showDatePicker() async {
    final now = DateTime.now();
    final primaryColor =
        widget.isDarkMode ? AppThemes.lightSecondary : AppThemes.darkPrimary;

    return showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      switchToInputEntryModeIcon: const Icon(Icons.calendar_today),
      switchToCalendarEntryModeIcon: const Icon(Icons.calendar_today),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              brightness:
                  widget.isDarkMode ? Brightness.dark : Brightness.light,
              primary: primaryColor,
              onPrimary:
                  widget.isDarkMode ? AppThemes.darkSurface : Colors.white,
              secondary: primaryColor,
              onSecondary: Colors.white,
              error: Colors.red,
              onError: Colors.white,
              surface: widget.isDarkMode ? AppThemes.darkSurface : Colors.white,
              onSurface: widget.isDarkMode ? Colors.white : Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryColor, // Cancel and OK button color
              ),
            ),
            dialogTheme: DialogThemeData(
                backgroundColor:
                    widget.isDarkMode ? AppThemes.darkSurface : Colors.white),
          ),
          child: child!,
        );
      },
    );
  }

  Future<TimeOfDay?> _showTimePicker() async {
    final primaryColor =
        widget.isDarkMode ? AppThemes.lightSecondary : AppThemes.darkPrimary;

    return showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              brightness:
                  widget.isDarkMode ? Brightness.dark : Brightness.light,
              primary: primaryColor,
              onPrimary:
                  widget.isDarkMode ? AppThemes.darkSurface : Colors.white,
              secondary: primaryColor,
              onSecondary: Colors.white,
              error: Colors.red,
              onError: Colors.white,
              surface: widget.isDarkMode ? AppThemes.darkSurface : Colors.white,
              onSurface: widget.isDarkMode ? Colors.white : Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
              ),
            ),
            dialogTheme: DialogThemeData(
                backgroundColor:
                    widget.isDarkMode ? AppThemes.darkSurface : Colors.white),
          ),
          child: child!,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            cursorColor: widget.isDarkMode
                ? AppThemes.lightSecondary
                : AppThemes.darkPrimary,
            controller: _taskController,
            decoration: InputDecoration(
              labelText: widget.task != null ? 'Edit task' : 'Enter a new task',
              labelStyle: TextStyle(
                  color: widget.isDarkMode
                      ? AppThemes.lightSecondary
                      : AppThemes.darkPrimary),
              hintText: widget.task != null ? 'Update task title' : 'My task',
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          // Category Dropdown
          DropdownButtonFormField<int>(
            initialValue: selectedCategoryId,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category),
            ),
            items: [
              const DropdownMenuItem<int>(
                value: null,
                child: Text('No Category'),
              ),
              ...widget.categoriesMap.values.map((category) {
                return DropdownMenuItem<int>(
                  value: category['id'],
                  child: Row(
                    children: [
                      Icon(
                        IconData(category['icon'], fontFamily: 'MaterialIcons'),
                        color: Color(category['color']),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(category['name']),
                    ],
                  ),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                selectedCategoryId = value;
              });
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await _showDatePicker();
                  if (date != null) {
                    setState(() => selectedDate = date);
                  }
                },
                icon: const Icon(Icons.calendar_today, color: Colors.grey),
                label: Text(
                  selectedDate != null
                      ? _formatDate(DateTime(
                          selectedDate!.year,
                          selectedDate!.month,
                          selectedDate!.day,
                          selectedTime?.hour ?? 0,
                          selectedTime?.minute ?? 0))
                      : 'Set Due Date',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              if (selectedDate != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final time = await _showTimePicker();
                    if (time != null) {
                      setState(() => selectedTime = time);
                    }
                  },
                  icon: const Icon(Icons.access_time, color: Colors.grey),
                  label: Text(
                    selectedTime != null
                        ? selectedTime!.format(context)
                        : 'Set Time',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (_taskController.text.isNotEmpty) {
                final taskData = {
                  'title': _taskController.text,
                  'done': false,
                  'due_date': selectedDate != null
                      ? DateTime(
                              selectedDate!.year,
                              selectedDate!.month,
                              selectedDate!.day,
                              selectedTime?.hour ?? 0,
                              selectedTime?.minute ?? 0)
                          .toIso8601String()
                      : null,
                  'category_id': selectedCategoryId,
                };
                widget.onSave(taskData);
                Navigator.pop(context);
              }
            },
            child: Text(widget.task != null ? 'Save Changes' : 'Add Task',
                style: TextStyle(
                    color: widget.isDarkMode
                        ? AppThemes.lightSecondary
                        : AppThemes.lightSecondary)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
