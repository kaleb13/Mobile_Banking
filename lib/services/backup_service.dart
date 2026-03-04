import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/sender.dart';
import '../models/reason.dart';
import 'database_service.dart';

/// Represents the result of a single record import attempt.
class ImportResult {
  final String type; // 'transaction', 'sender', 'reason', 'reason_link'
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

/// Full backup/restore service for Shibre app data.
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
    // getDirectoryPath() returns a real filesystem path — no content:// URI
    // issues — so we can write to it directly with dart:io.
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
      // Fallback: some ROMs restrict writing to certain SAF paths via dart:io.
      // Write to the app-scoped external directory instead (always accessible).
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

    // 1. Paths the user saved via the SAF picker (tracked in prefs)
    final tracked = await _getTrackedPaths();
    paths.addAll(tracked);

    // 2. Fallback: scan the default app-scoped external dir for .json files
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

    // Build File objects, filter to existing files only
    final files =
        paths.map((p) => File(p)).where((f) => f.existsSync()).toList();

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  // ─── Import ──────────────────────────────────────────────────────────────

  /// Opens the native file picker so the user can pick any .json backup file
  /// from anywhere on the device.
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

    // Track this path so it appears in the restore list next time
    await _trackSavedPath(path);
    return File(path);
  }

  /// Imports data from [file].
  ///
  /// Logic:
  ///  1. Parse the JSON backup.
  ///  2. Determine the LATEST transaction date found in the backup file.
  ///  3. Set the install_anchor_date in SharedPreferences to this date so that
  ///     the background refresh will scan for SMS messages AFTER this point.
  ///  4. Insert all records (senders, reasons, reason_links, transactions)
  ///     and collect per-item results so the UI can show success/error counts
  ///     and offer a retry for errors.
  Future<List<ImportResult>> importBackup(File file) async {
    final List<ImportResult> results = [];

    final jsonStr = await file.readAsString(encoding: utf8);
    final Map<String, dynamic> data = jsonDecode(jsonStr);

    // ── Senders ─────────────────────────────────────────────────
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

    // ── Reasons ─────────────────────────────────────────────────
    final reasonsRaw = (data['reasons'] as List<dynamic>?) ?? [];
    final Map<int, int> reasonIdMap = {};
    for (final raw in reasonsRaw) {
      try {
        final oldId = raw['id'] as int?;
        final reason = AppReason(
          name: raw['name'] as String,
          isSystem: (raw['isSystem'] as int) == 1,
        );
        if (reason.isSystem) {
          final existing = await DatabaseService.instance.getReasons();
          final match = existing.firstWhere(
            (r) => r.name == reason.name && r.isSystem,
            orElse: () => AppReason(id: null, name: reason.name),
          );
          if (match.id != null && oldId != null) {
            reasonIdMap[oldId] = match.id!;
          }
          results.add(ImportResult(
            type: 'reason',
            label: reason.name,
            success: true,
          ));
        } else {
          final newId = await DatabaseService.instance.insertReason(reason);
          if (oldId != null) reasonIdMap[oldId] = newId;
          results.add(ImportResult(
            type: 'reason',
            label: reason.name,
            success: true,
          ));
        }
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

    // ── Reason Links ─────────────────────────────────────────────
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

    // ── Transactions ─────────────────────────────────────────────
    final transactionsRaw = (data['transactions'] as List<dynamic>?) ?? [];
    DateTime? latestDate;

    for (final raw in transactionsRaw) {
      try {
        final rawMap = Map<String, dynamic>.from(raw);
        if (rawMap['reasonId'] != null) {
          final oldId = rawMap['reasonId'] as int;
          rawMap['reasonId'] = reasonIdMap[oldId] ?? oldId;
        }
        final tx = AppTransaction.fromMap(rawMap);
        await DatabaseService.instance.insertTransaction(tx);

        if (latestDate == null || tx.date.isAfter(latestDate)) {
          latestDate = tx.date;
        }

        results.add(ImportResult(
          type: 'transaction',
          label: '${tx.name} ${tx.amount} (${tx.type})',
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

    // ── Set anchor from latest imported transaction ──────────────
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
      switch (failed.type) {
        case 'sender':
          final sender =
              AppSender.fromMap(Map<String, dynamic>.from(failed.rawData!));
          await DatabaseService.instance.insertSender(sender);
          return ImportResult(
              type: failed.type, label: failed.label, success: true);

        case 'reason':
          final r = AppReason(
            name: failed.rawData!['name'] as String,
            isSystem: (failed.rawData!['isSystem'] as int) == 1,
          );
          await DatabaseService.instance.insertReason(r);
          return ImportResult(
              type: failed.type, label: failed.label, success: true);

        case 'reason_link':
          final link = AppReasonLink(
            reasonId: failed.rawData!['reasonId'] as int,
            linkedName: failed.rawData!['linkedName'] as String,
            linkType: failed.rawData!['linkType'] as String,
          );
          await DatabaseService.instance.insertReasonLink(link);
          return ImportResult(
              type: failed.type, label: failed.label, success: true);

        case 'transaction':
          final tx = AppTransaction.fromMap(
              Map<String, dynamic>.from(failed.rawData!));
          await DatabaseService.instance.insertTransaction(tx);
          return ImportResult(
              type: failed.type, label: failed.label, success: true);

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
      existing.insert(0, path); // prepend so newest is first
      await prefs.setStringList(_savedPathsKey, existing);
    }
  }

  // ─── Default fallback directory (no permission needed) ────────────────────

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

  // ─── Data collection ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _collectAllData() async {
    final transactions = await DatabaseService.instance.getTransactions();
    final senders = await DatabaseService.instance.getSenders();
    final reasons = await DatabaseService.instance.getReasons();
    final links = await DatabaseService.instance.getReasonLinks();

    return {
      'app': _appName,
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'senders': senders.map((s) => s.toMap()).toList(),
      'reasons': reasons
          .map((r) => {
                'id': r.id,
                'name': r.name,
                'isSystem': r.isSystem ? 1 : 0,
              })
          .toList(),
      'reason_links': links
          .map((l) => {
                'id': l.id,
                'reasonId': l.reasonId,
                'linkedName': l.linkedName,
                'linkType': l.linkType,
              })
          .toList(),
      'transactions': transactions.map((t) => t.toMap()).toList(),
    };
  }

  String _txLabel(dynamic raw) {
    try {
      return '${raw['name']} ${raw['amount']}';
    } catch (_) {
      return 'Transaction';
    }
  }
}
