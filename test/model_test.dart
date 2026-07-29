import 'package:flutter_test/flutter_test.dart';
import 'package:locallists/features/task/task.dart';

void main() {
  group('Subtask Model Tests', () {
    test('should construct a Subtask successfully with default done value', () {
      final subtask = Subtask(title: 'Read a book');
      expect(subtask.title, 'Read a book');
      expect(subtask.done, isFalse);
      expect(subtask.id, isNull);
      expect(subtask.taskId, isNull);
    });

    test('should serialize to Map correctly', () {
      final subtask = Subtask(id: 1, taskId: 10, title: 'Write unit tests', done: true);
      final map = subtask.toMap();

      expect(map['id'], 1);
      expect(map['task_id'], 10);
      expect(map['title'], 'Write unit tests');
      expect(map['done'], 1);
    });

    test('should deserialize from Map correctly', () {
      final map = {
        'id': 2,
        'task_id': 20,
        'title': 'Verify task functionality',
        'done': 0,
      };
      final subtask = Subtask.fromMap(map);

      expect(subtask.id, 2);
      expect(subtask.taskId, 20);
      expect(subtask.title, 'Verify task functionality');
      expect(subtask.done, isFalse);
    });
  });

  group('Category Model Tests', () {
    test('should construct a Category successfully', () {
      final category = Category(name: 'Urgent', color: 0xFFFF0000, icon: 12345);
      expect(category.name, 'Urgent');
      expect(category.color, 0xFFFF0000);
      expect(category.icon, 12345);
    });

    test('should serialize to Map correctly', () {
      final category = Category(id: 5, name: 'Personal', color: 0xFF00FF00, icon: 54321);
      final map = category.toMap();

      expect(map['id'], 5);
      expect(map['name'], 'Personal');
      expect(map['color'], 0xFF00FF00);
      expect(map['icon'], 54321);
    });

    test('should deserialize from Map correctly', () {
      final map = {
        'id': 7,
        'name': 'Work',
        'color': 0xFF0000FF,
        'icon': 98765,
      };
      final category = Category.fromMap(map);

      expect(category.id, 7);
      expect(category.name, 'Work');
      expect(category.color, 0xFF0000FF);
      expect(category.icon, 98765);
    });
  });

  group('Task Model Tests', () {
    test('should construct a Task successfully with defaults', () {
      final task = Task(title: 'Plan weekend trip');
      expect(task.title, 'Plan weekend trip');
      expect(task.done, isFalse);
      expect(task.details, isNull);
      expect(task.dueDate, isNull);
      expect(task.categoryId, isNull);
      expect(task.position, isNull);
      expect(task.subtasks, isEmpty);
    });

    test('should serialize to Map correctly', () {
      final dueDate = DateTime(2025, 12, 31, 23, 59);
      final task = Task(
        id: 100,
        title: 'Review proposal',
        details: 'Review the project specs and proposal',
        done: true,
        dueDate: dueDate,
        position: 1,
        categoryId: 3,
        notificationId: 999,
      );

      final map = task.toMap();

      expect(map['id'], 100);
      expect(map['title'], 'Review proposal');
      expect(map['details'], 'Review the project specs and proposal');
      expect(map['done'], 1);
      expect(map['due_date'], dueDate.toIso8601String());
      expect(map['position'], 1);
      expect(map['category_id'], 3);
      expect(map['notification_id'], 999);
    });

    test('should deserialize from Map correctly', () {
      final dateStr = '2025-06-15T12:00:00.000';
      final map = {
        'id': 200,
        'title': 'Submit report',
        'details': 'Draft final report and submit to manager',
        'done': 0,
        'due_date': dateStr,
        'position': 5,
        'category_id': 2,
        'notification_id': 888,
      };

      final task = Task.fromMap(map);

      expect(task.id, 200);
      expect(task.title, 'Submit report');
      expect(task.details, 'Draft final report and submit to manager');
      expect(task.done, isFalse);
      expect(task.dueDate, DateTime.parse(dateStr));
      expect(task.position, 5);
      expect(task.categoryId, 2);
      expect(task.notificationId, 888);
    });
  });
}
