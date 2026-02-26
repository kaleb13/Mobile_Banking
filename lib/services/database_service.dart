import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sender.dart';
import '../models/transaction.dart';
import '../models/app_notification.dart';
import '../models/reason.dart';
import '../models/loan_record.dart';

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
        version: 6, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  // ──────────────────────────────────────────────
  // Schema creation (fresh install)
  // ──────────────────────────────────────────────
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE senders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  senderName TEXT NOT NULL,
  depositKeywords TEXT NOT NULL,
  expenseKeywords TEXT NOT NULL
)
''');

    await db.execute('''
CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  amount REAL NOT NULL,
  type TEXT NOT NULL,
  date TEXT NOT NULL,
  sender TEXT NOT NULL,
  category TEXT NOT NULL,
  rawMessage TEXT NOT NULL,
  isAutoDetected INTEGER NOT NULL,
  totalBalance REAL NOT NULL,
  reason TEXT,
  reasonId INTEGER,
  customReasonText TEXT
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

    await db.execute('''
CREATE TABLE reasons (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  isSystem INTEGER NOT NULL DEFAULT 0
)
''');

    await db.execute('''
CREATE TABLE reason_links (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reasonId INTEGER NOT NULL,
  linkedName TEXT NOT NULL,
  linkType TEXT NOT NULL
)
''');

    // Seed system-defined reasons
    await _seedSystemReasons(db);

    // Loan tables
    await _createLoanTables(db);
  }

  Future<void> _createLoanTables(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS loan_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  loanType TEXT NOT NULL,
  personName TEXT NOT NULL,
  trackedSenderName TEXT,
  principalAmount REAL NOT NULL,
  paidAmount REAL NOT NULL DEFAULT 0.0,
  loanDate TEXT NOT NULL,
  dueDate TEXT NOT NULL,
  linkedTransactionId TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  note TEXT
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS loan_payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  loanId INTEGER NOT NULL,
  amount REAL NOT NULL,
  paymentDate TEXT NOT NULL,
  linkedTransactionId TEXT,
  note TEXT,
  FOREIGN KEY(loanId) REFERENCES loan_records(id) ON DELETE CASCADE
)
''');
  }

  // ──────────────────────────────────────────────
  // Migrations
  // ──────────────────────────────────────────────
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
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN reason TEXT;');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      // Add new transaction columns
      try {
        await db
            .execute('ALTER TABLE transactions ADD COLUMN reasonId INTEGER;');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE transactions ADD COLUMN customReasonText TEXT;');
      } catch (_) {}

      // Create reasons & reason_links tables
      await db.execute('''
CREATE TABLE IF NOT EXISTS reasons (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  isSystem INTEGER NOT NULL DEFAULT 0
)
''');
      await db.execute('''
