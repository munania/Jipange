import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class TaskDatabaseHelper {
  static final TaskDatabaseHelper instance = TaskDatabaseHelper._init();
  static Database? _database;

  TaskDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6, // Bumped to 6 to add pomodoro_sessions table
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (kDebugMode) {
      print('Upgrading database from $oldVersion to $newVersion');
    }

    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN due_date TEXT');
    }

    if (oldVersion < 3) {
      // Add details column to tasks table
      await db.execute('ALTER TABLE tasks ADD COLUMN details TEXT');

      // Create subtasks table
      await db.execute('''
        CREATE TABLE subtasks(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          task_id INTEGER,
          title TEXT,
          done INTEGER,
          FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
        )
      ''');

      // Enable foreign keys
      await db.execute('PRAGMA foreign_keys = ON');
    }

    // Combined migration for v4 and v5 to ensure schema is correct
    if (oldVersion < 5) {
      // Add category_id to tasks table
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN category_id INTEGER');
        if (kDebugMode) {
          print('Added category_id column');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error adding category_id (might already exist): $e');
        }
      }

      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN position INTEGER');
        if (kDebugMode) {
          print('Added position column');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error adding position (might already exist): $e');
        }
      }

      // Create categories table
      try {
        await db.execute('''
          CREATE TABLE categories(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            color INTEGER,
            icon INTEGER
          )
        ''');
        if (kDebugMode) {
          print('Created categories table');
        }

        // Insert default categories only if table was just created
        await db.insert('categories', {
          'name': 'Work',
          'color': 0xFF2196F3, // Colors.blue.value
          'icon': 58136, // Icons.work.codePoint
        });
        await db.insert('categories', {
          'name': 'Personal',
          'color': 0xFF4CAF50, // Colors.green.value
          'icon': 59389, // Icons.person.codePoint
        });
        await db.insert('categories', {
          'name': 'Shopping',
          'color': 0xFFFF9800, // Colors.orange.value
          'icon': 58780, // Icons.shopping_cart.codePoint
        });
        if (kDebugMode) {
          print('Inserted default categories');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error creating categories table (might already exist): $e');
        }
      }
    }

    if (oldVersion < 6) {
      try {
        await db.execute('''
          CREATE TABLE pomodoro_sessions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_type TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL,
            completed_at TEXT NOT NULL,
            task_id INTEGER,
            FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE SET NULL
          )
        ''');
        if (kDebugMode) {
          print('Created pomodoro_sessions table');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error creating pomodoro_sessions table (might already exist): $e');
        }
      }
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');

    // Create tasks table
    await db.execute('''
      CREATE TABLE tasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        title TEXT, 
        details TEXT,
        done INTEGER,
        due_date TEXT,
        category_id INTEGER,
        position INTEGER
      )
    ''');

    // Create subtasks table
    await db.execute('''
      CREATE TABLE subtasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER,
        title TEXT,
        done INTEGER,
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
      )
    ''');

    // Create categories table
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        color INTEGER,
        icon INTEGER
      )
    ''');

    // Insert default categories
    await db.insert('categories', {
      'name': 'Work',
      'color': 0xFF2196F3, // Colors.blue.value
      'icon': 58136, // Icons.work.codePoint
    });
    await db.insert('categories', {
      'name': 'Personal',
      'color': 0xFF4CAF50, // Colors.green.value
      'icon': 59389, // Icons.person.codePoint
    });
    await db.insert('categories', {
      'name': 'Shopping',
      'color': 0xFFFF9800, // Colors.orange.value
      'icon': 58780, // Icons.shopping_cart.codePoint
    });

    // Create pomodoro_sessions table
    await db.execute('''
      CREATE TABLE pomodoro_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_type TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        completed_at TEXT NOT NULL,
        task_id INTEGER,
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE SET NULL
      )
    ''');
  }

  /// Task CRUD Operations

  // Create (Insert) a new task
  Future<int> insertTask(Map<String, dynamic> task) async {
    final db = await instance.database;
    return await db.insert(
      'tasks',
      {
        'title': task['title'],
        'details': task['details'],
        'done': task['done'] ? 1 : 0,
        'due_date': task['due_date'],
        'category_id': task['category_id'],
        'position': task['position'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Read all tasks
  Future<List<Map<String, dynamic>>> getAllTasks({
    String? searchQuery,
    String? orderBy,
    List<int>? categoryIds,
  }) async {
    final db = await instance.database;

    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClauses.add('(title LIKE ? OR details LIKE ?)');
      whereArgs.addAll(['%$searchQuery%', '%$searchQuery%']);
    }

    if (categoryIds != null && categoryIds.isNotEmpty) {
      final placeholders = List.filled(categoryIds.length, '?').join(', ');
      whereClauses.add('category_id IN ($placeholders)');
      whereArgs.addAll(categoryIds);
    }

    final String? where =
        whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final List<Map<String, dynamic>> tasks = await db.query(
      'tasks',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderBy,
    );

    return tasks
        .map((task) => {
              'id': task['id'],
              'title': task['title'],
              'details': task['details'],
              'done': task['done'] == 1,
              'due_date': task['due_date'],
              'category_id': task['category_id'],
              'position': task['position'],
            })
        .toList();
  }

  // Get a single task with its subtasks
  Future<Map<String, dynamic>?> getTaskWithSubtasks(int taskId) async {
    final db = await instance.database;

    // Get the task
    final List<Map<String, dynamic>> tasks = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [taskId],
    );

    if (tasks.isEmpty) {
      return null;
    }

    // Get the subtasks
    final List<Map<String, dynamic>> subtasks = await db.query(
      'subtasks',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );

    // Convert the task and add its subtasks
    final task = {
      'id': tasks.first['id'],
      'title': tasks.first['title'],
      'details': tasks.first['details'],
      'done': tasks.first['done'] == 1,
      'due_date': tasks.first['due_date'],
      'category_id': tasks.first['category_id'],
      'position': tasks.first['position'],
      'subtasks': subtasks
          .map((subtask) => {
                'id': subtask['id'],
                'title': subtask['title'],
                'done': subtask['done'] == 1,
              })
          .toList(),
    };

    return task;
  }

  // Update task status
  Future<int> updateTaskStatus(int id, bool done) async {
    final db = await instance.database;
    return await db.update(
      'tasks',
      {'done': done ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Update task title
  Future<int> updateTaskTitle(int id, String title) async {
    final db = await instance.database;
    return await db.update(
      'tasks',
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Update task details
  Future<int> updateTaskDetails(int id, String details) async {
    final db = await instance.database;
    return await db.update(
      'tasks',
      {'details': details},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Update task due date
  Future<int> updateTaskDueDate(int id, String? dueDate) async {
    final db = await instance.database;
    return await db.update(
      'tasks',
      {'due_date': dueDate},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Update a complete task
  Future<int> updateTask(Map<String, dynamic> task) async {
    final db = await instance.database;
    return await db.update(
      'tasks',
      {
        'title': task['title'],
        'details': task['details'],
        'done': task['done'] ? 1 : 0,
        'due_date': task['due_date'],
        'category_id': task['category_id'],
        'position': task['position'],
      },
      where: 'id = ?',
      whereArgs: [task['id']],
    );
  }

  // Delete a task
  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Subtask CRUD Operations

  // Create (Insert) a new subtask
  Future<int> insertSubtask(Map<String, dynamic> subtask) async {
    final db = await instance.database;
    return await db.insert(
      'subtasks',
      {
        'task_id': subtask['task_id'],
        'title': subtask['title'],
        'done': subtask['done'] ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all subtasks for a task
  Future<List<Map<String, dynamic>>> getSubtasks(int taskId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> subtasks = await db.query(
      'subtasks',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );

    return subtasks
        .map((subtask) => {
              'id': subtask['id'],
              'task_id': subtask['task_id'],
              'title': subtask['title'],
              'done': subtask['done'] == 1,
            })
        .toList();
  }

  // Update subtask title
  Future<int> updateSubtaskTitle(int id, String title) async {
    final db = await instance.database;
    return await db.update(
      'subtasks',
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Update subtask status
  Future<int> updateSubtaskStatus(int id, bool done) async {
    final db = await instance.database;
    return await db.update(
      'subtasks',
      {'done': done ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete a subtask
  Future<int> deleteSubtask(int id) async {
    final db = await instance.database;
    return await db.delete(
      'subtasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete all subtasks for a task
  Future<int> deleteTaskSubtasks(int taskId) async {
    final db = await instance.database;
    return await db.delete(
      'subtasks',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
  }

  /// Batch operations

  // Save task with its subtasks (create or update)
  Future<void> saveTaskWithSubtasks(
      Map<String, dynamic> task, int? taskId) async {
    final db = await instance.database;

    await db.transaction((transaction) async {
      // Insert or update the main task
      if (taskId! > 0) {
        // Update existing task
        await transaction.update(
          'tasks',
          {
            'title': task['title'],
            'details': task['details'],
            'done': task['done'] ? 1 : 0,
            'due_date': task['due_date'],
            'category_id': task['category_id'],
            'position': task['position'],
          },
          where: 'id = ?',
          whereArgs: [taskId],
        );
      } else {
        // Insert new task
        taskId = await transaction.insert(
          'tasks',
          {
            'title': task['title'],
            'details': task['details'],
            'done': task['done'] ? 1 : 0,
            'due_date': task['due_date'],
            'category_id': task['category_id'],
            'position': task['position'],
          },
        );
      }

      // Handle subtasks if provided
      if (task.containsKey('subtasks')) {
        List<Map<String, dynamic>> subtasks = task['subtasks'];

        // Delete existing subtasks that aren't in the new list
        List<int> subtaskIds = subtasks
            .where((s) => s.containsKey('id'))
            .map<int>((s) => s['id'] as int)
            .toList();

        if (subtaskIds.isNotEmpty) {
          await transaction.delete(
            'subtasks',
            where:
                'task_id = ? AND id NOT IN (${subtaskIds.map((_) => '?').join(', ')})',
            whereArgs: [taskId, ...subtaskIds],
          );
        } else {
          // Delete all subtasks for this task
          await transaction.delete(
            'subtasks',
            where: 'task_id = ?',
            whereArgs: [taskId],
          );
        }

        // Insert or update subtasks
        for (var subtask in subtasks) {
          if (subtask.containsKey('id')) {
            // Update existing subtask
            await transaction.update(
              'subtasks',
              {
                'title': subtask['title'],
                'done': subtask['done'] ? 1 : 0,
              },
              where: 'id = ?',
              whereArgs: [subtask['id']],
            );
          } else {
            // Insert new subtask
            await transaction.insert(
              'subtasks',
              {
                'task_id': taskId,
                'title': subtask['title'],
                'done': subtask['done'] ? 1 : 0,
              },
            );
          }
        }
      }
    });
  }

  // CRUD for Categories

  Future<int> createCategory(Map<String, dynamic> category) async {
    final db = await instance.database;
    return await db.insert('categories', category);
  }

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await instance.database;
    return await db.query('categories');
  }

  Future<int> updateCategory(Map<String, dynamic> category) async {
    final db = await instance.database;
    return await db.update(
      'categories',
      category,
      where: 'id = ?',
      whereArgs: [category['id']],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    // Update tasks to remove category reference before deleting
    await db.update('tasks', {'category_id': null},
        where: 'category_id = ?', whereArgs: [id]);
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // Update task positions for reordering
  Future<void> updateTaskPositions(List<Map<String, dynamic>> tasks) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (var task in tasks) {
        await txn.update(
          'tasks',
          {'position': task['position']},
          where: 'id = ?',
          whereArgs: [task['id']],
        );
      }
    });
  }

  /// Pomodoro session operations

  // Record a completed pomodoro session
  Future<int> insertPomodoroSession({
    required String sessionType, // 'work', 'short_break', 'long_break'
    required int durationSeconds,
    required DateTime completedAt,
    int? taskId,
  }) async {
    final db = await instance.database;
    return await db.insert('pomodoro_sessions', {
      'session_type': sessionType,
      'duration_seconds': durationSeconds,
      'completed_at': completedAt.toIso8601String(),
      'task_id': taskId,
    });
  }

  // Get all pomodoro sessions between two dates (inclusive of start, exclusive of end)
  Future<List<Map<String, dynamic>>> getPomodoroSessions({
    required DateTime start,
    required DateTime end,
    String? sessionType,
  }) async {
    final db = await instance.database;

    final List<String> whereClauses = [
      'completed_at >= ?',
      'completed_at < ?',
    ];
    final List<dynamic> whereArgs = [
      start.toIso8601String(),
      end.toIso8601String(),
    ];

    if (sessionType != null) {
      whereClauses.add('session_type = ?');
      whereArgs.add(sessionType);
    }

    return await db.query(
      'pomodoro_sessions',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'completed_at ASC',
    );
  }

  // Delete a single pomodoro session (rarely needed, but useful for corrections)
  Future<int> deletePomodoroSession(int id) async {
    final db = await instance.database;
    return await db.delete('pomodoro_sessions',
        where: 'id = ?', whereArgs: [id]);
  }

  // Clear all pomodoro history
  Future<int> clearPomodoroHistory() async {
    final db = await instance.database;
    return await db.delete('pomodoro_sessions');
  }

  // Close the database
  Future<void> closeDatabase() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
