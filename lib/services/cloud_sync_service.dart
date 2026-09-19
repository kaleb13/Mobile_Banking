import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction.dart';
import '../models/sender.dart';
import '../models/reason.dart';
import '../models/transaction_split.dart';
import 'auth_service.dart';
import 'database_service.dart';

import 'bank_senders.dart';
import 'device_security_service.dart';
import 'sync_notification_service.dart';

enum CloudSyncStatus {
  idle,
  syncing,
  success,
  offline,
  error,
  disabled,
}

/// Detailed snapshot of cloud sync progress and status metrics.
class CloudSyncProgress {
  final int deviceTotal;
  final int cloudCount;
  final int pendingCount;
  final int failedCount;
  final int disabledBankCount;
  final String? failureMessage;
  final bool isSyncing;
  final int currentBatchUploaded;
  final int totalToUpload;

  const CloudSyncProgress({
    this.deviceTotal = 0,
    this.cloudCount = 0,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.disabledBankCount = 0,
    this.failureMessage,
    this.isSyncing = false,
    this.currentBatchUploaded = 0,
    this.totalToUpload = 0,
  });

  double get percentInCloud {
    if (deviceTotal <= 0) return 100.0;
    final pct = (cloudCount / deviceTotal) * 100.0;
    return pct.clamp(0.0, 100.0);
  }

  double get fractionInCloud {
    if (deviceTotal <= 0) return 1.0;
    final ratio = cloudCount / deviceTotal;
    return ratio.clamp(0.0, 1.0);
  }

  CloudSyncProgress copyWith({
    int? deviceTotal,
    int? cloudCount,
    int? pendingCount,
    int? failedCount,
    int? disabledBankCount,
    String? failureMessage,
    bool clearFailureMessage = false,
    bool? isSyncing,
    int? currentBatchUploaded,
    int? totalToUpload,
  }) {
    return CloudSyncProgress(
      deviceTotal: deviceTotal ?? this.deviceTotal,
      cloudCount: cloudCount ?? this.cloudCount,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      disabledBankCount: disabledBankCount ?? this.disabledBankCount,
      failureMessage: clearFailureMessage
          ? null
          : (failureMessage ?? this.failureMessage),
      isSyncing: isSyncing ?? this.isSyncing,
      currentBatchUploaded:
          currentBatchUploaded ?? this.currentBatchUploaded,
      totalToUpload: totalToUpload ?? this.totalToUpload,
    );
  }
}

