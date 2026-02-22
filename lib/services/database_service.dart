import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sender.dart';
import '../models/transaction.dart';

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

    return await openDatabase(path, version: 1, onCreate: _createDB);
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
  totalBalance $doubleType
)
''');
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
    // Generate an ID if it's not provided
    // We already use String? id in AppTransaction, we'll ensure FinanceProvider or TelebirrParser sets it.
    // Wait, if it's not set, let's create a temporary UUID or fallback ID.
    final idToUse =
        transaction.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final map = transaction.toMap();
    map['id'] = idToUse;

    return await db.insert(
      'transactions',
      map,
      conflictAlgorithm: ConflictAlgorithm.ignore, // Ignore duplicates
    );
  }

  Future<List<AppTransaction>> getTransactions() async {
    final db = await instance.database;
    final orderBy = 'date DESC';
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
}
