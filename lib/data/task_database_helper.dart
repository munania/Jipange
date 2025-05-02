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
      version: 3, // Increased version number for schema changes
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
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
        due_date TEXT
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
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Read all tasks
  Future<List<Map<String, dynamic>>> getAllTasks() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> tasks = await db.query('tasks');

    return tasks
        .map((task) => {
              'id': task['id'],
              'title': task['title'],
              'details': task['details'],
              'done': task['done'] == 1,
              'due_date': task['due_date'],
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

  // Create a new subtask
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

  // Close the database
  Future<void> closeDatabase() async {
    final db = await instance.database;
    await db.close();
  }
}
