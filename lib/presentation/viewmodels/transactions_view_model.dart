import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../models/transaction.dart';
import '../../models/sender.dart';
import '../../models/reason.dart';
import '../../models/bank_account_item.dart';
import '../../models/transaction_attachment.dart';
import '../../models/scan_window_option.dart';
import '../../models/scan_progress_status.dart';
import '../../services/telebirr_parser.dart';
import '../../services/sms_service.dart';
import '../../services/sms_batch_parser.dart';
import '../../services/bank_senders.dart';
import '../../services/database_service.dart';
import '../../models/app_notification.dart';
import '../../models/transaction_split.dart';
import '../../utils/counterparty_matcher.dart';

/// TransactionsViewModel — owns all transaction, sender, and reason state.
///
/// This is the core ViewModel for the transaction domain. It handles CRUD
/// operations, reason assignment, bookmarks, notes, attachments, and
/// sender/reason management.
///
/// All data access goes through TransactionRepository.
class TransactionsViewModel extends ChangeNotifier {
  final TransactionRepository _repository;
  final SettingsRepository? _settingsRepository;

  TransactionsViewModel({
    required TransactionRepository repository,
    SettingsRepository? settingsRepository,
  })  : _repository = repository,
        _settingsRepository = settingsRepository;

  // ── State ─────────────────────────────────────────────────────────────────

  List<AppTransaction> _transactions = [];
  List<AppSender> _senders = [];
  List<AppReason> _reasons = [];
  List<AppReasonLink> _reasonLinks = [];
  Set<String> _pausedBanks = {};
  List<SimCardInfo> _simCards = [];
  Map<String, List<TransactionSplit>> _transactionSplits = {};

  List<SimCardInfo> get simCards => _simCards;
  Map<String, List<TransactionSplit>> get transactionSplits =>
      Map.unmodifiable(_transactionSplits);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Guard: prevents re-scanning SMS on every loadAll() call.
  /// Only auto-scans once per app session when the DB is empty.
  bool _hasScannedOnce = false;

  // ── Indexed Aggregate Cache for O(1) Instant Lookups ─────────────────────
  Map<String, double> _cachedSenderBalances = {};
  Map<String, int> _cachedSenderTxCounts = {};
  Map<String, List<int>> _cachedBankAccounts = {};
  Map<String, Map<int, double>> _cachedAccountBalances = {};
  Map<String, List<AppTransaction>> _cachedBankTransactions = {};
  List<String> _cachedUniqueSenders = [];
  List<String> _cachedUniqueBanks = [];
  List<String> _cachedAllTrackedPersonNames = [];
  List<int> _cachedDetectedSimSlots = [0];
  List<AppSender> _cachedActiveSenders = [];
  List<AppSender> _cachedPausedSenders = [];
  List<AppTransaction> _cachedUnpausedTransactions = [];
  List<AppTransaction> _cachedRecent30DaysTransactions = [];
  double _cachedTotalBalance = 0.0;
  int _cachedCashTxCount = 0;

  // ── Transactions Access ───────────────────────────────────────────────────

  /// Filtered list excluding paused banks and paused accounts — what the UI sees (O(1)).
  List<AppTransaction> get transactions => _cachedUnpausedTransactions;

  /// Pre-filtered slice of the most recent 30 days of transactions (O(1)).
  List<AppTransaction> get recent30DaysTransactions => _cachedRecent30DaysTransactions;

  /// Raw unfiltered list — used internally for loan lookups etc.
  List<AppTransaction> get allTransactionsUnfiltered => _transactions;

  int get transactionCount => _transactions.length;

  // ── Senders Access ────────────────────────────────────────────────────────

  UnmodifiableListView<AppSender> get senders =>
      UnmodifiableListView(_senders);

  List<String> get bankSenderNames =>
      _senders.map((s) => s.senderName).toList();

  List<String> get uniqueSenders => _cachedUniqueSenders;

  List<String> get uniqueBanks => _cachedUniqueBanks;

  List<String> get allTrackedPersonNames => _cachedAllTrackedPersonNames;

  /// Returns all transactions matching a sender name (O(1) map lookup).
  List<AppTransaction> transactionsForSender(String senderName) {
    final canonical = BankSenders.match(senderName) ?? senderName.trim();
    final key = canonical.toUpperCase();
    return _cachedBankTransactions[key] ?? const [];
  }

  /// Returns all distinct accounts / SIM slots detected for a bank (O(1) lookup).
  /// If a bank has no transactions, returns `[0]`.
  List<int> accountsForBank(String bankName) {
    final canonical = BankSenders.match(bankName) ?? bankName.trim();
    final key = canonical.toUpperCase();
    return _cachedBankAccounts[key] ?? const [0];
  }

  /// Returns the latest balance for a specific SIM slot / account of a bank (O(1) lookup).
  double balanceForAccount(String bankName, int simSlot) {
    final canonical = BankSenders.match(bankName) ?? bankName.trim();
    final key = canonical.toUpperCase();
    return _cachedAccountBalances[key]?[simSlot] ?? 0.0;
  }

  /// Returns transactions for a specific SIM slot / account of a bank.
  List<AppTransaction> transactionsForSenderAndAccount(String bankName, int simSlot) {
    return transactionsForSender(bankName).where((t) => t.simSlot == simSlot).toList();
  }

