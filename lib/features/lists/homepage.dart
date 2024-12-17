import 'package:flutter/material.dart';
import 'package:locallists/utils/theme.dart';

import '../../data/taskDatabaseHelper.dart';

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
  Future<void> _insertTask(String title) async {
    final task = {'title': title, 'done': false};

    await TaskDatabaseHelper.instance.insertTask(task);
    await _loadTasks();
  }

  // Update task completion status
  Future<void> _updateTaskStatus(int id, bool done) async {
    await TaskDatabaseHelper.instance.updateTaskStatus(id, done);
    await _loadTasks();
  }

  // Update task title
  Future<void> _updateTaskTitle(int id, String title) async {
    await TaskDatabaseHelper.instance.updateTaskTitle(id, title);
    await _loadTasks(); // Reload tasks after the update
  }

  // Delete a task
  Future<void> _deleteTask(int id) async {
    await TaskDatabaseHelper.instance.deleteTask(id);
    await _loadTasks();
  }

  // Show bottom sheet to add a new task
  void _showAddTaskBottomSheet({Map<String, dynamic>? task}) {
    // Existing implementation remains the same
    if (task != null) {
      _taskController.text =
          task['title']; // Pre-fill the controller for editing
    } else {
      _taskController.clear(); // Clear the controller for adding
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
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
              SizedBox(height: 20),
              TextField(
                cursorColor: isDarkMode(context)
                    ? AppThemes.lightSecondary
                    : AppThemes.darkPrimary,
                controller: _taskController,
                decoration: InputDecoration(
                  labelText: task != null ? 'Edit task' : 'Enter a new task',
                  labelStyle: TextStyle(
                      color: isDarkMode(context)
                          ? AppThemes.lightSecondary
                          : AppThemes.darkPrimary),
                  hintText: task != null ? 'Update task title' : 'My task',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 2.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                ),
                autofocus: true,
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_taskController.text.isNotEmpty) {
                          if (task == null) {
                            // Add a new task
                            await _insertTask(_taskController.text);
                          } else {
                            // Update an existing task
                            await _updateTaskTitle(
                                task['id'], _taskController.text);
                          }
                          _taskController.clear();
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        task != null ? 'Save Changes' : 'Add Task',
                        style: TextStyle(
                            color: isDarkMode(context)
                                ? AppThemes.lightSecondary
                                : AppThemes.lightSecondary),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
            ],
          ),
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
                        await _deleteTask(task['id']);
                        return true; // Confirm delete
                      }
                      return false;
                    },
                    child: Card(
                      key: ValueKey(task['id']),
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                task['title'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  decoration: task['done']
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 20,
                            ),
                            GestureDetector(
                              onTap: () {
                                _updateTaskStatus(task['id'], !task['done']);
                              },
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
