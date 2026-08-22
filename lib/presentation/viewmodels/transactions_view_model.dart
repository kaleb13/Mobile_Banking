import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../models/transaction.dart';
import '../../models/sender.dart';
import '../../models/reason.dart';
import '../../models/transaction_attachment.dart';
import '../../models/scan_window_option.dart';
import '../../models/scan_progress_status.dart';
import '../../services/telebirr_parser.dart';
import '../../services/sms_service.dart';
import '../../services/sms_batch_parser.dart';
import '../../models/app_notification.dart';

/// TransactionsViewModel — owns all transaction, sender, and reason state.
///
/// This is the core ViewModel for the transaction domain. It handles CRUD
/// operations, reason assignment, bookmarks, notes, attachments, and
/// sender/reason management.
///
/// All data access goes through TransactionRepository.
class TransactionsViewModel extends ChangeNotifier {
  final TransactionRepository _repository;

  TransactionsViewModel({required TransactionRepository repository})
      : _repository = repository;

  // ── State ─────────────────────────────────────────────────────────────────

  List<AppTransaction> _transactions = [];
  List<AppSender> _senders = [];
  List<AppReason> _reasons = [];
  List<AppReasonLink> _reasonLinks = [];
  Set<String> _pausedBanks = {};

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Guard: prevents re-scanning SMS on every loadAll() call.
  /// Only auto-scans once per app session when the DB is empty.
  bool _hasScannedOnce = false;

  // ── Transactions Access ───────────────────────────────────────────────────

  /// Filtered list excluding paused banks — what the UI sees.
  List<AppTransaction> get transactions => _pausedBanks.isEmpty
      ? _transactions
      : _transactions
          .where((tx) => !_pausedBanks
              .any((b) => b.toUpperCase() == tx.name.toUpperCase()))
          .toList();

  /// Raw unfiltered list — used internally for loan lookups etc.
  List<AppTransaction> get allTransactionsUnfiltered => _transactions;

  int get transactionCount => _transactions.length;

  // ── Senders Access ────────────────────────────────────────────────────────

  UnmodifiableListView<AppSender> get senders =>
      UnmodifiableListView(_senders);

  List<String> get bankSenderNames =>
      _senders.map((s) => s.senderName).toList();

  List<String> get uniqueSenders {
    final sSet = <String>{};
    for (final tx in _transactions) {
      if (tx.sender.isNotEmpty) sSet.add(tx.sender);
    }
    return sSet.toList()..sort();
  }

  List<String> get uniqueBanks {
    final bSet = <String>{};
    for (final tx in _transactions) {
      if (tx.name.isNotEmpty) bSet.add(tx.name);
    }
    return bSet.toList()..sort();
  }

  List<String> get allTrackedPersonNames {
    final names = <String>{};
    for (final tx in _transactions) {
      if (tx.name.trim().isNotEmpty) names.add(tx.name.trim());
    }
    return names.toList()..sort();
  }

  /// Returns all transactions matching a sender name.
  List<AppTransaction> transactionsForSender(String senderName) {
    final sNameUp = senderName.trim().toUpperCase();
    return _transactions.where((t) {
      final txName = t.name.trim().toUpperCase();
      return txName == sNameUp || t.sender.trim().toUpperCase() == sNameUp;
    }).toList();
  }

  // ── Reasons Access ────────────────────────────────────────────────────────

  UnmodifiableListView<AppReason> get reasons =>
      UnmodifiableListView(_reasons);

  List<AppReason> get specialReasons => _reasons
      .where((r) =>
          r.isSpecial ||
          ['bounce', 'cash', 'internal transfer', 'loan']
              .contains(r.name.toLowerCase()))
      .toList();

  UnmodifiableListView<AppReasonLink> get reasonLinks =>
      UnmodifiableListView(_reasonLinks);

  List<AppReasonLink> linksForReason(int reasonId) =>
      _reasonLinks.where((l) => l.reasonId == reasonId).toList();

