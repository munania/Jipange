import 'dart:async';

import 'package:flutter/material.dart';
import 'package:locallists/data/task_database_helper.dart';
import 'package:locallists/features/lists/widgets/recurrence_picker_sheet.dart';
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

class _TaskDetailsState extends State<TaskDetails> with WidgetsBindingObserver {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  int? position;
  int? selectedCategoryId;
  TaskPriority priority = TaskPriority.none;
  RecurrenceRule recurrenceRule = RecurrenceRule.none;
  List<Category> categories = [];
  final List<SubtaskItem> subtasks = [];
  final TextEditingController detailsController = TextEditingController();
  bool isLoading = false;
  bool isSaving = false;
  bool isTaskDone = false;

  // Drives insert/remove animations for the subtasks list
  final GlobalKey<AnimatedListState> _subtaskListKey =
      GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    detailsController.addListener(_scheduleDebouncedSave);
    _initializeData();
  }

  // Autosave whenever the app is backgrounded, closed, or the OS is about
  // to reclaim it - so changes on this page are never lost by leaving the
  // app rather than tapping Save explicitly.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      if (!isLoading) {
        _performSave(showSnackbar: false, popAfter: false);
      }
    }
  }

  Future<void> _initializeData() async {
    // Load categories first
    await _loadCategories();
    // Then load task data if editing
    if (widget.taskId != null) {
      await _loadTaskData();
    } else if (mounted) {
      setState(() => isLoading = false);
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
    WidgetsBinding.instance.removeObserver(this);
    _saveDebounce?.cancel();
    // Clean up controllers
    detailsController.dispose();
    for (var subtask in subtasks) {
      subtask.controller.dispose();
      subtask.focusNode.dispose();
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
        recurrenceRule = RecurrenceRule.fromJson(taskData['recurrence_rule']);
        priority = TaskPriority.fromValue(taskData['priority']);

        isTaskDone = taskData['done'] == true || taskData['done'] == 1;

        // Populate subtasks (no animation for initial load)
        if (taskData.containsKey('subtasks')) {
          final List<dynamic> subtasksList = taskData['subtasks'];
          subtasks.clear();
          for (var subtask in subtasksList) {
            final controller = TextEditingController(text: subtask['title']);
            controller.addListener(_scheduleDebouncedSave);
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

  // Explicit Save button - shows feedback and always navigates back
  Future<void> _saveTask() => _performSave(showSnackbar: true, popAfter: true);

  // Shared save routine used by the Save button, back-navigation, and the
  // app-lifecycle autosave. `showSnackbar`/`popAfter` let each caller decide
  // how loud/navigational the save should be (e.g. a background autosave
  // should never try to pop or show UI).
  Future<bool> _performSave({
    required bool showSnackbar,
    required bool popAfter,
  }) async {
    if (!mounted) return false;
    setState(() {
      isSaving = true;
    });

    bool success = false;

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
        'done': isTaskDone, // New tasks are not done by default
        'due_date': formattedDate,
        'position': position,
        'category_id': selectedCategoryId,
        'priority': priority.value,
        'recurrence_rule': recurrenceRule.toJson(),
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

      success = true;

      // Show success message
      if (mounted && showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task saved successfully')),
        );
      }
    } catch (e) {
      if (showSnackbar) _showErrorSnackBar('Error saving task: $e');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }

    // Navigate back
    if (popAfter && mounted) {
      Navigator.pop(context, true); // Pass true to indicate change
    }

    return success;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Color get _accentColor {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode ? AppThemes.lightSecondary : AppThemes.darkPrimary;
  }

  // Date picker
  Future<void> _showDatePicker() async {
    final now = DateTime.now();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = _accentColor;

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
    final primaryColor = _accentColor;

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

  // Show a bottom sheet to pick a category
  Future<void> _showCategoryPicker() async {
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
                      'Category',
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
                  trailing: selectedCategoryId == null
                      ? Icon(Icons.check, color: _accentColor)
                      : null,
                  onTap: () => Navigator.pop(context, -1),
                ),
                ...categories.map((category) {
                  final isSelected = selectedCategoryId == category.id;
                  return ListTile(
                    leading: Icon(
                      IconData(category.icon!, fontFamily: 'MaterialIcons'),
                      color: Color(category.color!),
                    ),
                    title: Text(category.name),
                    trailing:
                        isSelected ? Icon(Icons.check, color: _accentColor) : null,
                    onTap: () => Navigator.pop(context, category.id),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    // -1 is our sentinel for "No Category" since null means "sheet dismissed"
    if (result != null && mounted) {
      setState(() {
        selectedCategoryId = result == -1 ? null : result;
      });
    }
  }

  Category? get _selectedCategory {
    if (selectedCategoryId == null) return null;
    try {
      return categories.firstWhere((c) => c.id == selectedCategoryId);
    } catch (_) {
      return null;
    }
  }

  // Shared pill-style container used for the category and due-date controls
  Widget _buildPill({
    required Widget child,
    required VoidCallback onTap,
    Color? borderColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor ?? Colors.grey.withValues(alpha: 0.4),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildCategoryPill() {
    final category = _selectedCategory;
    final color = category != null ? Color(category.color!) : Colors.grey;

    return _buildPill(
      onTap: _showCategoryPicker,
      borderColor: category != null ? color.withValues(alpha: 0.6) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            category != null
                ? IconData(category.icon!, fontFamily: 'MaterialIcons')
                : Icons.category_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              category?.name ?? 'Category',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: category != null ? color : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueDatePill() {
    final hasDate = selectedDate != null;

    return _buildPill(
      onTap: _showDatePicker,
      borderColor: hasDate ? _accentColor.withValues(alpha: 0.6) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            size: 16,
            color: hasDate ? _accentColor : Colors.grey,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              hasDate ? _formatDate(selectedDate!) : 'Due Date',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: hasDate ? _accentColor : Colors.grey,
              ),
            ),
          ),
          if (hasDate) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: _showTimePicker,
              child: Icon(Icons.access_time,
                  size: 16, color: _accentColor.withValues(alpha: 0.8)),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                setState(() {
                  selectedDate = null;
                  selectedTime = null;
                  // Repeating without a due date doesn't make sense - clear
                  // it too so the Repeat pill goes back to disabled/"None".
                  recurrenceRule = RecurrenceRule.none;
                });
                _persistNow();
              },
              child: const Icon(Icons.close, size: 16, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showRecurrencePicker() async {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Set a due date first to enable repeating')),
      );
      return;
    }

    final result = await showModalBottomSheet<RecurrenceRule>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => RecurrencePickerSheet(
        current: recurrenceRule,
        isDarkMode: Theme.of(context).brightness == Brightness.dark,
      ),
    );

    if (result != null && mounted) {
      setState(() => recurrenceRule = result);
      _persistNow();
    }
  }

  Widget _buildRepeatPill() {
    final enabled = selectedDate != null;
    final isActive = recurrenceRule.isActive;

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Align(
        alignment: Alignment.centerLeft,
        child: _buildPill(
          onTap: _showRecurrencePicker,
          borderColor: isActive ? _accentColor.withValues(alpha: 0.6) : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.repeat,
                size: 16,
                color: isActive ? _accentColor : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                isActive ? recurrenceRule.label : 'Repeat',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isActive ? _accentColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Toggle subtask completion
  void _toggleSubtaskDone(int index) {
    setState(() {
      subtasks[index].isDone = !subtasks[index].isDone;
    });
    _persistNow();
  }

  // Add a new (empty) subtask with a smooth insert animation
  void _addSubtask() {
    final newItem = SubtaskItem(
      controller: TextEditingController(),
      isDone: false,
    );
    // Persist as soon as the user stops typing the subtask's title, rather
    // than relying solely on back-navigation/app-lifecycle autosave timing.
    newItem.controller.addListener(_scheduleDebouncedSave);
    subtasks.add(newItem);
    _subtaskListKey.currentState?.insertItem(
      subtasks.length - 1,
      duration: const Duration(milliseconds: 300),
    );
    // Autofocus the newly added subtask field
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) newItem.focusNode.requestFocus();
    });
  }

  // Remove a subtask with a smooth removal animation
  void _removeSubtask(int index) {
    final removedItem = subtasks[index];
    removedItem.controller.removeListener(_scheduleDebouncedSave);
    _subtaskListKey.currentState?.removeItem(
      index,
      (context, animation) =>
          _buildAnimatedSubtaskRow(removedItem, index, animation),
      duration: const Duration(milliseconds: 250),
    );
    subtasks.removeAt(index);
    _persistNow();
  }

  // Debounced auto-save: fires ~600ms after the user stops typing, so
  // subtask/detail text is persisted well before they navigate away rather
  // than depending entirely on a single save-on-exit.
  Timer? _saveDebounce;
  void _scheduleDebouncedSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), _persistNow);
  }

  // Fire-and-forget immediate save, used by all the auto-save triggers
  // above. Intentionally silent (no snackbar/pop) so it never interrupts
  // what the user is doing.
  void _persistNow() {
    _performSave(showSnackbar: false, popAfter: false);
  }

  // Wraps a subtask row with the fade + size transition used for both
  // insertion and removal so they feel consistent.
  Widget _buildAnimatedSubtaskRow(
      SubtaskItem subtask, int index, Animation<double> animation) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return SizeTransition(
      sizeFactor: curved,
      child: FadeTransition(
        opacity: curved,
        child: _buildSubtaskWidget(subtask, index),
      ),
    );
  }

  // Create a subtask row
  Widget _buildSubtaskWidget(SubtaskItem subtask, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          // Checkbox/radio button with a subtle animated swap
          GestureDetector(
            onTap: () => _toggleSubtaskDone(index),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: child,
              ),
              child: Icon(
                subtask.isDone
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                key: ValueKey(subtask.isDone),
                color: subtask.isDone ? Colors.green : Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Text field
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 16,
                color: subtask.isDone ? Colors.grey : null,
                decoration:
                    subtask.isDone ? TextDecoration.lineThrough : null,
              ),
              child: TextFormField(
                controller: subtask.controller,
                focusNode: subtask.focusNode,
                cursorColor: _accentColor,
                minLines: 1,
                maxLines: null,
                style: TextStyle(
                  color: subtask.isDone ? Colors.grey : null,
                  decoration:
                      subtask.isDone ? TextDecoration.lineThrough : null,
                ),
                decoration: InputDecoration(
                  hintText: 'Add Subtask',
                  hintStyle: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
            onPressed: () => _removeSubtask(index),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = subtasks.where((s) => s.isDone).length;

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _performSave(showSnackbar: false, popAfter: false);
        if (mounted) {
          Navigator.pop(context, true);
        }
      },
      child: Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Title at the very top
              Text(
                widget.taskTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Category + due date, side by side
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildCategoryPill()),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDueDatePill()),
                ],
              ),

              const SizedBox(height: 16),

              // Priority selector
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TaskPriority.values.map((p) {
                  final isSelected = priority == p;
                  return ChoiceChip(
                    selected: isSelected,
                    avatar: Icon(
                      p.icon,
                      size: 16,
                      color: isSelected ? Colors.white : p.color,
                    ),
                    label: Text(p.label),
                    selectedColor: p.color,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (selected) {
                      setState(() => priority = selected ? p : TaskPriority.none);
                      _persistNow();
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Repeat selector (enabled once a due date is set)
              _buildRepeatPill(),

              const SizedBox(height: 24),

              // Details textarea, styled to comfortably hold paragraphs
              Text(
                'Details',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextFormField(
                  controller: detailsController,
                  cursorColor: _accentColor,
                  minLines: 5,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    hintText: 'Write as much as you need...',
                    hintStyle: TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Subtasks header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Subtasks',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (subtasks.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            key: ValueKey('$doneCount/${subtasks.length}'),
                            '$doneCount/${subtasks.length}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: _accentColor),
                    tooltip: 'Add Subtask',
                    onPressed: _addSubtask,
                  ),
                ],
              ),

              // Animated subtasks list
              AnimatedList(
                key: _subtaskListKey,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                initialItemCount: subtasks.length,
                itemBuilder: (context, index, animation) {
                  // Guard against transient index mismatches during removal
                  if (index >= subtasks.length) return const SizedBox.shrink();
                  return _buildAnimatedSubtaskRow(
                      subtasks[index], index, animation);
                },
              ),

              if (subtasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: GestureDetector(
                    onTap: _addSubtask,
                    child: Row(
                      children: [
                        Icon(Icons.account_tree_rounded,
                            color: Colors.grey.withValues(alpha: 0.7)),
                        const SizedBox(width: 10),
                        Text(
                          'Add a subtask',
                          style: TextStyle(
                              color: Colors.grey.withValues(alpha: 0.9)),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'task_details_save_fab',
        backgroundColor: _accentColor,
        onPressed: isSaving ? null : _saveTask,
        label: isSaving
            ? const Text('')
            : const Text(
                'Save',
                style: TextStyle(color: Colors.white),
              ),
        icon: isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(
                Icons.save,
                color: Colors.white,
              ),
      ),
      ),
    );
  }
}

// Helper class to track subtask data
class SubtaskItem {
  final int? id; // Database ID (null for new subtasks)
  final TextEditingController controller;
  final FocusNode focusNode = FocusNode();
  bool isDone;

  SubtaskItem({
    this.id,
    required this.controller,
    this.isDone = false,
  });
}
