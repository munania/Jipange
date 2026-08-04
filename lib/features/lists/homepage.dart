import 'package:flutter/material.dart';
import 'package:locallists/data/task_database_helper.dart';
import 'package:locallists/features/lists/task_details.dart';
import 'package:locallists/features/lists/widgets/add_task_sheet.dart';
import 'package:locallists/features/lists/widgets/filter_bottom_sheet.dart';
import 'package:locallists/features/lists/widgets/task_list_item.dart';
import 'package:locallists/features/settings/settings.dart';
import 'package:locallists/features/task/task.dart';
import 'package:locallists/services/notification_service.dart';
import 'package:locallists/services/search_history.dart';
import 'package:locallists/utils/theme.dart';

import 'package:shared_preferences/shared_preferences.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

enum SortOption { custom, dateCreated, dueDate, alphabetical, priority }

class _HomepageState extends State<Homepage> {
  List<Map<String, dynamic>> userTasks = [];
  Map<int, Map<String, dynamic>> _categoriesMap = {};
  bool _showCompleted = true;
  bool _isSearching = false;
  String _searchQuery = '';
  SortOption _currentSortOption = SortOption.custom;
  Set<int> _selectedCategoryIds = {};
  Set<int> _selectedPriorities = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<String> _recentSearches = [];

