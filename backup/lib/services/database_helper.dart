import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sleep_record.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sleep_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 创建新表结构
      await db.execute('''
        CREATE TABLE sleep_records_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          startTime TEXT NOT NULL,
          endTime TEXT NOT NULL,
          duration INTEGER NOT NULL,
          quality TEXT NOT NULL,
          notes TEXT
        )
      ''');

      // 迁移数据
      await db.execute('''
        INSERT INTO sleep_records_new (id, startTime, endTime, duration, quality, notes)
        SELECT id, startTime, endTime, duration, quality, notes FROM sleep_records
      ''');

      // 删除旧表
      await db.execute('DROP TABLE sleep_records');

      // 重命名新表
      await db.execute('ALTER TABLE sleep_records_new RENAME TO sleep_records');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sleep_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        duration INTEGER NOT NULL,
        quality TEXT NOT NULL,
        notes TEXT
      )
    ''');
  }

  Future<int> insertSleepRecord(SleepRecord record) async {
    final db = await database;
    return await db.insert('sleep_records', record.toMap());
  }

  Future<List<SleepRecord>> getSleepRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sleep_records');
    return List.generate(maps.length, (i) => SleepRecord.fromMap(maps[i]));
  }

  Future<SleepRecord?> getSleepRecord(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sleep_records',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return SleepRecord.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateSleepRecord(SleepRecord record) async {
    final db = await database;
    return await db.update(
      'sleep_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteSleepRecord(int id) async {
    final db = await database;
    return await db.delete(
      'sleep_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }

  Future<List<SleepRecord>> getAllSleepRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sleep_records');
    return List.generate(maps.length, (i) => SleepRecord.fromMap(maps[i]));
  }
} 