CREATE TABLE IF NOT EXISTS reason_links (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reasonId INTEGER NOT NULL,
  linkedName TEXT NOT NULL,
  linkType TEXT NOT NULL
)
''');

      // Seed system reasons if not already there
      final existing = await db.query('reasons', where: 'isSystem = 1');
      if (existing.isEmpty) {
        await _seedSystemReasons(db);
      }
    }
    if (oldVersion < 5) {
      await _createLoanTables(db);
    }
    if (oldVersion < 6) {
      await _addNewSystemReasons(db);
    }
  }

  Future<void> _seedSystemReasons(Database db) async {
    const systemReasons = [
      'Food',
      'Salary',
      'Transport',
      'Rent',
      'Shopping',
      'Utilities',
      'Internet',
      'Fuel',
      'Medical',
      'Gift',
      'Loan',
      'Entertainment',
      'Education',
      'Investment',
      'Airtime',
      'Cash',
    ];
    for (final name in systemReasons) {
      await db.insert('reasons', {'name': name, 'isSystem': 1},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _addNewSystemReasons(Database db) async {
    const newReasons = ['Airtime', 'Cash'];
    for (final name in newReasons) {
      await db.insert('reasons', {'name': name, 'isSystem': 1},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ──────────────────────────────────────────────
  // Sender Methods
  // ──────────────────────────────────────────────
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
    return db.update('senders', sender.toMap(),
        where: 'id = ?', whereArgs: [sender.id]);
  }

  Future<int> deleteSender(String id) async {
    final db = await instance.database;
    return await db.delete('senders', where: 'id = ?', whereArgs: [id]);
  }

  // ──────────────────────────────────────────────
  // Transaction Methods
  // ──────────────────────────────────────────────
  Future<int> insertTransaction(AppTransaction transaction) async {
    final db = await instance.database;
    final idToUse =
        transaction.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final map = transaction.toMap();
    map['id'] = idToUse;

    return await db.insert('transactions', map,
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> updateTransaction(AppTransaction transaction) async {
    final db = await instance.database;
    return await db.update('transactions', transaction.toMap(),
        where: 'id = ?', whereArgs: [transaction.id]);
  }

  Future<List<AppTransaction>> getTransactions() async {
    final db = await instance.database;
    const orderBy = 'date DESC';
    final maps = await db.query('transactions', orderBy: orderBy);
    return maps.map((map) => AppTransaction.fromMap(map)).toList();
  }

  Future<DateTime?> getLastTransactionDate() async {
    final db = await instance.database;
    final map = await db.query('transactions',
        columns: ['date'], orderBy: 'date DESC', limit: 1);

    if (map.isNotEmpty) {
      final dateString = map.first['date'] as String?;
      if (dateString != null) return DateTime.parse(dateString);
    }
    return null;
  }

  // ──────────────────────────────────────────────
  // Notification Methods
  // ──────────────────────────────────────────────
  Future<void> insertNotification(AppNotification notification) async {
    final db = await instance.database;
    await db.insert('notifications', notification.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
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

  // ──────────────────────────────────────────────
  // Reason Methods
  // ──────────────────────────────────────────────
  Future<List<AppReason>> getReasons() async {
    final db = await instance.database;
    final maps = await db.query('reasons', orderBy: 'isSystem DESC, name ASC');
    return maps.map((m) => AppReason.fromMap(m)).toList();
  }

  Future<AppReason?> getReasonById(int id) async {
    final db = await instance.database;
    final maps = await db.query('reasons', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return AppReason.fromMap(maps.first);
  }

  Future<int> insertReason(AppReason reason) async {
    final db = await instance.database;
    return await db.insert('reasons', reason.toMap());
  }

  Future<int> updateReason(AppReason reason) async {
    final db = await instance.database;
    return await db.update('reasons', reason.toMap(),
        where: 'id = ? AND isSystem = 0', whereArgs: [reason.id]);
  }

  Future<int> deleteReason(int id) async {
    final db = await instance.database;
    // Also delete links
    await db.delete('reason_links', where: 'reasonId = ?', whereArgs: [id]);
    return await db
        .delete('reasons', where: 'id = ? AND isSystem = 0', whereArgs: [id]);
  }

  // ──────────────────────────────────────────────
  // Reason Link Methods
  // ──────────────────────────────────────────────
  Future<List<AppReasonLink>> getReasonLinks() async {
    final db = await instance.database;
    final maps = await db.query('reason_links');
    return maps.map((m) => AppReasonLink.fromMap(m)).toList();
  }

  Future<List<AppReasonLink>> getLinksForReason(int reasonId) async {
    final db = await instance.database;
    final maps = await db
        .query('reason_links', where: 'reasonId = ?', whereArgs: [reasonId]);
    return maps.map((m) => AppReasonLink.fromMap(m)).toList();
  }

  Future<int> insertReasonLink(AppReasonLink link) async {
    final db = await instance.database;
    return await db.insert('reason_links', link.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> deleteReasonLink(int id) async {
    final db = await instance.database;
    return await db.delete('reason_links', where: 'id = ?', whereArgs: [id]);
  }

  /// Auto-categorize: find a matching reason for a given senderName.
  /// System-defined links take priority.
  Future<AppReason?> findAutoReason(
      String senderName, String transactionType) async {
    final db = await instance.database;
    final lower = senderName.toLowerCase();
    final expectedLinkType =
        transactionType == 'income' ? 'sender' : 'receiver';

    // Join reason_links with reasons to get isSystem flag, order system first
    final maps = await db.rawQuery('''
      SELECT r.id, r.name, r.isSystem
      FROM reason_links rl
      JOIN reasons r ON rl.reasonId = r.id
      WHERE LOWER(rl.linkedName) = ? AND rl.linkType = ?
      ORDER BY r.isSystem DESC
      LIMIT 1
    ''', [lower, expectedLinkType]);

    if (maps.isNotEmpty) return AppReason.fromMap(maps.first);
    return null;
  }

  // ──────────────────────────────────────────────
  // Loan Record Methods
  // ──────────────────────────────────────────────
  Future<int> insertLoanRecord(LoanRecord loan) async {
    final db = await instance.database;
    return await db.insert('loan_records', loan.toMap());
  }

  Future<List<LoanRecord>> getLoanRecords() async {
    final db = await instance.database;
    final maps = await db.query('loan_records', orderBy: 'loanDate DESC');
    return maps.map((m) => LoanRecord.fromMap(m)).toList();
  }

  Future<LoanRecord?> getLoanById(int id) async {
    final db = await instance.database;
    final maps =
        await db.query('loan_records', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return LoanRecord.fromMap(maps.first);
  }

  Future<int> updateLoanRecord(LoanRecord loan) async {
    final db = await instance.database;
    return await db.update('loan_records', loan.toMap(),
        where: 'id = ?', whereArgs: [loan.id]);
  }

  Future<int> deleteLoanRecord(int id) async {
    final db = await instance.database;
    // Also delete payments
    await db.delete('loan_payments', where: 'loanId = ?', whereArgs: [id]);
    return await db.delete('loan_records', where: 'id = ?', whereArgs: [id]);
  }

  // ──────────────────────────────────────────────
  // Loan Payment Methods
  // ──────────────────────────────────────────────
  Future<int> insertLoanPayment(LoanPayment payment) async {
    final db = await instance.database;
    return await db.insert('loan_payments', payment.toMap());
  }

  Future<List<LoanPayment>> getPaymentsForLoan(int loanId) async {
    final db = await instance.database;
    final maps = await db.query('loan_payments',
        where: 'loanId = ?', whereArgs: [loanId], orderBy: 'paymentDate DESC');
    return maps.map((m) => LoanPayment.fromMap(m)).toList();
  }

  Future<void> deleteLoanPayment(int id) async {
    final db = await instance.database;
    await db.delete('loan_payments', where: 'id = ?', whereArgs: [id]);
  }

  /// Find active loans whose trackedSenderName matches the incoming SMS sender.
  /// Used to auto-detect repayments.
  Future<List<LoanRecord>> findActiveLoansForSender(String senderName) async {
    final db = await instance.database;
    final lower = senderName.toLowerCase();
    final maps = await db.rawQuery('''
      SELECT * FROM loan_records
      WHERE status = 'active'
        AND trackedSenderName IS NOT NULL
        AND LOWER(trackedSenderName) = ?
    ''', [lower]);
    return maps.map((m) => LoanRecord.fromMap(m)).toList();
  }

  /// Recompute paidAmount from all payments and update loan status.
  Future<LoanRecord?> recalcLoanPaid(int loanId) async {
    final db = await instance.database;
    final payments = await getPaymentsForLoan(loanId);
    final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);

    final loanMaps =
        await db.query('loan_records', where: 'id = ?', whereArgs: [loanId]);
    if (loanMaps.isEmpty) return null;
    final loan = LoanRecord.fromMap(loanMaps.first);

    String newStatus = loan.status;
    if (totalPaid >= loan.principalAmount) {
      newStatus = 'paid';
    } else if (DateTime.now().isAfter(loan.dueDate)) {
      newStatus = 'overdue';
    } else {
      newStatus = 'active';
    }

    final updated = loan.copyWith(paidAmount: totalPaid, status: newStatus);
    await updateLoanRecord(updated);
    return updated;
  }
}