/// Real-time multi-device cloud synchronization service powered by Supabase.
///
/// Features:
/// - Explicit opt-in compliance (Google Play SMS privacy compliant).
/// - Instant transaction push to Supabase on local SMS ingestion.
/// - Supabase Realtime WebSocket listener for live multi-device synchronization.
/// - Full two-way reconciliation between local SQLite and cloud PostgreSQL.
class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  static const String _syncEnabledKey = 'cloud_sync_enabled';
  static const String _lastSyncedKey = 'cloud_last_synced_timestamp';

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  final ValueNotifier<CloudSyncStatus> statusNotifier =
      ValueNotifier<CloudSyncStatus>(CloudSyncStatus.idle);
  final ValueNotifier<DateTime?> lastSyncedNotifier =
      ValueNotifier<DateTime?>(null);
  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<CloudSyncProgress> progressNotifier =
      ValueNotifier<CloudSyncProgress>(const CloudSyncProgress());

  final List<AppTransaction> _failedUploadBatch = [];
  String? _lastBatchError;

  List<AppTransaction> get failedUploadBatch =>
      List.unmodifiable(_failedUploadBatch);
  int get failedUploadCount => _failedUploadBatch.length;
  String? get lastBatchError => _lastBatchError;

  /// Callback fired whenever a full sync completes successfully so UI view models can reload.
  VoidCallback? onSyncCompleted;

  RealtimeChannel? _txChannel;
  bool _isInitialized = false;
  bool _isBatchPurging = false;

  /// Initializes the service, sets up listeners, and connects Realtime if enabled.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    final prefs = await SharedPreferences.getInstance();
    final lastSyncedStr = prefs.getString(_lastSyncedKey);
    if (lastSyncedStr != null) {
      lastSyncedNotifier.value = DateTime.tryParse(lastSyncedStr);
    }

    final enabled = await isSyncEnabled();
    if (!enabled) {
      statusNotifier.value = CloudSyncStatus.disabled;
    }

    // Hook into DatabaseService to push new transactions as soon as they are saved
    DatabaseService.instance.onTransactionsChanged = (transactions) {
      if (transactions.isNotEmpty) {
        syncTransactionsImmediately(transactions);
      }
    };

    // Hook into DatabaseService to delete transactions from cloud immediately
    DatabaseService.instance.onTransactionDeleted = (txId) {
      deleteTransactionImmediately(txId);
    };

    // Hook into DatabaseService to push split allocations immediately
    DatabaseService.instance.onSplitsChanged = (txId, splits) {
      syncSplitsImmediately(txId, splits);
    };

    // Hook into DatabaseService to push contact rules immediately
    DatabaseService.instance.onReasonLinkChanged = (link, isDeleted) {
      syncReasonLinkImmediately(link, isDeleted);
    };

    // Listen to authentication changes
    AuthService.instance.onAuthStateChange.listen((data) {
      if (data.session != null) {
        _onUserSignedIn();
      } else {
        _onUserSignedOut();
      }
    });

    if (AuthService.instance.isAuthenticated && enabled) {
      subscribeToRealtime();
    }
  }

  /// Whether Cloud Sync is explicitly enabled by the user.
  Future<bool> isSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncEnabledKey) ?? false;
  }

  /// Toggles Cloud Sync on or off.
  Future<void> setSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncEnabledKey, enabled);

    if (enabled) {
      statusNotifier.value = CloudSyncStatus.idle;
      if (AuthService.instance.isAuthenticated) {
        subscribeToRealtime();
        // Perform initial sync in background
        unawaited(syncAll());
      }
    } else {
      unsubscribeFromRealtime();
      statusNotifier.value = CloudSyncStatus.disabled;
    }
  }

  // ─── Per-Bank Cloud Sync Controls ──────────────────────────────────────────

  String _disabledBanksPrefKey(String userId) {
    final sanitized = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '${sanitized}_cloud_sync_disabled_banks';
  }

  /// Returns the set of bank names explicitly disabled for cloud sync by the active user.
  Future<Set<String>> getDisabledSyncBanks() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return {};
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_disabledBanksPrefKey(user.id)) ?? [];
    return list.toSet();
  }

  /// Sets whether cloud sync is enabled for a specific bank.
  Future<void> setBankSyncEnabled(String bankName, bool enabled) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _disabledBanksPrefKey(user.id);
    final current = (prefs.getStringList(key) ?? []).toSet();
    if (enabled) {
      current.removeWhere((b) => BankSenders.isSameBank(b, bankName));
    } else {
      current.add(bankName);
    }
    await prefs.setStringList(key, current.toList());
  }

  /// Checks if a bank is permitted to sync to cloud:
  /// Must NOT be in pausedBanks, and must NOT be in disabledSyncBanks.
  Future<bool> isBankSyncAllowed(String bankName) async {
    // 1. Check if bank is paused from tracking
    final pausedBanks = await DatabaseService.instance.getPausedBanks();
    final isPaused = pausedBanks.any((b) => !b.contains(':') && BankSenders.isSameBank(b, bankName));
    if (isPaused) return false;

    // 2. Check if bank is explicitly disabled for cloud sync
    final disabledBanks = await getDisabledSyncBanks();
    final isDisabled = disabledBanks.any((b) => BankSenders.isSameBank(b, bankName));
    if (isDisabled) return false;

    return true;
  }

  Future<void> _onUserSignedIn() async {
    final client = _supabase;
    final user = AuthService.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();

    // Activate sync by default on login unless the user explicitly toggled it off previously
    final explicitlyDisabled = prefs.getBool(_syncEnabledKey) == false;
    if (!explicitlyDisabled) {
      await prefs.setBool(_syncEnabledKey, true);
    }

    if (client != null && user != null) {
      try {
        final profile = await client
            .from('profiles')
            .select('cloud_sync_enabled')
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null && profile['cloud_sync_enabled'] == true) {
          await prefs.setBool(_syncEnabledKey, true);
        }
      } catch (_) {}
    }

    final enabled = await isSyncEnabled();
    if (enabled) {
      statusNotifier.value = CloudSyncStatus.idle;
      subscribeToRealtime();
      await syncAll();
    }
  }

  void _onUserSignedOut() {
    unsubscribeFromRealtime();
    statusNotifier.value = CloudSyncStatus.disabled;
  }

  /// Handles switching the active account in CloudSyncService.
  Future<void> switchAccount(String userId) async {
    unsubscribeFromRealtime();
    final enabled = await isSyncEnabled();
    if (enabled && AuthService.instance.isAuthenticated) {
      statusNotifier.value = CloudSyncStatus.idle;
      subscribeToRealtime();
      await syncAll();
    }
  }

  // ─── Realtime WebSockets ──────────────────────────────────────────────────

  /// Subscribes to Supabase Realtime channel for live multi-device transaction updates.
  void subscribeToRealtime() {
    final user = AuthService.instance.currentUser;
    final client = _supabase;
    if (user == null || client == null) return;

    unsubscribeFromRealtime();

    try {
      _txChannel = client
          .channel('cloud_tx_${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'cloud_transactions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: user.id,
            ),
            callback: (payload) async {
              await _handleIncomingRealtimeTransaction(payload);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'cloud_reason_links',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: user.id,
            ),
            callback: (payload) async {
              await _handleIncomingRealtimeReasonLink(payload);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'cloud_transaction_splits',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: user.id,
            ),
            callback: (payload) async {
              await _handleIncomingRealtimeSplit(payload);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('CloudSyncService.subscribeToRealtime error: $e');
    }
  }

  /// Unsubscribes from Realtime channel.
  void unsubscribeFromRealtime() {
    if (_txChannel != null) {
      try {
        _supabase?.removeChannel(_txChannel!);
      } catch (_) {}
      _txChannel = null;
    }
  }

  Future<void> _handleIncomingRealtimeTransaction(
      PostgresChangePayload payload) async {
    try {
      if (payload.eventType == PostgresChangeEvent.delete) {
        if (_isBatchPurging) {
          debugPrint('[CloudSync] Suppressing local deletion during batch cloud purge');
          return;
        }
        final oldRecord = payload.oldRecord;
        final deletedId = oldRecord['id'] as String?;
        if (deletedId != null && deletedId.isNotEmpty) {
          debugPrint('[CloudSync] Realtime delete received for tx: $deletedId');
          await DatabaseService.instance.deleteTransaction(deletedId);
          onSyncCompleted?.call();
        }
        return;
      }

      final record = payload.newRecord;
      if (record.isEmpty) return;

      final bankName = record['bank_name'] as String? ?? '';
      if (!await isBankSyncAllowed(bankName)) {
        debugPrint('[CloudSync] Skipping incoming realtime transaction for paused/disabled bank: $bankName');
        return;
      }

      final tx = _mapCloudRowToTransaction(record);
      AppTransaction resolvedTx = tx;

      if (tx.reason != null && tx.reason!.trim().isNotEmpty) {
        final hierarchy =
            await DatabaseService.instance.resolveReasonHierarchy(tx.reason!);
        resolvedTx = tx.copyWith(
          reasonId: hierarchy['reasonId'],
          categoryId: hierarchy['categoryId'],
          subcategoryId: hierarchy['subcategoryId'],
        );
      } else if (tx.customReasonText != null &&
          tx.customReasonText!.trim().isNotEmpty) {
        resolvedTx = tx.copyWith(
          clearReasonId: true,
          clearCategoryId: true,
          clearSubcategoryId: true,
        );
      } else {
        // Explicitly unlinked / independent transaction
        resolvedTx = tx.copyWith(
          clearReason: true,
          clearReasonId: true,
          clearCategoryId: true,
          clearSubcategoryId: true,
          clearCustomReason: true,
        );
      }

      await DatabaseService.instance.upsertTransactionFromBackup(
        resolvedTx,
        authoritativeCategory: true,
      );
      onSyncCompleted?.call();
    } catch (e) {
      debugPrint('CloudSyncService._handleIncomingRealtimeTransaction error: $e');
    }
  }

  Future<void> _handleIncomingRealtimeReasonLink(
      PostgresChangePayload payload) async {
    try {
      if (payload.eventType == PostgresChangeEvent.delete) {
        final oldRecord = payload.oldRecord;
        final linkedName = oldRecord['linked_name'] as String?;
        final linkType = oldRecord['link_type'] as String?;
        if (linkedName != null && linkType != null) {
          debugPrint('[CloudSync] Realtime delete received for reason link: $linkedName ($linkType)');
          final db = await DatabaseService.instance.database;
          await db.delete(
            'reason_links',
            where: 'LOWER(linkedName) = ? AND linkType = ?',
            whereArgs: [linkedName.toLowerCase(), linkType],
          );
          onSyncCompleted?.call();
        }
        return;
      }

      final record = payload.newRecord;
      if (record.isEmpty) return;

      final linkedName = record['linked_name'] as String?;
      final linkType = record['link_type'] as String?;
      final reasonName = record['reason_name'] as String?;
      final parentReasonName = record['parent_reason_name'] as String?;

      if (linkedName == null || linkType == null || reasonName == null) return;

      final db = await DatabaseService.instance.database;
      int? resolvedReasonId;

      if (parentReasonName != null && parentReasonName.isNotEmpty) {
        final pMatches = await db.query(
          'reasons',
          where: 'LOWER(name) = ? AND parentId IS NULL',
          whereArgs: [parentReasonName.toLowerCase()],
        );
        if (pMatches.isNotEmpty) {
          final pId = pMatches.first['id'] as int;
          final cMatches = await db.query(
            'reasons',
            where: 'LOWER(name) = ? AND parentId = ?',
            whereArgs: [reasonName.toLowerCase(), pId],
          );
          if (cMatches.isNotEmpty) {
            resolvedReasonId = cMatches.first['id'] as int;
          }
        }
      } else {
        final rMatches = await db.query(
          'reasons',
          where: 'LOWER(name) = ? AND parentId IS NULL',
          whereArgs: [reasonName.toLowerCase()],
        );
        if (rMatches.isNotEmpty) {
          resolvedReasonId = rMatches.first['id'] as int;
        }
      }

      if (resolvedReasonId != null) {
        final existingLinks = await db.query(
          'reason_links',
          where: 'LOWER(linkedName) = ? AND linkType = ?',
          whereArgs: [linkedName.toLowerCase(), linkType],
        );

        if (existingLinks.isEmpty) {
          await db.insert('reason_links', {
            'linkedName': linkedName,
            'reasonId': resolvedReasonId,
            'linkType': linkType,
          });
        } else {
          final existingId = existingLinks.first['id'] as int;
          await db.update(
            'reason_links',
            {'reasonId': resolvedReasonId},
            where: 'id = ?',
            whereArgs: [existingId],
          );
        }
        onSyncCompleted?.call();
      }
    } catch (e) {
      debugPrint('CloudSyncService._handleIncomingRealtimeReasonLink error: $e');
    }
  }

  Future<void> _handleIncomingRealtimeSplit(
      PostgresChangePayload payload) async {
    try {
      final record = payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
      final txId = record['transaction_id'] as String?;
      if (txId == null || txId.isEmpty) return;

      final client = _supabase;
      final user = AuthService.instance.currentUser;
      if (client == null || user == null) return;

      // Query all current cloud splits for this transaction to maintain atomic consistency
      final List<dynamic> remoteSplits = await client
          .from('cloud_transaction_splits')
          .select()
          .eq('user_id', user.id)
          .eq('transaction_id', txId)
          .order('split_index', ascending: true);

      final db = await DatabaseService.instance.database;

      if (remoteSplits.isEmpty) {
        await db.delete(
          'transaction_splits',
          where: 'transactionId = ?',
          whereArgs: [txId],
        );
        onSyncCompleted?.call();
        return;
      }

      // Pre-fetch reasons to resolve local IDs
      final allReasons = await DatabaseService.instance.getReasons();
      final Map<String, AppReason> topLevelReasons = {
        for (final r in allReasons.where((r) => r.parentId == null))
          r.name.toLowerCase(): r
      };

      final List<TransactionSplit> localSplits = [];
      for (final raw in remoteSplits) {
        if (raw is! Map<String, dynamic>) continue;
        final amount = (raw['amount'] as num?)?.toDouble() ?? 0.0;
        final reasonName = raw['reason_name'] as String?;
        final parentReasonName = raw['parent_reason_name'] as String?;
        final categoryName = raw['category_name'] as String?;
        final customReasonText = raw['custom_reason_text'] as String?;
        final note = raw['note'] as String?;

        int? resolvedReasonId;
        int? resolvedCategoryId;
        int? resolvedSubcategoryId;

        if (reasonName != null && reasonName.isNotEmpty) {
          if (parentReasonName != null && parentReasonName.isNotEmpty) {
            final parent = topLevelReasons[parentReasonName.toLowerCase()];
            if (parent != null && parent.id != null) {
              resolvedCategoryId = parent.id;
              final childMatches = allReasons.where(
                (r) => r.parentId == parent.id && r.name.toLowerCase() == reasonName.toLowerCase(),
              );
              if (childMatches.isNotEmpty) {
                resolvedReasonId = childMatches.first.id;
                resolvedSubcategoryId = childMatches.first.id;
              }
            }
          } else {
            final top = topLevelReasons[reasonName.toLowerCase()];
            if (top != null) {
              resolvedReasonId = top.id;
              resolvedCategoryId = top.id;
            }
          }
        }

        if (resolvedCategoryId == null && categoryName != null && categoryName.isNotEmpty) {
          final cat = topLevelReasons[categoryName.toLowerCase()];
          if (cat != null) {
            resolvedCategoryId = cat.id;
          }
        }

        localSplits.add(TransactionSplit(
          transactionId: txId,
          amount: amount,
          reasonId: resolvedReasonId,
          reasonName: reasonName,
          categoryId: resolvedCategoryId,
          subcategoryId: resolvedSubcategoryId,
          customReasonText: customReasonText,
          note: note,
        ));
      }

      // Atomically replace local splits in SQLite
      await db.transaction((txn) async {
        await txn.delete(
          'transaction_splits',
          where: 'transactionId = ?',
          whereArgs: [txId],
        );
        for (final s in localSplits) {
          await txn.insert('transaction_splits', s.toMap());
        }
        await txn.update(
          'transactions',
          {'reason': 'Split'},
          where: 'id = ?',
          whereArgs: [txId],
        );
      });

      onSyncCompleted?.call();
    } catch (e) {
      debugPrint('CloudSyncService._handleIncomingRealtimeSplit error: $e');
    }
  }

  // ─── Push Transactions Immediately ────────────────────────────────────────

  /// Pushes newly ingested local transactions directly to Supabase without waiting.
  /// Transactions from paused or sync-disabled banks are strictly skipped.
  Future<void> syncTransactionsImmediately(List<AppTransaction> transactions) async {
    final enabled = await isSyncEnabled();
    final user = AuthService.instance.currentUser;
    final client = _supabase;
    if (!enabled || user == null || client == null || transactions.isEmpty) return;

    try {
      final allowedTransactions = <AppTransaction>[];
      for (final tx in transactions) {
        if (await isBankSyncAllowed(tx.bankName)) {
          allowedTransactions.add(tx);
        }
      }
      if (allowedTransactions.isEmpty) return;

      // Chunk in batches of 100 to prevent oversized HTTP payloads on bulk ingestion
      const chunkSize = 100;
      for (int i = 0; i < allowedTransactions.length; i += chunkSize) {
        final end = (i + chunkSize > allowedTransactions.length)
            ? allowedTransactions.length
            : i + chunkSize;
        final chunk = allowedTransactions.sublist(i, end);
        final rows = chunk.map((t) => _mapTransactionToCloudRow(t, user.id)).toList();
        await client.from('cloud_transactions').upsert(rows);
      }
      statusNotifier.value = CloudSyncStatus.success;
      final current = progressNotifier.value;
      if (current.deviceTotal > 0) {
        final newCloud = (current.cloudCount + allowedTransactions.length).clamp(0, current.deviceTotal);
        final newPending = (current.deviceTotal - newCloud).clamp(0, current.deviceTotal);
        progressNotifier.value = current.copyWith(
          cloudCount: newCloud,
          pendingCount: newPending,
        );
      }
    } catch (e) {
      debugPrint('CloudSyncService.syncTransactionsImmediately error (will retry in syncAll): $e');
      final err = e.toString().toLowerCase();
      if (err.contains('socket') ||
          err.contains('host') ||
          err.contains('network') ||
          err.contains('clientexception') ||
          err.contains('handshake') ||
          err.contains('connection refused')) {
        statusNotifier.value = CloudSyncStatus.offline;
      }
    }
  }

  /// Deletes a transaction directly from Supabase cloud_transactions immediately.
  Future<void> deleteTransactionImmediately(String txId) async {
    final enabled = await isSyncEnabled();
    final user = AuthService.instance.currentUser;
    final client = _supabase;
    if (!enabled || user == null || client == null) return;

    try {
      await client
          .from('cloud_transactions')
          .delete()
          .eq('id', txId)
          .eq('user_id', user.id);
      await client
          .from('cloud_transaction_splits')
          .delete()
          .eq('transaction_id', txId)
          .eq('user_id', user.id);
      debugPrint('[CloudSync] Successfully deleted transaction $txId and its splits from cloud');
    } catch (e) {
      debugPrint('[CloudSync] deleteTransactionImmediately error: $e');
    }
  }

  /// Pushes split allocations for a transaction immediately to Supabase.
  Future<void> syncSplitsImmediately(
      String transactionId, List<TransactionSplit> splits) async {
    final enabled = await isSyncEnabled();
    final user = AuthService.instance.currentUser;
    final client = _supabase;
    if (!enabled || user == null || client == null) return;

    try {
      // First delete existing splits for this transaction in the cloud
      await client
          .from('cloud_transaction_splits')
          .delete()
          .eq('user_id', user.id)
          .eq('transaction_id', transactionId);

      if (splits.isEmpty) {
        debugPrint('[CloudSync] Cleared splits in cloud for tx: $transactionId');
        return;
      }

      final allReasons = await DatabaseService.instance.getReasons();
      final reasonMap = {for (final r in allReasons) if (r.id != null) r.id!: r};

      final List<Map<String, dynamic>> rows = [];
      for (int i = 0; i < splits.length; i++) {
        final split = splits[i];
        String? reasonName = split.reasonName;
        String? parentReasonName;
        String? categoryName;

        if (split.reasonId != null && reasonMap.containsKey(split.reasonId)) {
          final r = reasonMap[split.reasonId]!;
          reasonName = r.name;
          if (r.parentId != null && reasonMap.containsKey(r.parentId)) {
            parentReasonName = reasonMap[r.parentId]!.name;
          }
        }
        if (split.categoryId != null && reasonMap.containsKey(split.categoryId)) {
          categoryName = reasonMap[split.categoryId]!.name;
        }

        rows.add({
          'user_id': user.id,
          'transaction_id': transactionId,
          'split_index': i,
          'amount': split.amount,
          'reason_name': reasonName,
          'parent_reason_name': parentReasonName,
          'category_name': categoryName,
          'custom_reason_text': split.customReasonText,
          'note': split.note,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      if (rows.isNotEmpty) {
        await client.from('cloud_transaction_splits').upsert(rows);
        debugPrint('[CloudSync] Pushed ${rows.length} splits for tx: $transactionId');
      }
    } catch (e) {
      debugPrint('CloudSyncService.syncSplitsImmediately error: $e');
    }
  }

  /// Pushes a contact auto-categorization rule immediately to Supabase.
  Future<void> syncReasonLinkImmediately(
      AppReasonLink link, bool isDeleted) async {
    final enabled = await isSyncEnabled();
    final user = AuthService.instance.currentUser;
    final client = _supabase;
    if (!enabled || user == null || client == null) return;

    try {
      if (isDeleted) {
        await client
            .from('cloud_reason_links')
            .delete()
            .eq('user_id', user.id)
            .eq('linked_name', link.linkedName)
            .eq('link_type', link.linkType);
        debugPrint('[CloudSync] Deleted reason link from cloud: ${link.linkedName} (${link.linkType})');
        return;
      }

      final reasons = await DatabaseService.instance.getReasons();
      final reason = reasons.where((r) => r.id == link.reasonId).firstOrNull;
      if (reason == null) return;

      final parentReason = reason.parentId != null
          ? reasons.where((r) => r.id == reason.parentId).firstOrNull
          : null;

      final row = {
        'user_id': user.id,
        'linked_name': link.linkedName,
        'link_type': link.linkType,
        'reason_name': reason.name,
        'parent_reason_name': parentReason?.name,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await client.from('cloud_reason_links').upsert(row);
      debugPrint('[CloudSync] Pushed reason link to cloud: ${link.linkedName} -> ${reason.name}');
    } catch (e) {
      debugPrint('CloudSyncService.syncReasonLinkImmediately error: $e');
    }
  }

  // ─── Full Two-Way Synchronization ─────────────────────────────────────────

  /// Executes a full bidirectional sync across transactions, categories, wallets,
  /// saving goals, and loans.
  Future<void> syncAll() async {
    final enabled = await isSyncEnabled();
    final user = AuthService.instance.currentUser;
    final client = _supabase;
    if (!enabled || user == null || client == null) return;

    if (statusNotifier.value == CloudSyncStatus.syncing) return;
    statusNotifier.value = CloudSyncStatus.syncing;
    errorNotifier.value = null;

    try {
      await SyncNotificationService.show(
        title: 'Cloud Sync',
        message: 'Synchronizing transactions…',
        isIndeterminate: true,
      );

      // 1. Push Local Categories to Cloud (with parent_name)
      await _syncCategoriesUp(client, user.id);

      // 2. Push Local Linked Users / Contact Rules (reason_links)
      await _syncReasonLinksUp(client, user.id);

      // 3. Push Local Wallets to Cloud
      await _syncWalletsUp(client, user.id);

      // 4. Push Local Transactions to Cloud (Batched in chunks of 100)
      await _syncTransactionsUp(client, user.id);

      // 5. Push Transaction Splits (Multi-Category Itemization)
      await _syncSplitsUp(client, user.id);

      // 6. Push Saving Goals & Loans
      await _syncSavingGoalsUp(client, user.id);
      await _syncLoansUp(client, user.id);

      // 7. Pull Remote Changes from Cloud (Categories, Links, Wallets, Transactions, Splits)
      await _pullRemoteChanges(client, user.id);

      // 7. Record successful sync timestamp
      final now = DateTime.now();
      lastSyncedNotifier.value = now;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncedKey, now.toIso8601String());

      await refreshProgressMetrics();

      if (_failedUploadBatch.isNotEmpty) {
        statusNotifier.value = CloudSyncStatus.error;
        errorNotifier.value = _lastBatchError ??
            '${_failedUploadBatch.length} transactions failed to upload';
      } else {
        statusNotifier.value = CloudSyncStatus.success;
      }
      onSyncCompleted?.call();
    } catch (e) {
      debugPrint('CloudSyncService.syncAll failed: $e');
      _lastBatchError = _formatCleanErrorMessage(e);
      errorNotifier.value = _lastBatchError;
      final err = e.toString().toLowerCase();
      final isOfflineErr = err.contains('socket') ||
          err.contains('host') ||
          err.contains('network') ||
          err.contains('clientexception') ||
          err.contains('handshake') ||
          err.contains('connection refused');
      statusNotifier.value =
          isOfflineErr ? CloudSyncStatus.offline : CloudSyncStatus.error;
      await refreshProgressMetrics();
    } finally {
      await SyncNotificationService.dismiss();
    }
  }

  Future<void> _syncCategoriesUp(SupabaseClient client, String userId) async {
    final reasons = await DatabaseService.instance.getReasons();
    if (reasons.isEmpty) return;

    final Map<int, String> idToName = {
      for (final r in reasons)
        if (r.id != null) r.id!: r.name
    };

    final rows = reasons.map((r) {
      final parentName = r.parentId != null ? idToName[r.parentId] : null;
      return {
        'id': r.id ?? 0,
        'user_id': userId,
        'name': r.name,
        'parent_id': r.parentId,
        'parent_name': parentName,
        'icon': r.icon,
        'color': r.color,
        'is_system': r.isSystem,
        'is_special': r.isSpecial,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
    }).toList();

    await client.from('cloud_categories').upsert(rows);
  }

  Future<void> _syncReasonLinksUp(SupabaseClient client, String userId) async {
    final links = await DatabaseService.instance.getReasonLinks();
    if (links.isEmpty) return;

    final reasons = await DatabaseService.instance.getReasons();
    final Map<int, AppReason> reasonMap = {
      for (final r in reasons)
        if (r.id != null) r.id!: r
    };

    final List<Map<String, dynamic>> rows = [];
    for (final l in links) {
      final reason = reasonMap[l.reasonId];
      if (reason == null) continue;

      final parentReason =
          reason.parentId != null ? reasonMap[reason.parentId] : null;
      rows.add({
        'user_id': userId,
        'linked_name': l.linkedName,
        'link_type': l.linkType,
        'reason_name': reason.name,
        'parent_reason_name': parentReason?.name,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    if (rows.isNotEmpty) {
      await client.from('cloud_reason_links').upsert(rows);
    }
  }

  Future<void> _syncWalletsUp(SupabaseClient client, String userId) async {
    final senders = await DatabaseService.instance.getSenders();
    if (senders.isEmpty) return;

    final rows = senders.map((s) => {
      'user_id': userId,
      'sender_name': s.senderName,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).toList();

    await client.from('cloud_wallets').upsert(rows);
  }

  Future<void> _syncTransactionsUp(SupabaseClient client, String userId) async {
    // 1. Synchronize local deletions to the cloud
    final deletedIds = await DatabaseService.instance.getDeletedTransactionIds();
    if (deletedIds.isNotEmpty) {
      const deleteChunkSize = 100;
      for (int i = 0; i < deletedIds.length; i += deleteChunkSize) {
        final chunk = deletedIds.sublist(
          i,
          (i + deleteChunkSize > deletedIds.length) ? deletedIds.length : i + deleteChunkSize,
        );
        try {
          await client
              .from('cloud_transactions')
              .delete()
              .eq('user_id', userId)
              .inFilter('id', chunk);
        } catch (e) {
          debugPrint('CloudSync error deleting remote transactions: $e');
        }
      }
    }

    // 2. Push existing transactions up
    final transactions = await DatabaseService.instance.getTransactions();
    if (transactions.isEmpty) return;

    final pausedBanks = await DatabaseService.instance.getPausedBanks();
    final disabledBanks = await getDisabledSyncBanks();
    final purgedDevices = await getPurgedDeviceFingerprints();

    final allowedTransactions = transactions.where((t) {
      final isPaused = pausedBanks.any((b) => !b.contains(':') && BankSenders.isSameBank(b, t.bankName));
      final isDisabled = disabledBanks.any((b) => BankSenders.isSameBank(b, t.bankName));
      if (isPaused || isDisabled) return false;

      // Filter out transactions belonging to devices purged by the user to prevent zombie re-upload
      if (t.originDeviceId != null && purgedDevices.contains(t.originDeviceId)) {
        return false;
      }

      // Suppress re-upload of unmodified remote replicas (only upload locally-ingested or user-edited transactions)
      if (t.isRemoteSync &&
          (t.customReasonText == null || t.customReasonText!.isEmpty) &&
          (t.note == null || t.note!.isEmpty)) {
        return false;
      }

      return true;
    }).toList();

    if (allowedTransactions.isEmpty) return;

    // Fetch IDs already present in the cloud to compute the incremental delta
    final cloudIdSet = await _getCloudTransactionIdSet(client, userId);

    // Delta: Only upload transactions that are NOT in the cloud,
    // or were locally customized by the user.
    final deltaToUpload = allowedTransactions.where((t) {
      if (t.id == null || t.id!.isEmpty) return false;
      if (!cloudIdSet.contains(t.id)) return true;
      final hasUserEdit = (t.note != null && t.note!.isNotEmpty) ||
          (t.customReasonText != null && t.customReasonText!.isNotEmpty);
      return hasUserEdit;
    }).toList();

    _failedUploadBatch.clear();
    _lastBatchError = null;

    if (deltaToUpload.isEmpty) {
      debugPrint('[CloudSync] All ${allowedTransactions.length} transactions already in cloud. Zero delta to upload.');
      return;
    }

    // Chunk transactions in batches of 100 for reliable HTTP transmission
    const chunkSize = 100;
    int uploadedCount = 0;

    for (int i = 0; i < deltaToUpload.length; i += chunkSize) {
      final end = (i + chunkSize > deltaToUpload.length)
          ? deltaToUpload.length
          : i + chunkSize;
      final chunk = deltaToUpload.sublist(i, end);
      try {
        final rows = chunk.map((t) => _mapTransactionToCloudRow(t, userId)).toList();
        await client.from('cloud_transactions').upsert(rows);
        uploadedCount += chunk.length;
        _updateProgressDuringSync(
          deviceTotal: transactions.length,
          uploadedCount: uploadedCount,
          totalToUpload: deltaToUpload.length,
        );
        await SyncNotificationService.show(
          title: 'Cloud Sync',
          message: 'Uploading new transactions ($end / ${deltaToUpload.length})…',
          progress: end,
          max: deltaToUpload.length,
          isIndeterminate: false,
        );
      } catch (e) {
        debugPrint('CloudSync: chunk upload failed for ${chunk.length} items: $e');
        _failedUploadBatch.addAll(chunk);
        _lastBatchError = _formatCleanErrorMessage(e);
      }
    }
  }

  /// Paginates through Supabase to retrieve all existing transaction IDs for this user.
  Future<Set<String>> _getCloudTransactionIdSet(SupabaseClient client, String userId) async {
    final cloudIdSet = <String>{};
    int offset = 0;
    const pageSize = 1000;
    bool hasMore = true;

    while (hasMore) {
      final List<dynamic> response = await client
          .from('cloud_transactions')
          .select('id')
          .eq('user_id', userId)
          .range(offset, offset + pageSize - 1);

      for (final row in response) {
        if (row is Map<String, dynamic>) {
          final id = row['id'] as String?;
          if (id != null && id.isNotEmpty) {
            cloudIdSet.add(id);
          }
        }
      }

      if (response.length < pageSize) {
        hasMore = false;
      } else {
        offset += pageSize;
      }
    }
    return cloudIdSet;
  }

  void _updateProgressDuringSync({
    required int deviceTotal,
    required int uploadedCount,
    required int totalToUpload,
  }) {
    final current = progressNotifier.value;
    progressNotifier.value = current.copyWith(
      deviceTotal: deviceTotal,
      isSyncing: true,
      currentBatchUploaded: uploadedCount,
      totalToUpload: totalToUpload,
      failedCount: _failedUploadBatch.length,
      failureMessage: _lastBatchError,
    );
  }

  /// Refreshes the three key metrics:
  /// 1. How many SMS/transactions on this device (enabled for cloud sync)
  /// 2. How many of them are in the cloud
  /// 3. How much is left (pending upload)
  Future<CloudSyncProgress> refreshProgressMetrics() async {
    final localTxs = await DatabaseService.instance.getTransactions();
    final pausedBanks = await DatabaseService.instance.getPausedBanks();
    final disabledBanks = await getDisabledSyncBanks();

    // Transactions eligible for cloud sync: strictly excludes paused and user-disabled banks
    final eligibleLocalTxs = localTxs.where((tx) {
      final isPaused = pausedBanks.any((b) => !b.contains(':') && BankSenders.isSameBank(b, tx.bankName));
      final isDisabled = disabledBanks.any((b) => BankSenders.isSameBank(b, tx.bankName));
      return !isPaused && !isDisabled;
    }).toList();

    final deviceTotal = eligibleLocalTxs.length;
    final disabledCount = localTxs.length - eligibleLocalTxs.length;

    int cloudCount = 0;
    final user = AuthService.instance.currentUser;
    final client = _supabase;

    if (user != null && client != null) {
      try {
        final cloudIdSet = await _getCloudTransactionIdSet(client, user.id);
        cloudCount = eligibleLocalTxs.where((tx) => cloudIdSet.contains(tx.id)).length;
      } catch (e) {
        debugPrint('CloudSyncService.refreshProgressMetrics error: $e');
        cloudCount = progressNotifier.value.cloudCount;
      }
    }

    final pendingCount = (deviceTotal - cloudCount).clamp(0, deviceTotal);
    final progress = CloudSyncProgress(
      deviceTotal: deviceTotal,
      cloudCount: cloudCount,
      pendingCount: pendingCount,
      failedCount: _failedUploadBatch.length,
      disabledBankCount: disabledCount,
      failureMessage: _lastBatchError,
      isSyncing: statusNotifier.value == CloudSyncStatus.syncing,
    );

    progressNotifier.value = progress;
    return progress;
  }

  /// Retries uploading specifically the collected failed transactions in batches.
  Future<bool> retryFailedUploads() async {
    final enabled = await isSyncEnabled();
    final user = AuthService.instance.currentUser;
    final client = _supabase;
    if (!enabled || user == null || client == null || _failedUploadBatch.isEmpty) {
      return false;
    }

    statusNotifier.value = CloudSyncStatus.syncing;
    final toRetry = List<AppTransaction>.from(_failedUploadBatch);
    final remainingFailed = <AppTransaction>[];

    try {
      await SyncNotificationService.show(
        title: 'Cloud Sync',
        message: 'Retrying ${toRetry.length} failed transactions…',
        isIndeterminate: true,
      );

      const chunkSize = 100;
      for (int i = 0; i < toRetry.length; i += chunkSize) {
        final end = (i + chunkSize > toRetry.length) ? toRetry.length : i + chunkSize;
        final chunk = toRetry.sublist(i, end);
        try {
          final rows = chunk.map((t) => _mapTransactionToCloudRow(t, user.id)).toList();
          await client.from('cloud_transactions').upsert(rows);
        } catch (e) {
          debugPrint('CloudSync retry chunk error: $e');
          remainingFailed.addAll(chunk);
          _lastBatchError = _formatCleanErrorMessage(e);
        }
      }

      _failedUploadBatch
        ..clear()
        ..addAll(remainingFailed);

      await refreshProgressMetrics();

      if (remainingFailed.isEmpty) {
        _lastBatchError = null;
        statusNotifier.value = CloudSyncStatus.success;
        onSyncCompleted?.call();
        return true;
      } else {
        statusNotifier.value = CloudSyncStatus.error;
        errorNotifier.value = _lastBatchError;
        return false;
      }
    } catch (e) {
      _lastBatchError = _formatCleanErrorMessage(e);
      statusNotifier.value = CloudSyncStatus.error;
      errorNotifier.value = _lastBatchError;
      return false;
    } finally {
      await SyncNotificationService.dismiss();
    }
  }

  String _formatCleanErrorMessage(Object e) {
    final str = e.toString().toLowerCase();
    if (str.contains('socket') ||
        str.contains('network') ||
        str.contains('host') ||
        str.contains('connection refused') ||
        str.contains('handshake') ||
        str.contains('clientexception')) {
      return 'Network connection dropped during batch upload. Tap Retry to resubmit.';
    }
    if (str.contains('timeout')) {
      return 'Server response timed out. Tap Retry to resend pending batches.';
    }
    if (str.contains('jwt') || str.contains('auth') || str.contains('unauthorized')) {
      return 'Authentication session expired. Please sign in again.';
    }
    return 'Batch upload interrupted. Tap Retry to continue syncing.';
  }

  Future<void> _syncSavingGoalsUp(SupabaseClient client, String userId) async {
    final goals = await DatabaseService.instance.getSavingGoals();
    if (goals.isEmpty) return;

    final rows = goals.map((g) => {
      'id': g.id,
      'user_id': userId,
      'title': g.title,
      'target_amount': g.targetAmount,
      'saved_amount': g.savedAmount,
      'color_theme': g.colorTheme,
      'target_date': g.targetDate,
      'priority': g.priority,
      'status': g.status,
      'allocation_mode': g.allocationMode,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).toList();

    await client.from('cloud_saving_goals').upsert(rows);
  }

  Future<void> _syncLoansUp(SupabaseClient client, String userId) async {
    final loans = await DatabaseService.instance.getLoanRecords();
    if (loans.isEmpty) return;

    final List<Map<String, dynamic>> rows = [];
    for (final l in loans) {
      if (l.id == null) continue;
      final payments = await DatabaseService.instance.getPaymentsForLoan(l.id!);
      rows.add({
        'id': l.id.toString(),
        'user_id': userId,
        'person_name': l.personName,
        'loan_type': l.loanType,
        'principal_amount': l.principalAmount,
        'paid_amount': l.paidAmount,
        'loan_date': l.loanDate.toUtc().toIso8601String(),
        'due_date': l.dueDate.toUtc().toIso8601String(),
        'status': l.status,
        'note': l.note,
        'contract_number': l.contractNumber,
        'payments': payments.map((p) => p.toMap()).toList(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    if (rows.isNotEmpty) {
      await client.from('cloud_loans').upsert(rows);
    }
  }

  Future<void> _syncSplitsUp(SupabaseClient client, String userId) async {
    final splits = await DatabaseService.instance.getAllTransactionSplits();
    if (splits.isEmpty) return;

    final allReasons = await DatabaseService.instance.getReasons();
    final reasonMap = {for (final r in allReasons) if (r.id != null) r.id!: r};

    final Map<String, List<TransactionSplit>> groupedSplits = {};
    for (final s in splits) {
      groupedSplits.putIfAbsent(s.transactionId, () => []).add(s);
    }

    final List<Map<String, dynamic>> rows = [];
    for (final entry in groupedSplits.entries) {
      final txId = entry.key;
      final txSplits = entry.value;
      for (int i = 0; i < txSplits.length; i++) {
        final split = txSplits[i];
        String? reasonName = split.reasonName;
        String? parentReasonName;
        String? categoryName;

        if (split.reasonId != null && reasonMap.containsKey(split.reasonId)) {
          final r = reasonMap[split.reasonId]!;
          reasonName = r.name;
          if (r.parentId != null && reasonMap.containsKey(r.parentId)) {
            parentReasonName = reasonMap[r.parentId]!.name;
          }
        }
        if (split.categoryId != null && reasonMap.containsKey(split.categoryId)) {
          categoryName = reasonMap[split.categoryId]!.name;
        }

        rows.add({
          'user_id': userId,
          'transaction_id': txId,
          'split_index': i,
          'amount': split.amount,
          'reason_name': reasonName,
          'parent_reason_name': parentReasonName,
          'category_name': categoryName,
          'custom_reason_text': split.customReasonText,
          'note': split.note,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    }

    if (rows.isNotEmpty) {
      const chunkSize = 100;
      for (int i = 0; i < rows.length; i += chunkSize) {
        final end = (i + chunkSize > rows.length) ? rows.length : i + chunkSize;
        await client.from('cloud_transaction_splits').upsert(rows.sublist(i, end));
      }
    }
  }

  Future<void> _pullRemoteChanges(SupabaseClient client, String userId) async {
    final lastSynced = lastSyncedNotifier.value;

    // 1. Pull Wallets / Senders
    try {
      final List<dynamic> remoteWallets =
          await client.from('cloud_wallets').select().eq('user_id', userId);
      final existingSenders = await DatabaseService.instance.getSenders();
      for (final raw in remoteWallets) {
        if (raw is Map<String, dynamic>) {
          final senderName = raw['sender_name'] as String?;
          if (senderName != null && senderName.isNotEmpty) {
            final already = existingSenders.any(
              (s) => s.senderName.toLowerCase() == senderName.toLowerCase(),
            );
            if (!already) {
              await DatabaseService.instance.insertSender(AppSender(senderName: senderName));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('CloudSyncService pull wallets note: $e');
    }

    // 2. Pull Categories (Two-Pass Natural Key Hierarchy)
    try {
      final List<dynamic> remoteCategories =
          await client.from('cloud_categories').select().eq('user_id', userId);
      final db = await DatabaseService.instance.database;

      for (final raw in remoteCategories) {
        if (raw is Map<String, dynamic>) {
          final parentName = raw['parent_name'] as String?;
          if (parentName == null || parentName.isEmpty) {
            final name = raw['name'] as String;
            final existing = await db.query(
              'reasons',
              where: 'LOWER(name) = ? AND parentId IS NULL',
              whereArgs: [name.toLowerCase()],
            );

            if (existing.isEmpty) {
              await db.insert('reasons', {
                'name': name,
                'parentId': null,
                'icon': raw['icon'],
                'color': raw['color'],
                'isSystem': raw['is_system'] == true ? 1 : 0,
                'isSpecial': raw['is_special'] == true ? 1 : 0,
              });
            }
          }
        }
      }

      for (final raw in remoteCategories) {
        if (raw is Map<String, dynamic>) {
          final parentName = raw['parent_name'] as String?;
          if (parentName != null && parentName.isNotEmpty) {
            final name = raw['name'] as String;
            final parentMatches = await db.query(
              'reasons',
              where: 'LOWER(name) = ? AND parentId IS NULL',
              whereArgs: [parentName.toLowerCase()],
            );

            if (parentMatches.isNotEmpty) {
              final parentId = parentMatches.first['id'] as int;
              final childMatches = await db.query(
                'reasons',
                where: 'LOWER(name) = ? AND parentId = ?',
                whereArgs: [name.toLowerCase(), parentId],
              );

              if (childMatches.isEmpty) {
                await db.insert('reasons', {
                  'name': name,
                  'parentId': parentId,
                  'icon': raw['icon'],
                  'color': raw['color'],
                  'isSystem': raw['is_system'] == true ? 1 : 0,
                  'isSpecial': raw['is_special'] == true ? 1 : 0,
                });
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('CloudSyncService pull categories note: $e');
    }

    // 3. Pull Reason Links (Contact Rules)
    try {
      final List<dynamic> remoteLinks =
          await client.from('cloud_reason_links').select().eq('user_id', userId);
      final db = await DatabaseService.instance.database;

      for (final raw in remoteLinks) {
        if (raw is Map<String, dynamic>) {
          final linkedName = raw['linked_name'] as String?;
          final linkType = raw['link_type'] as String?;
          final reasonName = raw['reason_name'] as String?;
          final parentReasonName = raw['parent_reason_name'] as String?;

          if (linkedName != null && linkType != null && reasonName != null) {
            int? resolvedReasonId;
            if (parentReasonName != null && parentReasonName.isNotEmpty) {
              final pMatches = await db.query(
                'reasons',
                where: 'LOWER(name) = ? AND parentId IS NULL',
                whereArgs: [parentReasonName.toLowerCase()],
              );
              if (pMatches.isNotEmpty) {
                final pId = pMatches.first['id'] as int;
                final cMatches = await db.query(
                  'reasons',
                  where: 'LOWER(name) = ? AND parentId = ?',
                  whereArgs: [reasonName.toLowerCase(), pId],
                );
                if (cMatches.isNotEmpty) {
                  resolvedReasonId = cMatches.first['id'] as int;
                }
              }
            } else {
              final rMatches = await db.query(
                'reasons',
                where: 'LOWER(name) = ? AND parentId IS NULL',
                whereArgs: [reasonName.toLowerCase()],
              );
              if (rMatches.isNotEmpty) {
                resolvedReasonId = rMatches.first['id'] as int;
              }
            }

            if (resolvedReasonId != null) {
              final existingLinks = await db.query(
                'reason_links',
                where: 'LOWER(linkedName) = ? AND linkType = ?',
                whereArgs: [linkedName.toLowerCase(), linkType],
              );

              if (existingLinks.isEmpty) {
                await DatabaseService.instance.insertReasonLink(
                  AppReasonLink(
                    linkedName: linkedName,
                    reasonId: resolvedReasonId,
                    linkType: linkType,
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('CloudSyncService pull reason links note: $e');
    }

    // 4. Pull Transactions (Paginated in batches of 1000)
    final currentFingerprint = DeviceSecurityService.instance.deviceFingerprint;
    int offset = 0;
    const pageSize = 1000;
    bool hasMore = true;
    final deletedIds =
        (await DatabaseService.instance.getDeletedTransactionIds()).toSet();
    final pausedBanks = await DatabaseService.instance.getPausedBanks();
    final disabledBanks = await getDisabledSyncBanks();
    final existingLocalIds =
        (await DatabaseService.instance.getTransactions()).map((t) => t.id).whereType<String>().toSet();

    // Pre-cache reason hierarchies in memory to eliminate thousands of disk queries during batch pull
    final allReasons = await DatabaseService.instance.getReasons();
    final hierarchyCache = <String, Map<String, int?>>{};
    for (final r in allReasons) {
      if (r.name.isNotEmpty && r.id != null) {
        if (r.isSubcategory) {
          hierarchyCache[r.name.toLowerCase()] = {
            'reasonId': r.id,
            'categoryId': r.parentId,
            'subcategoryId': r.id,
          };
        } else {
          hierarchyCache[r.name.toLowerCase()] = {
            'reasonId': r.id,
            'categoryId': r.id,
            'subcategoryId': null,
          };
        }
      }
    }

    while (hasMore) {
      var query = client.from('cloud_transactions').select().eq('user_id', userId);
      if (lastSynced != null) {
        query = query.gt('updated_at', lastSynced.toUtc().toIso8601String());
      }

      final List<dynamic> remoteRows =
          await query.range(offset, offset + pageSize - 1);

      final List<AppTransaction> toUpsert = [];

      for (final raw in remoteRows) {
        if (raw is Map<String, dynamic>) {
          final txId = raw['id'] as String?;
          final bankName = raw['bank_name'] as String? ?? '';
          final deviceFp = raw['device_fingerprint'] as String?;

          // Respect paused banks and user-disabled banks when pulling remote transactions
          final isPaused = pausedBanks.any((b) => !b.contains(':') && BankSenders.isSameBank(b, bankName));
          final isDisabled = disabledBanks.any((b) => BankSenders.isSameBank(b, bankName));
          if (isPaused || isDisabled) {
            continue;
          }

          if (txId != null && deletedIds.contains(txId)) {
            // Local user deleted this transaction! Do not restore it.
            // Also ensure it is deleted in the cloud:
            unawaited(client
                .from('cloud_transactions')
                .delete()
                .eq('id', txId)
                .eq('user_id', userId));
            continue;
          }

          // If this transaction was uploaded by this device and is already present locally in SQLite,
          // skip redundant re-upsert to prevent database lockups and stuttering.
          if (txId != null && existingLocalIds.contains(txId) && deviceFp == currentFingerprint) {
            continue;
          }

          final tx = _mapCloudRowToTransaction(raw);
          AppTransaction resolvedTx = tx;

          if (tx.reason != null && tx.reason!.trim().isNotEmpty) {
            final key = tx.reason!.trim().toLowerCase();
            final hierarchy = hierarchyCache[key] ??
                await DatabaseService.instance.resolveReasonHierarchy(tx.reason!);
            resolvedTx = tx.copyWith(
              reasonId: hierarchy['reasonId'],
              categoryId: hierarchy['categoryId'],
              subcategoryId: hierarchy['subcategoryId'],
            );
          } else if (tx.customReasonText != null && tx.customReasonText!.trim().isNotEmpty) {
            resolvedTx = tx.copyWith(
              clearReasonId: true,
              clearCategoryId: true,
              clearSubcategoryId: true,
            );
          } else {
            // Intentionally unlinked / independent transaction
            resolvedTx = tx.copyWith(
              clearReason: true,
              clearReasonId: true,
              clearCategoryId: true,
              clearSubcategoryId: true,
              clearCustomReason: true,
            );
          }

          toUpsert.add(resolvedTx);
        }
      }

      // Batch upsert to prevent database lock contention
      if (toUpsert.isNotEmpty) {
        await DatabaseService.instance.batchUpsertTransactionsFromBackup(
          toUpsert,
          authoritativeCategory: true,
        );
      }

      if (remoteRows.length < pageSize) {
        hasMore = false;
      } else {
        offset += pageSize;
      }
    }

    // 5. Pull Transaction Splits
    try {
      final List<dynamic> remoteSplits =
          await client.from('cloud_transaction_splits').select().eq('user_id', userId);

      if (remoteSplits.isNotEmpty) {
        final db = await DatabaseService.instance.database;
        final allReasons = await DatabaseService.instance.getReasons();
        final Map<String, AppReason> topLevelReasons = {
          for (final r in allReasons.where((r) => r.parentId == null))
            r.name.toLowerCase(): r
        };

        // Group by transaction_id
        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (final raw in remoteSplits) {
          if (raw is Map<String, dynamic>) {
            final txId = raw['transaction_id'] as String?;
            if (txId != null && txId.isNotEmpty) {
              grouped.putIfAbsent(txId, () => []).add(raw);
            }
          }
        }

        for (final entry in grouped.entries) {
          final txId = entry.key;
          final splitRows = entry.value;
          splitRows.sort((a, b) =>
              (a['split_index'] as int? ?? 0).compareTo(b['split_index'] as int? ?? 0));

          final List<TransactionSplit> localSplits = [];
          for (final raw in splitRows) {
            final amount = (raw['amount'] as num?)?.toDouble() ?? 0.0;
            final reasonName = raw['reason_name'] as String?;
            final parentReasonName = raw['parent_reason_name'] as String?;
            final categoryName = raw['category_name'] as String?;
            final customReasonText = raw['custom_reason_text'] as String?;
            final note = raw['note'] as String?;

            int? resolvedReasonId;
            int? resolvedCategoryId;
            int? resolvedSubcategoryId;

            if (reasonName != null && reasonName.isNotEmpty) {
              if (parentReasonName != null && parentReasonName.isNotEmpty) {
                final parent = topLevelReasons[parentReasonName.toLowerCase()];
                if (parent != null && parent.id != null) {
                  resolvedCategoryId = parent.id;
                  final childMatches = allReasons.where(
                    (r) => r.parentId == parent.id && r.name.toLowerCase() == reasonName.toLowerCase(),
                  );
                  if (childMatches.isNotEmpty) {
                    resolvedReasonId = childMatches.first.id;
                    resolvedSubcategoryId = childMatches.first.id;
                  }
                }
              } else {
                final top = topLevelReasons[reasonName.toLowerCase()];
                if (top != null) {
                  resolvedReasonId = top.id;
                  resolvedCategoryId = top.id;
                }
              }
            }

            if (resolvedCategoryId == null && categoryName != null && categoryName.isNotEmpty) {
              final cat = topLevelReasons[categoryName.toLowerCase()];
              if (cat != null) {
                resolvedCategoryId = cat.id;
              }
            }

            localSplits.add(TransactionSplit(
              transactionId: txId,
              amount: amount,
              reasonId: resolvedReasonId,
              reasonName: reasonName,
              categoryId: resolvedCategoryId,
              subcategoryId: resolvedSubcategoryId,
              customReasonText: customReasonText,
              note: note,
            ));
          }

          await db.transaction((txn) async {
            await txn.delete(
              'transaction_splits',
              where: 'transactionId = ?',
              whereArgs: [txId],
            );
            for (final s in localSplits) {
              await txn.insert('transaction_splits', s.toMap());
            }
          });
        }
      }
    } catch (e) {
      debugPrint('CloudSyncService pull splits note: $e');
    }
  }

  // ─── Cloud Backup Management & Batch Deletion ──────────────────────────────

  /// Retrieves list of physical devices that have uploaded transactions to this user's cloud account,
  /// including transaction count per device.
  Future<List<Map<String, dynamic>>> getCloudContributingDevices() async {
    final user = AuthService.instance.currentUser;
    final client = _supabase;
    if (user == null || client == null) return [];

    try {
      final Map<String, Map<String, dynamic>> deviceMap = {};
      int offset = 0;
      const pageSize = 1000;
      bool hasMore = true;

      while (hasMore) {
        final List<dynamic> response = await client
            .from('cloud_transactions')
            .select('device_fingerprint, device_model')
            .eq('user_id', user.id)
            .range(offset, offset + pageSize - 1);

        for (final row in response) {
          if (row is Map<String, dynamic>) {
            final fp = (row['device_fingerprint'] as String?) ?? 'unspecified_device';
            final model = (row['device_model'] as String?) ?? 'Unspecified Device';
            if (!deviceMap.containsKey(fp)) {
              deviceMap[fp] = {
                'device_fingerprint': fp,
                'device_model': model,
                'count': 0,
              };
            }
            deviceMap[fp]!['count'] = (deviceMap[fp]!['count'] as int) + 1;
          }
        }

        if (response.length < pageSize) {
          hasMore = false;
        } else {
          offset += pageSize;
        }
      }

      return deviceMap.values.toList();
    } catch (e) {
      debugPrint('CloudSyncService.getCloudContributingDevices error: $e');
      return [];
    }
  }

  /// Retrieves list of banks that have uploaded transactions in this user's cloud account,
  /// including transaction count per bank.
  Future<List<Map<String, dynamic>>> getCloudBankSummary() async {
    final user = AuthService.instance.currentUser;
    final client = _supabase;
    if (user == null || client == null) return [];

    try {
      final Map<String, int> bankCountMap = {};
      int offset = 0;
      const pageSize = 1000;
      bool hasMore = true;

      while (hasMore) {
        final List<dynamic> response = await client
            .from('cloud_transactions')
            .select('bank_name')
            .eq('user_id', user.id)
            .range(offset, offset + pageSize - 1);

        for (final row in response) {
          if (row is Map<String, dynamic>) {
            final bank = (row['bank_name'] as String?) ?? 'Unknown Bank';
            bankCountMap[bank] = (bankCountMap[bank] ?? 0) + 1;
          }
        }

        if (response.length < pageSize) {
          hasMore = false;
        } else {
          offset += pageSize;
        }
      }

      return bankCountMap.entries
          .map((e) => {'bank_name': e.key, 'count': e.value})
          .toList();
    } catch (e) {
      debugPrint('CloudSyncService.getCloudBankSummary error: $e');
      return [];
    }
  }

  /// Batch deletes all cloud transactions uploaded by a specific physical device.
  /// Suppresses local SQLite deletion so other devices keep their local data intact.
  Future<bool> deleteCloudTransactionsByDevice(String deviceFingerprint) async {
    final user = AuthService.instance.currentUser;
    final client = _supabase;
    if (user == null || client == null) return false;

    _isBatchPurging = true;
    try {
      // Remember purged device so local phone never re-uploads its transactions
      final prefs = await SharedPreferences.getInstance();
      final currentPurged = (prefs.getStringList('cloud_purged_device_fingerprints') ?? []).toSet();
      currentPurged.add(deviceFingerprint);
      await prefs.setStringList('cloud_purged_device_fingerprints', currentPurged.toList());

      if (deviceFingerprint == 'unspecified_device') {
        await client
            .from('cloud_transactions')
            .delete()
            .eq('user_id', user.id)
            .isFilter('device_fingerprint', null);
      } else {
        await client
            .from('cloud_transactions')
            .delete()
            .eq('user_id', user.id)
            .eq('device_fingerprint', deviceFingerprint);
      }
      return true;
    } catch (e) {
      debugPrint('CloudSyncService.deleteCloudTransactionsByDevice error: $e');
      return false;
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        _isBatchPurging = false;
      });
    }
  }

  /// Retrieves list of device fingerprints purged from the cloud to prevent zombie re-uploads.
  Future<Set<String>> getPurgedDeviceFingerprints() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('cloud_purged_device_fingerprints') ?? [];
    return list.toSet();
  }

  /// Batch deletes all cloud transactions for a specific bank.
  /// Suppresses local SQLite deletion so local phone data is preserved.
  Future<bool> deleteCloudTransactionsByBank(String bankName) async {
    final user = AuthService.instance.currentUser;
    final client = _supabase;
    if (user == null || client == null) return false;

    _isBatchPurging = true;
    try {
      final summary = await getCloudBankSummary();
      final matchingNames = summary
          .map((s) => s['bank_name'] as String? ?? '')
          .where((remoteName) => BankSenders.isSameBank(remoteName, bankName))
          .toSet();
      matchingNames.add(bankName);

      for (final name in matchingNames) {
        await client
            .from('cloud_transactions')
            .delete()
            .eq('user_id', user.id)
            .eq('bank_name', name);
      }
      return true;
    } catch (e) {
      debugPrint('CloudSyncService.deleteCloudTransactionsByBank error: $e');
      return false;
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        _isBatchPurging = false;
      });
    }
  }

  // ─── Serialization Mappers ────────────────────────────────────────────────

  Map<String, dynamic> _mapTransactionToCloudRow(AppTransaction tx, String userId) {
    return {
      'id': tx.id ?? AppTransaction.generateManualId('SHIBRE_CASH'),
      'user_id': userId,
      'bank_name': tx.bankName,
      'amount': tx.amount,
      'type': tx.type,
      'date': tx.date.toUtc().toIso8601String(),
      'counterparty': tx.counterparty,
      'total_balance': tx.totalBalance,
      'category': tx.sourceTag,
      'note': tx.note,
      'reason': tx.reason,
      'reason_id': tx.reasonId,
      'category_id': tx.categoryId,
      'subcategory_id': tx.subcategoryId,
      'custom_reason_text': tx.customReasonText,
      'is_bookmarked': tx.isBookmarked,
      'linked_transaction_id': tx.linkedTransactionId,
      'raw_message': tx.rawMessage,
      'sim_slot': tx.simSlot,
      'device_fingerprint': tx.originDeviceId ?? DeviceSecurityService.instance.deviceFingerprint,
      'device_model': tx.originDeviceModel ?? DeviceSecurityService.instance.deviceModel,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  AppTransaction _mapCloudRowToTransaction(Map<String, dynamic> row) {
    return AppTransaction(
      id: row['id'] as String?,
      name: row['bank_name'] as String,
      amount: (row['amount'] as num).toDouble(),
      type: row['type'] as String,
      date: DateTime.parse(row['date'] as String).toLocal(),
      sender: row['counterparty'] as String?,
      category: row['category'] as String? ?? 'Auto',
      rawMessage: row['raw_message'] as String? ?? '',
      isAutoDetected: (row['category'] as String? ?? 'Auto') == 'Auto',
      totalBalance: (row['total_balance'] as num?)?.toDouble() ?? 0.0,
      reason: row['reason'] as String?,
      reasonId: row['reason_id'] as int?,
      categoryId: row['category_id'] as int?,
      subcategoryId: row['subcategory_id'] as int?,
      customReasonText: row['custom_reason_text'] as String?,
      note: row['note'] as String?,
      linkedTransactionId: row['linked_transaction_id'] as String?,
      isBookmarked: row['is_bookmarked'] == true || row['is_bookmarked'] == 1,
      simSlot: row['sim_slot'] as int? ?? 0,
      originDeviceId: row['device_fingerprint'] as String?,
      originDeviceModel: row['device_model'] as String?,
      isRemoteSync: true,
    );
  }
}
