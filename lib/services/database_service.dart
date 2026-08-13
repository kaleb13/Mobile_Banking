import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sender.dart';
import '../models/transaction.dart';
import '../models/app_notification.dart';
import '../models/reason.dart';
import '../models/loan_record.dart';
import '../models/loan_repayment_request.dart';
import '../models/expense_definition.dart';
import '../models/cash_transaction.dart';
import '../models/saving_goal.dart';
import '../models/transaction_attachment.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('finance_v3.db');
    await _createIndexes(_database!);
    await _seedHierarchicalCategories(_database!);
    return _database!;
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_date ON transactions(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_type ON transactions(type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cash_date ON cash_transactions(date)');
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path,
        version: 25, onCreate: _createDB, onUpgrade: _upgradeDB);
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
  expenseKeywords TEXT NOT NULL,
  accountNumber TEXT,
  pin TEXT
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
  categoryId INTEGER,
  subcategoryId INTEGER,
  customReasonText TEXT,
  note TEXT,
  linkedTransactionId TEXT,
  bankReference TEXT
)
''');

    await db.execute('''
CREATE TABLE notifications (
  id TEXT PRIMARY KEY,
  sender TEXT NOT NULL,
  body TEXT NOT NULL,
  date TEXT NOT NULL,
  isRead INTEGER NOT NULL DEFAULT 0,
  reason TEXT,
  transactionId TEXT
)
''');

    await db.execute('''
