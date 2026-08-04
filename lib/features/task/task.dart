import 'dart:convert';

import 'package:flutter/material.dart';

/// How a recurring task repeats. Stored as JSON in `tasks.recurrence_rule`
/// (e.g. '{"type":"weekly","interval":1}'), null/none meaning "doesn't repeat".
enum RecurrenceType { none, daily, weekly, monthly, custom }

class RecurrenceRule {
  final RecurrenceType type;
  // Used by "custom" (every N days). Daily/weekly/monthly always step by 1
  // of their own unit.
  final int interval;

  const RecurrenceRule({required this.type, this.interval = 1});

  static const none = RecurrenceRule(type: RecurrenceType.none);

  bool get isActive => type != RecurrenceType.none;

  String get label {
    switch (type) {
      case RecurrenceType.none:
        return 'None';
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.monthly:
        return 'Monthly';
      case RecurrenceType.custom:
        return 'Every $interval day${interval == 1 ? '' : 's'}';
    }
  }

  /// Null when the rule is "none" (matches how it's stored: no row value).
  String? toJson() {
    if (type == RecurrenceType.none) return null;
    return jsonEncode({'type': type.name, 'interval': interval});
  }

  static RecurrenceRule fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return RecurrenceRule.none;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final type = RecurrenceType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => RecurrenceType.none,
      );
      final interval = (map['interval'] as num?)?.toInt() ?? 1;
      return RecurrenceRule(type: type, interval: interval);
    } catch (_) {
      return RecurrenceRule.none;
    }
  }

  /// The next occurrence's due date, computed from the *previous* due date
  /// (not "now") so a late completion doesn't shift the whole cadence -
  /// e.g. a daily task due Monday but completed Thursday still lines its
  /// next occurrence up as Tuesday, not Friday.
  DateTime nextDueDate(DateTime from) {
    switch (type) {
      case RecurrenceType.none:
        return from;
      case RecurrenceType.daily:
        return from.add(const Duration(days: 1));
      case RecurrenceType.weekly:
        return from.add(const Duration(days: 7));
      case RecurrenceType.monthly:
        return DateTime(from.year, from.month + 1, from.day, from.hour,
            from.minute);
      case RecurrenceType.custom:
        return from.add(Duration(days: interval));
    }
  }
}

/// Task priority levels. The integer `value` is what's stored in the
/// `tasks.priority` column (0 = none/default).
enum TaskPriority {
  none(0),
  low(1),
  medium(2),
  high(3);

  final int value;
  const TaskPriority(this.value);

  static TaskPriority fromValue(int? value) {
    return TaskPriority.values.firstWhere(
      (p) => p.value == value,
      orElse: () => TaskPriority.none,
    );
  }

  String get label {
    switch (this) {
      case TaskPriority.none:
        return 'None';
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  Color get color {
    switch (this) {
      case TaskPriority.none:
        return Colors.grey;
      case TaskPriority.low:
        return const Color(0xFF4CAF50); // green
      case TaskPriority.medium:
        return const Color(0xFFEF8B3B); // orange
      case TaskPriority.high:
        return const Color(0xFFE24C4C); // red
    }
  }

  IconData get icon {
    switch (this) {
      case TaskPriority.none:
        return Icons.remove;
      case TaskPriority.low:
        return Icons.keyboard_arrow_down;
      case TaskPriority.medium:
        return Icons.drag_handle;
      case TaskPriority.high:
        return Icons.keyboard_arrow_up;
    }
  }
}

class Task {
  int? id;
  String title;
  String? details;
  bool done;
  DateTime? dueDate;
  int? position;
  int? categoryId;
  int? notificationId;
  List<Subtask> subtasks;

  Task({
    this.id,
    required this.title,
    this.details,
    this.done = false,
    this.dueDate,
    this.position,
    this.categoryId,
    this.notificationId,
    this.subtasks = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'details': details,
      'done': done ? 1 : 0,
      'due_date': dueDate?.toIso8601String(),
      'position': position,
      'category_id': categoryId,
      'notification_id': notificationId,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      details: map['details'],
      done: map['done'] == 1,
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
      position: map['position'],
      categoryId: map['category_id'],
      notificationId: map['notification_id'],
    );
  }
}

class Subtask {
  int? id;
  int? taskId;
  String title;
  bool done;

  Subtask({
    this.id,
    this.taskId,
    required this.title,
    this.done = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'title': title,
      'done': done ? 1 : 0,
    };
  }

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'],
      taskId: map['task_id'],
      title: map['title'],
      done: map['done'] == 1,
    );
  }
}

class Category {
  int? id;
  String name;
  int? color;
  int? icon;

  Category({
    this.id,
    required this.name,
    this.color,
    this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'icon': icon,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      color: map['color'],
      icon: map['icon'],
    );
  }
}
