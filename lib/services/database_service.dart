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
import '../models/transaction_split.dart';
import 'sms_batch_parser.dart';
import 'bank_senders.dart';
import '../utils/counterparty_matcher.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('finance_v3.db');
    await _ensureSendersTableSchema(_database!);
    await _createIndexes(_database!);
    await _seedHierarchicalCategories(_database!);
    return _database!;
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_date ON transactions(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_type ON transactions(type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_name ON transactions(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_sender ON transactions(sender)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_reason ON transactions(reasonId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_bookmark ON transactions(isBookmarked)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_date_type ON transactions(date, type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cash_date ON cash_transactions(date)');
  }

  /// Safely flushes the SQLite WAL journal and truncates the .db-wal file
  /// back to 0 bytes on disk, reclaiming temporary journal space after large batch writes.
  Future<void> checkpointWal() async {
    try {
      final db = await instance.database;
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');
    } catch (_) {}
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path,
        version: 29, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  // ──────────────────────────────────────────────
  // Schema creation (fresh install)
  // ──────────────────────────────────────────────
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE senders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  senderName TEXT NOT NULL
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
  bankReference TEXT,
  isBookmarked INTEGER NOT NULL DEFAULT 0,
  simSlot INTEGER NOT NULL DEFAULT 0,
  accountIdentifier TEXT
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

    await db.execute('''
CREATE TABLE IF NOT EXISTS transaction_splits (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transactionId TEXT NOT NULL,
  amount REAL NOT NULL,
  reasonId INTEGER,
  reasonName TEXT,
  categoryId INTEGER,
  subcategoryId INTEGER,
  customReasonText TEXT,
  note TEXT,
  createdAt TEXT NOT NULL,
  FOREIGN KEY (transactionId) REFERENCES transactions (id) ON DELETE CASCADE
);
''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_splits_tx_id ON transaction_splits(transactionId);');

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
    if (oldVersion < 26) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN isBookmarked INTEGER NOT NULL DEFAULT 0;');
      } catch (_) {}
    }
    if (oldVersion < 27) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN simSlot INTEGER NOT NULL DEFAULT 0;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN accountIdentifier TEXT;');
      } catch (_) {}
    }
    if (oldVersion < 28) {
      await _upgradeToVersion28(db);
    }
    if (oldVersion < 29) {
      await _upgradeToVersion29(db);
    }
  }

  Future<void> _upgradeToVersion29(Database db) async {
    try {
      await db.execute('''
CREATE TABLE IF NOT EXISTS transaction_splits (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transactionId TEXT NOT NULL,
  amount REAL NOT NULL,
  reasonId INTEGER,
  reasonName TEXT,
  categoryId INTEGER,
  subcategoryId INTEGER,
  customReasonText TEXT,
  note TEXT,
  createdAt TEXT NOT NULL,
  FOREIGN KEY (transactionId) REFERENCES transactions (id) ON DELETE CASCADE
);
''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_splits_tx_id ON transaction_splits(transactionId);');
    } catch (_) {}
  }

  Future<void> _upgradeToVersion28(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS senders_v28 (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          senderName TEXT NOT NULL
        );
      ''');
      await db.execute('''
        INSERT OR IGNORE INTO senders_v28 (id, senderName)
        SELECT id, senderName FROM senders;
      ''');
      await db.execute('DROP TABLE IF EXISTS senders;');
      await db.execute('ALTER TABLE senders_v28 RENAME TO senders;');
    } catch (_) {}
  }

  Future<void> _ensureSendersTableSchema(Database db) async {
    try {
      final tableInfo = await db.rawQuery("PRAGMA table_info(senders)");
      final hasLegacyKeywords = tableInfo.any((c) =>
          c['name'] == 'depositKeywords' || c['name'] == 'expenseKeywords');
      if (hasLegacyKeywords) {
        await _upgradeToVersion28(db);
      }
      // Clean up duplicate sender rows in SQLite
      await db.execute('''
        DELETE FROM senders
        WHERE id NOT IN (
          SELECT MIN(id) FROM senders GROUP BY UPPER(senderName)
        );
      ''');
    } catch (_) {}
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

    // Mark 4 core special reasons (using Pass-Through)
    await db.execute('''
      UPDATE reasons SET name = 'Pass-Through' WHERE LOWER(TRIM(name)) = 'bounce';
      UPDATE transactions SET reason = 'Pass-Through' WHERE LOWER(TRIM(reason)) = 'bounce';
      UPDATE transactions SET customReasonText = 'Pass-Through' WHERE LOWER(TRIM(customReasonText)) = 'bounce';
    ''');
    const specialReasonNames = ['Pass-Through', 'Cash', 'Internal Transfer', 'Loan'];
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
      'Mobile & Internet': {'icon': 'phone_android', 'color': '#8B5CF6', 'subs': ['Airtime', 'Package', 'Internet', 'Wifi']},
      'Goods': {'icon': 'shopping_bag', 'color': '#EC4899', 'subs': ['Clothing & Apparel', 'Electronics', 'Household Supplies', 'Supermarket Goods', 'Gifts']},
      'Entertainment': {'icon': 'movie', 'color': '#8B5CF6', 'subs': ['Movies', 'Gaming', 'Streaming & Subscriptions', 'Events & Concerts', 'Hobbies']},
      'Health & Personal Care': {'icon': 'medical_services', 'color': '#14B8A6', 'subs': ['Pharmacy & Medicine', 'Doctor & Hospital', 'Salon & Spa', 'Fitness & Gym']},
      'Education': {'icon': 'school', 'color': '#2563EB', 'subs': ['Tuition', 'Books & Stationary', 'Online Courses']},
      'Investment & Savings': {'icon': 'trending_up', 'color': '#10B981', 'subs': ['Stocks & Crypto', 'Fixed Deposit', 'Personal Savings']},
      'Salary': {'icon': 'account_balance_wallet', 'color': '#10B981', 'subs': ['Primary Salary', 'Bonus & Commission', 'Freelance']},
    };

    // Migrate legacy 'Data Bundles' / 'Data Bundle' / 'data-bundle' to 'Package' under Mobile & Internet
    await db.execute('''
      UPDATE reasons 
      SET name = 'Package' 
      WHERE (LOWER(name) = 'data bundles' OR LOWER(name) = 'data bundle' OR LOWER(name) = 'data-bundle')
      AND parentId IN (SELECT id FROM reasons WHERE LOWER(name) = 'mobile & internet');
    ''');

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
    try {
      return await db.insert(
        'senders',
        sender.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      final map = sender.toMap();
      map['depositKeywords'] = '[]';
      map['expenseKeywords'] = '[]';
      return await db.insert(
        'senders',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<AppSender>> getSenders() async {
    final db = await instance.database;
    final maps = await db.query('senders');
    final rawList = maps.map((map) => AppSender.fromMap(map)).toList();

    // Check which banks actually have recorded transactions in the database
    final txMaps = await db.rawQuery(
      'SELECT DISTINCT name FROM transactions WHERE name IS NOT NULL AND TRIM(name) != ""',
    );
    final activeTxBankNames = <String>{};
    for (final row in txMaps) {
      final n = row['name'] as String?;
      if (n != null && n.trim().isNotEmpty) {
        final canonical = BankSenders.match(n) ?? n.trim();
        activeTxBankNames.add(canonical.toUpperCase());
      }
    }

    // Load paused banks so they are NEVER pruned/deleted even if they have 0 transactions
    final pausedBanks = await getPausedBanks();
    final pausedCanonicalUpper = <String>{};
    for (final b in pausedBanks) {
      final base = b.contains(':') ? b.split(':').first : b;
      final canonical = BankSenders.match(base) ?? base.trim();
      if (canonical.isNotEmpty) {
        pausedCanonicalUpper.add(canonical.toUpperCase());
      }
    }

    final uniqueMap = <String, AppSender>{};
    final toDeleteIds = <String>[];

    for (final s in rawList) {
      final canonical = BankSenders.match(s.senderName) ?? s.senderName.trim();
      final key = canonical.toUpperCase();

      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = AppSender(id: s.id, senderName: canonical);
      } else {
        if (s.id != null) toDeleteIds.add(s.id!);
      }
    }

    for (final id in toDeleteIds) {
      try {
        await db.delete('senders', where: 'id = ?', whereArgs: [id]);
      } catch (_) {}
    }

    // Ensure all banks with active transactions or in paused list exist in senders
    final criticalBanks = {...activeTxBankNames, ...pausedCanonicalUpper};
    for (final key in criticalBanks) {
      if (!uniqueMap.containsKey(key)) {
        final canonical = BankSenders.match(key) ?? key;
        try {
          final id = await db.insert(
            'senders',
            {'senderName': canonical},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          uniqueMap[key] = AppSender(id: id.toString(), senderName: canonical);
        } catch (_) {
          uniqueMap[key] = AppSender(senderName: canonical);
        }
      }
    }

    return uniqueMap.values.toList();
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

  /// High-performance atomic batch insert for large volumes of transactions.
  /// Runs inside a single SQLite transaction with batching, reducing thousands
  /// of disk commits down to a single atomic write (< 40ms).
  Future<int> insertTransactionsBatch(List<AppTransaction> transactions) async {
    if (transactions.isEmpty) return 0;
    final db = await instance.database;
    int insertedCount = 0;

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final tx in transactions) {
        final idToUse =
            tx.id ?? DateTime.now().millisecondsSinceEpoch.toString();
        final map = tx.toMap();
        map['id'] = idToUse;
        batch.rawInsert('''
          INSERT INTO transactions (
            id, name, amount, type, date, sender, category, rawMessage,
            isAutoDetected, totalBalance, reason, reasonId, categoryId,
            subcategoryId, customReasonText, note, linkedTransactionId,
            bankReference, isBookmarked, simSlot, accountIdentifier
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            simSlot = excluded.simSlot,
            accountIdentifier = COALESCE(excluded.accountIdentifier, transactions.accountIdentifier),
            totalBalance = CASE WHEN excluded.totalBalance > 0 THEN excluded.totalBalance ELSE transactions.totalBalance END
        ''', [
          map['id'],
          map['name'],
          map['amount'],
          map['type'],
          map['date'],
          map['sender'],
          map['category'] ?? 'Auto',
          map['rawMessage'],
          map['isAutoDetected'] ?? 1,
          map['totalBalance'] ?? 0.0,
          map['reason'],
          map['reasonId'],
          map['categoryId'],
          map['subcategoryId'],
          map['customReasonText'],
          map['note'],
          map['linkedTransactionId'],
          map['bankReference'],
          map['isBookmarked'] ?? 0,
          map['simSlot'] ?? 0,
          map['accountIdentifier'],
        ]);
      }
      final results = await batch.commit(noResult: false);
      insertedCount = results.where((r) => r is int && r > 0).length;
    });

    if (insertedCount > 0) {
      await checkpointWal();
      await reconcilePendingNotificationReasons();
    }

    return insertedCount;
  }

  /// Reconciles any pending reasons saved in `notifications` (from notification actions or
  /// quick edit drawer) into matching `transactions` by rawMessage.
  /// Resolves `reasonId`, `categoryId`, and `subcategoryId` hierarchy from `reasons` table,
  /// and prunes successfully reconciled notifications.
  Future<int> reconcilePendingNotificationReasons() async {
    final db = await instance.database;
    int reconciledCount = 0;

    try {
      final pendingNotifs = await db.rawQuery(
        "SELECT id, body, reason FROM notifications WHERE reason IS NOT NULL AND TRIM(reason) != ''",
      );
      if (pendingNotifs.isEmpty) return 0;

      final reasons = await getReasons();
      final reasonMap = <String, AppReason>{};
      for (final r in reasons) {
        reasonMap[r.name.toLowerCase().trim()] = r;
      }

      for (final notif in pendingNotifs) {
        final notifId = notif['id'] as String;
        final notifBody = (notif['body'] as String? ?? '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final reasonName = (notif['reason'] as String? ?? '').trim();
        if (notifBody.isEmpty || reasonName.isEmpty) continue;

        final matchedReason = reasonMap[reasonName.toLowerCase()];
        final int? reasonId = matchedReason?.id;
        final int? categoryId = matchedReason?.isSubcategory == true
            ? matchedReason?.parentId
            : (matchedReason?.isTopLevelCategory == true ? matchedReason?.id : null);
        final int? subcategoryId =
            matchedReason?.isSubcategory == true ? matchedReason?.id : null;
        final resolvedReasonName = matchedReason?.name ?? reasonName;

        final txRows = await db.rawQuery(
          "SELECT id, rawMessage, reason FROM transactions ORDER BY date DESC, rowid DESC",
        );

        bool matched = false;
        for (final tx in txRows) {
          final txRaw = (tx['rawMessage'] as String? ?? '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          if (txRaw == notifBody) {
            await db.update(
              'transactions',
              {
                'reason': resolvedReasonName,
                'reasonId': reasonId,
                'categoryId': categoryId,
                'subcategoryId': subcategoryId,
                'customReasonText': null,
              },
              where: 'id = ?',
              whereArgs: [tx['id']],
            );
            reconciledCount++;
            matched = true;
            break;
          }
        }

        if (matched) {
          await db.delete('notifications', where: 'id = ?', whereArgs: [notifId]);
        }
      }
    } catch (_) {}

    return reconciledCount;
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

  /// Clears/unlinks the reason and category metadata for a single transaction.
  Future<int> unlinkSingleTransaction(String id) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      {
        'reason': null,
        'reasonId': null,
        'categoryId': null,
        'subcategoryId': null,
        'customReasonText': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Clears/unlinks reasons from all past transactions matching a given contact name or phone number.
  Future<int> unlinkAllTransactionsForContact({
    required String contactName,
    int? reasonId,
  }) async {
    final db = await instance.database;
    final lowerName = contactName.toLowerCase();
    final phoneKey = CounterpartyMatcher.extractPhoneKey(contactName);

    String whereClause;
    List<dynamic> whereArgs;

    if (phoneKey != null) {
      final variations = [
        phoneKey,
        '0$phoneKey',
        '251$phoneKey',
        '+251$phoneKey',
      ];
      final parts = <String>[];
      whereArgs = <dynamic>[];
      for (final v in variations) {
        parts.add('LOWER(sender) = ?');
        whereArgs.add(v.toLowerCase());
        parts.add('sender LIKE ?');
        whereArgs.add('%$v%');
      }
      whereClause = '(${parts.join(' OR ')})';
    } else {
      whereClause = 'LOWER(sender) = ?';
      whereArgs = [lowerName];
    }
    
    if (reasonId != null) {
      return await db.update(
        'transactions',
        {
          'reason': null,
          'reasonId': null,
          'categoryId': null,
          'subcategoryId': null,
          'customReasonText': null,
        },
        where: '$whereClause AND reasonId = ?',
        whereArgs: [...whereArgs, reasonId],
      );
    } else {
      return await db.update(
        'transactions',
        {
          'reason': null,
          'reasonId': null,
          'categoryId': null,
          'subcategoryId': null,
          'customReasonText': null,
        },
        where: whereClause,
        whereArgs: whereArgs,
      );
    }
  }

  /// Sets the bookmark/favorite status for a transaction by ID.
  Future<int> setTransactionBookmarked(String id, bool isBookmarked) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      {'isBookmarked': isBookmarked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<AppTransaction>> getTransactions({int? limit, int? offset}) async {
    final db = await instance.database;
    const orderBy = 'date DESC';
    final maps = await db.query(
      'transactions',
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return maps.map((map) => AppTransaction.fromMap(map)).toList();
  }

  /// Fast indexed query returning unique bank names across all transactions (< 1ms).
  Future<List<String>> getDistinctBankNames() async {
    final db = await instance.database;
    final results = await db.rawQuery('SELECT DISTINCT name FROM transactions ORDER BY name ASC');
    return results.map((row) => (row['name'] as String?) ?? '').where((s) => s.isNotEmpty).toList();
  }

  /// Fast indexed query returning unique sender names across all transactions (< 1ms).
  Future<List<String>> getDistinctSenders() async {
    final db = await instance.database;
    final results = await db.rawQuery('SELECT DISTINCT sender FROM transactions ORDER BY sender ASC');
    return results.map((row) => (row['sender'] as String?) ?? '').where((s) => s.isNotEmpty).toList();
  }

  /// Fast indexed query for transactions strictly on or after [since].
  Future<List<AppTransaction>> getTransactionsSince(DateTime since, {int? limit, int? offset}) async {
    final db = await instance.database;
    final maps = await db.query(
      'transactions',
      where: 'date >= ?',
      whereArgs: [since.toIso8601String()],
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((map) => AppTransaction.fromMap(map)).toList();
  }

  /// Fast query for transactions matching a bank reference code.
  Future<List<AppTransaction>> getTransactionsByBankReference(String bankReference) async {
    final db = await instance.database;
    final maps = await db.query(
      'transactions',
      where: 'bankReference = ? OR id LIKE ?',
      whereArgs: [bankReference, '${bankReference}_%'],
    );
    return maps.map((map) => AppTransaction.fromMap(map)).toList();
  }

  /// Automatically pairs and locks matching Dual-SIM internal transfers in SQLite (< 5ms).
  Future<int> reconcileInternalTransfers() async {
    final db = await instance.database;
    final specialReasons = await getReasons();
    final itReason = specialReasons.cast<AppReason?>().firstWhere(
          (r) => r?.name.toLowerCase() == 'internal transfer',
          orElse: () => null,
        );
    final reasonId = itReason?.id;
    const reasonName = 'Internal Transfer';

    final rows = await db.rawQuery('''
      SELECT t1.id AS id1, t2.id AS id2
      FROM transactions t1
      INNER JOIN transactions t2 ON t1.bankReference = t2.bankReference
        AND t1.amount = t2.amount
        AND t1.type != t2.type
        AND t1.id != t2.id
      WHERE t1.bankReference IS NOT NULL
        AND length(t1.bankReference) >= 4
        AND (t1.reason IS NULL OR t1.reason != 'Internal Transfer' OR t1.linkedTransactionId IS NULL)
    ''');

    int updatedCount = 0;
    for (final row in rows) {
      final id1 = row['id1'] as String?;
      final id2 = row['id2'] as String?;
      if (id1 != null && id2 != null) {
        await db.update(
          'transactions',
          {
            'reason': reasonName,
            'reasonId': reasonId,
            'linkedTransactionId': id2,
          },
          where: 'id = ?',
          whereArgs: [id1],
        );
        await db.update(
          'transactions',
          {
            'reason': reasonName,
            'reasonId': reasonId,
            'linkedTransactionId': id1,
          },
          where: 'id = ?',
          whereArgs: [id2],
        );
        updatedCount++;
      }
    }
    return updatedCount;
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

  /// Deletes transactions that occurred strictly before [cutoff].
  /// Used when narrowing the SMS Scan History Range so older transactions are purged.
  Future<int> deleteTransactionsOlderThan(DateTime cutoff) async {
    final db = await instance.database;
    return await db.delete(
      'transactions',
      where: 'date < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
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

  /// High-performance atomic batch insert for multiple notifications.
  Future<void> insertNotificationsBatch(List<AppNotification> notifications) async {
    if (notifications.isEmpty) return;
    final db = await instance.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final notif in notifications) {
        batch.insert('notifications', notif.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });
    await checkpointWal();
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

      // 3. Ensure 4 core special reasons exist with isSpecial = 1 and isSystem = 1 (Migrate Bounce to Pass-Through)
      await db.execute('''
        UPDATE reasons SET name = 'Pass-Through' WHERE LOWER(TRIM(name)) = 'bounce';
        UPDATE transactions SET reason = 'Pass-Through' WHERE LOWER(TRIM(reason)) = 'bounce';
        UPDATE transactions SET customReasonText = 'Pass-Through' WHERE LOWER(TRIM(customReasonText)) = 'bounce';
      ''');
      const specialNames = ['Loan', 'Cash', 'Internal Transfer', 'Pass-Through'];
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
    if (reason.id != null) {
      final reasonQuery =
          await db.query('reasons', where: 'id = ?', whereArgs: [reason.id]);
      if (reasonQuery.isNotEmpty) {
        final r = reasonQuery.first;
        final origNameLower = (r['name'] as String).trim().toLowerCase();
        final parentId = r['parentId'] as int?;

        // Protect 'Mobile & Internet' top category from renaming
        if (parentId == null && origNameLower == 'mobile & internet') {
          return 0;
        }
        // Protect 'Airtime' and 'Package' subcategories from renaming
        if (parentId != null &&
            (origNameLower == 'airtime' || origNameLower == 'package')) {
          return 0;
        }
      }
    }
    return await db.update('reasons', reason.toMap(),
        where: 'id = ? AND isSpecial = 0', whereArgs: [reason.id]);
  }

  Future<int> deleteReason(int id) async {
    final db = await instance.database;
    final reasonQuery =
        await db.query('reasons', where: 'id = ?', whereArgs: [id]);
    if (reasonQuery.isNotEmpty) {
      final r = reasonQuery.first;
      final nameLower = (r['name'] as String).trim().toLowerCase();
      final parentId = r['parentId'] as int?;

      // Protect 'Mobile & Internet' top category
      if (parentId == null && nameLower == 'mobile & internet') {
        return 0;
      }
      // Protect 'Airtime' and 'Package' subcategories
      if (parentId != null &&
          (nameLower == 'airtime' || nameLower == 'package')) {
        return 0;
      }
    }

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

  /// Fetches all active auto-reason rules in a single query for fast in-memory lookups.
  Future<List<AutoReasonRule>> getAutoReasonRules() async {
    final db = await instance.database;
    final rows = await db.rawQuery('''
      SELECT r.id, r.name, rl.linkedName as sender, rl.linkType
      FROM reason_links rl
      JOIN reasons r ON rl.reasonId = r.id
      ORDER BY r.isSystem DESC
    ''');
    return rows.map((row) {
      final linkType = row['linkType'] as String?;
      final String? txType = linkType == 'sender'
          ? 'income'
          : (linkType == 'receiver' ? 'expense' : null);
      return AutoReasonRule(
        id: row['id'] as int,
        name: row['name'] as String,
        sender: row['sender'] as String,
        type: txType,
      );
    }).toList();
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

  Future<void> deleteAllLoanRecords() async {
    final db = await instance.database;
    await db.delete('loan_payments');
    await db.delete('loan_records');
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

  Future<void> updateGoalsPriority(List<SavingGoal> goals) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (int i = 0; i < goals.length; i++) {
        final goal = goals[i];
        await txn.update(
          'saving_goals',
          {'priority': i + 1},
          where: 'id = ?',
          whereArgs: [goal.id],
        );
      }
    });
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

  // ──────────────────────────────────────────────
  // App Settings Methods
  // ──────────────────────────────────────────────
  Future<void> setAppSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getAppSetting(String key) async {
    final db = await instance.database;
    final maps = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  // ──────────────────────────────────────────────
  // Pause Tracking Data Clean-Up Methods
  // ──────────────────────────────────────────────
  /// Deletes transactions for [bankName] that DO NOT have an assigned reason, note, or bookmark.
  /// Transactions with reasons, category links, notes, or bookmarks are strictly preserved.
  Future<int> deleteUncategorizedTransactionsForBank(String bankName) async {
    final db = await instance.database;
    return await db.delete(
      'transactions',
      where: 'UPPER(name) = ? AND (reason IS NULL OR reason = "") AND reasonId IS NULL AND (customReasonText IS NULL OR customReasonText = "") AND (note IS NULL OR note = "") AND isBookmarked = 0',
      whereArgs: [bankName.toUpperCase()],
    );
  }

  /// Deletes notifications for [bankName] that DO NOT have an assigned reason.
  Future<int> deleteUncategorizedNotificationsForBank(String bankName) async {
    final db = await instance.database;
    return await db.delete(
      'notifications',
      where: 'UPPER(sender) = ? AND (reason IS NULL OR reason = "")',
      whereArgs: [bankName.toUpperCase()],
    );
  }

  // ──────────────────────────────────────────────
  // Transaction Splits (Multi-Category Itemization)
  // ──────────────────────────────────────────────

  /// Returns all transaction splits across all transactions.
  Future<List<TransactionSplit>> getAllTransactionSplits() async {
    final db = await instance.database;
    final rows = await db.query('transaction_splits', orderBy: 'id ASC');
    return rows.map((r) => TransactionSplit.fromMap(r)).toList();
  }

  /// Returns all split allocations for a specific transaction ID.
  Future<List<TransactionSplit>> getSplitsForTransaction(String transactionId) async {
    final db = await instance.database;
    final rows = await db.query(
      'transaction_splits',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
      orderBy: 'id ASC',
    );
    return rows.map((r) => TransactionSplit.fromMap(r)).toList();
  }

  /// Atomically saves (replaces) all split allocations for a transaction.
  Future<void> saveTransactionSplits(
      String transactionId, List<TransactionSplit> splits) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete(
        'transaction_splits',
        where: 'transactionId = ?',
        whereArgs: [transactionId],
      );
      for (final s in splits) {
        await txn.insert('transaction_splits', s.toMap());
      }
      if (splits.isNotEmpty) {
        await txn.update(
          'transactions',
          {'reason': 'Split'},
          where: 'id = ?',
          whereArgs: [transactionId],
        );
      } else {
        await txn.update(
          'transactions',
          {'reason': null, 'reasonId': null, 'customReasonText': null},
          where: 'id = ?',
          whereArgs: [transactionId],
        );
      }
    });
  }

  /// Deletes all split allocations for a specific transaction.
  Future<int> deleteTransactionSplits(String transactionId) async {
    final db = await instance.database;
    final count = await db.delete(
      'transaction_splits',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
    );
    await db.update(
      'transactions',
      {'reason': null, 'reasonId': null, 'customReasonText': null},
      where: 'id = ?',
      whereArgs: [transactionId],
    );
    return count;
  }
}

