import 'dart:convert';
import 'dart:io';
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
  static const String _appFolderName = 'Shibre_Backups';
  static const String _appName = 'Shibre';

  // ─── Export ──────────────────────────────────────────────────────────────

  /// Creates a backup JSON file in the Shibre_Backups folder on external storage.
  /// Returns the absolute path of the created file.
  Future<String> createBackup() async {
    final data = await _collectAllData();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

    final dir = await _getBackupDirectory();
    final dateStr = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final fileName = '${_appName}_backup_$dateStr.json';
    final file = File('${dir.path}/$fileName');

    await file.writeAsString(jsonStr, encoding: utf8);
    return file.path;
  }

  /// Returns all backup files found in the Shibre_Backups folder, newest first.
  Future<List<File>> listBackupFiles() async {
    final dir = await _getBackupDirectory();
    if (!await dir.exists()) return [];

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  // ─── Import ──────────────────────────────────────────────────────────────

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
        // Only insert if not already present by name
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
    // Map old ID → new ID for re-linking
    final Map<int, int> reasonIdMap = {};
    for (final raw in reasonsRaw) {
      try {
        final oldId = raw['id'] as int?;
        final reason = AppReason(
          name: raw['name'] as String,
          isSystem: (raw['isSystem'] as int) == 1,
        );
        // Skip system reasons (they're seeded)
        if (reason.isSystem) {
          // Find the existing system reason with the same name
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
        // Re-map reason IDs
        final rawMap = Map<String, dynamic>.from(raw);
        if (rawMap['reasonId'] != null) {
          final oldId = rawMap['reasonId'] as int;
          rawMap['reasonId'] = reasonIdMap[oldId] ?? oldId;
        }
        final tx = AppTransaction.fromMap(rawMap);
        await DatabaseService.instance.insertTransaction(tx);

        // Track latest date
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
      // The anchor is the date of the latest imported transaction.
      // The refresh scan will pick up ALL messages AFTER this point.
      await prefs.setString(
          'install_anchor_date', latestDate.toIso8601String());
      // Mark as not first boot so refresh scan runs next time
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

  // ─── Helpers ─────────────────────────────────────────────────────────────

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

  Future<Directory> _getBackupDirectory() async {
    Directory? baseDir;

    // Prefer external storage (Downloads) so user can find the file easily
    try {
      final extDirs = await getExternalStorageDirectories();
      if (extDirs != null && extDirs.isNotEmpty) {
        // Go up to the root external storage
        String path = extDirs.first.path;
        // Navigate up to the root external dir
        final parts = path.split('/');
        final androidIdx = parts.indexOf('Android');
        if (androidIdx > 0) {
          path = parts.sublist(0, androidIdx).join('/');
        }
        baseDir = Directory(path);
      }
    } catch (_) {}

    baseDir ??= await getApplicationDocumentsDirectory();

    final backupDir = Directory('${baseDir.path}/$_appFolderName');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  String _txLabel(dynamic raw) {
    try {
      return '${raw['name']} ${raw['amount']}';
    } catch (_) {
      return 'Transaction';
    }
  }
}
