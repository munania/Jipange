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

// Order matters - matches the swipeable tab order (Today, All, No Due Date).
enum HomeTab { today, all, noDueDate }

extension on HomeTab {
  String get label {
    switch (this) {
      case HomeTab.today:
        return 'Today';
      case HomeTab.all:
        return 'All';
      case HomeTab.noDueDate:
        return 'No Due Date';
    }
  }

  IconData get icon {
    switch (this) {
      case HomeTab.today:
        return Icons.today_rounded;
      case HomeTab.all:
        return Icons.list_alt_rounded;
      case HomeTab.noDueDate:
        return Icons.event_busy_rounded;
    }
  }
}

class _HomepageState extends State<Homepage> {
  List<Map<String, dynamic>> userTasks = [];
  Map<int, Map<String, dynamic>> _categoriesMap = {};
  // Auto-hides completed tasks by default so finished work doesn't clutter
  // the list; the eye icon in the AppBar still lets it be toggled back on.
  bool _showCompleted = false;
  bool _isSearching = false;
  String _searchQuery = '';
  SortOption _currentSortOption = SortOption.custom;
  Set<int> _selectedCategoryIds = {};
  Set<int> _selectedPriorities = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<String> _recentSearches = [];

  // Today / All / No Due Date swipeable tabs
  HomeTab _selectedTab = HomeTab.today;
  late final PageController _tabPageController =
      PageController(initialPage: HomeTab.today.index);

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
      _showCompleted = prefs.getBool('showCompleted') ?? false;
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

  // Filters the already-loaded (and already search/category/priority
  // filtered) task list down to what a given tab should show.
  List<Map<String, dynamic>> _tasksForTab(HomeTab tab) {
    switch (tab) {
      case HomeTab.today:
        final now = DateTime.now();
        return userTasks.where((t) {
          if (t['due_date'] == null) return false;
          final d = DateTime.parse(t['due_date']);
          return d.year == now.year &&
              d.month == now.month &&
              d.day == now.day;
        }).toList();
      case HomeTab.noDueDate:
        return userTasks.where((t) => t['due_date'] == null).toList();
      case HomeTab.all:
        return userTasks;
    }
  }

  void _onTabTapped(HomeTab tab) {
    setState(() => _selectedTab = tab);
    _tabPageController.animateToPage(
      tab.index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
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

  // Segmented Today/All/No Due Date control with a sliding colored
  // indicator, matching the style used elsewhere in the app (e.g. the
  // Pomodoro analytics period tabs).
  Widget _buildHomeTabBar(bool isDarkMode, Color accent) {
    final trackColor =
        isDarkMode ? const Color(0xFF22252C) : const Color(0xFFE9EAF0);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / HomeTab.values.length;
          final selectedIndex = _selectedTab.index;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: tabWidth * selectedIndex,
                width: tabWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: HomeTab.values.map((tab) {
                  final isSelected = tab == _selectedTab;
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _onTabTapped(tab),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tab.icon,
                              size: 18,
                              color: isSelected
                                  ? Colors.white
                                  : (isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600]),
                            ),
                            const SizedBox(height: 3),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : (isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600]),
                              ),
                              child: Text(tab.label, textAlign: TextAlign.center),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyTabMessage(HomeTab tab, bool isDarkMode) {
    String message;
    IconData icon;
    switch (tab) {
      case HomeTab.today:
        message = 'Nothing due today. Enjoy the breathing room.';
        icon = Icons.wb_sunny_outlined;
        break;
      case HomeTab.noDueDate:
        message = 'No open-ended tasks right now.';
        icon = Icons.event_busy_outlined;
        break;
      case HomeTab.all:
        message = 'No tasks yet - tap + to add one.';
        icon = Icons.checklist_rtl;
        break;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 40,
                color: isDarkMode
                    ? AppThemes.darkTextSecondary
                    : AppThemes.lightTextSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDarkMode
                    ? AppThemes.darkTextSecondary
                    : AppThemes.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskListForTab(HomeTab tab, bool isDarkMode) {
    final tasksForThisTab = _tasksForTab(tab);

    if (tasksForThisTab.isEmpty) {
      return _emptyTabMessage(tab, isDarkMode);
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: tasksForThisTab.length,
      itemBuilder: (context, index) {
        final task = tasksForThisTab[index];
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
              if (!context.mounted) return false;

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
                if (!context.mounted) return false;
                await _deleteTask(taskId);
                return true;
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
            _loadCategories();
            _loadTasks();
          },
          onStatusToggle: () => _updateTaskStatus(taskId, !task['done']),
          onEdit: () => _showAddTaskBottomSheet(task: task),
        );
      },
      onReorderItem: (int oldIndex, int newIndex) {
        // Reordering only makes sense on the unfiltered "All" tab - the
        // custom `position` ordering is global, so reordering within a
        // date-filtered subset (Today/No Due Date) would corrupt it.
        if (tab != HomeTab.all ||
            !_showCompleted ||
            _currentSortOption != SortOption.custom ||
            _selectedCategoryIds.isNotEmpty ||
            _selectedPriorities.isNotEmpty ||
            _selectionMode ||
            _searchQuery.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Switch to the All tab (with no filters/search) to reorder')),
          );
          return;
        }

        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }

          final Map<String, dynamic> movedTask =
              userTasks.removeAt(oldIndex);
          userTasks.insert(newIndex, movedTask);

          final updatedTasks = userTasks.asMap().entries.map((e) {
            return {
              'id': e.value['id'],
              'position': e.key,
            };
          }).toList();

          TaskDatabaseHelper.instance.updateTaskPositions(updatedTasks);
        });
      },
    );
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
        body: Column(
          children: [
            if (showRecentSearches)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _buildHomeTabBar(isDarkMode, accent),
            ),
            Expanded(
              child: PageView(
                controller: _tabPageController,
                onPageChanged: (index) {
                  setState(() => _selectedTab = HomeTab.values[index]);
                },
                children: HomeTab.values
                    .map((tab) => _buildTaskListForTab(tab, isDarkMode))
                    .toList(),
              ),
            ),
          ],
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
    _tabPageController.dispose();
    super.dispose();
  }
}
