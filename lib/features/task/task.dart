class Task {
  final int? id;
  final String title;
  final String? details;
  final bool done;
  final String? dueDate;
  final List<Subtask> subtasks;

  Task({
    this.id,
    required this.title,
    this.details,
    this.done = false,
    this.dueDate,
    this.subtasks = const [],
  });

  // Convert Task to a Map for database operations
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'details': details,
      'done': done,
      'due_date': dueDate,
      'subtasks': subtasks.map((subtask) => subtask.toMap()).toList(),
    };
  }

  // Create Task from a database Map
  factory Task.fromMap(Map<String, dynamic> map) {
    List<Subtask> subtasksList = [];

    if (map.containsKey('subtasks')) {
      subtasksList = (map['subtasks'] as List)
          .map((subtaskMap) => Subtask.fromMap(subtaskMap))
          .toList();
    }

    return Task(
      id: map['id'],
      title: map['title'],
      details: map['details'],
      done: map['done'] ?? false,
      dueDate: map['due_date'],
      subtasks: subtasksList,
    );
  }

  // Create a copy of this Task with some fields updated
  Task copyWith({
    int? id,
    String? title,
    String? details,
    bool? done,
    String? dueDate,
    List<Subtask>? subtasks,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      details: details ?? this.details,
      done: done ?? this.done,
      dueDate: dueDate ?? this.dueDate,
      subtasks: subtasks ?? this.subtasks,
    );
  }
}

class Subtask {
  final int? id;
  final String title;
  final bool done;

  Subtask({
    this.id,
    required this.title,
    this.done = false,
  });

  // Convert Subtask to a Map for database operations
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'done': done,
    };
  }

  // Create Subtask from a database Map
  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'],
      title: map['title'],
      done: map['done'] ?? false,
    );
  }

  // Create a copy of this Subtask with some fields updated
  Subtask copyWith({
    int? id,
    String? title,
    bool? done,
  }) {
    return Subtask(
      id: id ?? this.id,
      title: title ?? this.title,
      done: done ?? this.done,
    );
  }
}
