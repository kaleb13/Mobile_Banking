import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/sender.dart';
import '../models/reason.dart';
import '../models/cash_transaction.dart';
import '../models/saving_goal.dart';
import '../models/loan_record.dart';
import 'database_service.dart';

/// Represents the result of a single record import attempt.
class ImportResult {
  final String type; // 'transaction', 'sender', 'reason', 'reason_link', 'cash_transaction', 'saving_goal', 'loan', 'loan_payment'
  final String label;
  final bool success;
  final String? error;
  final Map<String, dynamic>? rawData;

  ImportResult({
    required this.type,
    required this.label,
    required this.success,
    this.error,
    this.rawData,
  });
}

/// Full backup/restore service for Shibre app data (Version 2).
///
/// Features:
/// - Full categories & subcategories preservation (parents, icons, colors, flow types).
/// - Tombstone restoration (deleted default categories remain deleted on restore).
/// - Complete financial domains: Bank transactions, Cash transactions, Saving goals, and Loans.
/// - Non-destructive smart merge: If a transaction already exists, merges user notes,
///   custom reasons, and bookmark states without duplicating.
/// - Full backward-compatibility with Version 1 backups.
class BackupService {
  static const String _appName = 'Shibre';
  static const String _savedPathsKey = 'backup_saved_paths';

  // ─── Export ──────────────────────────────────────────────────────────────

