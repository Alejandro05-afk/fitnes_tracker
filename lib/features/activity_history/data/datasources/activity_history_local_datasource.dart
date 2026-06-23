import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/activity_record_model.dart';

class ActivityHistoryLocalDatasource {
  static const _dbName = 'fitness_tracker.db';
  static const _dbVersion = 1;
  static const _tableName = 'activity_history';

  final Database _db;

  ActivityHistoryLocalDatasource._(this._db);

  static Future<ActivityHistoryLocalDatasource> create() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            activityType TEXT NOT NULL,
            stepCount INTEGER NOT NULL DEFAULT 0,
            distanceKm REAL NOT NULL DEFAULT 0,
            durationSeconds INTEGER NOT NULL DEFAULT 0,
            calories REAL NOT NULL DEFAULT 0,
            startTime TEXT NOT NULL,
            endTime TEXT,
            createdAt TEXT NOT NULL
          )
        ''');
      },
    );
    return ActivityHistoryLocalDatasource._(db);
  }

  Future<ActivityRecordModel> insert(ActivityRecordModel record) async {
    final id = await _db.insert(_tableName, record.toMap()..remove('id'));
    return record.copyWith(id: id);
  }

  Future<List<ActivityRecordModel>> getAll() async {
    final maps = await _db.query(_tableName, orderBy: 'createdAt DESC');
    return maps.map((map) => ActivityRecordModel.fromMap(map)).toList();
  }

  Future<ActivityRecordModel?> getById(int id) async {
    final maps = await _db.query(_tableName, where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return ActivityRecordModel.fromMap(maps.first);
  }

  Future<ActivityRecordModel> update(ActivityRecordModel record) async {
    await _db.update(
      _tableName,
      record.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [record.id],
    );
    return record;
  }

  Future<void> delete(int id) async {
    await _db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }
}