  // Bulk multi-select
  bool _selectionMode = false;
  Set<int> _selectedTaskIds = {};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadRecentSearches();
    // Rebuild when search focus changes so the recent-searches list can
    // show/hide itself.
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showCompleted = prefs.getBool('showCompleted') ?? true;
    });
    _loadCategories();
    _loadTasks();
  }

  Future<void> _loadRecentSearches() async {
    final recent = await SearchHistory.load();
    if (mounted) setState(() => _recentSearches = recent);
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
      case SortOption.priority:
        orderBy = 'priority DESC';
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
        priorities:
            _selectedPriorities.isEmpty ? null : _selectedPriorities.toList(),
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
            priorities: _selectedPriorities.isEmpty
                ? null
                : _selectedPriorities.toList(),
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
      await _spawnNextRecurrenceIfNeeded(id);
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

  // When a recurring task is completed, spawn the next occurrence as a new
  // task row (rather than mutating this one), so history/Pomodoro links on
  // the completed task stay intact. The next due date is calculated from
  // this task's own due date, not "now" - see RecurrenceRule.nextDueDate.
  Future<void> _spawnNextRecurrenceIfNeeded(int completedTaskId) async {
    final task =
        await TaskDatabaseHelper.instance.getTaskWithSubtasks(completedTaskId);
    if (task == null) return;

    final rule = RecurrenceRule.fromJson(task['recurrence_rule']);
    if (!rule.isActive) return;
    if (task['due_date'] == null) return; // shouldn't happen, but be safe

    final currentDue = DateTime.parse(task['due_date']);
    final nextDue = rule.nextDueDate(currentDue);

    final subtasks = (task['subtasks'] as List<dynamic>? ?? [])
        .map((s) => {
              'title': s['title'],
              'done': false,
            })
        .toList();

    final newTask = {
      'title': task['title'],
      'details': task['details'],
      'done': false,
      'due_date': nextDue.toIso8601String(),
      'category_id': task['category_id'],
      'position': task['position'],
      'priority': task['priority'],
      'recurrence_rule': task['recurrence_rule'],
      'recurrence_parent_id': completedTaskId,
      'subtasks': subtasks,
    };

    final newId =
        await TaskDatabaseHelper.instance.saveTaskWithSubtasks(newTask, null);

    // Only schedule a notification if the next due date carries a specific
    // time (matches how due dates with just a date, no time, are handled
    // elsewhere in the app).
    if (nextDue.hour != 0 || nextDue.minute != 0) {
      await NotificationService.instance.scheduleTaskNotification(
        taskId: newId,
        taskTitle: task['title'],
        dueDateTime: nextDue,
      );
    }
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
          selectedPriorities: _selectedPriorities,
          isDarkMode: isDarkMode(context),
          onSortChanged: (sort) {
            setState(() => _currentSortOption = sort);
            _loadTasks();
          },
          onCategoriesChanged: (categoryIds) {
            setState(() => _selectedCategoryIds = categoryIds);
            _loadTasks();
          },
          onPrioritiesChanged: (priorities) {
            setState(() => _selectedPriorities = priorities);
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

  // Run a search, saving it into recent-search history
  Future<void> _runSearch(String value) async {
    setState(() => _searchQuery = value);
    _loadTasks();
    if (value.trim().isNotEmpty) {
      final updated = await SearchHistory.add(value);
      if (mounted) setState(() => _recentSearches = updated);
    }
  }

  void _applyRecentSearch(String query) {
    _searchController.text = query;
    _searchController.selection =
        TextSelection.collapsed(offset: query.length);
    _runSearch(query);
    _searchFocusNode.unfocus();
  }

  Future<void> _removeRecentSearch(String query) async {
    final updated = await SearchHistory.remove(query);
    if (mounted) setState(() => _recentSearches = updated);
  }

  Future<void> _clearRecentSearches() async {
    await SearchHistory.clear();
    if (mounted) setState(() => _recentSearches = []);
  }

  // ---- Bulk selection ----

  void _enterSelectionMode(int taskId) {
    setState(() {
      _selectionMode = true;
      _selectedTaskIds = {taskId};
    });
  }

  void _toggleTaskSelection(int taskId) {
    setState(() {
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
      } else {
        _selectedTaskIds.add(taskId);
      }
      if (_selectedTaskIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedTaskIds = {};
    });
  }

  Future<void> _bulkDelete() async {
    final count = _selectedTaskIds.length;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tasks'),
        content: Text(
            'Are you sure you want to delete $count task${count == 1 ? '' : 's'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final ids = List<int>.from(_selectedTaskIds);
    for (final id in ids) {
      await _deleteTask(id);
    }
    _exitSelectionMode();
  }

  Future<void> _bulkMarkDone() async {
    final ids = List<int>.from(_selectedTaskIds);
    for (final id in ids) {
      await _updateTaskStatus(id, true);
    }
    _exitSelectionMode();
  }

  Future<void> _bulkMoveToCategory() async {
    final result = await showModalBottomSheet<int?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Move to category',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.grey),
                  title: const Text('No Category'),
                  onTap: () => Navigator.pop(context, -1),
                ),
                ..._categoriesMap.values.map((category) {
                  return ListTile(
                    leading: Icon(
                      IconData(category['icon'], fontFamily: 'MaterialIcons'),
                      color: Color(category['color']),
                    ),
                    title: Text(category['name']),
                    onTap: () => Navigator.pop(context, category['id']),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) return; // dismissed without a choice
    final categoryId = result == -1 ? null : result;

    final ids = List<int>.from(_selectedTaskIds);
    for (final id in ids) {
      await TaskDatabaseHelper.instance.updateTaskCategory(id, categoryId);
    }
    await _loadTasks();
    _exitSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accent = AppThemes.accentFor(isDarkMode);
    final showRecentSearches = _isSearching &&
        _searchFocusNode.hasFocus &&
        _searchQuery.isEmpty &&
        _recentSearches.isNotEmpty;

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectionMode) _exitSelectionMode();
      },
      child: Scaffold(
        appBar: _selectionMode
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitSelectionMode,
                ),
                title: Text('${_selectedTaskIds.length} selected'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    tooltip: 'Mark done',
                    onPressed:
                        _selectedTaskIds.isEmpty ? null : _bulkMarkDone,
                  ),
                  IconButton(
                    icon: const Icon(Icons.label_outline),
                    tooltip: 'Move to category',
                    onPressed:
                        _selectedTaskIds.isEmpty ? null : _bulkMoveToCategory,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    onPressed: _selectedTaskIds.isEmpty ? null : _bulkDelete,
                  ),
                ],
              )
            : AppBar(
                title: _isSearching
                    ? TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
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
                          setState(() => _searchQuery = value);
                          _loadTasks();
                        },
                        onSubmitted: _runSearch,
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
                    icon: Icon(_showCompleted
                        ? Icons.visibility
                        : Icons.visibility_off),
                    tooltip: _showCompleted
                        ? 'Hide finished tasks'
                        : 'Show finished tasks',
                    onPressed: _toggleShowCompleted,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.tune,
                      color: _selectedCategoryIds.isNotEmpty ||
                              _selectedPriorities.isNotEmpty ||
                              _currentSortOption != SortOption.custom
                          ? accent
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
            padding: const EdgeInsets.only(
                left: 16.0, right: 16, top: 16, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showRecentSearches) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent searches',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: _clearRecentSearches,
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _recentSearches.map((query) {
                      return InputChip(
                        avatar: const Icon(Icons.history, size: 16),
                        label: Text(query),
                        onPressed: () => _applyRecentSearch(query),
                        onDeleted: () => _removeRecentSearch(query),
                        deleteIconColor: Colors.grey,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
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
                    final taskId = task['id'] as int;
                    return TaskListItem(
                      key: ValueKey(taskId),
                      task: task,
                      categoriesMap: _categoriesMap,
                      isDarkMode: isDarkMode,
                      selectionMode: _selectionMode,
                      isSelected: _selectedTaskIds.contains(taskId),
                      onLongPress: () => _enterSelectionMode(taskId),
                      onSelectToggle: () => _toggleTaskSelection(taskId),
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
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );

                          if (shouldDelete == true) {
                            // Check if context is still mounted before proceeding
                            if (!context.mounted) return false;
                            await _deleteTask(taskId);
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
                              taskId: taskId,
                            ),
                          ),
                        );
                        // Reload categories and tasks after returning from TaskDetails
                        _loadCategories();
                        _loadTasks();
                      },
                      onStatusToggle: () =>
                          _updateTaskStatus(taskId, !task['done']),
                      onEdit: () => _showAddTaskBottomSheet(task: task),
                    );
                  },
                  onReorderItem: (int oldIndex, int newIndex) {
                    // Prevent reordering if filtering is active or sorting is not custom or searching
                    if (!_showCompleted ||
                        _currentSortOption != SortOption.custom ||
                        _selectedCategoryIds.isNotEmpty ||
                        _selectedPriorities.isNotEmpty ||
                        _selectionMode ||
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
        floatingActionButton: _selectionMode
            ? null
            : FloatingActionButton(
                heroTag: 'homepage_add_task_fab',
                backgroundColor: accent,
                onPressed: () => _showAddTaskBottomSheet(),
                child: const Icon(Icons.add, color: Colors.white),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    // Note: intentionally NOT closing TaskDatabaseHelper here anymore.
    // Homepage now lives inside MainNavigation's IndexedStack alongside the
    // Pomodoro tab, and both share the same TaskDatabaseHelper singleton, so
    // closing it here could break Pomodoro session storage. The database
    // connection is left open for the lifetime of the app.
    super.dispose();
  }
}
