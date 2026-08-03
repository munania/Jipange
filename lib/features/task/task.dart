import 'package:flutter/material.dart';

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
