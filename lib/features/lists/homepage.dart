import 'package:flutter/material.dart';
import 'package:locallists/features/lists/task_details.dart';
import 'package:locallists/utils/theme.dart';

import '../../data/task_database_helper.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  List<Map<String, dynamic>> userTasks = [];
  final TextEditingController _taskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  // Load tasks from the database
  Future<void> _loadTasks() async {
    final tasks = await TaskDatabaseHelper.instance.getAllTasks();
    setState(() {
      userTasks = tasks;
    });
  }

  // Insert a new task into the database
  Future<void> _insertTask(Map<String, dynamic> taskData) async {
    await TaskDatabaseHelper.instance.insertTask(taskData);
    await _loadTasks();
  }

  // Update task completion status
  Future<void> _updateTask(int id, Map<String, dynamic> taskData) async {
    await TaskDatabaseHelper.instance.updateTaskTitle(id, taskData['title']);
    if (taskData['due_date'] != null) {
      await TaskDatabaseHelper.instance
          .updateTaskDueDate(id, taskData['due_date']);
    }
    await _loadTasks();
  }

  // Update task status
  Future<void> _updateTaskStatus(int id, bool done) async {
    await TaskDatabaseHelper.instance.updateTaskStatus(id, done);
    await _loadTasks();
  }

  // Delete a task
  Future<void> _deleteTask(int id) async {
    await TaskDatabaseHelper.instance.deleteTask(id);
    await _loadTasks();
  }

  // Date picker
  Future<DateTime?> _showDatePicker() async {
    final now = DateTime.now();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Define custom colors
    final primaryColor =
        isDarkMode ? AppThemes.lightSecondary : AppThemes.darkPrimary;

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
  }

  // Format date
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year.toString().substring(2)}';
  }

  // Show bottom sheet to add a new task
  void _showAddTaskBottomSheet({Map<String, dynamic>? task}) {
    DateTime? selectedDate;
    if (task != null) {
      _taskController.text = task['title'];
      selectedDate =
          task['due_date'] != null ? DateTime.parse(task['due_date']) : null;
    } else {
      _taskController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
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
                    cursorColor: isDarkMode(context)
                        ? AppThemes.lightSecondary
                        : AppThemes.darkPrimary,
                    controller: _taskController,
                    decoration: InputDecoration(
                      labelText:
                          task != null ? 'Edit task' : 'Enter a new task',
                      labelStyle: TextStyle(
                          color: isDarkMode(context)
                              ? AppThemes.lightSecondary
                              : AppThemes.darkPrimary),
                      hintText: task != null ? 'Update task title' : 'My task',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final date = await _showDatePicker();
                          if (date != null) {
                            setState(() => selectedDate = date);
                          }
                        },
                        icon: Icon(Icons.calendar_today, color: Colors.grey),
                        label: Text(
                          selectedDate != null
                              ? 'Due: ${_formatDate(selectedDate!)}'
                              : 'Set Due Date',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (_taskController.text.isNotEmpty) {
                        final taskData = {
                          'title': _taskController.text,
                          'done': false,
                          'due_date': selectedDate?.toIso8601String(),
                        };
                        // Capture the current context
                        final currentContext = context;
                        if (task == null) {
                          await _insertTask(taskData);
                        } else {
                          await _updateTask(task['id'], taskData);
                        }
                        _taskController.clear();

                        // Use the captured context
                        if (currentContext.mounted) {
                          Navigator.pop(currentContext);
                        }
                      }
                    },
                    child: Text(task != null ? 'Save Changes' : 'Add Task',
                        style: TextStyle(
                            color: isDarkMode(context)
                                ? AppThemes.darkPrimary
                                : AppThemes.lightSecondary)),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Jipange"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding:
              const EdgeInsets.only(left: 16.0, right: 16, top: 16, bottom: 70),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Tasks',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 16),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: userTasks.length,
                itemBuilder: (context, index) {
                  final task = userTasks[index];
                  return Dismissible(
                    key: ValueKey(task['id']),
                    background: Container(
                      color: Colors.blue,
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.only(left: 20),
                      child: Icon(Icons.edit, color: AppThemes.lightSecondary),
                    ),
                    secondaryBackground: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 20),
                      child:
                          Icon(Icons.delete, color: AppThemes.lightSecondary),
                    ),
                    direction: DismissDirection.horizontal,
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        _showAddTaskBottomSheet(
                            task: task); // Open bottom sheet for editing
                        return false; // Do not dismiss
                      } else if (direction == DismissDirection.endToStart) {
                        // Store the context's mounted status before the async gap
                        if (!context.mounted) return false;

                        // Show dialog and await the result
                        final bool? shouldDelete = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: Text('Delete Task'),
                            content: Text(
                                'Are you sure you want to delete this task?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );

                        if (shouldDelete == true) {
                          // Check if context is still mounted before proceeding
                          if (!context.mounted) return false;
                          await _deleteTask(task['id']);
                          return true; // Confirm delete
                        }
                      }
                      return false;
                    },
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TaskDetails(
                              taskTitle: task['title'],
                              taskId: task['id'],
                            ),
                          ),
                        );
                      },
                      child: Card(
                        key: ValueKey(task['id']),
                        margin: EdgeInsets.symmetric(vertical: 8),
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
                                    if (task['due_date'] != null) ...[
                                      SizedBox(height: 4),
                                      Text(
                                        'Due: ${_formatDate(DateTime.parse(task['due_date']))}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _updateTaskStatus(
                                    task['id'], !task['done']),
                                child: Icon(
                                  task['done']
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: task['done']
                                      ? isDarkMode(context)
                                          ? AppThemes.lightSecondary
                                          : AppThemes.darkSurface
                                      : isDarkMode(context)
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
                },
                onReorder: (int oldIndex, int newIndex) {
                  setState(() {
                    // Adjust newIndex if moving an item with a lower index to a higher index
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }

                    // Remove the item from the old index
                    final Map<String, dynamic> movedTask =
                        userTasks.removeAt(oldIndex);

                    // Insert the item at the new index
                    userTasks.insert(newIndex, movedTask);
                  });
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor:
            isDarkMode(context) ? AppThemes.darkSurface : AppThemes.darkPrimary,
        onPressed: _showAddTaskBottomSheet,
        child: Icon(Icons.add,
            color: isDarkMode(context)
                ? AppThemes.lightSecondary
                : AppThemes.lightSecondary),
      ),
    );
  }

  @override
  void dispose() {
    _taskController.dispose();
    TaskDatabaseHelper.instance.closeDatabase();
    super.dispose();
  }
}