  /// Returns UI-ready account items for the bank detail screen when multiple SIM accounts exist.
  List<BankAccountItem> getBankDetailAccounts(String bankName) {
    final rawAccounts = accountsForBank(bankName);
    if (rawAccounts.length <= 1) return const [];

    final List<BankAccountItem> items = [];
    final double combinedBal = balanceForSender(bankName);
    items.add(
      BankAccountItem(
        simSlot: null,
        label: 'All (${rawAccounts.length} SIMs)',
        balance: combinedBal,
        txCount: transactionsForSender(bankName).length,
        isPaused: isTrackingPaused(bankName),
      ),
    );
    for (final slot in rawAccounts) {
      final double slotBal = balanceForAccount(bankName, slot);
      final slotTxs = transactionsForSenderAndAccount(bankName, slot);
      final bool isPaused = isAccountPaused(bankName, slot);
      final simInfo = _simCards.where((s) => s.simSlot == slot).firstOrNull;
      final String label = (simInfo != null && simInfo.displayName.isNotEmpty)
          ? 'SIM ${slot + 1} (${simInfo.displayName})'
          : 'SIM ${slot + 1}';
      items.add(
        BankAccountItem(
          simSlot: slot,
          label: label,
          balance: slotBal,
          txCount: slotTxs.length,
          isPaused: isPaused,
        ),
      );
    }
    return items;
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

  bool isTrackingPaused(String bankName) {
    if (_pausedBanks.any((b) => !b.contains(':') && BankSenders.isSameBank(b, bankName))) {
      return true;
    }
    final accounts = accountsForBank(bankName);
    if (accounts.isNotEmpty &&
        accounts.every((slot) => _pausedBanks.any((b) {
          if (!b.contains(':')) return false;
          final parts = b.split(':');
          return BankSenders.isSameBank(parts[0], bankName) && parts[1] == '$slot';
        }))) {
      return true;
    }
    return false;
  }

  bool isAccountPaused(String bankName, int simSlot) {
    if (_pausedBanks.any((b) => !b.contains(':') && BankSenders.isSameBank(b, bankName))) {
      return true;
    }
    return _pausedBanks.any((b) {
      if (!b.contains(':')) return false;
      final parts = b.split(':');
      return BankSenders.isSameBank(parts[0], bankName) && parts[1] == '$simSlot';
    });
  }

  Future<void> pauseAccountTracking(String bankName, int simSlot) async {
    final canonical = BankSenders.match(bankName) ?? bankName.trim();
    final key = '$canonical:$simSlot';
    _pausedBanks = {..._pausedBanks, key};
    await _repository.setPausedBanks(_pausedBanks);
    _rebuildAggregateIndices();
    notifyListeners();
  }

  Future<void> resumeAccountTracking(String bankName, int simSlot) async {
    final canonical = BankSenders.match(bankName) ?? bankName.trim();
    _pausedBanks = _pausedBanks.where((b) {
      if (b.contains(':')) {
        final parts = b.split(':');
        final isThisSlot = BankSenders.isSameBank(parts[0], canonical) && parts[1] == '$simSlot';
        return !isThisSlot;
      }
      // If a whole-bank pause existed, remove it so remaining unpaused accounts can function
      return !BankSenders.isSameBank(b, canonical);
    }).toSet();
    await _repository.setPausedBanks(_pausedBanks);
    _rebuildAggregateIndices();
    notifyListeners();
  }

  Future<void> toggleAccountPause(String bankName, int simSlot) async {
    if (isAccountPaused(bankName, simSlot)) {
      await resumeAccountTracking(bankName, simSlot);
    } else {
      await pauseAccountTracking(bankName, simSlot);
    }
  }

  List<AppSender> get activeSenders =>
      UnmodifiableListView(_cachedActiveSenders);

  List<AppSender> get pausedSenders =>
      UnmodifiableListView(_cachedPausedSenders);

  List<String> get orderedWalletNames {
    return [
      ..._cachedActiveSenders.map((s) => s.senderName),
      'Cash Wallet',
      ..._cachedPausedSenders.map((s) => s.senderName),
    ];
  }

  /// Reorders active bank cards and persists the new order across the app.
  Future<void> reorderActiveSenders(int oldIndex, int newIndex) async {
    final active = List<AppSender>.from(_cachedActiveSenders);
    if (oldIndex < 0 || oldIndex >= active.length) return;
    if (newIndex < 0 || newIndex > active.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final movedSender = active.removeAt(oldIndex);
    active.insert(newIndex, movedSender);

    final paused = _cachedPausedSenders;
    _senders = [...active, ...paused];
    _recomputeActiveAndPausedSenders();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'custom_senders_order',
        _senders.map((s) => s.senderName).toList(),
      );
    } catch (_) {}
  }