  bool isTrackingPaused(String bankName) =>
      _pausedBanks.any((b) => b.toUpperCase() == bankName.toUpperCase());

  List<AppSender> get activeSenders =>
      _senders.where((s) => !isTrackingPaused(s.senderName)).toList();

  List<AppSender> get pausedSenders =>
      _senders.where((s) => isTrackingPaused(s.senderName)).toList();

  List<String> get orderedWalletNames {
    return [
      ...activeSenders.map((s) => s.senderName),
      'Cash Wallet',
      ...pausedSenders.map((s) => s.senderName),
    ];
  }

  double balanceForSender(String senderName, {double cashBalance = 0.0}) {
    if (senderName.trim().toUpperCase() == 'CASH WALLET') {
      return cashBalance;
    }
    final txs = transactionsForSender(senderName);
    final withBal = txs.where((t) => t.totalBalance > 0);
    if (withBal.isNotEmpty) {
      return withBal.first.totalBalance;
    }
    return 0.0;
  }

  double getLatestBalanceForBank(String bankName) => balanceForSender(bankName);

  double get totalBalance {
    double sum = 0.0;
    for (final sender in activeSenders) {
      sum += balanceForSender(sender.senderName);
    }
    return sum;
  }

  double get telebirrSavingBalance {
    final telebirrTxs = transactionsForSender('Telebirr');
    for (final tx in telebirrTxs) {
      if (TelebirrParser.isSavingsMessage(tx.rawMessage)) {
        final bal = TelebirrParser.extractSavingBalance(tx.rawMessage);
        if (bal != null && bal > 0) return bal;
      }
    }
    return 0.0;
  }

  int txCountForSender(String senderName, {int cashTxCount = 0}) {
    if (senderName.trim().toUpperCase() == 'CASH WALLET') {
      int count = 0;
      for (var tx in _transactions) {
        if (tx.reason?.toLowerCase() == 'cash' ||
            tx.customReasonText?.toLowerCase() == 'cash' ||
            tx.resolvedReason?.toLowerCase() == 'cash') {
          count++;
        }
      }
      return count + cashTxCount;
    }
    return transactionsForSender(senderName).length;
  }

  List<AppTransaction> get activeBankCashWithdrawals {
    return _transactions.where((t) {
      if (t.type != 'expense') return false;
      final reasonStr = (t.reason ?? t.customReasonText ?? t.resolvedReason ?? '')
          .toLowerCase()
          .trim();
      return reasonStr == 'cash';
    }).toList();
  }

  // ── Paused Banks ──────────────────────────────────────────────────────────

  Set<String> get pausedBanks => Set.unmodifiable(_pausedBanks);

  Future<void> setPausedBanks(Set<String> banks) async {
    _pausedBanks = banks;
    await _repository.setPausedBanks(banks);
    notifyListeners();
  }

  Future<void> pauseTracking(String bankName) async {
    _pausedBanks = {..._pausedBanks, bankName};
    await _repository.setPausedBanks(_pausedBanks);
    await _repository.deleteUncategorizedTransactionsForBank(bankName);
    await _repository.deleteUncategorizedNotificationsForBank(bankName);
    _transactions = await _repository.getTransactions();
    notifyListeners();
  }

  Future<void> resumeTracking(String bankName) async {
    _pausedBanks = _pausedBanks
        .where((b) => b.toUpperCase() != bankName.toUpperCase())
        .toSet();
    await _repository.setPausedBanks(_pausedBanks);
    _transactions = await _repository.getTransactions();
    notifyListeners();
  }

  // ── Data Loading & SMS Scanning ──────────────────────────────────────────

  StreamSubscription? _smsSubscription;

  /// Optional callback invoked after live SMS events reload data.
  /// Wired by main.dart to trigger NotificationsViewModel.loadNotifications().
  VoidCallback? onSmsEventReceived;

