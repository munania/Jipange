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
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        title TEXT, 
        done INTEGER
      )
    ''');
  }

  // Create (Insert) a new task
  Future<int> insertTask(Map<String, dynamic> task) async {
    final db = await instance.database;
    return await db.insert(
      'tasks',
      {'title': task['title'], 'done': task['done'] ? 1 : 0},
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
              'done': task['done'] == 1
            })
        .toList();
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

  // Delete a task
  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Close the database
  Future<void> closeDatabase() async {
    final db = await instance.database;
    await db.close();
  }
}