  Future<void> _applySavedSendersOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList('custom_senders_order');
      if (savedOrder != null && savedOrder.isNotEmpty) {
        final orderMap = <String, int>{};
        for (int i = 0; i < savedOrder.length; i++) {
          orderMap[savedOrder[i].trim().toUpperCase()] = i;
        }
        _senders.sort((a, b) {
          final aKey = a.senderName.trim().toUpperCase();
          final bKey = b.senderName.trim().toUpperCase();
          final aPos = orderMap[aKey] ?? 9999;
          final bPos = orderMap[bKey] ?? 9999;
          if (aPos != bPos) return aPos.compareTo(bPos);
          return _defaultBankComparator(a, b);
        });
      } else {
        _senders.sort(_defaultBankComparator);
      }
    } catch (_) {
      _senders.sort(_defaultBankComparator);
    }
  }

  int _defaultBankComparator(AppSender a, AppSender b) {
    final aName = a.senderName.trim().toUpperCase();
    final bName = b.senderName.trim().toUpperCase();
    if (aName == bName) return 0;

    final aIsTelebirr = aName == 'TELEBIRR';
    final bIsTelebirr = bName == 'TELEBIRR';
    if (aIsTelebirr && !bIsTelebirr) return -1;
    if (!aIsTelebirr && bIsTelebirr) return 1;

    final aIsCbe = aName == 'CBE' || aName.contains('COMMERCIAL');
    final bIsCbe = bName == 'CBE' || bName.contains('COMMERCIAL');
    if (aIsCbe && !bIsCbe) return -1;
    if (!aIsCbe && bIsCbe) return 1;

    final aIsCbeBirr = aName == 'CBE BIRR' || aName == 'CBEBIRR';
    final bIsCbeBirr = bName == 'CBE BIRR' || bName == 'CBEBIRR';
    if (aIsCbeBirr && !bIsCbeBirr) return -1;
    if (!aIsCbeBirr && bIsCbeBirr) return 1;

    // Place based on total balance (higher balance first)
    final balA = balanceForSender(a.senderName);
    final balB = balanceForSender(b.senderName);
    if (balA != balB) {
      return balB.compareTo(balA);
    }

    return 0;
  }

  /// Returns true if the top 3 active unpaused wallets are Telebirr, CBE, and CBE Birr in order.
  bool get hasClassicTopThreeDeck {
    final active = _cachedActiveSenders;
    if (active.length < 3) return false;
    final firstThree =
        active.take(3).map((s) => s.senderName.trim().toUpperCase()).toList();
    final isTelebirr = firstThree[0] == 'TELEBIRR';
    final isCbe =
        firstThree[1] == 'CBE' || firstThree[1].contains('COMMERCIAL');
    final isCbeBirr =
        firstThree[2] == 'CBE BIRR' || firstThree[2] == 'CBEBIRR';
    return isTelebirr && isCbe && isCbeBirr;
  }

  /// Calculates total balance for a sender in O(1) time.
  /// For multi-account banks, sums up the latest balance of each active account.
  double balanceForSender(String senderName, {double cashBalance = 0.0}) {
    if (senderName.trim().toUpperCase() == 'CASH WALLET') {
      return cashBalance;
    }
    if (isTrackingPaused(senderName)) return 0.0;

    final canonical = BankSenders.match(senderName) ?? senderName.trim();
    final key = canonical.toUpperCase();

    final accounts = accountsForBank(senderName);
    if (accounts.length <= 1) {
      final slot = accounts.isNotEmpty ? accounts.first : 0;
      if (isAccountPaused(senderName, slot)) return 0.0;
      return _cachedSenderBalances[key] ?? 0.0;
    }

    double sum = 0.0;
    final slotMap = _cachedAccountBalances[key];
    if (slotMap != null) {
      for (final slot in accounts) {
        if (!isAccountPaused(senderName, slot)) {
          sum += (slotMap[slot] ?? 0.0);
        }
      }
    }
    return sum;
  }

  double getLatestBalanceForBank(String bankName) => balanceForSender(bankName);

  /// Calculates total balance across all active banks for a specific SIM slot (or combined if [simSlot] is null).
  double totalBalanceForSim(int? simSlot, {double cashBalance = 0.0}) {
    if (simSlot == null) {
      double sum = cashBalance;
      for (final sender in _cachedActiveSenders) {
        sum += balanceForSender(sender.senderName);
      }
      return sum;
    }

    double sum = 0.0;
    for (final sender in _cachedActiveSenders) {
      if (sender.senderName.trim().toUpperCase() == 'CASH WALLET') continue;
      if (!isAccountPaused(sender.senderName, simSlot)) {
        sum += balanceForAccount(sender.senderName, simSlot);
      }
    }
    return sum;
  }

  double get totalBalance => _cachedTotalBalance;

  /// Returns all distinct SIM slots detected across all stored transactions.
  List<int> get detectedSimSlots => _cachedDetectedSimSlots;

  /// Whether the app has detected multiple SIM accounts across stored transactions.
  bool get hasMultipleSims => _cachedDetectedSimSlots.length > 1;

  /// Returns Telebirr Sanduq / Savings balance for a specific SIM slot.
  /// If [simSlot] is null, returns the accumulated sum of latest Sanduq balances from all active SIM slots.
  double telebirrSavingBalanceForAccount([int? simSlot]) {
    if (simSlot != null) {
      final simTxs = transactionsForSenderAndAccount('Telebirr', simSlot);
      for (final tx in simTxs) {
        if (TelebirrParser.isSavingsMessage(tx.rawMessage)) {
          final bal = TelebirrParser.extractSavingBalance(tx.rawMessage);
          if (bal != null && bal > 0) return bal;
        }
      }
      return 0.0;
    }

    final accounts = accountsForBank('Telebirr');
    if (accounts.length <= 1) {
      final telebirrTxs = transactionsForSender('Telebirr');
      for (final tx in telebirrTxs) {
        if (TelebirrParser.isSavingsMessage(tx.rawMessage)) {
          final bal = TelebirrParser.extractSavingBalance(tx.rawMessage);
          if (bal != null && bal > 0) return bal;
        }
      }
      return 0.0;
    }

    double sum = 0.0;
    for (final slot in accounts) {
      if (!isAccountPaused('Telebirr', slot)) {
        sum += telebirrSavingBalanceForAccount(slot);
      }
    }
    return sum;
  }

  double get telebirrSavingBalance => telebirrSavingBalanceForAccount(null);

  /// Returns transaction count for a sender in O(1) time.
  int txCountForSender(String senderName, {int cashTxCount = 0}) {
    if (senderName.trim().toUpperCase() == 'CASH WALLET') {
      return _cachedCashTxCount + cashTxCount;
    }
    final canonical = BankSenders.match(senderName) ?? senderName.trim();
    final key = canonical.toUpperCase();
    return _cachedSenderTxCounts[key] ?? 0;
  }

  List<AppTransaction> get activeBankCashWithdrawals {
    return _cachedUnpausedTransactions.where((t) {
      if (t.type != 'expense') return false;
      final reasonStr = (t.reason ?? t.customReasonText ?? t.resolvedReason ?? '')
          .toLowerCase()
          .trim();
      return reasonStr == 'cash';
    }).toList();
  }

  // ── Indexed Aggregate Computation (Single O(N) pass) ─────────────────────

  void _rebuildAggregateIndices() {
    final senderBalances = <String, double>{};
    final senderTxCounts = <String, int>{};
    final bankAccounts = <String, Set<int>>{};
    final bankSlotBalances = <String, Map<int, double>>{};
    final bankTransactions = <String, List<AppTransaction>>{};
    final uniqueSendersSet = SplayTreeSet<String>((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final uniqueBanksSet = SplayTreeSet<String>((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final allPersonNamesSet = SplayTreeSet<String>((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final allSimSlots = <int>{};
    int cashReasonCount = 0;

    final unpausedList = <AppTransaction>[];
    final recent30DaysList = <AppTransaction>[];
    final cutoff30Days = DateTime.now().subtract(const Duration(days: 30));

    // Single O(N) pass across all transactions in memory
    for (int i = 0; i < _transactions.length; i++) {
      final tx = _transactions[i];

      if (tx.sender.isNotEmpty) uniqueSendersSet.add(tx.sender);
      if (tx.name.isNotEmpty) {
        uniqueBanksSet.add(tx.name);
        allPersonNamesSet.add(tx.name.trim());
      }
      allSimSlots.add(tx.simSlot);

      final canonicalBank = BankSenders.match(tx.name) ?? tx.name.trim();
      final bankKey = canonicalBank.toUpperCase();

      // Group transactions by canonical bank key
      bankTransactions.putIfAbsent(bankKey, () => []).add(tx);

      // Track SIM slots per bank
      bankAccounts.putIfAbsent(bankKey, () => <int>{}).add(tx.simSlot);

      // Track latest balance per bank & per SIM slot (first occurrence because _transactions is sorted date DESC)
      if (tx.totalBalance > 0) {
        senderBalances.putIfAbsent(bankKey, () => tx.totalBalance);
        bankSlotBalances.putIfAbsent(bankKey, () => <int, double>{});
        bankSlotBalances[bankKey]!.putIfAbsent(tx.simSlot, () => tx.totalBalance);
      }

      senderTxCounts[bankKey] = (senderTxCounts[bankKey] ?? 0) + 1;

      final reasonStr = (tx.reason ?? tx.customReasonText ?? tx.resolvedReason ?? '').toLowerCase().trim();
      if (reasonStr == 'cash') {
        cashReasonCount++;
      }

      // Check paused
      bool isTxPaused = false;
      if (_pausedBanks.isNotEmpty) {
        if (_pausedBanks.any((b) => !b.contains(':') && BankSenders.isSameBank(b, tx.name))) {
          isTxPaused = true;
        } else {
          isTxPaused = _pausedBanks.any((b) {
            if (!b.contains(':')) return false;
            final parts = b.split(':');
            return BankSenders.isSameBank(parts[0], tx.name) && parts[1] == '${tx.simSlot}';
          });
        }
      }

      if (!isTxPaused) {
        unpausedList.add(tx);
        if (!tx.date.isBefore(cutoff30Days)) {
          recent30DaysList.add(tx);
        }
      }
    }

    _cachedSenderBalances = senderBalances;
    _cachedSenderTxCounts = senderTxCounts;
    _cachedBankAccounts = bankAccounts.map((k, v) => MapEntry(k, v.toList()..sort()));
    _cachedAccountBalances = bankSlotBalances;
    _cachedBankTransactions = bankTransactions;
    _cachedUniqueSenders = uniqueSendersSet.toList();
    _cachedUniqueBanks = uniqueBanksSet.toList();
    _cachedAllTrackedPersonNames = allPersonNamesSet.toList();
    _cachedDetectedSimSlots = allSimSlots.isEmpty ? [0] : (allSimSlots.toList()..sort());
    _cachedCashTxCount = cashReasonCount;
    _cachedUnpausedTransactions = unpausedList;
    _cachedRecent30DaysTransactions = recent30DaysList;

    _recomputeActiveAndPausedSenders();
    _recomputeTotalBalance();
  }

  void _recomputeActiveAndPausedSenders() {
    _cachedActiveSenders = _senders.where((s) => !isTrackingPaused(s.senderName)).toList();

    final Map<String, AppSender> map = {};
    for (final s in _senders) {
      if (isTrackingPaused(s.senderName)) {
        final canonical = BankSenders.match(s.senderName) ?? s.senderName.trim();
        map[canonical.toUpperCase()] = s;
      }
    }
    for (final paused in _pausedBanks) {
      final base = paused.contains(':') ? paused.split(':').first : paused;
      final canonical = BankSenders.match(base) ?? base.trim();
      final key = canonical.toUpperCase();
      if (key.isNotEmpty && !map.containsKey(key)) {
        map[key] = AppSender(senderName: canonical);
      }
    }
    _cachedPausedSenders = map.values.toList();
  }

  void _recomputeTotalBalance() {
    double sum = 0.0;
    for (final sender in _cachedActiveSenders) {
      sum += balanceForSender(sender.senderName);
    }
    _cachedTotalBalance = sum;
  }

  // ── Category Resolution ─────────────────────────────────────────────────

  /// Resolves a transaction's reason to its top-level category name.
  /// Used by AnalyticsViewModel to compute expense highlights (carousel pills).
  String getTopLevelCategoryForTransaction(AppTransaction tx) {
    // 1. Resolve by reasonId → walk up to parent if subcategory
    if (tx.reasonId != null) {
      final r = _reasons.where((item) => item.id == tx.reasonId).firstOrNull;
      if (r != null) {
        if (r.isSpecial || r.name.toLowerCase() == 'loan') return r.name;
        if (r.isSubcategory && r.parentId != null) {
          final parent =
              _reasons.where((p) => p.id == r.parentId).firstOrNull;
          if (parent != null) return parent.name;
        }
        if (r.isTopLevelCategory) return r.name;
      }
    }

    // 2. Resolve by categoryId
    if (tx.categoryId != null) {
      final cat =
          _reasons.where((c) => c.id == tx.categoryId).firstOrNull;
      if (cat != null) return cat.name;
    }

    // 3. Fallback: match by resolved reason string
    final reasonStr = tx.resolvedReason?.trim();
    if (reasonStr != null && reasonStr.isNotEmpty) {
      final matched = _reasons
          .where((r) => r.name.toLowerCase() == reasonStr.toLowerCase())
          .firstOrNull;
      if (matched != null) {
        if (matched.isSpecial || matched.name.toLowerCase() == 'loan') {
          return matched.name;
        }
        if (matched.isSubcategory && matched.parentId != null) {
          final parent =
              _reasons.where((p) => p.id == matched.parentId).firstOrNull;
          if (parent != null) return parent.name;
        }
        if (matched.isTopLevelCategory) return matched.name;
        return matched.name;
      }
      return reasonStr;
    }

    return 'Uncategorized';
  }

  // ── Paused Banks ──────────────────────────────────────────────────────────

  Set<String> get pausedBanks => Set.unmodifiable(_pausedBanks);

  Future<void> setPausedBanks(Set<String> banks) async {
    _pausedBanks = banks;
    await _repository.setPausedBanks(banks);
    _rebuildAggregateIndices();
    notifyListeners();
  }

  Future<void> pauseTracking(String bankName) async {
    final canonical = BankSenders.match(bankName) ?? bankName.trim();
    _pausedBanks = {..._pausedBanks, canonical};
    await _repository.setPausedBanks(_pausedBanks);
    // Note: Do NOT delete transactions from SQLite so history is never permanently lost.
    // The filtered getter txVM.transactions automatically hides transactions while paused.
    await _repository.deleteUncategorizedNotificationsForBank(canonical);
    await loadAll();
  }

  Future<void> resumeTracking(String bankName) async {
    final canonical = BankSenders.match(bankName) ?? bankName.trim();
    final cUp = canonical.toUpperCase();
    final bUp = bankName.toUpperCase();
    _pausedBanks = _pausedBanks.where((b) {
      if (BankSenders.isSameBank(b, canonical)) return false;
      if (b.toUpperCase() == cUp || b.toUpperCase() == bUp) return false;
      if (b.toUpperCase().startsWith('$cUp:') || b.toUpperCase().startsWith('$bUp:')) return false;
      return true;
    }).toSet();
    await _repository.setPausedBanks(_pausedBanks);
    await loadAll();
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
      try {
        await DatabaseService.instance.reconcileInternalTransfers();
        await DatabaseService.instance.deduplicateTransactions();
      } catch (_) {}

      // Strictly enforce active historical scan window on every load/restart when configured
      if (_settingsRepository != null) {
        final activeScanWindow = await _settingsRepository!.getScanWindow();
        if (activeScanWindow != ScanWindowOption.allTime) {
          final cutoff = await _settingsRepository!.getEffectiveScanWindowAnchorDate() ??
              activeScanWindow.anchorDate;
          try {
            await _repository.deleteTransactionsOlderThan(cutoff);
          } catch (_) {}
        }
      }

      final results = await Future.wait([
        _repository.getTransactions(),
        _repository.getSenders(),
        _repository.getReasons(),
        _repository.getReasonLinks(),
        _repository.getPausedBanks(),
        _repository.getAllTransactionSplits(),
      ]);
      _transactions = results[0] as List<AppTransaction>;
      _senders = results[1] as List<AppSender>;
      if (_senders.isEmpty) {
        try {
          final bool hasPermission = await Permission.sms.status.isGranted;
          if (hasPermission) {
            final detected = await SmsService().detectBankingSendersInInbox();
            for (final bankName in detected) {
              await _repository.insertSender(AppSender(senderName: bankName));
            }
            _senders = await _repository.getSenders();
          }
        } catch (_) {}
      }
      await _applySavedSendersOrder();
      _reasons = results[2] as List<AppReason>;
      _reasonLinks = results[3] as List<AppReasonLink>;
      _pausedBanks = results[4] as Set<String>;
      final allSplits = results[5] as List<TransactionSplit>;
      final Map<String, List<TransactionSplit>> splitsMap = {};
      for (final s in allSplits) {
        splitsMap.putIfAbsent(s.transactionId, () => []).add(s);
      }
      _transactionSplits = splitsMap;
      _rebuildAggregateIndices();

      try {
        _simCards = await SmsService().getSimCards();
      } catch (_) {}

      // Auto-scan SMS on startup when DB is empty and we haven't scanned yet
      // this session. This handles first boot when no data exists.
      if (_transactions.isEmpty && !_hasScannedOnce) {
        final hasPermission = await Permission.sms.status.isGranted;
        if (hasPermission) {
          _hasScannedOnce = true;
          // Release the loading lock before scanning so the UI can render
          _isLoading = false;
          notifyListeners();
          final activeOption = await _settingsRepository?.getScanWindow() ?? ScanWindowOption.sevenDays;
          await scanSms(scanWindowOption: activeOption);
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

  /// Discovers bank senders physically present in the phone's SMS inbox across all time and syncs them to SQLite.
  Future<void> discoverAndSyncPhoneSenders() async {
    try {
      final detected = await SmsService().detectBankingSendersInInbox(
        customSenders: _senders.map((s) => s.senderName).toList(),
      );
      for (final bankName in detected) {
        await _repository.insertSender(AppSender(senderName: bankName));
      }
      _senders = await _repository.getSenders();
      _rebuildAggregateIndices();
      notifyListeners();
    } catch (_) {}
  }

  /// Compatibility alias ensuring all present device bank senders are synced.
  Future<void> ensureDefaultSenders() => discoverAndSyncPhoneSenders();

  /// High-speed SMS batch scanner that parses messages within the active scan window in a background isolate
  Future<int> scanSms({
    ScanWindowOption? scanWindowOption,
    void Function(ScanProgressStatus)? onProgress,
    DateTime? since,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final activeOption = scanWindowOption ??
          await _settingsRepository?.getScanWindow() ??
          ScanWindowOption.allTime;

      onProgress?.call(const ScanProgressStatus(
        progress: 0.05,
        stage: 'Connecting to secure SMS inbox…',
      ));

      // Discover bank senders present on device across all time
      try {
        final detectedPhoneBanks = await SmsService().detectBankingSendersInInbox(
          customSenders: _senders.map((s) => s.senderName).toList(),
        );
        for (final bankName in detectedPhoneBanks) {
          await _repository.insertSender(AppSender(senderName: bankName));
        }
        _senders = await _repository.getSenders();
      } catch (_) {}

      // Strictly clamp since/anchorDate to never reach beyond active scan window fixed inception date
      DateTime? boundaryAnchor;
      if (activeOption != ScanWindowOption.allTime) {
        boundaryAnchor = (await _settingsRepository?.getEffectiveScanWindowAnchorDate()) ??
            activeOption.anchorDate;
      }
      DateTime? effectiveSince;
      if (since != null) {
        if (boundaryAnchor != null && since.isBefore(boundaryAnchor)) {
          effectiveSince = boundaryAnchor;
        } else {
          effectiveSince = since;
        }
      } else {
        effectiveSince = boundaryAnchor;
      }
      final cutoff = effectiveSince?.subtract(const Duration(minutes: 1));

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
        await loadAll();
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

      // ── Diagnostic: Raw message SIM distribution ──
      final sim0Raw = rawMessages.where((m) => m.simSlot == 0).length;
      final sim1Raw = rawMessages.where((m) => m.simSlot == 1).length;
      debugPrint('[ShibreSIM-Dart] Raw messages: total=${rawMessages.length} SIM1(slot0)=$sim0Raw SIM2(slot1)=$sim1Raw');

      final parseResult = await SmsBatchParser.parseInIsolate(BatchParseParams(
        rawMessages: rawMessages,
        pausedBanks: _pausedBanks.toList(),
        customSenders: _senders,
        autoReasonRules: autoRules,
        initialBankBalances: initialBalances,
      ));

      // ── Diagnostic: Parsed transaction SIM distribution ──
      final sim0Parsed = parseResult.transactions.where((t) => t.simSlot == 0).length;
      final sim1Parsed = parseResult.transactions.where((t) => t.simSlot == 1).length;
      debugPrint('[ShibreSIM-Dart] Parsed transactions: total=${parseResult.transactions.length} SIM1(slot0)=$sim0Parsed SIM2(slot1)=$sim1Parsed');

      // Per-bank SIM breakdown
      final Map<String, Map<int, int>> bankSimCounts = {};
      for (final tx in parseResult.transactions) {
        bankSimCounts.putIfAbsent(tx.name, () => {});
        bankSimCounts[tx.name]![tx.simSlot] = (bankSimCounts[tx.name]![tx.simSlot] ?? 0) + 1;
      }
      for (final entry in bankSimCounts.entries) {
        debugPrint('[ShibreSIM-Dart] ${entry.key}: ${entry.value}');
      }

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

      await _repository.reconcilePendingNotificationReasons();

      if (parseResult.unrecognizedNotifications.isNotEmpty) {
        await insertNotificationsBatch?.call(
            parseResult.unrecognizedNotifications);
      }

      await loadAll();
      onSmsEventReceived?.call();

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

  /// Reconciles any pending notification reasons and refreshes state on app resume
  Future<void> reconcileOnResume() async {
    try {
      await _repository.reconcilePendingNotificationReasons();
      await loadAll();
    } catch (_) {}
  }

  /// Adjusts the historical scan range, purging transactions that fall outside
  /// the new window when narrowing, and ingesting SMS up to the new anchor date.
  Future<int> updateScanWindowRange(
    ScanWindowOption newOption, {
    void Function(ScanProgressStatus)? onProgress,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      onProgress?.call(const ScanProgressStatus(
        progress: 0.05,
        stage: 'Adjusting historical scan window…',
      ));

      // If narrowing the window, purge transactions older than the new anchor date immediately
      if (_settingsRepository != null) {
        await _settingsRepository!.setScanWindow(newOption);
      }

      DateTime? cutoff;
      if (newOption != ScanWindowOption.allTime) {
        cutoff = (await _settingsRepository?.getEffectiveScanWindowAnchorDate()) ?? newOption.anchorDate;
        try {
          await _repository.deleteTransactionsOlderThan(cutoff);
        } catch (_) {}
      }

      // Ingest SMS within the updated window
      final count = await scanSms(
        scanWindowOption: newOption,
        since: cutoff,
        onProgress: onProgress,
      );

      return count;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reloads recent data by scanning SMS strictly bounded by the active scan window starting date.
  Future<void> refreshData({int? lastDays}) async {
    final activeOption = await _settingsRepository?.getScanWindow() ??
        ScanWindowOption.allTime;
    final anchorDate = (activeOption != ScanWindowOption.allTime && _settingsRepository != null)
        ? (await _settingsRepository!.getEffectiveScanWindowAnchorDate() ?? activeOption.anchorDate)
        : (activeOption != ScanWindowOption.allTime ? activeOption.anchorDate : null);

    DateTime? lookbackDate;
    if (lastDays != null) {
      final target = DateTime.now().subtract(Duration(days: lastDays));
      if (anchorDate != null && target.isBefore(anchorDate)) {
        lookbackDate = anchorDate;
      } else {
        lookbackDate = target;
      }
    } else {
      lookbackDate = anchorDate;
    }
    await scanSms(
      scanWindowOption: activeOption,
      since: lookbackDate,
    );
  }

  /// Reloads transaction data specifically for [bankName], querying only this bank's SMS
  /// up to [scanWindowOption] (or [lastDays]), parsing in an isolate, and persisting new records.
  Future<int> refreshBankData({
    required String bankName,
    int? lastDays,
    ScanWindowOption? scanWindowOption,
    void Function(ScanProgressStatus)? onProgress,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      onProgress?.call(ScanProgressStatus(
        progress: 0.05,
        stage: 'Connecting to $bankName SMS records…',
      ));

      final activeGlobal = await _settingsRepository?.getScanWindow() ??
          ScanWindowOption.allTime;
      final anchorDate = (activeGlobal != ScanWindowOption.allTime && _settingsRepository != null)
          ? (await _settingsRepository!.getEffectiveScanWindowAnchorDate() ?? activeGlobal.anchorDate)
          : (activeGlobal != ScanWindowOption.allTime ? activeGlobal.anchorDate : null);

      // Calculate anchor date / cutoff strictly bounded by active global scan window starting date
      DateTime? effectiveAnchor;
      if (scanWindowOption != null) {
        effectiveAnchor = scanWindowOption == ScanWindowOption.allTime
            ? null
            : scanWindowOption.anchorDate;
      } else if (lastDays != null) {
        effectiveAnchor = DateTime.now().subtract(Duration(days: lastDays));
      } else {
        effectiveAnchor = anchorDate;
      }

      // Clamp against active global window starting date
      if (anchorDate != null) {
        if (effectiveAnchor == null || effectiveAnchor.isBefore(anchorDate)) {
          effectiveAnchor = anchorDate;
        }
      }

      final DateTime? cutoff = effectiveAnchor?.subtract(const Duration(minutes: 1));

      // Resolve targeted bank search keywords
      final targetKeywords = BankSenders.getKeywordsForBank(bankName);

      final rawMessages = await SmsService().getBankMessagesFast(
        since: cutoff,
        overrideSenders: targetKeywords,
      );

      if (rawMessages.isEmpty) {
        onProgress?.call(ScanProgressStatus(
          progress: 1.0,
          stage: 'No $bankName messages found in window',
          scannedBanks: [],
          isComplete: true,
        ));
        await loadAll();
        return 0;
      }

      onProgress?.call(ScanProgressStatus(
        progress: 0.35,
        stage: 'Reading & analyzing $bankName records…',
      ));

      final autoRules = await _repository.getAutoReasonRules();
      final initialBalances = <String, double>{
        bankName: balanceForSender(bankName),
      };

      final parseResult = await SmsBatchParser.parseInIsolate(BatchParseParams(
        rawMessages: rawMessages,
        pausedBanks: _pausedBanks.toList(),
        customSenders: _senders,
        autoReasonRules: autoRules,
        initialBankBalances: initialBalances,
      ));

      onProgress?.call(ScanProgressStatus(
        progress: 0.80,
        stage: 'Storing verified $bankName transactions in database…',
        scannedBanks: [
          ScannedBankProgress(
            bankName: bankName,
            transactionCount: parseResult.transactions.length,
            latestBalance: parseResult.transactions.isNotEmpty && parseResult.transactions.last.totalBalance > 0
                ? parseResult.transactions.last.totalBalance
                : null,
          ),
        ],
      ));

      final insertedCount = await _repository
          .insertTransactionsBatch(parseResult.transactions);

      await _repository.reconcilePendingNotificationReasons();

      if (parseResult.unrecognizedNotifications.isNotEmpty) {
        await insertNotificationsBatch?.call(
            parseResult.unrecognizedNotifications);
      }

      await loadAll();
      onSmsEventReceived?.call();

      onProgress?.call(ScanProgressStatus(
        progress: 1.0,
        stage: 'Refreshed $bankName transactions',
        isComplete: true,
      ));

      return insertedCount;
    } catch (e) {
      debugPrint('Error during refreshBankData for $bankName: $e');
      onProgress?.call(ScanProgressStatus(
        progress: 1.0,
        stage: 'Failed to refresh $bankName records',
        isComplete: true,
      ));
      return 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Smart refresh: re-scans all SMS starting from the initial inception anchor date forward to Today.
  Future<void> smartRefresh({
    ScanWindowOption? scanWindowOption,
    void Function(ScanProgressStatus)? onProgress,
  }) async {
    final activeOption = scanWindowOption ??
        await _settingsRepository?.getScanWindow() ??
        ScanWindowOption.allTime;
    DateTime? startDate;
    if (activeOption != ScanWindowOption.allTime && _settingsRepository != null) {
      startDate = await _settingsRepository!.getEffectiveScanWindowAnchorDate();
    } else if (activeOption != ScanWindowOption.allTime) {
      startDate = activeOption.anchorDate;
    }

    await scanSms(
      scanWindowOption: activeOption,
      since: startDate,
      onProgress: onProgress,
    );
  }

  /// Purges transactions and re-scans cleanly from the initial inception anchor date.
  Future<void> purgeAndRescan({
    ScanWindowOption? scanWindowOption,
    void Function(ScanProgressStatus)? onProgress,
  }) async {
    final activeOption = scanWindowOption ??
        await _settingsRepository?.getScanWindow() ??
        ScanWindowOption.allTime;
    DateTime? startDate;
    if (activeOption != ScanWindowOption.allTime && _settingsRepository != null) {
      startDate = await _settingsRepository!.getEffectiveScanWindowAnchorDate();
    } else if (activeOption != ScanWindowOption.allTime) {
      startDate = activeOption.anchorDate;
    }

    await _repository.deleteAllTransactions();
    _transactions = [];
    _rebuildAggregateIndices();
    notifyListeners();
    await scanSms(
      scanWindowOption: activeOption,
      since: startDate,
      onProgress: onProgress,
    );
  }

  /// Full reset: clears transactions, custom reasons, notifications, paused banks and re-scans all available history.
  Future<void> fullReset({
    void Function(ScanProgressStatus)? onProgress,
  }) async {
    await _repository.deleteAllTransactions();
    _transactions = [];
    _pausedBanks = {};
    await _repository.setPausedBanks({});
    await _repository.deleteAllUserReasons();
    _reasons = await _repository.getReasons();
    _reasonLinks = [];
    await _repository.deleteAllNotifications();
    _rebuildAggregateIndices();
    notifyListeners();
    await scanSms(scanWindowOption: ScanWindowOption.allTime, onProgress: onProgress);
  }

  /// Step 1 of full reset: delete all transactions from database and clear paused banks.
  Future<void> fullResetStep1DeleteTransactions() async {
    await _repository.deleteAllTransactions();
    _transactions = [];
    _pausedBanks = {};
    await _repository.setPausedBanks({});
    _rebuildAggregateIndices();
    notifyListeners();
  }

  /// Step 2 of full reset: clear all custom reasons and reason links.
  Future<void> fullResetStep2ClearCustomReasons() async {
    await _repository.deleteAllUserReasons();
    _reasons = await _repository.getReasons();
    _reasonLinks = [];
    _rebuildAggregateIndices();
    notifyListeners();
  }

  /// Step 3 of full reset: delete all notifications from database.
  Future<void> fullResetStep3DeleteNotifications() async {
    await _repository.deleteAllNotifications();
    notifyListeners();
  }

  // ── Transaction CRUD ──────────────────────────────────────────────────────

  Future<void> addTransaction(AppTransaction transaction) async {
    await _repository.insertTransaction(transaction);
    _transactions.insert(0, transaction);
    await _ensureSenderExists(transaction.name);
    _rebuildAggregateIndices();
    notifyListeners();
  }

  Future<void> addTransactionsBatch(List<AppTransaction> transactions) async {
    await _repository.insertTransactionsBatch(transactions);
    _transactions.insertAll(0, transactions);
    for (final tx in transactions) {
      await _ensureSenderExists(tx.name);
    }
    _rebuildAggregateIndices();
    notifyListeners();
  }

  Future<void> _ensureSenderExists(String bankName) async {
    final trimmed = bankName.trim();
    if (trimmed.isEmpty) return;
    final canonical = BankSenders.match(trimmed) ?? trimmed;
    final exists = _senders.any(
      (s) => s.senderName.trim().toUpperCase() == canonical.toUpperCase(),
    );
    if (!exists) {
      final newSender = AppSender(senderName: canonical);
      final id = await _repository.insertSender(newSender);
      _senders.add(AppSender(id: id.toString(), senderName: canonical));
    }
  }

  Future<void> deleteTransaction(String id) async {
    await _repository.deleteTransaction(id);
    _transactions.removeWhere((t) => t.id == id);
    _rebuildAggregateIndices();
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
    int? resolvedCategoryId = categoryId;
    int? resolvedSubcategoryId = subcategoryId;
    int? resolvedReasonId = reasonId;
    String? resolvedReason = reason;

    if (resolvedReasonId != null) {
      final matched = _reasons.where((r) => r.id == resolvedReasonId).firstOrNull;
      if (matched != null) {
        resolvedReason ??= matched.name;
        resolvedCategoryId ??= matched.isSubcategory ? matched.parentId : (matched.isTopLevelCategory ? matched.id : null);
        resolvedSubcategoryId ??= matched.isSubcategory ? matched.id : null;
      }
    } else if (resolvedReason != null && resolvedReason.isNotEmpty) {
      final matched = _reasons.where((r) => r.name.toLowerCase().trim() == resolvedReason!.toLowerCase().trim()).firstOrNull;
      if (matched != null) {
        resolvedReasonId = matched.id;
        resolvedCategoryId ??= matched.isSubcategory ? matched.parentId : (matched.isTopLevelCategory ? matched.id : null);
        resolvedSubcategoryId ??= matched.isSubcategory ? matched.id : null;
      }
    }

    final idx = _transactions.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final updated = _transactions[idx].copyWith(
        reasonId: resolvedReasonId,
        categoryId: resolvedCategoryId,
        subcategoryId: resolvedSubcategoryId,
        note: note,
        reason: resolvedReason,
        customReasonText: customReasonText ?? (resolvedReasonId == null ? resolvedReason : null),
      );
      _transactions[idx] = updated;
      _rebuildAggregateIndices();
      notifyListeners();
      await _repository.updateTransaction(updated);
    } else {
      if (resolvedReason != null) {
        await _repository.updateTransactionReason(id, resolvedReason, resolvedReasonId);
      }
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
      _rebuildAggregateIndices();
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
    _rebuildAggregateIndices();
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
      _rebuildAggregateIndices();
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
      _rebuildAggregateIndices();
      notifyListeners();
      await _repository.updateTransaction(_transactions[idx]);
    }
  }

  /// Returns unlinked candidate transactions with opposite type within ±[daysRange] days
  /// (default 7 days before and 7 days after) of [sourceTransaction], ordered by their
  /// closeness in amount to [sourceTransaction.amount].
  List<AppTransaction> getInternalTransferCandidates(
    AppTransaction sourceTransaction, {
    int daysRange = 7,
  }) {
    final targetType =
        sourceTransaction.type == 'income' ? 'expense' : 'income';
    final cutoffDate =
        sourceTransaction.date.subtract(Duration(days: daysRange));
    final futureDate =
        sourceTransaction.date.add(Duration(days: daysRange));

    final candidates = _transactions.where((tx) {
      if (tx.id == sourceTransaction.id) return false;
      if (tx.type != targetType) return false;
      if (tx.linkedTransactionId != null &&
          tx.linkedTransactionId!.isNotEmpty) {
        return false;
      }
      if (tx.date.isBefore(cutoffDate) || tx.date.isAfter(futureDate)) {
        return false;
      }
      return true;
    }).toList();

    // Sort based on closeness of amount to sourceTransaction.amount
    candidates.sort((a, b) {
      final diffA = (a.amount - sourceTransaction.amount).abs();
      final diffB = (b.amount - sourceTransaction.amount).abs();
      final diffCmp = diffA.compareTo(diffB);
      if (diffCmp != 0) return diffCmp;

      // Tie-breaker: closeness of date to sourceTransaction.date
      final dateDiffA = (a.date.difference(sourceTransaction.date)).abs();
      final dateDiffB = (b.date.difference(sourceTransaction.date)).abs();
      return dateDiffA.compareTo(dateDiffB);
    });

    return candidates;
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
      parentId: reason.parentId,
      isSystem: reason.isSystem,
      isSpecial: reason.isSpecial,
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
    _reasons.removeWhere((r) => r.id == id || r.parentId == id);
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

          if (CounterpartyMatcher.matches(tx.sender, linkedName) &&
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

    _rebuildAggregateIndices();
    notifyListeners();
  }

  Future<void> deleteReasonLink(int id) async {
    await _repository.deleteReasonLink(id);
    _reasonLinks.removeWhere((l) => l.id == id);
    _rebuildAggregateIndices();
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

          if (CounterpartyMatcher.matches(tx.sender, linkedName) &&
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

    _rebuildAggregateIndices();
    notifyListeners();
  }

  Future<AppReason?> findAutoReason(
      String senderName, String transactionType) {
    return _repository.findAutoReason(senderName, transactionType);
  }

  /// Returns all reason links for a category and all of its subcategories.
  List<AppReasonLink> allLinksForCategoryTree(int categoryId) {
    final subIds = _reasons
        .where((r) => r.parentId == categoryId && r.id != null)
        .map((r) => r.id!)
        .toSet();
    final allTargetIds = {categoryId, ...subIds};
    return _reasonLinks
        .where((l) => allTargetIds.contains(l.reasonId))
        .toList();
  }

  /// Whether a reason (or any of its subcategories) has linked persons.
  bool hasLinkedPersons(int reasonId) {
    return allLinksForCategoryTree(reasonId).isNotEmpty;
  }

  /// Returns a sorted unique list of known counterparty names from transactions and senders.
  List<String> get uniqueCounterparties {
    final Set<String> names = {};
    for (final s in _senders) {
      final n = s.senderName.trim();
      if (n.isNotEmpty) names.add(n);
    }
    for (final t in _transactions) {
      final n = t.sender.trim();
      if (n.isNotEmpty) names.add(n);
    }
    final sorted = names.toList();
    sorted.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  // ── Category / Subcategory Helpers ──────────────────────────────────────

  /// Top-level user-visible categories (excludes system specials like
  /// pass-through, cash, internal transfer, loan) ordered by frequent expenses.
  List<AppReason> get topLevelCategories {
    final list = _reasons
        .where((r) =>
            r.parentId == null &&
            !r.isSpecial &&
            !['pass-through', 'pass through', 'bounce', 'cash', 'internal transfer', 'loan']
                .contains(r.name.trim().toLowerCase()))
        .toList();
    list.sort(AppReason.compareCategories);
    return list;
  }

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

  // ── Transaction Splits Management ──────────────────────────────────────────

  /// Returns all splits allocated to a transaction ID.
  List<TransactionSplit> getSplitsForTransaction(String? txId) {
    if (txId == null || txId.isEmpty) return const [];
    return _transactionSplits[txId] ?? const [];
  }

  /// Whether a transaction has itemized splits.
  bool hasSplits(String? txId) {
    if (txId == null || txId.isEmpty) return false;
    return _transactionSplits[txId]?.isNotEmpty ?? false;
  }

  /// Returns the total amount of all splits for a transaction ID.
  double getSplitTotal(String? txId) {
    if (txId == null || txId.isEmpty) return 0.0;
    return (_transactionSplits[txId] ?? [])
        .fold(0.0, (sum, s) => sum + s.amount);
  }

  /// Atomically saves splits for a transaction, persisting to SQLite and updating in-memory cache.
  Future<void> saveTransactionSplits(
      String txId, List<TransactionSplit> splits) async {
    await _repository.saveTransactionSplits(txId, splits);
    if (splits.isEmpty) {
      _transactionSplits.remove(txId);
    } else {
      _transactionSplits[txId] = splits;
    }
    final idx = _transactions.indexWhere((t) => t.id == txId);
    if (idx != -1) {
      _transactions[idx] = _transactions[idx].copyWith(
        reason: splits.isNotEmpty ? 'Split' : null,
      );
    }
    _rebuildAggregateIndices();
    notifyListeners();
  }

  /// Deletes all splits for a transaction.
  Future<void> deleteTransactionSplits(String txId) async {
    await _repository.deleteTransactionSplits(txId);
    _transactionSplits.remove(txId);
    final idx = _transactions.indexWhere((t) => t.id == txId);
    if (idx != -1) {
      _transactions[idx] = _transactions[idx].copyWith(
        reason: null,
      );
    }
    _rebuildAggregateIndices();
    notifyListeners();
  }

  /// Total count of all active splits across all transactions.
  int get totalSplitsCount =>
      _transactionSplits.values.fold(0, (sum, l) => sum + l.length);
}
