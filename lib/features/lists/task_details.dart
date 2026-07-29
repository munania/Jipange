import 'package:flutter/material.dart';
import 'package:locallists/data/task_database_helper.dart';
import 'package:locallists/features/task/task.dart';
import 'package:locallists/services/notification_service.dart';
import 'package:locallists/utils/theme.dart' show AppThemes;

class TaskDetails extends StatefulWidget {
  final String taskTitle;
  final int? taskId; // Optional task ID for editing existing tasks

  const TaskDetails({
    super.key,
    required this.taskTitle,
    required this.taskId,
  });

  @override
  State<TaskDetails> createState() => _TaskDetailsState();
}

class _TaskDetailsState extends State<TaskDetails> {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  int? position;
  int? selectedCategoryId;
  List<Category> categories = [];
  final List<SubtaskItem> subtasks = [];
  final TextEditingController detailsController = TextEditingController();
  bool isLoading = false;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Load categories first
    await _loadCategories();
    // Then load task data if editing
    if (widget.taskId != null) {
      await _loadTaskData();
    }
  }

  Future<void> _loadCategories() async {
    final cats = await TaskDatabaseHelper.instance.getAllCategories();
    setState(() {
      categories = cats.map((c) => Category.fromMap(c)).toList();
    });
  }

  @override
  void dispose() {
    // Clean up controllers
    detailsController.dispose();
    for (var subtask in subtasks) {
      subtask.controller.dispose();
    }
    super.dispose();
  }

  // Load task data from database
  Future<void> _loadTaskData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final taskData =
          await TaskDatabaseHelper.instance.getTaskWithSubtasks(widget.taskId!);

      if (taskData != null) {
        // Populate details
        detailsController.text = taskData['details'] ?? '';

        // Populate due date and time
        if (taskData['due_date'] != null && taskData['due_date'].isNotEmpty) {
          final dateTime = DateTime.parse(taskData['due_date']);
          selectedDate = dateTime;
          // Extract time if it's not midnight (meaning time was set)
          if (dateTime.hour != 0 || dateTime.minute != 0) {
            selectedTime =
                TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
          }
        }

        // Populate position
        position = taskData['position'];

        // Populate category
        selectedCategoryId = taskData['category_id'];

        // Populate subtasks
        if (taskData.containsKey('subtasks')) {
          final List<dynamic> subtasksList = taskData['subtasks'];
          subtasks.clear();
          for (var subtask in subtasksList) {
            final controller = TextEditingController(text: subtask['title']);
            subtasks.add(SubtaskItem(
              id: subtask['id'],
              controller: controller,
              isDone: subtask['done'],
            ));
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error loading task: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Save task to database
  Future<void> _saveTask() async {
    if (!mounted) return;
    setState(() {
      isSaving = true;
    });

    try {
      // Format date with time if both are selected
      String? formattedDate;
      if (selectedDate != null) {
        if (selectedTime != null) {
          // Combine date and time
          final dateTime = DateTime(
            selectedDate!.year,
            selectedDate!.month,
            selectedDate!.day,
            selectedTime!.hour,
            selectedTime!.minute,
          );
          formattedDate = dateTime.toIso8601String();
        } else {
          formattedDate = selectedDate!.toIso8601String();
        }
      }

      // Create the task object
      final task = {
        if (widget.taskId != null) 'id': widget.taskId,
        'title': widget.taskTitle,
        'details': detailsController.text,
        'done': false, // New tasks are not done by default
        'due_date': formattedDate,
        'position': position,
        'category_id': selectedCategoryId,
        'subtasks': subtasks
            .map((subtask) => {
                  if (subtask.id != null) 'id': subtask.id,
                  'title': subtask.controller.text,
                  'done': subtask.isDone,
                })
            .toList(),
      };

      // Save to database
      await TaskDatabaseHelper.instance
          .saveTaskWithSubtasks(task, widget.taskId);

      // Schedule notification if due date/time is set
      if (formattedDate != null && selectedTime != null) {
        final dueDateTime = DateTime(
          selectedDate!.year,
          selectedDate!.month,
          selectedDate!.day,
          selectedTime!.hour,
          selectedTime!.minute,
        );

        // Only schedule if in the future
        if (dueDateTime.isAfter(DateTime.now())) {
          final notificationId =
              await NotificationService.instance.scheduleTaskNotification(
            taskId: widget.taskId ?? task['id'] as int,
            taskTitle: widget.taskTitle,
            dueDateTime: dueDateTime,
          );

          // Update task with notification ID
          if (widget.taskId == null) {
            // For new tasks, update the notification_id
            await TaskDatabaseHelper.instance.updateTask({
              'id': task['id'],
              'notification_id': notificationId,
            });
          }
        }
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task saved successfully')),
        );
      }

      // Navigate back
      if (mounted) {
        Navigator.pop(context, true); // Pass true to indicate change
      }
    } catch (e) {
      _showErrorSnackBar('Error saving task: $e');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Date picker
  Future<void> _showDatePicker() async {
    final now = DateTime.now();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Define custom colors
    final primaryColor =
        isDarkMode ? AppThemes.lightSecondary : AppThemes.darkPrimary;

    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      switchToInputEntryModeIcon: const Icon(Icons.calendar_today),
      switchToCalendarEntryModeIcon: const Icon(Icons.calendar_today),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              brightness: isDarkMode ? Brightness.dark : Brightness.light,
              primary: primaryColor,
              onPrimary: isDarkMode ? AppThemes.darkSurface : Colors.white,
              secondary: primaryColor,
              onSecondary: Colors.white,
              error: Colors.red,
              onError: Colors.white,
              surface: isDarkMode ? AppThemes.darkSurface : Colors.white,
              onSurface: isDarkMode ? Colors.white : Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryColor, // Cancel and OK button color
              ),
            ),
            dialogTheme: DialogThemeData(
                backgroundColor:
                    isDarkMode ? AppThemes.darkSurface : Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      setState(() => selectedDate = date);
    }
  }

  // Format date
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year.toString().substring(2)}';
  }

  // Time picker
  Future<void> _showTimePicker() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppThemes.lightSecondary : AppThemes.darkPrimary;

    final time = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              brightness: isDarkMode ? Brightness.dark : Brightness.light,
              primary: primaryColor,
              onPrimary: isDarkMode ? AppThemes.darkSurface : Colors.white,
              secondary: primaryColor,
              onSecondary: Colors.white,
              error: Colors.red,
              onError: Colors.white,
              surface: isDarkMode ? AppThemes.darkSurface : Colors.white,
              onSurface: isDarkMode ? Colors.white : Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
              ),
            ),
            dialogTheme: DialogThemeData(
                backgroundColor:
                    isDarkMode ? AppThemes.darkSurface : Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (time != null && mounted) {
      setState(() => selectedTime = time);
    }
  }

  // Toggle subtask completion
  void _toggleSubtaskDone(int index) {
    setState(() {
      subtasks[index].isDone = !subtasks[index].isDone;
    });
  }

  // Create a subtask widget
  Widget _buildSubtaskWidget(int index) {
    final subtask = subtasks[index];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          // Checkbox/radio button
          GestureDetector(
            onTap: () => _toggleSubtaskDone(index),
            child: Icon(
              subtask.isDone
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: subtask.isDone ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 10),
          // Text field
          Expanded(
            child: TextFormField(
              controller: subtask.controller,
              cursorColor: Theme.of(context).brightness == Brightness.dark
                  ? AppThemes.lightBackground
                  : AppThemes.lightTextSecondary,
              minLines: 1,
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Add Subtask',
                hintStyle: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                enabledBorder: InputBorder.none,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      subtasks.removeAt(index);
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.taskTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskTitle),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Details Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 12.0),
                    child: Icon(Icons.my_library_books, color: Colors.grey),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: detailsController,
                      cursorColor: isDarkMode
                          ? AppThemes.lightBackground
                          : AppThemes.lightTextSecondary,
                      minLines: 1,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: 'Add Details',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        enabledBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Category Dropdown
              DropdownButtonFormField<int>(
                value: selectedCategoryId,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('No Category'),
                  ),
                  ...categories.map((category) {
                    return DropdownMenuItem<int>(
                      value: category.id,
                      child: Row(
                        children: [
                          Icon(
                            IconData(category.icon!,
                                fontFamily: 'MaterialIcons'),
                            color: Color(category.color!),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(category.name),
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Due Date Section
                  GestureDetector(
                    onTap: _showDatePicker,
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          selectedDate != null
                              ? 'Due: ${_formatDate(selectedDate!)}'
                              : 'Add Due Date',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Time picker button (only show if date is selected)
                  if (selectedDate != null)
                    GestureDetector(
                      onTap: _showTimePicker,
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            selectedTime != null
                                ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                                : 'Add Time',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(width: 10),

                  // Clear due date button (if date is set)
                  if (selectedDate != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          selectedDate = null;
                          selectedTime = null; // Also clear time
                        });
                      },
                      child: const Text('Clear Due Date',
                          style: TextStyle(color: Colors.grey)),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // List of subtasks
              ...List.generate(
                subtasks.length,
                (index) => _buildSubtaskWidget(index),
              ),

              const SizedBox(height: 20),

              // Add Subtask Button
              GestureDetector(
                onTap: () {
                  setState(() {
                    subtasks.add(SubtaskItem(
                      controller: TextEditingController(),
                      isDone: false,
                    ));
                  });
                },
                child: Row(
                  children: [
                    const Icon(Icons.account_tree_rounded, color: Colors.grey),
                    const SizedBox(width: 10),
                    Text(
                      'Add Subtask',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor:
            isDarkMode ? AppThemes.darkSurface : AppThemes.darkPrimary,
        onPressed: isSaving ? null : _saveTask,
        label: isSaving
            ? const Text('')
            : const Text(
                'Save',
                style: TextStyle(color: Colors.white),
              ),
        icon: isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : Icon(
                Icons.save,
                color: isDarkMode
                    ? AppThemes.lightSecondary
                    : AppThemes.lightSecondary,
              ),
      ),
    );
  }
}

// Helper class to track subtask data
class SubtaskItem {
  final int? id; // Database ID (null for new subtasks)
  final TextEditingController controller;
  bool isDone;

  SubtaskItem({
    this.id,
    required this.controller,
    this.isDone = false,
  });
}
