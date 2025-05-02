import 'package:flutter/material.dart';
import 'package:locallists/data/task_database_helper.dart';
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
  final List<SubtaskItem> subtasks = [];
  final TextEditingController detailsController = TextEditingController();
  bool isLoading = false;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    // Load existing task data if we're editing
    if (widget.taskId != null) {
      _loadTaskData();
    }
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

        // Populate due date
        if (taskData['due_date'] != null && taskData['due_date'].isNotEmpty) {
          selectedDate = DateTime.parse(taskData['due_date']);
        }

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
      // Format date as a string if selected
      final formattedDate = selectedDate?.toIso8601String();

      // Create the task object
      final task = {
        if (widget.taskId != null) 'id': widget.taskId,
        'title': widget.taskTitle,
        'details': detailsController.text,
        'done': false, // New tasks are not done by default
        'due_date': formattedDate,
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
        // Add this check
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

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                // mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Due Date Section
                  GestureDetector(
                    onTap: _showDatePicker,
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.grey),
                        const SizedBox(
                            width: 8), // Add spacing between the icon and text
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

                  // Clear due date button (if date is set)
                  if (selectedDate != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          selectedDate = null;
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
