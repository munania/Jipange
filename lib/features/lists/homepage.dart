import 'package:flutter/material.dart';
import 'package:locallists/data/task_database_helper.dart';
import 'package:locallists/features/lists/task_details.dart';
import 'package:locallists/features/lists/widgets/add_task_sheet.dart';
import 'package:locallists/features/lists/widgets/filter_bottom_sheet.dart';
import 'package:locallists/features/lists/widgets/task_list_item.dart';
import 'package:locallists/features/settings/settings.dart';
import 'package:locallists/services/notification_service.dart';
import 'package:locallists/utils/theme.dart';

import 'package:shared_preferences/shared_preferences.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

enum SortOption { custom, dateCreated, dueDate, alphabetical }

class _HomepageState extends State<Homepage> {
  List<Map<String, dynamic>> userTasks = [];
  Map<int, Map<String, dynamic>> _categoriesMap = {};
  bool _showCompleted = true;
  bool _isSearching = false;
  String _searchQuery = '';
  SortOption _currentSortOption = SortOption.custom;
  Set<int> _selectedCategoryIds = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showCompleted = prefs.getBool('showCompleted') ?? true;
    });
    _loadCategories();
    _loadTasks();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await TaskDatabaseHelper.instance.getAllCategories();
      setState(() {
        _categoriesMap = {for (var c in categories) c['id']: c};
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  // Load tasks from the database
  Future<void> _loadTasks() async {
    String? orderBy;
    switch (_currentSortOption) {
      case SortOption.dateCreated:
        orderBy = 'id DESC';
        break;
      case SortOption.dueDate:
        orderBy = 'due_date ASC';
        break;
      case SortOption.alphabetical:
        orderBy = 'title ASC';
        break;
      case SortOption.custom:
        orderBy = 'position ASC';
        break;
    }

    try {
      final tasks = await TaskDatabaseHelper.instance.getAllTasks(
        searchQuery: _searchQuery,
        orderBy: orderBy,
        categoryIds: _selectedCategoryIds.isEmpty
            ? null
            : _selectedCategoryIds.toList(),
      );

      setState(() {
        if (_showCompleted) {
          userTasks = tasks;
        } else {
          userTasks = tasks.where((t) => t['done'] == false).toList();
        }
      });
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      // Fallback to ID sort if position fails (likely due to missing column)
      if (orderBy == 'position ASC') {
        try {
          final tasks = await TaskDatabaseHelper.instance.getAllTasks(
            searchQuery: _searchQuery,
            orderBy: 'id DESC',
            categoryIds: _selectedCategoryIds.isEmpty
                ? null
                : _selectedCategoryIds.toList(),
          );
          setState(() {
            if (_showCompleted) {
              userTasks = tasks;
            } else {
              userTasks = tasks.where((t) => t['done'] == false).toList();
            }
          });
        } catch (e2) {
          debugPrint('Error loading tasks fallback: $e2');
        }
      }
    }
  }

  // Insert a new task into the database
  Future<void> _insertTask(Map<String, dynamic> taskData) async {
    final id = await TaskDatabaseHelper.instance.insertTask(taskData);
    if (taskData['due_date'] != null) {
      await NotificationService.instance.scheduleTaskNotification(
        taskId: id,
        taskTitle: taskData['title'],
        dueDateTime: DateTime.parse(taskData['due_date']),
      );
    }
    await _loadTasks();
  }

  // Update task details
  Future<void> _updateTask(int id, Map<String, dynamic> taskData) async {
    await TaskDatabaseHelper.instance.updateTaskTitle(id, taskData['title']);
    if (taskData['due_date'] != null) {
      await TaskDatabaseHelper.instance
          .updateTaskDueDate(id, taskData['due_date']);

      // Reschedule notification
      await NotificationService.instance.cancelTaskNotification(id);
      await NotificationService.instance.scheduleTaskNotification(
        taskId: id,
        taskTitle: taskData['title'],
        dueDateTime: DateTime.parse(taskData['due_date']),
      );
    }
    await _loadTasks();
  }

  // Update task status
  Future<void> _updateTaskStatus(int id, bool done) async {
    await TaskDatabaseHelper.instance.updateTaskStatus(id, done);
    if (done) {
      await NotificationService.instance.cancelTaskNotification(id);
    } else {
      // Re-schedule if unchecked? We'd need the due date.
      // For now, let's just cancel if done.
      // Ideally we should fetch the task to get the due date if we want to reschedule.
      final task = await TaskDatabaseHelper.instance.getTaskWithSubtasks(id);
      if (task != null && task['due_date'] != null) {
        await NotificationService.instance.scheduleTaskNotification(
          taskId: id,
          taskTitle: task['title'],
          dueDateTime: DateTime.parse(task['due_date']),
        );
      }
    }
    await _loadTasks();
  }

  // Delete a task
  Future<void> _deleteTask(int id) async {
    await TaskDatabaseHelper.instance.deleteTask(id);
    await NotificationService.instance.cancelTaskNotification(id);
    await _loadTasks();
  }

  // Show bottom sheet to add a new task
  void _showAddTaskBottomSheet({Map<String, dynamic>? task}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return AddTaskSheet(
          task: task,
          categoriesMap: _categoriesMap,
          isDarkMode: isDarkMode(context),
          onSave: (taskData) async {
            if (task == null) {
              await _insertTask(taskData);
            } else {
              await _updateTask(task['id'], taskData);
            }
          },
        );
      },
    );
  }

  // Show bottom sheet with sort/filter options
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return FilterBottomSheet(
          categoriesMap: _categoriesMap,
          currentSort: _currentSortOption,
          selectedCategoryIds: _selectedCategoryIds,
          isDarkMode: isDarkMode(context),
          onSortChanged: (sort) {
            setState(() => _currentSortOption = sort);
            _loadTasks();
          },
          onCategoriesChanged: (categoryIds) {
            setState(() => _selectedCategoryIds = categoryIds);
            _loadTasks();
          },
        );
      },
    );
  }

  // Toggle whether finished tasks are shown, persisted across launches
  Future<void> _toggleShowCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _showCompleted = !_showCompleted);
    await prefs.setBool('showCompleted', _showCompleted);
    _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search tasks...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                  _loadTasks();
                },
              )
            : const Text("Jipange"),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                  _loadTasks();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon:
                Icon(_showCompleted ? Icons.visibility : Icons.visibility_off),
            tooltip: _showCompleted ? 'Hide finished tasks' : 'Show finished tasks',
            onPressed: _toggleShowCompleted,
          ),
          IconButton(
            icon: Icon(
              Icons.tune,
              color: _selectedCategoryIds.isNotEmpty ||
                      _currentSortOption != SortOption.custom
                  ? (isDarkMode
                      ? AppThemes.lightSecondary
                      : AppThemes.darkPrimary)
                  : null,
            ),
            tooltip: 'Filter & Sort',
            onPressed: _showFilterSheet,
          ),
          IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Future.delayed(
                  const Duration(seconds: 0),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  ).then((_) {
                    _loadCategories(); // Reload categories after returning
                    _loadTasks();
                  }),
                );
              }),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding:
              const EdgeInsets.only(left: 16.0, right: 16, top: 16, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Tasks',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: userTasks.length,
                itemBuilder: (context, index) {
                  final task = userTasks[index];
                  return TaskListItem(
                    key: ValueKey(task['id']),
                    task: task,
                    categoriesMap: _categoriesMap,
                    isDarkMode: isDarkMode,
                    onDismiss: (direction) async {
                      if (direction == DismissDirection.endToStart) {
                        // Store the context's mounted status before the async gap
                        if (!context.mounted) return false;

                        // Show dialog and await the result
                        final bool? shouldDelete = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: const Text('Delete Task'),
                            content: const Text(
                                'Are you sure you want to delete this task?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete',
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
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TaskDetails(
                            taskTitle: task['title'],
                            taskId: task['id'],
                          ),
                        ),
                      );
                      // Reload categories and tasks after returning from TaskDetails
                      _loadCategories();
                      _loadTasks();
                    },
                    onStatusToggle: () =>
                        _updateTaskStatus(task['id'], !task['done']),
                    onEdit: () => _showAddTaskBottomSheet(task: task),
                  );
                },
                onReorderItem: (int oldIndex, int newIndex) {
                  // Prevent reordering if filtering is active or sorting is not custom or searching
                  if (!_showCompleted ||
                      _currentSortOption != SortOption.custom ||
                      _selectedCategoryIds.isNotEmpty ||
                      _searchQuery.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Cannot reorder when filtered, sorted, or searching')),
                    );
                    return;
                  }

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

                    // Update positions in database
                    final updatedTasks = userTasks.asMap().entries.map((e) {
                      return {
                        'id': e.value['id'],
                        'position': e.key,
                      };
                    }).toList();

                    TaskDatabaseHelper.instance
                        .updateTaskPositions(updatedTasks);
                  });
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'homepage_add_task_fab',
        backgroundColor: AppThemes.accentFor(isDarkMode),
        onPressed: () => _showAddTaskBottomSheet(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Note: intentionally NOT closing TaskDatabaseHelper here anymore.
    // Homepage now lives inside MainNavigation's IndexedStack alongside the
    // Pomodoro tab, and both share the same TaskDatabaseHelper singleton, so
    // closing it here could break Pomodoro session storage. The database
    // connection is left open for the lifetime of the app.
    super.dispose();
  }
}