CREATE TABLE reasons (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  isSystem INTEGER NOT NULL DEFAULT 0,
  parentId INTEGER REFERENCES reasons(id),
  isSpecial INTEGER NOT NULL DEFAULT 0,
  icon TEXT,
  color TEXT
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

    await db.execute('''
CREATE TABLE IF NOT EXISTS transaction_attachments (
  id TEXT PRIMARY KEY,
  transactionId TEXT NOT NULL,
  filePath TEXT NOT NULL,
  fileType TEXT NOT NULL,
  fileName TEXT,
  fileSize INTEGER,
  createdAt TEXT NOT NULL,
  FOREIGN KEY(transactionId) REFERENCES transactions(id) ON DELETE CASCADE
)
''');

    // Seed 4 core special reasons
    const specialReasonNames = ['Bounce', 'Cash', 'Internal Transfer', 'Loan'];
    for (final name in specialReasonNames) {
      await db.insert('reasons', {'name': name, 'isSystem': 1, 'isSpecial': 1});
    }

    // Seed Top-Level Categories & Subcategories
    await _seedHierarchicalCategories(db);

    // Loan tables
    await _createLoanTables(db);

    // Cash Wallet and Recurring Expenses tables
    await _createCashTables(db);

    // App settings key-value table
    await db.execute('''
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');

    // Saving goals table
    await _createSavingGoalsTable(db);
  }

  Future<void> _createCashTables(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS expense_definitions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  defaultAmount REAL NOT NULL,
  isRecurring INTEGER NOT NULL DEFAULT 0,
  recurringType TEXT,
  intervalDays INTEGER,
  specificDay INTEGER,
  selectedDaysOfWeek TEXT,
  timesPerDay INTEGER NOT NULL DEFAULT 1,
  isActive INTEGER NOT NULL DEFAULT 1,
  lastAppliedDate TEXT,
  reasonId INTEGER
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS cash_transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,
  amount REAL NOT NULL,
  date TEXT NOT NULL,
  description TEXT,
  expenseDefinitionId INTEGER,
  reasonId INTEGER,
  reasonName TEXT,
  linkedTransactionId TEXT,
  FOREIGN KEY(expenseDefinitionId) REFERENCES expense_definitions(id) ON DELETE SET NULL
)
''');
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
  note TEXT,
  contractNumber TEXT
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
    await db.execute('''
CREATE TABLE IF NOT EXISTS loan_repayment_requests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  loanId INTEGER NOT NULL,
  transactionId TEXT NOT NULL,
  senderFound TEXT NOT NULL,
  trackedName TEXT NOT NULL,
  amount REAL NOT NULL,
  createdAt TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
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
    if (oldVersion < 7) {
      await _createCashTables(db);
    }
    if (oldVersion < 8) {
      // Add loan_repayment_requests table
      await db.execute('''
CREATE TABLE IF NOT EXISTS loan_repayment_requests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  loanId INTEGER NOT NULL,
  transactionId TEXT NOT NULL,
  senderFound TEXT NOT NULL,
  trackedName TEXT NOT NULL,
  amount REAL NOT NULL,
  createdAt TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  FOREIGN KEY(loanId) REFERENCES loan_records(id) ON DELETE CASCADE
)
''');
    }
    if (oldVersion < 9) {
      try {
        await db.execute(
            'ALTER TABLE expense_definitions ADD COLUMN selectedDaysOfWeek TEXT;');
      } catch (_) {}
    }
    if (oldVersion < 10) {
      try {
        await db.execute(
            'ALTER TABLE expense_definitions ADD COLUMN timesPerDay INTEGER NOT NULL DEFAULT 1;');
      } catch (_) {}
    }
    if (oldVersion < 11) {
      try {
        await db.execute(
            'ALTER TABLE expense_definitions ADD COLUMN isActive INTEGER NOT NULL DEFAULT 1;');
      } catch (_) {}
    }
    if (oldVersion < 12) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');
    }
    if (oldVersion < 13) {
      try {
        await db.execute('ALTER TABLE senders ADD COLUMN accountNumber TEXT;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE senders ADD COLUMN pin TEXT;');
      } catch (_) {}
    }
    if (oldVersion < 14) {
      await _addNewSystemReasons2(db);
    }
    if (oldVersion < 16) {
      try {
        await db.execute(
            'ALTER TABLE transactions ADD COLUMN linkedTransactionId TEXT;');
      } catch (_) {}
    }
    if (oldVersion < 17) {
      try {
        await db.execute(
            'ALTER TABLE cash_transactions ADD COLUMN reasonId INTEGER;');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE cash_transactions ADD COLUMN reasonName TEXT;');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE expense_definitions ADD COLUMN reasonId INTEGER;');
      } catch (_) {}
    }
    if (oldVersion < 18) {
      await _createSavingGoalsTable(db);
    }
    if (oldVersion < 19) {
      // Add allocation columns to existing saving_goals rows.
      // Wrapped in try/catch so re-runs on the same version are safe.
      try {
        await db.execute(
            "ALTER TABLE saving_goals ADD COLUMN allocation_mode TEXT NOT NULL DEFAULT 'global_percent';");
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE saving_goals ADD COLUMN account_allocations TEXT;');
      } catch (_) {}
    }
    if (oldVersion < 20) {
      try {
        await db.execute(
            "ALTER TABLE saving_goals ADD COLUMN color_theme TEXT NOT NULL DEFAULT 'green';");
      } catch (_) {}
    }
    if (oldVersion < 21) {
      // Add contractNumber column to loan_records for Telebirr credit tracking.
      try {
        await db.execute(
            'ALTER TABLE loan_records ADD COLUMN contractNumber TEXT;');
      } catch (_) {}
    }
    if (oldVersion < 22) {
      // Add bankReference column to transactions table.
      try {
        await db.execute(
            'ALTER TABLE transactions ADD COLUMN bankReference TEXT;');
      } catch (_) {}
      // Safety net: add reason column to notifications for users who
      // installed before this column existed in _createDB.
      try {
        await db.execute(
            'ALTER TABLE notifications ADD COLUMN reason TEXT;');
      } catch (_) {}
      // Add transactionId column to notifications so we can link a
      // notification directly to the parsed transaction row.
      try {
        await db.execute(
            'ALTER TABLE notifications ADD COLUMN transactionId TEXT;');
      } catch (_) {}
    }
    if (oldVersion < 24) {
      await _upgradeToVersion23(db);
    }
    if (oldVersion < 25) {
      try {
        await db.execute('ALTER TABLE cash_transactions ADD COLUMN linkedTransactionId TEXT;');
      } catch (_) {}
    }
  }

  Future<void> _upgradeToVersion23(Database db) async {
    try {
      await db.execute('ALTER TABLE reasons ADD COLUMN parentId INTEGER REFERENCES reasons(id);');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE reasons ADD COLUMN isSpecial INTEGER NOT NULL DEFAULT 0;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE reasons ADD COLUMN icon TEXT;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE reasons ADD COLUMN color TEXT;');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN categoryId INTEGER;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN subcategoryId INTEGER;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN note TEXT;');
    } catch (_) {}

    await db.execute('''
CREATE TABLE IF NOT EXISTS transaction_attachments (
  id TEXT PRIMARY KEY,
  transactionId TEXT NOT NULL,
  filePath TEXT NOT NULL,
  fileType TEXT NOT NULL,
  fileName TEXT,
  fileSize INTEGER,
  createdAt TEXT NOT NULL,
  FOREIGN KEY(transactionId) REFERENCES transactions(id) ON DELETE CASCADE
)
''');

    // Mark 4 core special reasons
    const specialReasonNames = ['Bounce', 'Cash', 'Internal Transfer', 'Loan'];
    for (final name in specialReasonNames) {
      final existing = await db.query('reasons', where: 'LOWER(name) = ?', whereArgs: [name.toLowerCase()]);
      if (existing.isEmpty) {
        await db.insert('reasons', {'name': name, 'isSystem': 1, 'isSpecial': 1});
      } else {
        await db.update('reasons', {'isSpecial': 1, 'isSystem': 1},
            where: 'id = ?', whereArgs: [existing.first['id']]);
      }
    }

    // Seed Top-Level Categories & Subcategories Templates
    await _seedHierarchicalCategories(db);
  }

  Future<void> _seedHierarchicalCategories(Database db) async {
    final Map<String, Map<String, dynamic>> topLevel = {
      'Food': {'icon': 'restaurant', 'color': '#FF9800', 'subs': ['Breakfast', 'Lunch', 'Dinner', 'Bakery', 'Snacks']},
      'Drink': {'icon': 'local_cafe', 'color': '#06B6D4', 'subs': ['Coffee', 'Tea', 'Keshir', 'Beer & Alcohol', 'Soft Drinks', 'Juices']},
      'Transportation': {'icon': 'directions_car', 'color': '#3B82F6', 'subs': ['Fuel & Gas', 'Taxi & Rideshare', 'Public Transit', 'Parking & Tolls', 'Vehicle Maintenance']},
      'Housing': {'icon': 'home', 'color': '#6366F1', 'subs': ['Rent', 'Mortgage', 'Property Tax', 'Home Repairs', 'Furniture']},
      'Utilities': {'icon': 'lightbulb', 'color': '#F59E0B', 'subs': ['Electricity', 'Water', 'Gas', 'Garbage & Sewer']},
      'Mobile & Internet': {'icon': 'phone_android', 'color': '#8B5CF6', 'subs': ['Airtime', 'Internet', 'Wifi', 'Data Bundles']},
      'Goods': {'icon': 'shopping_bag', 'color': '#EC4899', 'subs': ['Clothing & Apparel', 'Electronics', 'Household Supplies', 'Supermarket Goods', 'Gifts']},
      'Entertainment': {'icon': 'movie', 'color': '#8B5CF6', 'subs': ['Movies', 'Gaming', 'Streaming & Subscriptions', 'Events & Concerts', 'Hobbies']},
      'Health & Personal Care': {'icon': 'medical_services', 'color': '#14B8A6', 'subs': ['Pharmacy & Medicine', 'Doctor & Hospital', 'Salon & Spa', 'Fitness & Gym']},
      'Education': {'icon': 'school', 'color': '#2563EB', 'subs': ['Tuition', 'Books & Stationary', 'Online Courses']},
      'Investment & Savings': {'icon': 'trending_up', 'color': '#10B981', 'subs': ['Stocks & Crypto', 'Fixed Deposit', 'Personal Savings']},
      'Salary': {'icon': 'account_balance_wallet', 'color': '#10B981', 'subs': ['Primary Salary', 'Bonus & Commission', 'Freelance']},
    };

    // Remove legacy food subcategories
    await db.delete('reasons',
        where: 'LOWER(name) IN (?, ?, ?) AND parentId IS NOT NULL',
        whereArgs: ['restaurants', 'fast food', 'groceries']);

    // Remove any erroneous loan/financial subcategory links under Food or Drink
    await db.execute('''
      DELETE FROM reasons 
      WHERE (LOWER(name) LIKE '%loan%' OR LOWER(name) LIKE '%borrow%' OR LOWER(name) LIKE '%lend%') 
      AND parentId IN (SELECT id FROM reasons WHERE LOWER(name) IN ('food', 'drink'));
    ''');

    // Delete legacy unparented flat system reasons (Gift, Investment, Fuel, Medical, Rent, Shopping, Transport, etc.)
    await db.delete('reasons',
        where: '(parentId IS NULL OR parentId = 0) AND (isSpecial IS NULL OR isSpecial = 0) AND LOWER(name) NOT IN (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        whereArgs: [
          'food',
          'drink',
          'transportation',
          'housing',
          'utilities',
          'mobile & internet',
          'goods',
          'entertainment',
          'health & personal care',
          'education',
          'investment & savings',
          'salary',
        ]);

    for (final entry in topLevel.entries) {
      final catName = entry.key;
      final info = entry.value;
      int catId;

      final existing = await db.query('reasons', where: 'LOWER(name) = ?', whereArgs: [catName.toLowerCase()]);
      if (existing.isNotEmpty) {
        catId = existing.first['id'] as int;
        await db.update('reasons', {
          'isSpecial': 0,
          'isSystem': 1,
          'icon': info['icon'],
          'color': info['color'],
        }, where: 'id = ?', whereArgs: [catId]);
      } else {
        catId = await db.insert('reasons', {
          'name': catName,
          'isSystem': 1,
          'isSpecial': 0,
          'icon': info['icon'],
          'color': info['color'],
        });
      }

      final List<String> subs = List<String>.from(info['subs']);
      for (final subName in subs) {
        final existingSub = await db.query('reasons',
            where: 'LOWER(name) = ? AND parentId = ?',
            whereArgs: [subName.toLowerCase(), catId]);
        if (existingSub.isEmpty) {
          await db.insert('reasons', {
            'name': subName,
            'parentId': catId,
            'isSystem': 1,
            'isSpecial': 0,
          });
        }
      }
    }
  }

  Future<void> _addNewSystemReasons2(Database db) async {
    const newReasons = ['Bounce'];
    for (final name in newReasons) {
      await db.insert('reasons', {'name': name, 'isSystem': 1},
          conflictAlgorithm: ConflictAlgorithm.ignore);
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
      'Bounce',
      'Goods',
      'Internal Transfer',
    ];
    for (final name in systemReasons) {
      await db.insert('reasons', {'name': name, 'isSystem': 1},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _addNewSystemReasons(Database db) async {
    const newReasons = ['Airtime', 'Cash', 'Bounce', 'Goods'];
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

  Future<int> deleteTransaction(String id) async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// Updates ONLY the reason/reasonId on an existing transaction by its ID.
  /// Returns the number of rows affected (0 or 1).
  Future<int> updateTransactionReason(
      String id, String reason, int? reasonId) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      {'reason': reason, 'reasonId': reasonId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Finds a transaction whose rawMessage matches [rawMessage] and updates
  /// its reason/reasonId. Returns the number of rows affected.
  /// Used when the notification's SHA-256 ID doesn't match the parser's bank-extracted ID.
  Future<int> updateTransactionReasonByRawMessage(
      String rawMessage, String reason, int? reasonId) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      {'reason': reason, 'reasonId': reasonId},
      where: 'rawMessage = ? AND rawMessage != \'\'',
      whereArgs: [rawMessage],
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
    final map = await db.query('transactions',
        columns: ['date'], orderBy: 'date DESC', limit: 1);

    if (map.isNotEmpty) {
      final dateString = map.first['date'] as String?;
      if (dateString != null) return DateTime.parse(dateString);
    }
    return null;
  }

  /// Quick count query — almost zero CPU cost.
  /// Used by the lightweight DB sync to detect new background insertions.
  Future<int> getTransactionCount() async {
    final db = await instance.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM transactions');
    return (result.first['count'] as int?) ?? 0;
  }

  /// Quick notification count query — almost zero CPU cost.
  Future<int> getNotificationCount() async {
    final db = await instance.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM notifications');
    return (result.first['count'] as int?) ?? 0;
  }

  /// Wipes every row from the transactions table.
  Future<void> deleteAllTransactions() async {
    final db = await instance.database;
    await db.delete('transactions');
  }

  /// Wipes user-created reasons and all reason_links.
  /// System reasons (isSystem == 1) are preserved.
  Future<void> deleteAllUserReasons() async {
    final db = await instance.database;
    await db.delete('reason_links');
    await db.delete('reasons', where: 'isSystem = 0');
  }

  /// Wipes all reason_links only (keeps reason names, removes assignments).
  Future<void> deleteAllReasonLinks() async {
    final db = await instance.database;
    await db.delete('reason_links');
  }

  /// Wipes all in-app notifications.
  Future<void> deleteAllNotifications() async {
    final db = await instance.database;
    await db.delete('notifications');
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

    // 1. Delete legacy unparented flat system reasons that duplicate modern categories
    await db.execute('''
      DELETE FROM reasons 
      WHERE (parentId IS NULL OR parentId = 0) 
        AND (isSpecial IS NULL OR isSpecial = 0) 
        AND LOWER(TRIM(name)) IN ('transport', 'rent', 'shopping', 'internet', 'fuel', 'medical', 'gift', 'investment', 'airtime');
    ''');

    // 2. Deduplicate reasons with identical (name, parentId, isSpecial)
    await db.execute('''
      DELETE FROM reasons 
      WHERE id NOT IN (
        SELECT MIN(id) 
        FROM reasons 
        GROUP BY LOWER(TRIM(name)), COALESCE(parentId, -1), COALESCE(isSpecial, 0)
      );
    ''');

    // 3. Ensure 4 core special reasons exist with isSpecial = 1 and isSystem = 1
    const specialNames = ['Loan', 'Cash', 'Internal Transfer', 'Bounce'];
    for (final name in specialNames) {
      final existing = await db.query('reasons',
          where: 'LOWER(name) = ?', whereArgs: [name.toLowerCase()]);
      if (existing.isEmpty) {
        await db.insert('reasons', {'name': name, 'isSystem': 1, 'isSpecial': 1});
      } else if ((existing.first['isSpecial'] as int?) != 1) {
        await db.update('reasons', {'isSpecial': 1, 'isSystem': 1},
            where: 'id = ?', whereArgs: [existing.first['id']]);
      }
    }

    // 4. Ensure top-level categories and subcategories exist if DB has no subcategories
    final countRes = await db.rawQuery(
        'SELECT COUNT(*) as count FROM reasons WHERE parentId IS NOT NULL');
    final subCount = (countRes.first['count'] as int?) ?? 0;
    if (subCount == 0) {
      await _seedHierarchicalCategories(db);
    }

    final maps = await db.query('reasons',
        orderBy: 'isSpecial DESC, isSystem DESC, name ASC');
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
        where: 'id = ? AND isSpecial = 0', whereArgs: [reason.id]);
  }

  Future<int> deleteReason(int id) async {
    final db = await instance.database;
    // Also delete links and subcategories
    await db.delete('reason_links', where: 'reasonId = ?', whereArgs: [id]);
    await db.delete('reasons', where: 'parentId = ?', whereArgs: [id]);
    return await db
        .delete('reasons', where: 'id = ? AND isSpecial = 0', whereArgs: [id]);
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

  // ──────────────────────────────────────────────
  // Telebirr Credit Loan Helpers
  // ──────────────────────────────────────────────

  /// Find the oldest active Telebirr credit loan.
  /// These are loans where contractNumber is not null and trackedSenderName = 'Telebirr'.
  /// Returns null if no matching loan is found.
  Future<LoanRecord?> findActiveTelebirrCreditLoan() async {
    final db = await instance.database;
    final maps = await db.rawQuery('''
      SELECT * FROM loan_records
      WHERE status = 'active'
        AND contractNumber IS NOT NULL
        AND LOWER(trackedSenderName) = 'telebirr'
      ORDER BY loanDate ASC
      LIMIT 1
    ''');
    if (maps.isEmpty) return null;
    return LoanRecord.fromMap(maps.first);
  }

  /// Apply a Telebirr repayment to a loan:
  /// 1. Records a LoanPayment entry
  /// 2. Updates paidAmount on the loan
  /// 3. Sets status to 'paid' if totalOutstanding is 0, otherwise recalculates
  Future<LoanRecord?> applyTelebirrRepayment({
    required int loanId,
    required double paidAmount,
    required double totalOutstanding,
    String? linkedTransactionId,
  }) async {
    final db = await instance.database;

    // 1. Record the payment
    await db.insert('loan_payments', {
      'loanId': loanId,
      'amount': paidAmount,
      'paymentDate': DateTime.now().toIso8601String(),
      'linkedTransactionId': linkedTransactionId,
      'note': 'Auto-detected from Telebirr repayment SMS',
    });

    // 2. Get the current loan
    final loanMaps =
        await db.query('loan_records', where: 'id = ?', whereArgs: [loanId]);
    if (loanMaps.isEmpty) return null;
    final loan = LoanRecord.fromMap(loanMaps.first);

    // 3. Recalculate total paid from all payments
    final payments = await db.query('loan_payments',
        where: 'loanId = ?', whereArgs: [loanId]);
    final totalPaid =
        payments.fold<double>(0, (s, p) => s + (p['amount'] as num).toDouble());

    // 4. Determine new status
    // If telebirr says outstanding = 0, mark as paid regardless of amounts
    final String newStatus;
    if (totalOutstanding <= 0.0 || totalPaid >= loan.principalAmount) {
      newStatus = 'paid';
    } else if (DateTime.now().isAfter(loan.dueDate)) {
      newStatus = 'overdue';
    } else {
      newStatus = 'active';
    }

    // 5. Update the loan record
    final updated = loan.copyWith(paidAmount: totalPaid, status: newStatus);
    await db.update('loan_records', updated.toMap(),
        where: 'id = ?', whereArgs: [loanId]);
    return updated;
  }

  // ──────────────────────────────────────────────
  // Loan Repayment Request Methods
  // ──────────────────────────────────────────────

  Future<int> insertLoanRepaymentRequest(LoanRepaymentRequest req) async {
    final db = await instance.database;
    // Block re-queueing for any transactionId that is already pending OR approved.
    // Only 'rejected' requests allow a new one to be created (user explicitly said no
    // last time, but a new SMS might legitimately match again in rare edge cases).
    final existing = await db.query(
      'loan_repayment_requests',
      where: 'transactionId = ? AND loanId = ? AND status != ?',
      whereArgs: [req.transactionId, req.loanId, 'rejected'],
    );
    if (existing.isNotEmpty) return existing.first['id'] as int;
    return await db.insert('loan_repayment_requests', req.toMap());
  }

  Future<List<LoanRepaymentRequest>> getPendingRepaymentRequests() async {
    final db = await instance.database;
    final maps = await db.query('loan_repayment_requests',
        where: 'status = ?', whereArgs: ['pending'], orderBy: 'createdAt DESC');
    return maps.map((m) => LoanRepaymentRequest.fromMap(m)).toList();
  }

  Future<void> updateRepaymentRequestStatus(int id, String status) async {
    final db = await instance.database;
    await db.update(
      'loan_repayment_requests',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteRepaymentRequest(int id) async {
    final db = await instance.database;
    await db
        .delete('loan_repayment_requests', where: 'id = ?', whereArgs: [id]);
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

  // ──────────────────────────────────────────────
  // Expense Definition Methods
  // ──────────────────────────────────────────────
  Future<int> insertExpenseDefinition(ExpenseDefinition definition) async {
    final db = await instance.database;
    return await db.insert('expense_definitions', definition.toMap());
  }

  Future<List<ExpenseDefinition>> getExpenseDefinitions() async {
    final db = await instance.database;
    final maps = await db.query('expense_definitions', orderBy: 'name ASC');
    return maps.map((map) => ExpenseDefinition.fromMap(map)).toList();
  }

  Future<ExpenseDefinition?> getExpenseDefinitionById(int id) async {
    final db = await instance.database;
    final maps =
        await db.query('expense_definitions', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return ExpenseDefinition.fromMap(maps.first);
  }

  Future<int> updateExpenseDefinition(ExpenseDefinition definition) async {
    final db = await instance.database;
    return await db.update('expense_definitions', definition.toMap(),
        where: 'id = ?', whereArgs: [definition.id]);
  }

  Future<int> deleteExpenseDefinition(int id) async {
    final db = await instance.database;
    return await db
        .delete('expense_definitions', where: 'id = ?', whereArgs: [id]);
  }

  // ──────────────────────────────────────────────
  // Cash Transaction Methods
  // ──────────────────────────────────────────────
  Future<int> insertCashTransaction(CashTransaction transaction) async {
    final db = await instance.database;
    return await db.insert('cash_transactions', transaction.toMap());
  }

  Future<List<CashTransaction>> getCashTransactions() async {
    final db = await instance.database;
    final maps = await db.query('cash_transactions', orderBy: 'date DESC');
    return maps.map((map) => CashTransaction.fromMap(map)).toList();
  }

  Future<int> deleteCashTransaction(int id) async {
    final db = await instance.database;
    return await db
        .delete('cash_transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateCashTransaction(CashTransaction transaction) async {
    final db = await instance.database;
    return await db.update('cash_transactions', transaction.toMap(),
        where: 'id = ?', whereArgs: [transaction.id]);
  }

  // ──────────────────────────────────────────────
  // App Settings (key-value store)
  // ──────────────────────────────────────────────
  Future<String?> getSetting(String key) async {
    try {
      final db = await instance.database;
      final maps =
          await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
      if (maps.isEmpty) return null;
      return maps.first['value'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> setSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Pause Tracking helpers ─────────────────────────────────────────────────
  /// Returns the set of bank names for which tracking is currently paused.
  Future<Set<String>> getPausedBanks() async {
    final raw = await getSetting('paused_banks');
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = (raw.split(','))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
      return list;
    } catch (_) {
      return {};
    }
  }

  /// Persists the set of paused bank names.
  Future<void> setPausedBanks(Set<String> banks) async {
    await setSetting('paused_banks', banks.join(','));
  }

  // ──────────────────────────────────────────────
  // Saving Goals Methods & Helper
  // ──────────────────────────────────────────────
  Future<void> _createSavingGoalsTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS saving_goals (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  targetAmount REAL NOT NULL,
  savedAmount REAL NOT NULL,
  imagePath TEXT NOT NULL,
  category TEXT NOT NULL,
  status TEXT NOT NULL,
  targetDate TEXT,
  priority INTEGER NOT NULL DEFAULT 1,
  allocation_mode TEXT NOT NULL DEFAULT 'global_percent',
  account_allocations TEXT NOT NULL DEFAULT '{"*":30.0}',
  color_theme TEXT NOT NULL DEFAULT 'green'
)
''');
    // No seed data — user creates their own goals
  }

  Future<int> insertSavingGoal(SavingGoal goal) async {
    final db = await instance.database;
    try {
      return await db.insert('saving_goals', goal.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {
      try {
        await db.execute(
            "ALTER TABLE saving_goals ADD COLUMN color_theme TEXT NOT NULL DEFAULT 'green';");
      } catch (_) {}
      return await db.insert('saving_goals', goal.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<SavingGoal>> getSavingGoals() async {
    final db = await instance.database;
    final maps = await db.query('saving_goals', orderBy: 'priority ASC, id ASC');
    return maps.map((map) => SavingGoal.fromMap(map)).toList();
  }

  Future<int> updateSavingGoal(SavingGoal goal) async {
    final db = await instance.database;
    try {
      return await db.update('saving_goals', goal.toMap(),
          where: 'id = ?', whereArgs: [goal.id]);
    } catch (_) {
      try {
        await db.execute(
            "ALTER TABLE saving_goals ADD COLUMN color_theme TEXT NOT NULL DEFAULT 'green';");
      } catch (_) {}
      return await db.update('saving_goals', goal.toMap(),
          where: 'id = ?', whereArgs: [goal.id]);
    }
  }

  Future<int> deleteSavingGoal(String id) async {
    final db = await instance.database;
    return await db.delete('saving_goals', where: 'id = ?', whereArgs: [id]);
  }

  // ──────────────────────────────────────────────
  // Transaction Attachment Methods
  // ──────────────────────────────────────────────
  Future<int> insertAttachment(TransactionAttachment attachment) async {
    final db = await instance.database;
    return await db.insert('transaction_attachments', attachment.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TransactionAttachment>> getAttachmentsForTransaction(String transactionId) async {
    final db = await instance.database;
    final maps = await db.query('transaction_attachments',
        where: 'transactionId = ?', whereArgs: [transactionId], orderBy: 'createdAt ASC');
    return maps.map((m) => TransactionAttachment.fromMap(m)).toList();
  }

  Future<int> deleteAttachment(String attachmentId) async {
    final db = await instance.database;
    return await db.delete('transaction_attachments',
        where: 'id = ?', whereArgs: [attachmentId]);
  }
}