  /// Builds the backup JSON string without writing it yet.
  Future<String> _buildBackupJson() async {
    final data = await _collectAllData();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Opens the native Android folder picker (SAF) so the user can choose
  /// any destination directory. Writes the backup there and returns the path.
  /// Returns null if the user cancels.
  Future<String?> createBackup() async {
    final jsonStr = await _buildBackupJson();
    final dateStr = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final suggestedName = '${_appName}_backup_$dateStr.json';

    // Show the native Android folder picker (ACTION_OPEN_DOCUMENT_TREE via SAF).
    final String? dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose folder to save your backup',
    );

    if (dirPath == null) return null; // user cancelled

    // Attempt to write directly into the chosen directory.
    try {
      final file = File('$dirPath/$suggestedName');
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonStr, encoding: utf8);
      await _trackSavedPath(file.path);
      return file.path;
    } catch (_) {
      // Fallback: app-scoped external directory
      final fallbackDir = await _defaultBackupDirectory();
      await fallbackDir.create(recursive: true);
      final fallbackFile = File('${fallbackDir.path}/$suggestedName');
      await fallbackFile.writeAsString(jsonStr, encoding: utf8);
      await _trackSavedPath(fallbackFile.path);
      return fallbackFile.path;
    }
  }

  /// Returns all previously saved backup files (tracked paths + fallback dir),
  /// newest first, filtering out files that no longer exist.
  Future<List<File>> listBackupFiles() async {
    final Set<String> paths = {};

    final tracked = await _getTrackedPaths();
    paths.addAll(tracked);

    try {
      final defaultDir = await _defaultBackupDirectory();
      if (await defaultDir.exists()) {
        for (final entity in defaultDir.listSync()) {
          if (entity is File && entity.path.endsWith('.json')) {
            paths.add(entity.path);
          }
        }
      }
    } catch (_) {}

    final files =
        paths.map((p) => File(p)).where((f) => f.existsSync()).toList();

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  // ─── Import ──────────────────────────────────────────────────────────────

  /// Opens the native file picker so the user can pick any .json backup file.
  Future<File?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Backup File',
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final path = result.files.single.path;
    if (path == null) return null;

    await _trackSavedPath(path);
    return File(path);
  }

  /// Imports complete application state from [file].
  Future<List<ImportResult>> importBackup(File file) async {
    final List<ImportResult> results = [];

    final jsonStr = await file.readAsString(encoding: utf8);
    final Map<String, dynamic> data = jsonDecode(jsonStr);

    // ── 1. User Preferences & App Settings ───────────────────────
    try {
      if (data['user_preferences'] != null) {
        final prefs = await SharedPreferences.getInstance();
        final up = data['user_preferences'] as Map<String, dynamic>;
        if (up['is_balance_visible'] is bool) {
          await prefs.setBool('is_balance_visible', up['is_balance_visible'] as bool);
        }
        if (up['selected_theme_mode'] is String) {
          await prefs.setString('selected_theme_mode', up['selected_theme_mode'] as String);
        }
        if (up['app_locale'] is String) {
          await prefs.setString('app_locale', up['app_locale'] as String);
        }
        if (up['biometrics_enabled'] is bool) {
          await prefs.setBool('biometrics_enabled', up['biometrics_enabled'] as bool);
        }
      }

      if (data['app_settings'] != null) {
        final settings = data['app_settings'] as Map<String, dynamic>;
        for (final entry in settings.entries) {
          if (entry.value is String) {
            await DatabaseService.instance.setSetting(entry.key, entry.value as String);
          }
        }
      }
    } catch (_) {}

    // ── 2. Deleted Default Categories (Tombstones) ───────────────
    final deletedReasonsRaw = (data['deleted_default_reasons'] as List<dynamic>?) ?? [];
    for (final raw in deletedReasonsRaw) {
      try {
        final name = (raw['name'] ?? '').toString();
        final parentName = (raw['parentName'] ?? '').toString();
        final deletedAt = (raw['deletedAt'] ?? DateTime.now().toIso8601String()).toString();
        if (name.isNotEmpty) {
          await DatabaseService.instance.insertDeletedDefaultReason(name, parentName, deletedAt);
        }
      } catch (_) {}
    }

    // ── 3. Senders / Wallets ─────────────────────────────────────
    final sendersRaw = (data['senders'] as List<dynamic>?) ?? [];
    for (final raw in sendersRaw) {
      try {
        final sender = AppSender.fromMap(Map<String, dynamic>.from(raw));
        final existing = await DatabaseService.instance.getSenders();
        final alreadyExists = existing.any(
          (s) => s.senderName.toLowerCase() == sender.senderName.toLowerCase(),
        );
        if (!alreadyExists) {
          await DatabaseService.instance.insertSender(sender);
        }
        results.add(ImportResult(
          type: 'sender',
          label: sender.senderName,
          success: true,
        ));
      } catch (e) {
        results.add(ImportResult(
          type: 'sender',
          label: (raw['senderName'] ?? 'Unknown').toString(),
          success: false,
          error: e.toString(),
          rawData: Map<String, dynamic>.from(raw),
        ));
      }
    }

    // ── 4. Categories & Subcategories (2-Pass Hierarchy) ─────────
    final reasonsRaw = (data['reasons'] as List<dynamic>?) ?? [];
    final Map<int, int> reasonIdMap = {};

    // Pass 1: Top-level reasons (parentId == null)
    final topLevel = reasonsRaw.where((r) => r['parentId'] == null).toList();
    for (final raw in topLevel) {
      try {
        final oldId = raw['id'] as int?;
        final name = raw['name'] as String;
        final isSystem = (raw['isSystem'] as int? ?? (raw['isSystem'] == true ? 1 : 0)) == 1;
        final isSpecial = (raw['isSpecial'] as int? ?? 0) == 1;
        final icon = raw['icon'] as String?;
        final color = raw['color'] as String?;

        final existing = await DatabaseService.instance.getReasons();
        final match = existing.firstWhere(
          (r) => r.name.toLowerCase().trim() == name.toLowerCase().trim() && r.parentId == null,
          orElse: () => AppReason(id: null, name: name),
        );

        if (match.id != null) {
          if (oldId != null) reasonIdMap[oldId] = match.id!;
          if ((icon != null || color != null) && (match.icon == null || match.color == null)) {
            await DatabaseService.instance.updateReason(match.copyWith(
              icon: icon ?? match.icon,
              color: color ?? match.color,
            ));
          }
        } else {
          final db = await DatabaseService.instance.database;
          final map = {
            'name': name,
            'isSystem': isSystem ? 1 : 0,
            'isSpecial': isSpecial ? 1 : 0,
            'parentId': null,
            'icon': icon,
            'color': color,
          };
          final newId = await db.insert('reasons', map);
          if (oldId != null) reasonIdMap[oldId] = newId;
        }

        results.add(ImportResult(type: 'reason', label: name, success: true));
      } catch (e) {
        results.add(ImportResult(
          type: 'reason',
          label: (raw['name'] ?? 'Unknown').toString(),
          success: false,
          error: e.toString(),
          rawData: Map<String, dynamic>.from(raw),
        ));
      }
    }

    // Pass 2: Subcategories (parentId != null)
    final subcategories = reasonsRaw.where((r) => r['parentId'] != null).toList();
    for (final raw in subcategories) {
      try {
        final oldId = raw['id'] as int?;
        final oldParentId = raw['parentId'] as int;
        final newParentId = reasonIdMap[oldParentId] ?? oldParentId;
        final name = raw['name'] as String;
        final isSystem = (raw['isSystem'] as int? ?? 0) == 1;
        final isSpecial = (raw['isSpecial'] as int? ?? 0) == 1;
        final icon = raw['icon'] as String?;
        final color = raw['color'] as String?;

        final existing = await DatabaseService.instance.getReasons();
        final match = existing.firstWhere(
          (r) => r.name.toLowerCase().trim() == name.toLowerCase().trim() && r.parentId == newParentId,
          orElse: () => AppReason(id: null, name: name),
        );

        if (match.id != null) {
          if (oldId != null) reasonIdMap[oldId] = match.id!;
        } else {
          final db = await DatabaseService.instance.database;
          final map = {
            'name': name,
            'isSystem': isSystem ? 1 : 0,
            'isSpecial': isSpecial ? 1 : 0,
            'parentId': newParentId,
            'icon': icon,
            'color': color,
          };
          final newId = await db.insert('reasons', map);
          if (oldId != null) reasonIdMap[oldId] = newId;
        }

        results.add(ImportResult(type: 'reason', label: name, success: true));
      } catch (e) {
        results.add(ImportResult(
          type: 'reason',
          label: (raw['name'] ?? 'Unknown').toString(),
          success: false,
          error: e.toString(),
          rawData: Map<String, dynamic>.from(raw),
        ));
      }
    }

    // ── 5. Reason Links ──────────────────────────────────────────
    final linksRaw = (data['reason_links'] as List<dynamic>?) ?? [];
    for (final raw in linksRaw) {
      try {
        final oldReasonId = raw['reasonId'] as int;
        final newReasonId = reasonIdMap[oldReasonId] ?? oldReasonId;
        final link = AppReasonLink(
          reasonId: newReasonId,
          linkedName: raw['linkedName'] as String,
          linkType: raw['linkType'] as String,
        );
        await DatabaseService.instance.insertReasonLink(link);
        results.add(ImportResult(
          type: 'reason_link',
          label: '${link.linkedName} → ${link.linkType}',
          success: true,
        ));
      } catch (e) {
        results.add(ImportResult(
          type: 'reason_link',
          label: (raw['linkedName'] ?? 'Unknown').toString(),
          success: false,
          error: e.toString(),
          rawData: Map<String, dynamic>.from(raw),
        ));
      }
    }

    // ── 6. Transactions (Smart Merge / Upsert) ───────────────────
    final transactionsRaw = (data['transactions'] as List<dynamic>?) ?? [];
    DateTime? latestDate;

    for (final raw in transactionsRaw) {
      try {
        final rawMap = Map<String, dynamic>.from(raw);
        if (rawMap['reasonId'] != null) {
          final oldId = rawMap['reasonId'] as int;
          rawMap['reasonId'] = reasonIdMap[oldId] ?? oldId;
        }
        if (rawMap['categoryId'] != null) {
          final oldCatId = rawMap['categoryId'] as int;
          rawMap['categoryId'] = reasonIdMap[oldCatId] ?? oldCatId;
        }
        if (rawMap['subcategoryId'] != null) {
          final oldSubId = rawMap['subcategoryId'] as int;
          rawMap['subcategoryId'] = reasonIdMap[oldSubId] ?? oldSubId;
        }

        final tx = AppTransaction.fromMap(rawMap);
        await DatabaseService.instance.upsertTransactionFromBackup(tx);

        if (latestDate == null || tx.date.isAfter(latestDate)) {
          latestDate = tx.date;
        }

        results.add(ImportResult(
          type: 'transaction',
          label: '${tx.bankName} ${tx.amount} (${tx.type})',
          success: true,
        ));
      } catch (e) {
        results.add(ImportResult(
          type: 'transaction',
          label: _txLabel(raw),
          success: false,
          error: e.toString(),
          rawData: Map<String, dynamic>.from(raw),
        ));
      }
    }

    // ── 7. Cash Transactions ─────────────────────────────────────
    final cashRaw = (data['cash_transactions'] as List<dynamic>?) ?? [];
    for (final raw in cashRaw) {
      try {
        final rawMap = Map<String, dynamic>.from(raw);
        if (rawMap['reasonId'] != null) {
          final oldId = rawMap['reasonId'] as int;
          rawMap['reasonId'] = reasonIdMap[oldId] ?? oldId;
        }
        final cashTx = CashTransaction.fromMap(rawMap);

        final existingCash = await DatabaseService.instance.getCashTransactions();
        final isDuplicate = existingCash.any((c) =>
            c.amount == cashTx.amount &&
            c.type == cashTx.type &&
            c.date.isAtSameMomentAs(cashTx.date) &&
            c.description == cashTx.description);

        if (!isDuplicate) {
          await DatabaseService.instance.insertCashTransaction(cashTx);
        }

        results.add(ImportResult(
          type: 'cash_transaction',
          label: 'Cash ${cashTx.type} ${cashTx.amount}',
          success: true,
        ));
      } catch (e) {
        results.add(ImportResult(
          type: 'cash_transaction',
          label: 'Cash Transaction',
          success: false,
          error: e.toString(),
          rawData: Map<String, dynamic>.from(raw),
        ));
      }
    }

    // ── 8. Saving Goals ──────────────────────────────────────────
    final goalsRaw = (data['saving_goals'] as List<dynamic>?) ?? [];
    for (final raw in goalsRaw) {
      try {
        final goal = SavingGoal.fromMap(Map<String, dynamic>.from(raw));
        await DatabaseService.instance.insertSavingGoal(goal);
        results.add(ImportResult(
          type: 'saving_goal',
          label: goal.title,
          success: true,
        ));
      } catch (e) {
        results.add(ImportResult(
          type: 'saving_goal',
          label: (raw['title'] ?? 'Goal').toString(),
          success: false,
          error: e.toString(),
          rawData: Map<String, dynamic>.from(raw),
        ));
      }
    }

    // ── 9. Loans & Repayments ────────────────────────────────────
    final loansRaw = (data['loans'] as List<dynamic>?) ?? [];
    final Map<int, int> loanIdMap = {};
    for (final raw in loansRaw) {
      try {
        final oldId = raw['id'] as int?;
        final loan = LoanRecord.fromMap(Map<String, dynamic>.from(raw));
        final db = await DatabaseService.instance.database;
        final map = Map<String, dynamic>.from(loan.toMap());
        map.remove('id');
        map.remove('monitoredBanks');

        final newId = await db.insert('loan_records', map);
        if (oldId != null) {
          loanIdMap[oldId] = newId;
        }

        results.add(ImportResult(
          type: 'loan',
          label: '${loan.personName} (${loan.principalAmount})',
          success: true,
        ));
      } catch (e) {
        results.add(ImportResult(
          type: 'loan',
          label: (raw['personName'] ?? 'Loan').toString(),
          success: false,
          error: e.toString(),
          rawData: Map<String, dynamic>.from(raw),
        ));
      }
    }

    final paymentsRaw = (data['loan_payments'] as List<dynamic>?) ?? [];
    for (final raw in paymentsRaw) {
      try {
        final oldLoanId = raw['loanId'] as int;
        final newLoanId = loanIdMap[oldLoanId] ?? oldLoanId;
        final rawMap = Map<String, dynamic>.from(raw);
        rawMap['loanId'] = newLoanId;
        rawMap.remove('id');

        final payment = LoanPayment.fromMap(rawMap);
        await DatabaseService.instance.insertLoanPayment(payment);
        await DatabaseService.instance.recalcLoanPaid(newLoanId);

        results.add(ImportResult(
          type: 'loan_payment',
          label: 'Payment ${payment.amount}',
          success: true,
        ));
      } catch (e) {
        results.add(ImportResult(
          type: 'loan_payment',
          label: 'Loan Payment',
          success: false,
          error: e.toString(),
          rawData: Map<String, dynamic>.from(raw),
        ));
      }
    }

    // ── 10. Set anchor from latest imported transaction ──────────
    if (latestDate != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'install_anchor_date', latestDate.toIso8601String());
      await prefs.setBool('is_first_boot_v3', false);
    }

    return results;
  }

  // ─── Retry single failed record ───────────────────────────────────────────

  Future<ImportResult> retryImport(ImportResult failed) async {
    try {
      if (failed.rawData == null) {
        return ImportResult(type: failed.type, label: failed.label, success: false, error: 'No raw data');
      }
      final raw = Map<String, dynamic>.from(failed.rawData!);

      switch (failed.type) {
        case 'sender':
          final sender = AppSender.fromMap(raw);
          await DatabaseService.instance.insertSender(sender);
          return ImportResult(type: failed.type, label: failed.label, success: true);

        case 'reason':
          final r = AppReason.fromMap(raw);
          await DatabaseService.instance.insertReason(r);
          return ImportResult(type: failed.type, label: failed.label, success: true);

        case 'reason_link':
          final link = AppReasonLink.fromMap(raw);
          await DatabaseService.instance.insertReasonLink(link);
          return ImportResult(type: failed.type, label: failed.label, success: true);

        case 'transaction':
          final tx = AppTransaction.fromMap(raw);
          await DatabaseService.instance.upsertTransactionFromBackup(tx);
          return ImportResult(type: failed.type, label: failed.label, success: true);

        case 'cash_transaction':
          final cash = CashTransaction.fromMap(raw);
          await DatabaseService.instance.insertCashTransaction(cash);
          return ImportResult(type: failed.type, label: failed.label, success: true);

        case 'saving_goal':
          final goal = SavingGoal.fromMap(raw);
          await DatabaseService.instance.insertSavingGoal(goal);
          return ImportResult(type: failed.type, label: failed.label, success: true);

        case 'loan':
          final loan = LoanRecord.fromMap(raw);
          final db = await DatabaseService.instance.database;
          final map = Map<String, dynamic>.from(loan.toMap())..remove('id')..remove('monitoredBanks');
          await db.insert('loan_records', map);
          return ImportResult(type: failed.type, label: failed.label, success: true);

        case 'loan_payment':
          final payment = LoanPayment.fromMap(raw);
          await DatabaseService.instance.insertLoanPayment(payment);
          return ImportResult(type: failed.type, label: failed.label, success: true);

        default:
          return ImportResult(
              type: failed.type,
              label: failed.label,
              success: false,
              error: 'Unknown type');
      }
    } catch (e) {
      return ImportResult(
        type: failed.type,
        label: failed.label,
        success: false,
        error: e.toString(),
        rawData: failed.rawData,
      );
    }
  }

  // ─── Path tracking (SharedPreferences) ───────────────────────────────────

  Future<List<String>> _getTrackedPaths() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_savedPathsKey) ?? [];
  }

  Future<void> _trackSavedPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_savedPathsKey) ?? [];
    if (!existing.contains(path)) {
      existing.insert(0, path);
      await prefs.setStringList(_savedPathsKey, existing);
    }
  }

  // ─── Default fallback directory ──────────────────────────────────────────

  Future<Directory> _defaultBackupDirectory() async {
    Directory? dir;
    try {
      final extDirs = await getExternalStorageDirectories();
      if (extDirs != null && extDirs.isNotEmpty) {
        dir = Directory('${extDirs.first.path}/Shibre_Backups');
      }
    } catch (_) {}
    dir ??= Directory(
        '${(await getApplicationDocumentsDirectory()).path}/Shibre_Backups');
    return dir;
  }

  // ─── Data collection (Version 2) ─────────────────────────────────────────

  Future<Map<String, dynamic>> _collectAllData() async {
    final transactions = await DatabaseService.instance.getTransactions();
    final senders = await DatabaseService.instance.getSenders();
    final reasons = await DatabaseService.instance.getReasons();
    final links = await DatabaseService.instance.getReasonLinks();
    final deletedReasons = await DatabaseService.instance.getDeletedDefaultReasons();
    final cashTransactions = await DatabaseService.instance.getCashTransactions();
    final savingGoals = await DatabaseService.instance.getSavingGoals();
    final loans = await DatabaseService.instance.getLoanRecords();

    final List<Map<String, dynamic>> loanPaymentsList = [];
    for (final l in loans) {
      if (l.id != null) {
        final payments = await DatabaseService.instance.getPaymentsForLoan(l.id!);
        for (final p in payments) {
          loanPaymentsList.add(p.toMap());
        }
      }
    }

    final appSettings = await DatabaseService.instance.getAllAppSettings();

    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> userPreferences = {
      'is_balance_visible': prefs.getBool('is_balance_visible'),
      'selected_theme_mode': prefs.getString('selected_theme_mode'),
      'app_locale': prefs.getString('app_locale'),
      'biometrics_enabled': prefs.getBool('biometrics_enabled'),
    };

    return {
      'app': _appName,
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'user_preferences': userPreferences,
      'app_settings': appSettings,
      'senders': senders.map((s) => s.toMap()).toList(),
      'reasons': reasons.map((r) => r.toMap()).toList(),
      'deleted_default_reasons': deletedReasons,
      'reason_links': links.map((l) => l.toMap()).toList(),
      'transactions': transactions.map((t) => t.toMap()).toList(),
      'cash_transactions': cashTransactions.map((c) => c.toMap()).toList(),
      'saving_goals': savingGoals.map((g) => g.toMap()).toList(),
      'loans': loans.map((l) => l.toMap()).toList(),
      'loan_payments': loanPaymentsList,
    };
  }

  String _txLabel(dynamic raw) {
    try {
      return '${raw['name'] ?? raw['bankName']} ${raw['amount']}';
    } catch (_) {
      return 'Transaction';
    }
  }
}