  /// Optional callback for inserting unrecognized notification batches.
  /// Wired by main.dart to delegate to NotificationsViewModel.
  Future<void> Function(List<AppNotification> notifications)?
      insertNotificationsBatch;

  void initEventListener() {
    _smsSubscription?.cancel();
    const channel = EventChannel('com.shibre/sms_events');
    _smsSubscription = channel.receiveBroadcastStream().listen(
      (_) {
        loadAll();
        onSmsEventReceived?.call();
      },
      onError: (err) => debugPrint('SMS event channel error: $err'),
    );
  }

  @override
  void dispose() {
    _smsSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadData() => loadAll();

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.getTransactions(),
        _repository.getSenders(),
        _repository.getReasons(),
        _repository.getReasonLinks(),
        _repository.getPausedBanks(),
      ]);
      _transactions = results[0] as List<AppTransaction>;
      _senders = results[1] as List<AppSender>;
      _reasons = results[2] as List<AppReason>;
      _reasonLinks = results[3] as List<AppReasonLink>;
      _pausedBanks = results[4] as Set<String>;

      // Auto-backfill in-memory and DB reasons for any records where reasonId is set but reason name is missing
      for (int i = 0; i < _transactions.length; i++) {
        final tx = _transactions[i];
        if (tx.reasonId != null && (tx.reason == null || tx.reason!.isEmpty)) {
          final matched = _reasons.where((r) => r.id == tx.reasonId).firstOrNull;
          if (matched != null) {
            final isSub = matched.isSubcategory;
            final isTop = matched.isTopLevelCategory;
            _transactions[i] = tx.copyWith(
              reason: matched.name,
              categoryId: tx.categoryId ?? (isSub ? matched.parentId : (isTop ? matched.id : null)),
              subcategoryId: tx.subcategoryId ?? (isSub ? matched.id : null),
            );
            _repository.updateTransaction(_transactions[i]);
          }
        }
      }

      // Seed default bank senders if database is completely empty on fresh install
      if (_senders.isEmpty) {
        _senders = [
          AppSender(id: '1', senderName: 'Telebirr'),
          AppSender(id: '2', senderName: 'CBE'),
          AppSender(id: '3', senderName: 'CBE Birr'),
          AppSender(id: '4', senderName: 'Ahadu Bank'),
          AppSender(id: '5', senderName: 'BOA'),
          AppSender(id: '6', senderName: 'Dashen Bank'),
        ];
        for (var s in _senders) {
          await _repository.insertSender(s);
        }
      }

      // Auto-scan SMS on startup when DB is empty and we haven't scanned yet
      // this session. This handles first boot when no data exists.
      if (_transactions.isEmpty && !_hasScannedOnce) {
        final hasPermission = await Permission.sms.status.isGranted;
        if (hasPermission) {
          _hasScannedOnce = true;
          // Release the loading lock before scanning so the UI can render
          _isLoading = false;
          notifyListeners();
          await scanSms();
          return; // scanSms() calls loadAll() at the end, so we're done
        }
      }
    } catch (e) {
      debugPrint('Error loading transaction data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// High-speed SMS batch scanner that parses all messages in a background isolate
  Future<int> scanSms({
    ScanWindowOption scanWindowOption = ScanWindowOption.thirtyDays,
    void Function(ScanProgressStatus)? onProgress,
    DateTime? since,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      onProgress?.call(const ScanProgressStatus(
        progress: 0.05,
        stage: 'Connecting to secure SMS inbox…',
      ));

      if (_senders.isEmpty) {
        _senders = [
          AppSender(id: '1', senderName: 'Telebirr'),
          AppSender(id: '2', senderName: 'CBE'),
          AppSender(id: '3', senderName: 'CBE Birr'),
          AppSender(id: '4', senderName: 'Ahadu Bank'),
          AppSender(id: '5', senderName: 'BOA'),
          AppSender(id: '6', senderName: 'Dashen Bank'),
        ];
        for (var s in _senders) {
          await _repository.insertSender(s);
        }
      }

      final anchorDate = since ?? scanWindowOption.anchorDate;
      final cutoff = anchorDate.subtract(const Duration(minutes: 1));

      final customSenderNames = _senders.map((s) => s.senderName).toList();
      final rawMessages = await SmsService().getBankMessagesFast(
        since: cutoff,
        customSenders: customSenderNames,
      );

      if (rawMessages.isEmpty) {
        onProgress?.call(const ScanProgressStatus(
          progress: 1.0,
          stage: 'No banking messages found in window',
          scannedBanks: [],
          isComplete: true,
        ));
        return 0;
      }

      onProgress?.call(const ScanProgressStatus(
        progress: 0.35,
        stage: 'Reading & analyzing bank records…',
      ));

      final autoRules = await _repository.getAutoReasonRules();
      final initialBalances = <String, double>{};
      for (final s in _senders) {
        initialBalances[s.senderName] = balanceForSender(s.senderName);
      }

      onProgress?.call(const ScanProgressStatus(
        progress: 0.55,
        stage: 'Parsing transactions in background worker…',
      ));

      final parseResult = await SmsBatchParser.parseInIsolate(BatchParseParams(
        rawMessages: rawMessages,
        pausedBanks: _pausedBanks.toList(),
        customSenders: _senders,
        autoReasonRules: autoRules,
        initialBankBalances: initialBalances,
      ));

      final Map<String, int> bankCounts = {};
      final Map<String, double> bankLatestBalances = {};
      for (final tx in parseResult.transactions) {
        bankCounts[tx.name] = (bankCounts[tx.name] ?? 0) + 1;
        if (tx.totalBalance > 0) {
          bankLatestBalances[tx.name] = tx.totalBalance;
        }
      }
      final List<ScannedBankProgress> scannedBankList = bankCounts.entries.map((e) {
        return ScannedBankProgress(
          bankName: e.key,
          transactionCount: e.value,
          latestBalance: bankLatestBalances[e.key],
        );
      }).toList();

      onProgress?.call(ScanProgressStatus(
        progress: 0.80,
        stage: 'Storing verified transactions in database…',
        scannedBanks: scannedBankList,
      ));

      final insertedCount = await _repository
          .insertTransactionsBatch(parseResult.transactions);

      if (parseResult.unrecognizedNotifications.isNotEmpty) {
        await insertNotificationsBatch?.call(
            parseResult.unrecognizedNotifications);
      }

      await loadAll();

      onProgress?.call(ScanProgressStatus(
        progress: 1.0,
        stage: 'Calculated financial balance & tier',
        scannedBanks: scannedBankList,
        isComplete: true,
      ));

      return insertedCount;
    } catch (e) {
      debugPrint('Error during scanSms: $e');
      onProgress?.call(const ScanProgressStatus(
        progress: 1.0,
        stage: 'Calculated financial balance & tier',
        isComplete: true,
      ));
      return 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reloads recent data by scanning SMS for the specified lookback days.
  Future<void> refreshData({int? lastDays}) async {
    final days = lastDays ?? 30;
    await scanSms(
      since: DateTime.now().subtract(Duration(days: days)),
    );
  }

  /// Smart refresh: re-scans the SMS inbox using the active scan window.
  Future<void> smartRefresh({
    ScanWindowOption scanWindowOption = ScanWindowOption.thirtyDays,
    void Function(ScanProgressStatus)? onProgress,
  }) async {
    await scanSms(scanWindowOption: scanWindowOption, onProgress: onProgress);
  }

  /// Full reset: clears transactions and re-scans all available history.
  Future<void> fullReset({
    void Function(ScanProgressStatus)? onProgress,
  }) async {
    await _repository.deleteAllTransactions();
    await scanSms(scanWindowOption: ScanWindowOption.allTime, onProgress: onProgress);
  }

  // ── Transaction CRUD ──────────────────────────────────────────────────────

  Future<void> addTransaction(AppTransaction transaction) async {
    await _repository.insertTransaction(transaction);
    _transactions.insert(0, transaction);
    notifyListeners();
  }

  Future<void> addTransactionsBatch(List<AppTransaction> transactions) async {
    await _repository.insertTransactionsBatch(transactions);
    _transactions.insertAll(0, transactions);
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    await _repository.deleteTransaction(id);
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // ── Transaction Reason Updates ────────────────────────────────────────────

  Future<void> updateTransactionReason(
    String id, {
    String? reason,
    String? customReasonText,
    int? reasonId,
    int? categoryId,
    int? subcategoryId,
    String? note,
  }) async {
    final idx = _transactions.indexWhere((t) => t.id == id);
    if (idx != -1) {
      String? resolvedReason = reason;
      if ((resolvedReason == null || resolvedReason.isEmpty) && reasonId != null) {
        resolvedReason = _reasons.where((r) => r.id == reasonId).firstOrNull?.name;
      }
      final updated = _transactions[idx].copyWith(
        reasonId: reasonId,
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        note: note,
        reason: resolvedReason,
        customReasonText: customReasonText ?? (reasonId == null ? resolvedReason : null),
      );
      _transactions[idx] = updated;
      notifyListeners();
      await _repository.updateTransaction(updated);
    }
  }

  Future<void> unlinkSingleTransaction(String id) async {
    await _repository.unlinkSingleTransaction(id);
    final idx = _transactions.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _transactions[idx] = _transactions[idx].copyWith(
        clearReasonId: true,
        clearCategoryId: true,
        clearSubcategoryId: true,
        clearCustomReason: true,
      );
      notifyListeners();
    }
  }

  Future<void> unlinkAllTransactionsForContact({
    required String contactName,
    int? reasonId,
  }) async {
    await _repository.unlinkAllTransactionsForContact(
      contactName: contactName,
      reasonId: reasonId,
    );
    // Reload to get fresh state
    _transactions = await _repository.getTransactions();
    notifyListeners();
  }

  // ── Bookmarks & Notes ─────────────────────────────────────────────────────

  Future<void> toggleTransactionBookmark(String transactionId) async {
    final idx = _transactions.indexWhere((t) => t.id == transactionId);
    if (idx != -1) {
      final current = _transactions[idx].isBookmarked;
      _transactions[idx] = _transactions[idx].copyWith(
        isBookmarked: !current,
      );
      notifyListeners();
      await _repository.setTransactionBookmarked(transactionId, !current);
    }
  }

  Future<void> updateTransactionNote(
      String transactionId, String? note) async {
    final idx = _transactions.indexWhere((t) => t.id == transactionId);
    if (idx != -1) {
      _transactions[idx] = _transactions[idx].copyWith(
        note: note,
        clearNote: note == null,
      );
      notifyListeners();
      await _repository.updateTransaction(_transactions[idx]);
    }
  }

  Future<void> linkAsInternalTransfer(String txId1, String txId2) async {
    final idx1 = _transactions.indexWhere((t) => t.id == txId1);
    final idx2 = _transactions.indexWhere((t) => t.id == txId2);

    if (idx1 == -1 || idx2 == -1) return;

    final tx1 = _transactions[idx1];
    final tx2 = _transactions[idx2];

    final internalTransferReason = _reasons.cast<AppReason?>().firstWhere(
          (r) => r?.name.toLowerCase() == 'internal transfer',
          orElse: () => null,
        );

    final reasonId = internalTransferReason?.id;
    final reasonName = internalTransferReason?.name ?? 'Internal Transfer';

    final newTx1 = tx1.copyWith(
      reasonId: reasonId,
      reason: reasonName,
      linkedTransactionId: tx2.id,
    );

    final newTx2 = tx2.copyWith(
      reasonId: reasonId,
      reason: reasonName,
      linkedTransactionId: tx1.id,
    );

    await _repository.updateTransaction(newTx1);
    await _repository.updateTransaction(newTx2);

    _transactions[idx1] = newTx1;
    _transactions[idx2] = newTx2;

    notifyListeners();
  }

  Future<void> unlinkInternalTransfer(String txId) async {
    final idx = _transactions.indexWhere((t) => t.id == txId);
    if (idx == -1) return;

    final tx = _transactions[idx];
    final linkedId = tx.linkedTransactionId;

    final unlinkedTx = tx.copyWith(clearLinkedTransactionId: true);
    await _repository.updateTransaction(unlinkedTx);
    _transactions[idx] = unlinkedTx;

    if (linkedId != null) {
      final idx2 = _transactions.indexWhere((t) => t.id == linkedId);
      if (idx2 != -1) {
        final unlinkedTx2 =
            _transactions[idx2].copyWith(clearLinkedTransactionId: true);
        await _repository.updateTransaction(unlinkedTx2);
        _transactions[idx2] = unlinkedTx2;
      }
    }

    notifyListeners();
  }

  // ── Attachments ───────────────────────────────────────────────────────────

  Future<List<TransactionAttachment>> loadAttachmentsForTransaction(
      String transactionId) async {
    return _repository.getAttachmentsForTransaction(transactionId);
  }

  Future<void> addAttachment(
    String transactionId,
    String filePath,
    String fileType, {
    String? fileName,
    int? fileSize,
  }) async {
    final attachment = TransactionAttachment(
      id: '${transactionId}_${DateTime.now().millisecondsSinceEpoch}',
      transactionId: transactionId,
      filePath: filePath,
      fileType: fileType,
      fileName: fileName,
      fileSize: fileSize,
      createdAt: DateTime.now().toIso8601String(),
    );

    await _repository.insertAttachment(attachment);
    final idx = _transactions.indexWhere((t) => t.id == transactionId);
    if (idx != -1) {
      final oldTx = _transactions[idx];
      final newAttachments = [...oldTx.attachments, attachment];
      _transactions[idx] = oldTx.copyWith(attachments: newAttachments);
      notifyListeners();
    }
  }

  Future<void> deleteAttachment(
      String transactionId, String attachmentId) async {
    await _repository.deleteAttachment(attachmentId);
    final idx = _transactions.indexWhere((t) => t.id == transactionId);
    if (idx != -1) {
      final oldTx = _transactions[idx];
      final newAttachments =
          oldTx.attachments.where((a) => a.id != attachmentId).toList();
      _transactions[idx] = oldTx.copyWith(attachments: newAttachments);
      notifyListeners();
    }
  }

  // ── Sender CRUD ───────────────────────────────────────────────────────────

  Future<void> addSender(AppSender sender) async {
    final id = await _repository.insertSender(sender);
    _senders.add(AppSender(
      id: id.toString(),
      senderName: sender.senderName,
      accountNumber: sender.accountNumber,
      pin: sender.pin,
    ));
    notifyListeners();
  }

  Future<void> updateSender(AppSender sender) async {
    await _repository.updateSender(sender);
    final idx = _senders.indexWhere((s) => s.id == sender.id);
    if (idx != -1) _senders[idx] = sender;
    notifyListeners();
  }

  Future<void> deleteSender(String id) async {
    await _repository.deleteSender(id);
    _senders.removeWhere((s) => s.id.toString() == id);
    notifyListeners();
  }

  // ── Reason CRUD ───────────────────────────────────────────────────────────

  Future<void> addReason(AppReason reason) async {
    final id = await _repository.insertReason(reason);
    _reasons.add(AppReason(
      id: id,
      name: reason.name,
      icon: reason.icon,
      color: reason.color,
    ));
    notifyListeners();
  }

  Future<void> updateReason(AppReason reason) async {
    await _repository.updateReason(reason);
    final idx = _reasons.indexWhere((r) => r.id == reason.id);
    if (idx != -1) _reasons[idx] = reason;
    notifyListeners();
  }

  Future<void> deleteReason(int id) async {
    await _repository.deleteReason(id);
    _reasons.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  Future<void> addReasonLink(AppReasonLink link) async {
    final id = await _repository.insertReasonLink(link);
    _reasonLinks.add(AppReasonLink(
      id: id,
      reasonId: link.reasonId,
      linkedName: link.linkedName,
      linkType: link.linkType,
    ));
    notifyListeners();
  }

  Future<void> addReasonLinkScoped({
    required int reasonId,
    required String linkedName,
    required String linkType,
    LinkScope scope = LinkScope.allTransactions,
    String? currentTransactionId,
  }) async {
    final lowerName = linkedName.toLowerCase();

    // 1. Remove any existing link for exactly this name and type
    final existingLinksToRemove = _reasonLinks
        .where((l) =>
            l.linkedName.toLowerCase() == lowerName && l.linkType == linkType)
        .toList();
    for (var l in existingLinksToRemove) {
      await deleteReasonLink(l.id!);
    }

    // 2. Add the new link
    final id = await _repository.insertReasonLink(AppReasonLink(
        reasonId: reasonId, linkedName: linkedName, linkType: linkType));
    _reasonLinks.add(AppReasonLink(
        id: id,
        reasonId: reasonId,
        linkedName: linkedName,
        linkType: linkType));

    // 3. Resolve the reason object
    final r = _reasons.firstWhere((r) => r.id == reasonId,
        orElse: () => AppReason(name: ''));
    if (r.name.isNotEmpty) {
      final isSub = r.isSubcategory;
      final isTop = r.isTopLevelCategory;
      final catId = isSub ? r.parentId : (isTop ? r.id : null);
      final subId = isSub ? r.id : null;

      if (scope == LinkScope.allTransactions) {
        for (int i = 0; i < _transactions.length; i++) {
          final tx = _transactions[i];
          final expectedLinkType = tx.type == 'income' ? 'sender' : 'receiver';

          if (tx.sender.toLowerCase() == lowerName &&
              expectedLinkType == linkType) {
            final newTx = tx.copyWith(
              reasonId: reasonId,
              reason: r.name,
              categoryId: catId,
              subcategoryId: subId,
              clearCustomReason: true,
            );
            await _repository.updateTransaction(newTx);
            _transactions[i] = newTx;
          }
        }
      } else if (currentTransactionId != null) {
        final idx = _transactions.indexWhere((t) => t.id == currentTransactionId);
        if (idx != -1) {
          final newTx = _transactions[idx].copyWith(
            reasonId: reasonId,
            reason: r.name,
            categoryId: catId,
            subcategoryId: subId,
            clearCustomReason: true,
          );
          await _repository.updateTransaction(newTx);
          _transactions[idx] = newTx;
        }
      }
    }

    notifyListeners();
  }

  Future<void> deleteReasonLink(int id) async {
    await _repository.deleteReasonLink(id);
    _reasonLinks.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  Future<void> unlinkReason({
    required int linkId,
    required String linkedName,
    required String linkType,
    required UnlinkScope scope,
    String? currentTransactionId,
    int? reasonId,
  }) async {
    final lowerName = linkedName.toLowerCase();

    switch (scope) {
      case UnlinkScope.allTransactions:
        await _repository.deleteReasonLink(linkId);
        _reasonLinks.removeWhere((l) => l.id == linkId);

        await _repository.unlinkAllTransactionsForContact(
          contactName: linkedName,
          reasonId: reasonId,
        );

        for (int i = 0; i < _transactions.length; i++) {
          final tx = _transactions[i];
          final expectedLinkType = tx.type == 'income' ? 'sender' : 'receiver';

          if (tx.sender.toLowerCase() == lowerName &&
              expectedLinkType == linkType &&
              (reasonId == null || tx.reasonId == reasonId)) {
            _transactions[i] = tx.copyWith(
              clearReason: true,
              clearReasonId: true,
              clearCategoryId: true,
              clearSubcategoryId: true,
              clearCustomReason: true,
            );
          }
        }
        break;

      case UnlinkScope.thisTransactionOnly:
        if (currentTransactionId != null) {
          final idx = _transactions.indexWhere((t) => t.id == currentTransactionId);
          if (idx != -1) {
            await _repository.unlinkSingleTransaction(currentTransactionId);
            _transactions[idx] = _transactions[idx].copyWith(
              clearReason: true,
              clearReasonId: true,
              clearCategoryId: true,
              clearSubcategoryId: true,
              clearCustomReason: true,
            );
          }
        }
        break;

      case UnlinkScope.futureTransactionsOnly:
        await _repository.deleteReasonLink(linkId);
        _reasonLinks.removeWhere((l) => l.id == linkId);
        break;
    }

    notifyListeners();
  }

  Future<AppReason?> findAutoReason(
      String senderName, String transactionType) {
    return _repository.findAutoReason(senderName, transactionType);
  }

  // ── Category / Subcategory Helpers ──────────────────────────────────────

  /// Top-level user-visible categories (excludes system specials like
  /// bounce, cash, internal transfer, loan).
  List<AppReason> get topLevelCategories => _reasons
      .where((r) =>
          r.parentId == null &&
          !r.isSpecial &&
          !['bounce', 'cash', 'internal transfer', 'loan']
              .contains(r.name.trim().toLowerCase()))
      .toList();

  /// Subcategories for a given parent category, with loan/borrow filtering
  /// under food/drink parents.
  List<AppReason> subcategoriesFor(int categoryId) {
    AppReason? parent;
    for (final r in _reasons) {
      if (r.id == categoryId) {
        parent = r;
        break;
      }
    }
    final parentName = parent?.name.toLowerCase() ?? '';
    return _reasons.where((r) {
      if (r.parentId != categoryId) return false;
      final rName = r.name.toLowerCase();
      if ((parentName.contains('food') || parentName.contains('drink')) &&
          (rName.contains('loan') ||
              rName.contains('borrow') ||
              rName.contains('lend'))) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<AppReason> addTopLevelCategory(String name,
      {String? icon, String? color}) async {
    final reason = AppReason(
      name: name,
      isSystem: false,
      isSpecial: false,
      icon: icon,
      color: color,
    );
    final id = await _repository.insertReason(reason);
    final inserted = AppReason(
      id: id,
      name: name,
      isSystem: false,
      isSpecial: false,
      icon: icon,
      color: color,
    );
    _reasons.add(inserted);
    notifyListeners();
    return inserted;
  }

  Future<AppReason> addSubcategory(int parentId, String name) async {
    final sub = AppReason(
      name: name,
      parentId: parentId,
      isSystem: false,
      isSpecial: false,
    );
    final id = await _repository.insertReason(sub);
    final inserted = AppReason(
      id: id,
      name: name,
      parentId: parentId,
      isSystem: false,
      isSpecial: false,
    );
    _reasons.add(inserted);
    notifyListeners();
    return inserted;
  }

  Future<void> updateCategory(int id, String newName) async {
    final idx = _reasons.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final updated = _reasons[idx].copyWith(name: newName);
    await _repository.updateReason(updated);
    _reasons[idx] = updated;
    notifyListeners();
  }

  Future<void> deleteCategory(int id) async {
    await _repository.deleteReason(id);
    _reasons.removeWhere((r) => r.id == id || r.parentId == id);
    notifyListeners();
  }

  /// Reload reasons and reason links from the database.
  Future<void> loadReasons() async {
    final results = await Future.wait([
      _repository.getReasons(),
      _repository.getReasonLinks(),
    ]);
    _reasons = results[0] as List<AppReason>;
    _reasonLinks = results[1] as List<AppReasonLink>;
    notifyListeners();
  }
}
