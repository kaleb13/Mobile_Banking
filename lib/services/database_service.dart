import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sender.dart';
import '../models/transaction.dart';
import '../models/app_notification.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('finance_v3.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path,
        version: 3, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const doubleType = 'REAL NOT NULL';
    const boolType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE senders (
  id $idType,
  senderName $textType,
  depositKeywords $textType,
  expenseKeywords $textType
)
''');

    await db.execute('''
CREATE TABLE transactions (
  id $textType PRIMARY KEY,
  name $textType,
  amount $doubleType,
  type $textType,
  date $textType,
  sender $textType,
  category $textType,
  rawMessage $textType,
  isAutoDetected $boolType,
  totalBalance $doubleType,
  reason TEXT
)
''');

    await db.execute('''
CREATE TABLE notifications (
  id TEXT PRIMARY KEY,
  sender TEXT NOT NULL,
  body TEXT NOT NULL,
  date TEXT NOT NULL,
  isRead INTEGER NOT NULL DEFAULT 0
)
''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS notifications (
  id TEXT PRIMARY KEY,
  sender TEXT NOT NULL,
  body TEXT NOT NULL,
  date TEXT NOT NULL,
  isRead INTEGER NOT NULL DEFAULT 0
)
''');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE transactions ADD COLUMN reason TEXT;');
    }
  }

  // --- Sender Methods ---
  Future<int> insertSender(AppSender sender) async {
    final db = await instance.database;
    return await db.insert('senders', sender.toMap());
  }

  Future<List<AppSender>> getSenders() async {
    final db = await instance.database;
    final maps = await db.query('senders');
    return maps.map((map) => AppSender.fromMap(map)).toList();
  }

  Future<int> updateSender(AppSender sender) async {
    final db = await instance.database;
    return db.update(
      'senders',
      sender.toMap(),
      where: 'id = ?',
      whereArgs: [sender.id],
    );
  }

  Future<int> deleteSender(String id) async {
    final db = await instance.database;
    return await db.delete('senders', where: 'id = ?', whereArgs: [id]);
  }

  // --- Transaction Methods ---
  Future<int> insertTransaction(AppTransaction transaction) async {
    final db = await instance.database;
    final idToUse =
        transaction.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final map = transaction.toMap();
    map['id'] = idToUse;

    return await db.insert(
      'transactions',
      map,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> updateTransaction(AppTransaction transaction) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<List<AppTransaction>> getTransactions() async {
    final db = await instance.database;
    const orderBy = 'date DESC';
    final maps = await db.query('transactions', orderBy: orderBy);
    return maps.map((map) => AppTransaction.fromMap(map)).toList();
  }

  Future<DateTime?> getLastTransactionDate() async {
    final db = await instance.database;
    final map = await db.query(
      'transactions',
      columns: ['date'],
      orderBy: 'date DESC',
      limit: 1,
    );

    if (map.isNotEmpty) {
      final dateString = map.first['date'] as String?;
      if (dateString != null) {
        return DateTime.parse(dateString);
      }
    }
    return null;
  }

  // --- Notification Methods ---
  Future<void> insertNotification(AppNotification notification) async {
    final db = await instance.database;
    await db.insert(
      'notifications',
      notification.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<AppNotification>> getNotifications() async {
    final db = await instance.database;
    final maps = await db.query('notifications', orderBy: 'date DESC');
    return maps.map((map) => AppNotification.fromMap(map)).toList();
  }

  Future<int> getUnreadNotificationCount() async {
    final db = await instance.database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM notifications WHERE isRead = 0');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<void> markAllNotificationsRead() async {
    final db = await instance.database;
    await db.update('notifications', {'isRead': 1});
  }

  Future<void> deleteNotification(String id) async {
    final db = await instance.database;
    await db.delete('notifications', where: 'id = ?', whereArgs: [id]);
  }
}
