import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/app_currency.dart';
import '../models/sender.dart';
import '../models/transaction.dart';
import '../models/app_notification.dart';
import '../models/reason.dart';
import '../models/loan_record.dart';
import '../models/loan_repayment_request.dart';
import '../models/expense_definition.dart';
import '../models/cash_transaction.dart';
import '../models/saving_goal.dart';
import '../models/goal_feasibility.dart';
import '../services/database_service.dart';
import '../services/sms_service.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart' as sms_inbox;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/telebirr_parser.dart';
import '../services/cbe_parser.dart';
import '../services/cbe_birr_parser.dart';
import '../services/ahadu_parser.dart';
import '../services/bank_senders.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:telephony/telephony.dart';
import '../services/background_service.dart';

import '../main.dart' show appNavigatorKey;
import '../widgets/level_up_modal.dart';

class FinanceProvider with ChangeNotifier, WidgetsBindingObserver {
  List<AppSender> _senders = [];
  List<AppTransaction> _transactions = [];
  List<AppNotification> _notifications = [];
  List<AppReason> _reasons = [];
  List<AppReasonLink> _reasonLinks = [];
  List<LoanRecord> _loanRecords = [];
  Map<int, List<LoanPayment>> _loanPayments = {}; // keyed by loanId
  List<LoanRepaymentRequest> _pendingRepaymentRequests = [];

  // Cash Wallet & Expenses
  List<ExpenseDefinition> _expenseDefinitions = [];
  List<CashTransaction> _cashTransactions = [];
  double _cashBalance = 0;
  List<SavingGoal> _savingGoals = [];

  /// Set of bank names whose tracking is currently paused.
  /// When a bank is paused, its messages are not processed and its
  /// transactions are excluded from all balance and stats calculations.
  Set<String> _pausedBanks = {};

  int _unreadNotificationCount = 0;
  bool _isLoading = true;
  double _totalBalance = 0;
  /// Latest known balance per bank/account name (e.g. {'CBE': 12500.0, 'Telebirr': 3200.0}).
  Map<String, double> _latestBalancesMap = {};
  double _incomeThisMonth = 0;
  double _expenseThisMonth = 0;
  double _incomeForSelectedDate = 0;
  double _expenseForSelectedDate = 0;
  double _netForSelectedDate = 0;
  double _incomePercentageChange = 0;
  double _netOverall = 0;
  double _percentageChangeOverall = 0;
  int _todayTransactionCount = 0;
  DateTime _selectedDate = DateTime.now();
  DateTime? _customMonthAnchorDate;
  AppCurrency _currentCurrency = AppCurrency.defaultCurrency;

  Map<String, dynamic>? _cachedMostExpenseToday;
  Map<String, dynamic>? _cachedMostExpenseThisMonth;
  Map<String, dynamic>? _cachedTopExpenseHighlight;

  AppCurrency get currentCurrency => _currentCurrency;

  Future<void> setCurrency(String code) async {
    _currentCurrency = AppCurrency.fromCode(code);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_currency_code', code);
    await DatabaseService.instance.setSetting('selected_currency_code', code);
  }

  bool _hasPermission = false;
  bool _isOnboardingComplete;
  bool _isBalanceVisible = true;
  bool _isShowingAll = false;
  bool _isMenuOpen = false;
  int _currentScreenIndex = 0;
  double _pageOffset = 0.0;
  String? _userName;
  Timer? _dbSyncTimer;
  int _lastKnownTxCount = 0;
  int _lastKnownNotificationCount = 0;
  bool _isBatchProcessing = false;

  bool _isForegroundListenerInitialized = false;

  void _initForegroundSmsListener() {
    if (_isForegroundListenerInitialized) return;
    _isForegroundListenerInitialized = true;
    try {
      final Telephony telephony = Telephony.instance;
      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          await processBackgroundSms(message);
          await _reloadFromDatabase();
        },
        onBackgroundMessage: backgroundMessageHandler,
        listenInBackground: true,
      );
    } catch (_) {}
  }

  /// The last level the user was shown a level-up modal for.
  /// Persisted to SharedPreferences so re-launches don't re-show old modals.
  int _lastSeenLevel = 1;

  /// Guard: prevents firing the modal during the initial load (when we are
  /// just restoring state, not actually advancing).
  bool _levelDetectionReady = false;

  /// [initialOnboardingComplete] should be read from SharedPreferences in
  /// main() BEFORE runApp() so the first frame is always correct.
  FinanceProvider({bool initialOnboardingComplete = false})
      : _isOnboardingComplete = initialOnboardingComplete;

  String? get userName => _userName;

  // ── Pause Tracking ────────────────────────────────────────────────────────
  /// The set of bank names that are currently paused.
  Set<String> get pausedBanks => Set.unmodifiable(_pausedBanks);

  /// Returns true if tracking for [bankName] is currently paused.
  bool isTrackingPaused(String bankName) =>
      _pausedBanks.any((b) => b.toUpperCase() == bankName.toUpperCase());

  /// Pauses tracking for [bankName].
  /// - New SMS messages from this bank will be ignored.
  /// - Existing transactions from this bank are excluded from all
  ///   balance and income/expense calculations until tracking resumes.
  Future<void> pauseTracking(String bankName) async {
    _pausedBanks = {..._pausedBanks, bankName};
    await DatabaseService.instance.setPausedBanks(_pausedBanks);
    _calculateStats();
    notifyListeners();
  }

  /// Resumes tracking for [bankName], re-including its transactions in
  /// all balance and stats calculations.
  Future<void> resumeTracking(String bankName) async {
    _pausedBanks = _pausedBanks
        .where((b) => b.toUpperCase() != bankName.toUpperCase())
        .toSet();
    await DatabaseService.instance.setPausedBanks(_pausedBanks);
    _calculateStats();
    notifyListeners();
  }

  List<AppSender> get senders => _senders;

  /// Returns all unique person/sender names captured in transaction records.
  /// Used to power "pick from existing contacts" in the loan form.
  List<String> get allTrackedPersonNames {
    final names = <String>{};
    for (final tx in _transactions) {
      if (tx.sender.isNotEmpty && tx.sender != 'Manual Entry') {
        names.add(tx.sender);
      }
    }
    final sorted = names.toList()..sort();
    return sorted;
  }

  /// Returns the hardcoded bank/system sender names (always available).
  List<String> get bankSenderNames =>
      _senders.map((s) => s.senderName).toList();

  /// Public transactions list — **excludes** transactions from paused banks.
  /// All UI screens (dashboard, search, analysis) should use this getter so
  /// paused bank data is invisible to the user.
  List<AppTransaction> get transactions => _pausedBanks.isEmpty
      ? _transactions
      : _transactions
          .where((tx) => !_pausedBanks
              .any((b) => b.toUpperCase() == tx.name.toUpperCase()))
          .toList();

  /// Raw unfiltered transaction list — includes paused bank transactions.
  /// Used only internally (e.g. loan repayment history lookups) where the
  /// full history is needed regardless of pause state.
  List<AppTransaction> get allTransactionsUnfiltered => _transactions;

  List<AppTransaction> get transactionsForSelectedDate {
    final base = transactions; // already filtered
    if (_isShowingAll) return base;
    return base
        .where((tx) =>
            tx.date.year == _selectedDate.year &&
            tx.date.month == _selectedDate.month &&
            tx.date.day == _selectedDate.day)
        .toList();
  }

  List<AppTransaction> get transactionsForSelectedMonth {
    return transactions // already filtered
        .where((tx) => isDateInMonthOf(tx.date, _selectedDate))
        .toList();
  }

  bool isDateInMonthOf(DateTime date, DateTime relativeTo) {
    if (_customMonthAnchorDate == null) {
      return date.year == relativeTo.year && date.month == relativeTo.month;
    }
    final strippedAnchor = DateTime(_customMonthAnchorDate!.year,
        _customMonthAnchorDate!.month, _customMonthAnchorDate!.day);
    final strippedRelative =
        DateTime(relativeTo.year, relativeTo.month, relativeTo.day);
    final strippedDate = DateTime(date.year, date.month, date.day);

    final int daysSince = strippedRelative.difference(strippedAnchor).inDays;
    final int periodIndex = (daysSince / 30).floor();

    final DateTime periodStart =
        strippedAnchor.add(Duration(days: periodIndex * 30));
    final DateTime periodEnd = periodStart.add(const Duration(days: 30));

    return !strippedDate.isBefore(periodStart) &&
        strippedDate.isBefore(periodEnd);
  }

  Future<void> setCustomMonthAnchorDate(DateTime? date) async {
    _customMonthAnchorDate = date;
    final prefs = await SharedPreferences.getInstance();
    if (date == null) {
      await prefs.remove('custom_month_anchor_date');
    } else {
      await prefs.setString('custom_month_anchor_date', date.toIso8601String());
    }
    _calculateStats();
    notifyListeners();
  }

  bool get isLoading => _isLoading;
  bool get hasPermission => _hasPermission;
  bool get isOnboardingComplete => _isOnboardingComplete;
  bool get isBalanceVisible => _isBalanceVisible;
  bool get isShowingAll => _isShowingAll;
  bool get isMenuOpen => _isMenuOpen;
  DateTime get selectedDate => _selectedDate;
  DateTime? get customMonthAnchorDate => _customMonthAnchorDate;
  int get currentScreenIndex => _currentScreenIndex;
  double get pageOffset => _pageOffset;

  void setPageOffset(double offset) {
    if ((_pageOffset - offset).abs() > 0.001) {
      _pageOffset = offset;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  bool get isSelectedDateToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  double get totalBalance => _totalBalance;

  /// Returns 1–5 based on total balance thresholds:
  /// LV1: ≤ 100,000 | LV2: 100k–500k | LV3: 500k–1M | LV4: 1M–5M | LV5: > 5M
  int get userLevel {
    if (_totalBalance <= 100000) return 1;
    if (_totalBalance <= 500000) return 2;
    if (_totalBalance <= 1000000) return 3;
    if (_totalBalance <= 5000000) return 4;
    return 5;
  }

  /// Human-readable name for the user's current level.
  String get userLevelName {
    switch (userLevel) {
      case 1: return 'Survivor';
      case 2: return 'Builder';
      case 3: return 'Flourishing';
      case 4: return 'Prospering';
      case 5: return 'Elite';
      default: return 'Survivor';
    }
  }

  /// Motivational description per level.
  String get userLevelDescription {
    switch (userLevel) {
      case 1:
        return 'Welcome to the journey! Every birr you save is a step forward. Keep tracking your spending, build an emergency fund, and watch your future grow.';
      case 2:
        return 'You are a Builder! Your financial foundation is taking shape. Keep growing your savings and making your money work smarter for you.';
      case 3:
        return 'You are Flourishing! You have built a strong financial cushion. Now it is time to diversify and let your wealth multiply.';
      case 4:
        return 'Outstanding! You are among the financially prosperous. Your discipline has created real wealth. Keep optimizing and expanding your portfolio.';
      case 5:
        return 'Elite level achieved! You are in a rare class of financial excellence. Your wealth speaks for itself — now focus on legacy and impact.';
      default:
        return 'Keep going! Every step counts toward your financial freedom.';
    }
  }

  /// The minimum balance threshold for the user's current level.
  double get currentLevelMinBalance {
    switch (userLevel) {
      case 1: return 0.0;
      case 2: return 100000.0;
      case 3: return 500000.0;
      case 4: return 1000000.0;
      case 5: return 5000000.0;
      default: return 0.0;
    }
  }

  /// The target balance needed to reach the next level (or null if max level).
  double? get nextLevelTargetBalance {
    switch (userLevel) {
      case 1: return 100000.0;
      case 2: return 500000.0;
      case 3: return 1000000.0;
      case 4: return 5000000.0;
      case 5: return null;
      default: return 100000.0;
    }
  }

  /// Name of the next level (or null if at max level).
  String? get nextLevelName {
    switch (userLevel) {
      case 1: return 'Builder';
      case 2: return 'Flourishing';
      case 3: return 'Prospering';
      case 4: return 'Elite';
      case 5: return null;
      default: return null;
    }
  }

  /// How much money remains to reach the next level (0.0 if max level).
  double get remainingToNextLevel {
    final target = nextLevelTargetBalance;
    if (target == null) return 0.0;
    final diff = target - _totalBalance;
    return diff < 0 ? 0.0 : diff;
  }

  /// Progress fraction (0.0 to 1.0) towards the next level.
  double get nextLevelProgress {
    final target = nextLevelTargetBalance;
    if (target == null) return 1.0;
    final minBal = currentLevelMinBalance;
    final span = target - minBal;
    if (span <= 0) return 1.0;
    final currentInSpan = _totalBalance - minBal;
    return (currentInSpan / span).clamp(0.0, 1.0);
  }

  /// Start loading financial data in the background during onboarding
  /// without marking onboarding as complete. Call this early so data
  /// is ready by the time the user reaches the level reveal page.
  Future<void> startBackgroundInit() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('user_name_v1');
    _hasPermission = await Permission.sms.status.isGranted;
    if (!_hasPermission) return;
    _initForegroundSmsListener();

    final dbSenders = await DatabaseService.instance.getSenders();
    if (dbSenders.isNotEmpty) {
      _senders = dbSenders;
      if (!_senders.any((s) => s.senderName.toUpperCase().contains('AHADU'))) {
        final ahadu = AppSender(id: '4', senderName: 'Ahadu Bank');
        await DatabaseService.instance.insertSender(ahadu);
        _senders.add(ahadu);
      }
    } else {
      _senders = [
        AppSender(id: '1', senderName: 'Telebirr'),
        AppSender(id: '2', senderName: 'CBE'),
        AppSender(id: '3', senderName: 'CBE Birr'),
        AppSender(id: '4', senderName: 'Ahadu Bank'),
      ];
      for (var s in _senders) {
        await DatabaseService.instance.insertSender(s);
      }
    }

    _pausedBanks = await DatabaseService.instance.getPausedBanks();
    _transactions = await DatabaseService.instance.getTransactions();
    _expenseDefinitions = await DatabaseService.instance.getExpenseDefinitions();
    _cashTransactions = await DatabaseService.instance.getCashTransactions();
    _savingGoals = await DatabaseService.instance.getSavingGoals();

    // Ensure install_anchor_date is set so refreshData() never silently bails.
    // This mirrors the same guard in init(). Without this, any user who goes
    // through the new onboarding flow (startBackgroundInit → completeOnboarding
    // early-return path) would never have install_anchor_date written, causing
    // refreshData() to return immediately with no SMS scan.
    const anchorVersion = 'v4';
    final bool needsAnchorReset =
        prefs.getString('anchor_version') != anchorVersion;
    if (needsAnchorReset) {
      await prefs.setString('install_anchor_date',
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String());
      await prefs.setString('anchor_version', anchorVersion);
    }

    bool isFirstBoot = prefs.getBool('is_first_boot_v5') ?? true;
    if (isFirstBoot && _transactions.isEmpty) {
      final installAnchor = DateTime.now().subtract(const Duration(days: 30));
      List<sms_inbox.SmsMessage> allMessages =
          await SmsService().getAllMessages(since: installAnchor);
      allMessages.sort((a, b) {
        if (a.date == null || b.date == null) return 0;
        return b.date!.compareTo(a.date!);
      });
      Set<String> processedSenders = {};
      _isBatchProcessing = true;
      for (var msg in allMessages) {
        if (msg.sender != null && msg.body != null && msg.date != null) {
          final msgDate = msg.date!;
          if (!_isEnglishBankingMessage(msg.body!)) continue;
          final bank = BankSenders.match(msg.sender);
          if (bank == 'Telebirr' && !processedSenders.contains('Telebirr')) {
            AppTransaction? tx = TelebirrParser.parse(msg.body!, msgDate);
            if (tx != null) { await addTransaction(tx); processedSenders.add('Telebirr'); }
          } else if (bank == 'CBE Birr' && !processedSenders.contains('CBE Birr')) {
            AppTransaction? tx = CbeBirrParser.parse(msg.body!, msgDate);
            if (tx != null) { await addTransaction(tx); processedSenders.add('CBE Birr'); }
          } else if (bank == 'CBE' && !processedSenders.contains('CBE')) {
            if (_userName == null) {
              final name = CbeParser.extractOwnerName(msg.body!);
              if (name != null) { _userName = name; await prefs.setString('user_name_v1', name); }
            }
            AppTransaction? tx = CbeParser.parse(msg.body!, msgDate);
            if (tx != null) { await addTransaction(tx); processedSenders.add('CBE'); }
          } else if (bank == 'Ahadu Bank' && !processedSenders.contains('Ahadu Bank')) {
            if (_userName == null) {
              final name = AhaduParser.extractOwnerName(msg.body!);
              if (name != null) { _userName = name; await prefs.setString('user_name_v1', name); }
            }
            AppTransaction? tx = AhaduParser.parse(msg.body!, msgDate);
            if (tx != null) { await addTransaction(tx); processedSenders.add('Ahadu Bank'); }
          }
        }
        if (processedSenders.contains('Telebirr') &&
            processedSenders.contains('CBE') &&
            processedSenders.contains('CBE Birr') &&
            processedSenders.contains('Ahadu Bank')) { break; }
      }
      _isBatchProcessing = false;
      await prefs.setBool('is_first_boot_v5', false);
      _transactions = await DatabaseService.instance.getTransactions();
    }

    _calculateStats();
    _isLoading = false;

    _lastSeenLevel = userLevel;
    await prefs.setInt('last_seen_level', _lastSeenLevel);
    _levelDetectionReady = true;

    notifyListeners();
  }

  double get incomeThisMonth => _incomeThisMonth;
  double get expenseThisMonth => _expenseThisMonth;
  double get incomeForSelectedDate => _incomeForSelectedDate;
  double get expenseForSelectedDate => _expenseForSelectedDate;
  double get netForSelectedDate => _netForSelectedDate;
  double get incomePercentageChange => _incomePercentageChange;
  double get netOverall => _netOverall;
  double get percentageChangeOverall => _percentageChangeOverall;
  int get todayTransactionCount => _todayTransactionCount;
  List<AppNotification> get notifications => _notifications;
  int get unreadNotificationCount => _unreadNotificationCount;
  List<AppReason> get reasons => _reasons;
  List<AppReasonLink> get reasonLinks => _reasonLinks;
  List<LoanRecord> get loanRecords => _loanRecords;
  List<LoanPayment> paymentsForLoan(int loanId) => _loanPayments[loanId] ?? [];
  List<LoanRepaymentRequest> get pendingRepaymentRequests =>
      _pendingRepaymentRequests;

  List<ExpenseDefinition> get expenseDefinitions => _expenseDefinitions;
  List<CashTransaction> get cashTransactions => _cashTransactions;
  double get cashBalance => _cashBalance;
  List<SavingGoal> get savingGoals => _savingGoals;

  /// Live balance per detected bank account, e.g. {'CBE': 12500.0, 'Telebirr': 3200.0}.
  Map<String, double> get latestBalancesMap => Map.unmodifiable(_latestBalancesMap);

  /// Sorted list of account names that have a known balance (for the account picker UI).
  List<String> get allAccountNames =>
      _latestBalancesMap.keys.where((k) => _latestBalancesMap[k]! > 0).toList()
        ..sort();

  // ── Feasibility Engine ─────────────────────────────────────────────────────

  /// Computes the feasibility of [goal] given current account balances and
  /// the allocation settings of every other active goal.
  GoalFeasibility goalFeasibility(SavingGoal goal) {
    final balances = _latestBalancesMap;
    final remaining = goal.remainingAmount;

    // ── 1. Compute available amount ──────────────────────────────────────────
    double available = 0;
    switch (goal.allocationMode) {
      case AllocationMode.globalPercent:
        final pct = (goal.accountAllocations['*'] ?? 30.0) / 100.0;
        available = _totalBalance * pct;
        break;
      case AllocationMode.accountSpecific:
      case AllocationMode.multiAccount:
        for (final entry in goal.accountAllocations.entries) {
          final acctBalance = balances[entry.key] ?? 0.0;
          available += acctBalance * (entry.value / 100.0);
        }
        break;
    }

    // ── 2. Conflict detection ─────────────────────────────────────────────────
    // For each account this goal uses, sum allocations from ALL other active goals.
    final conflicts = <String>[];
    if (goal.allocationMode != AllocationMode.globalPercent) {
      for (final accountName in goal.accountAllocations.keys) {
        double totalPct = goal.accountAllocations[accountName] ?? 0;
        for (final other in _savingGoals) {
          if (other.id == goal.id) continue;
          if (other.status != 'active') continue;
          if (other.allocationMode == AllocationMode.globalPercent) continue;
          final otherPct = other.accountAllocations[accountName];
          if (otherPct != null) totalPct += otherPct;
        }
        if (totalPct > 100) {
          conflicts.add(
              '$accountName is over-allocated (${totalPct.toStringAsFixed(0)}%)');
        }
      }
    }

    return GoalFeasibility(
      availableAmount: available,
      remainingAmount: remaining,
      canAffordNow: available >= remaining,
      conflictWarning: conflicts.join(' · '),
    );
  }

  // Stub for cash spending tracking (not yet implemented in DB)
  List<dynamic> spendingsForTransaction(String transactionId) => [];

  // ── Loan convenience getters ──────────────────
  List<LoanRecord> get activeLoans =>
      _loanRecords.where((l) => l.status == 'active').toList();
  List<LoanRecord> get overdueLoans =>
      _loanRecords.where((l) => l.isOverdue).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  List<LoanRecord> get paidLoans =>
      _loanRecords.where((l) => l.isPaid).toList();
  int get activeLoanCount => activeLoans.length;
  int get overdueLoanCount => overdueLoans.length;

  // ── Profit & Loss Getters ────────────────────────────────────────────────

  /// Total outstanding liability from money the user has BORROWED (not lent).
  /// Borrowed money is in the user's hands but is a liability in P/L analysis.
  double get totalBorrowedLiability {
    return _loanRecords
        .where((l) => l.loanType == 'borrowed' && !l.isPaid)
        .fold(0.0, (sum, l) => sum + l.remainingAmount);
  }

  /// The date of the earliest transaction ever recorded.
  DateTime? get installDate {
    if (_transactions.isEmpty) return null;
    return _transactions.reduce((a, b) => a.date.isBefore(b.date) ? a : b).date;
  }

  /// Daily P/L: income minus expenses for today. CAN be negative.
  double get dailyPnl {
    final now = DateTime.now();
    double income = 0;
    double expense = 0;
    for (final tx in _transactions) {
      if (tx.date.year == now.year &&
          tx.date.month == now.month &&
          tx.date.day == now.day) {
        final isCash = tx.resolvedReason?.toLowerCase() == 'cash';
        final isBounce = tx.resolvedReason?.toLowerCase() == 'bounce' ||
            tx.resolvedReason?.toLowerCase() == 'internal transfer';
        if (!isCash && !isBounce) {
          if (tx.type == 'income') income += tx.amount;
          if (tx.type == 'expense') expense += tx.amount;
        }
      }
    }
    for (final ctx in _cashTransactions) {
      if (ctx.date.year == now.year &&
          ctx.date.month == now.month &&
          ctx.date.day == now.day) {
        if (ctx.type == 'addition') income += ctx.amount;
        if (ctx.type == 'expense') expense += ctx.amount;
      }
    }
    return income - expense;
  }

  /// Monthly P/L: cannot go below 0 UNLESS borrowed liabilities exceed gross income.
  double get monthlyPnl {
    double income = 0;
    double expense = 0;
    final now = DateTime.now();
    for (final tx in _transactions) {
      if (!isDateInMonthOf(tx.date, now)) continue;
      final isCash = tx.resolvedReason?.toLowerCase() == 'cash';
      final isBounce = tx.resolvedReason?.toLowerCase() == 'bounce' ||
          tx.resolvedReason?.toLowerCase() == 'internal transfer';
      if (!isCash && !isBounce) {
        if (tx.type == 'income') income += tx.amount;
        if (tx.type == 'expense') expense += tx.amount;
      }
    }
    for (final ctx in _cashTransactions) {
      if (!isDateInMonthOf(ctx.date, now)) continue;
      if (ctx.type == 'addition') income += ctx.amount;
      if (ctx.type == 'expense') expense += ctx.amount;
    }
    final rawPnl = income - expense;
    final liabilityDrag = totalBorrowedLiability;
    // Only allow going below zero when borrowed amount exceeds gross income
    if (liabilityDrag > income) {
      return rawPnl - liabilityDrag;
    }
    return rawPnl.clamp(0.0, double.infinity);
  }

  /// All-time P/L. Baseline = initial detected bank balances at first boot.
  /// Can only be negative if borrowed liabilities exceed total current assets.
  double get overallPnl {
    double baseline = 0;
    if (_transactions.isNotEmpty) {
      final Map<String, double> earliestBalances = {};
      final sorted = List<AppTransaction>.from(_transactions)
        ..sort((a, b) => a.date.compareTo(b.date));
      for (final tx in sorted) {
        if (!earliestBalances.containsKey(tx.name) && tx.totalBalance > 0) {
          earliestBalances[tx.name] = tx.totalBalance;
        }
      }
      baseline = earliestBalances.values.fold(0.0, (s, v) => s + v);
    }
    final currentAssets = _totalBalance;
    final rawPnl = currentAssets - baseline;
    final liabilityDrag = totalBorrowedLiability;
    final adjustedPnl = rawPnl - liabilityDrag;
    if (liabilityDrag > currentAssets) {
      return adjustedPnl;
    }
    return adjustedPnl.clamp(0.0, double.infinity);
  }

  // ── Dashboard Banner Helpers ──────────────────
  Map<String, dynamic>? get mostExpenseToday => _cachedMostExpenseToday;
  Map<String, dynamic>? get mostExpenseThisMonth => _cachedMostExpenseThisMonth;
  Map<String, dynamic>? get topExpenseHighlight => _cachedTopExpenseHighlight;

  AppSender? get mostAffectedAccount {
    if (_senders.isEmpty) return null;

    // Logic: Account with highest transaction count or latest transaction
    Map<String, int> counts = {};
    Map<String, DateTime> latestTimes = {};

    for (var tx in _transactions) {
      counts[tx.name] = (counts[tx.name] ?? 0) + 1;
      if (latestTimes[tx.name] == null ||
          tx.date.isAfter(latestTimes[tx.name]!)) {
        latestTimes[tx.name] = tx.date;
      }
    }

    AppSender? winner;
    int maxCount = -1;
    DateTime? maxDate;

    for (var sender in _senders) {
      int count = counts[sender.senderName] ?? 0;
      DateTime? date = latestTimes[sender.senderName];

      if (count > maxCount) {
        maxCount = count;
        winner = sender;
        maxDate = date;
      } else if (count == maxCount &&
          count > 0 &&
          date != null &&
          maxDate != null) {
        if (date.isAfter(maxDate)) {
          winner = sender;
          maxDate = date;
        }
      }
    }

    return winner ?? (_senders.isNotEmpty ? _senders.first : null);
  }

  AppSender? get lessAffectedAccount {
    if (_senders.isEmpty) return null;

    Map<String, int> counts = {};
    for (var tx in _transactions) {
      counts[tx.name] = (counts[tx.name] ?? 0) + 1;
    }

    AppSender? winner;
    int minCount = 999999;

    for (var sender in _senders) {
      int count = counts[sender.senderName] ?? 0;
      if (count < minCount) {
        minCount = count;
        winner = sender;
      }
    }

    return winner;
  }

  Future<void> requestPermission() async {
    _hasPermission = await SmsService().requestPermission();
    if (_hasPermission) {
      _initForegroundSmsListener();
      // Re-init when permission is granted
      await init();
    } else {
      notifyListeners();
    }
  }

  Future<bool> requestStoragePermission() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  Future<void> completeOnboarding() async {
    _isOnboardingComplete = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_onboarding_complete_v1', true);
    // If startBackgroundInit() already loaded the data (_isLoading == false),
    // we just flip onboardingComplete and start the sync — no need to re-scan.
    if (!_isLoading && _transactions.isNotEmpty) {
      _startLightweightDbSync();
      notifyListeners();
      return;
    }
    // Otherwise run the full init (this covers the edge case where SMS was
    // not granted before reaching this point).
    await init();
  }

  void setScreenIndex(int index) {
    if (_currentScreenIndex == index) return;
    _currentScreenIndex = index;
    notifyListeners();
  }

  void toggleIsMenuOpen() {
    _isMenuOpen = !_isMenuOpen;
    notifyListeners();
  }

  void setIsMenuOpen(bool value) {
    if (_isMenuOpen == value) return;
    _isMenuOpen = value;
    notifyListeners();
  }

  void toggleBalanceVisibility() {
    _isBalanceVisible = !_isBalanceVisible;
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    _isShowingAll = false;
    _calculateStats();
    notifyListeners();
  }

  void setShowingAll() {
    _isShowingAll = true;
    _calculateStats();
    notifyListeners();
  }

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);

    // Load onboarding state first.
    final prefs = await SharedPreferences.getInstance();
    _isOnboardingComplete = prefs.getBool('is_onboarding_complete_v1') ?? false;
    _userName = prefs.getString('user_name_v1');
    // Restore the level the user has already been congratulated for, so we
    // don't re-fire the modal after a cold restart.
    _lastSeenLevel = prefs.getInt('last_seen_level') ?? 1;

    if (!_isOnboardingComplete) {
      _isLoading = false;
      notifyListeners();
      return; // Stay on OnboardingScreen; nothing to load yet.
    }

    _hasPermission = await Permission.sms.status.isGranted;

    if (!_hasPermission) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    _initForegroundSmsListener();

    // Load senders from DB or seed defaults
    final dbSenders = await DatabaseService.instance.getSenders();
    if (dbSenders.isNotEmpty) {
      _senders = dbSenders;
      if (!_senders.any((s) => s.senderName.toUpperCase().contains('AHADU'))) {
        final ahadu = AppSender(id: '4', senderName: 'Ahadu Bank');
        await DatabaseService.instance.insertSender(ahadu);
        _senders.add(ahadu);
      }
    } else {
      _senders = [
        AppSender(id: '1', senderName: 'Telebirr'),
        AppSender(id: '2', senderName: 'CBE'),
        AppSender(id: '3', senderName: 'CBE Birr'),
        AppSender(id: '4', senderName: 'Ahadu Bank'),
      ];
      // Seed them into DB for future persistent updates
      for (var s in _senders) {
        await DatabaseService.instance.insertSender(s);
      }
    }

    _pausedBanks = await DatabaseService.instance.getPausedBanks();
    _transactions = await DatabaseService.instance.getTransactions();
    _reasons = await DatabaseService.instance.getReasons();
    _reasonLinks = await DatabaseService.instance.getReasonLinks();
    _expenseDefinitions =
        await DatabaseService.instance.getExpenseDefinitions();
    _cashTransactions = await DatabaseService.instance.getCashTransactions();
    _savingGoals = await DatabaseService.instance.getSavingGoals();
    await _loadLoans();
    await _refreshOverdueStatuses();

    // Auto-apply recurring cash expenses
    await _applyRecurringCashExpenses();

    // 2. Discover last fetch time & Install state
    bool isFirstBoot = prefs.getBool('is_first_boot_v5') ?? true;

    final anchorIso = prefs.getString('custom_month_anchor_date');
    if (anchorIso != null) {
      _customMonthAnchorDate = DateTime.tryParse(anchorIso);
    }

    final savedCurrencyCode = prefs.getString('selected_currency_code') ??
        await DatabaseService.instance.getSetting('selected_currency_code');
    if (savedCurrencyCode != null) {
      _currentCurrency = AppCurrency.fromCode(savedCurrencyCode);
    }

    // The install_anchor_date marks the oldest boundary for message scanning.
    // Refresh NEVER looks at messages older than this date.
    // anchor_version guards against upgrades that stored wrong anchor dates.
    const anchorVersion = 'v4';
    final bool needsAnchorReset =
        prefs.getString('anchor_version') != anchorVersion;
    if (needsAnchorReset) {
      // Anchor = install date MINUS 30 days exactly.
      // The app will never access messages older than 30 days before first launch.
      await prefs.setString('install_anchor_date',
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String());
      await prefs.setString('anchor_version', anchorVersion);
    }

    DateTime? lastTxDate =
        await DatabaseService.instance.getLastTransactionDate();

    if (isFirstBoot && lastTxDate == null) {
      // First boot: fetch messages within the 30-day window before install.
      final installAnchor = DateTime.now().subtract(const Duration(days: 30));
      List<sms_inbox.SmsMessage> allMessages =
          await SmsService().getAllMessages(since: installAnchor);

      // Sort newest first so we pick the most recent message per bank
      allMessages.sort((a, b) {
        if (a.date == null || b.date == null) return 0;
        return b.date!.compareTo(a.date!);
      });

      Set<String> processedSenders = {};
      _isBatchProcessing = true;
      for (var msg in allMessages) {
        if (msg.sender != null && msg.body != null && msg.date != null) {
          final msgDate = msg.date!;

          if (!_isEnglishBankingMessage(msg.body!)) continue;

          final bank = BankSenders.match(msg.sender);

          if (bank == 'Telebirr' && !processedSenders.contains('Telebirr')) {
            AppTransaction? tx = TelebirrParser.parse(msg.body!, msgDate);
            if (tx != null) {
              await addTransaction(tx);
              processedSenders.add('Telebirr');
            }
          } else if (bank == 'CBE Birr' &&
              !processedSenders.contains('CBE Birr')) {
            AppTransaction? tx = CbeBirrParser.parse(msg.body!, msgDate);
            if (tx != null) {
              await addTransaction(tx);
              processedSenders.add('CBE Birr');
            }
          } else if (bank == 'CBE' && !processedSenders.contains('CBE')) {
            // Try to extract name from ANY CBE message during first scan
            if (_userName == null) {
              final name = CbeParser.extractOwnerName(msg.body!);
              if (name != null) {
                _userName = name;
                await prefs.setString('user_name_v1', name);
              }
            }
            AppTransaction? tx = CbeParser.parse(msg.body!, msgDate);
            if (tx != null) {
              await addTransaction(tx);
              processedSenders.add('CBE');
            }
          } else if (bank == 'Ahadu Bank' &&
              !processedSenders.contains('Ahadu Bank')) {
            if (_userName == null) {
              final name = AhaduParser.extractOwnerName(msg.body!);
              if (name != null) {
                _userName = name;
                await prefs.setString('user_name_v1', name);
              }
            }
            AppTransaction? tx = AhaduParser.parse(msg.body!, msgDate);
            if (tx != null) {
              await addTransaction(tx);
              processedSenders.add('Ahadu Bank');
            }
          }
        }
        if (processedSenders.contains('Telebirr') &&
            processedSenders.contains('CBE') &&
            processedSenders.contains('CBE Birr') &&
            processedSenders.contains('Ahadu Bank')) {
          break;
        }
      }
      _isBatchProcessing = false;
      await prefs.setBool('is_first_boot_v5', false);
    }
    // On subsequent opens we do NOT rescan SMS — the background service
    // keeps the database up to date silently. We just load from DB below.

    // Refresh after all updates inserted
    _transactions = await DatabaseService.instance.getTransactions();
    await _loadNotifications();

    // NOTE: We do NOT set up a duplicate SMS listener here.
    // The background service (background_service.dart) already listens for
    // incoming SMS via Telephony and writes new transactions to the DB.
    // Running a second listener would cause double processing, double CPU,
    // and double battery drain.

    _calculateStats();
    _isLoading = false;

    // Track current transaction count for lightweight DB sync
    _lastKnownTxCount = _transactions.length;

    // Start a lightweight DB sync that checks for new rows periodically.
    // This catches transactions inserted by the background service isolate.
    _startLightweightDbSync();

    // Sync _lastSeenLevel to current level without firing the modal —
    // this is a restore, not a new level advance.
    _lastSeenLevel = userLevel;
    await SharedPreferences.getInstance().then(
        (p) => p.setInt('last_seen_level', _lastSeenLevel));
    _levelDetectionReady = true;

    notifyListeners();
  }

  /// Lightweight periodic DB sync.
  /// Checks SQLite counts every 4 seconds with minimal overhead to catch background insertions.
  void _startLightweightDbSync() {
    _dbSyncTimer?.cancel();
    _dbSyncTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      await _checkDbForNewTransactions();
    });
  }



  Future<void> _checkDbForNewTransactions() async {
    if (!_hasPermission) return;

    // Quick count query — near-zero CPU cost
    final currentTxCount = await DatabaseService.instance.getTransactionCount();
    final currentNotifCount =
        await DatabaseService.instance.getNotificationCount();

    if (currentTxCount != _lastKnownTxCount ||
        currentNotifCount != _lastKnownNotificationCount) {
      // Background service inserted new transactions or notifications — reload
      await _reloadFromDatabase();
    }
  }

  Future<void> loadSenders() async {
    final fromDb = await DatabaseService.instance.getSenders();
    if (fromDb.isNotEmpty) {
      _senders = fromDb;
    }
    notifyListeners();
  }

  Future<void> updateSender(AppSender sender) async {
    await DatabaseService.instance.updateSender(sender);
    final index = _senders.indexWhere((s) => s.id == sender.id);
    if (index != -1) {
      _senders[index] = sender;
    }
    notifyListeners();
  }

  // ── Load loans helper ─────────────────────────────────────────────────────
  Future<void> _loadLoans() async {
    _loanRecords = await DatabaseService.instance.getLoanRecords();
    _loanPayments = {};
    for (final loan in _loanRecords) {
      _loanPayments[loan.id!] =
          await DatabaseService.instance.getPaymentsForLoan(loan.id!);
    }
    _pendingRepaymentRequests =
        await DatabaseService.instance.getPendingRepaymentRequests();
  }

  /// Refresh statuses for active loans whose due date has passed.
  Future<void> _refreshOverdueStatuses() async {
    bool changed = false;
    for (int i = 0; i < _loanRecords.length; i++) {
      final loan = _loanRecords[i];
      if (loan.status == 'active' &&
          DateTime.now().isAfter(loan.dueDate) &&
          !loan.isPaid) {
        final updated = loan.copyWith(status: 'overdue');
        await DatabaseService.instance.updateLoanRecord(updated);
        _loanRecords[i] = updated;
        changed = true;
        // Notify the user
        await addUnrecognizedNotification(
          sender: 'Loan Alert',
          body: loan.loanType == 'lent'
              ? '🔔 ${loan.personName} owes you ${loan.remainingAmount.toStringAsFixed(2)} ETB — repayment was due!'
              : '🔔 Your loan from ${loan.personName} is overdue — ${loan.remainingAmount.toStringAsFixed(2)} ETB remaining.',
          date: DateTime.now(),
        );
      }
    }
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _dbSyncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground — reload any transactions the background service
      // inserted while we were away, then restart the sync timer.
      _reloadFromDatabase();
      if (!(_dbSyncTimer?.isActive ?? false)) {
        _startLightweightDbSync();
      }
    } else if (state == AppLifecycleState.paused) {
      // App moved to background — stop the polling timer to save CPU/battery.
      _dbSyncTimer?.cancel();
    }
  }

  Future<void> _reloadFromDatabase() async {
    _transactions = await DatabaseService.instance.getTransactions();
    _expenseDefinitions =
        await DatabaseService.instance.getExpenseDefinitions();
    _cashTransactions = await DatabaseService.instance.getCashTransactions();
    await _loadNotifications();
    await _applyRecurringCashExpenses();
    _lastKnownTxCount = _transactions.length;
    _lastKnownNotificationCount = _notifications.length;
    _calculateStats();
    notifyListeners();
  }

  /// Checks whether the user has crossed into a new level since the last time
  /// we showed the celebration modal. If so, shows it via the global navigator.
  Future<void> _maybeFireLevelUpModal() async {
    if (!_levelDetectionReady || _isBatchProcessing) return;
    final currentLevel = userLevel;
    if (currentLevel <= _lastSeenLevel) return; // no level advance

    // Level advance detected! Update persisted value IMMEDIATELY so duplicate triggers are blocked
    _lastSeenLevel = currentLevel;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_seen_level', currentLevel);

    // Schedule on post-frame to ensure current build/layout cycle is finished before opening modal sheet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = appNavigatorKey.currentContext;
      if (navContext != null) {
        showLevelUpModal(
          navContext,
          newLevel: currentLevel,
          newLevelName: userLevelName,
          newLevelDescription: userLevelDescription,
          nextLevelName: nextLevelName,
          nextLevelProgress: nextLevelProgress,
        );
      }
    });
  }

  /// Re-scans SMS and ingests any new transactions.
  ///
  /// [lastDays] limits the scan to the most recent N days (e.g. 7 or 30).
  /// When null, scans the full range since the install anchor. The cutoff is
  /// never earlier than the install anchor, so pre-install messages stay
  /// excluded regardless of the chosen window.
  Future<void> refreshData({int? lastDays}) async {
    final prefs = await SharedPreferences.getInstance();

    // Use the install anchor date so we scan the FULL range since install,
    // catching any messages that fell in gaps between already-stored transactions.
    final anchorStr = prefs.getString('install_anchor_date');
    final DateTime? anchorDate =
        anchorStr != null ? DateTime.tryParse(anchorStr) : null;

    if (anchorDate == null) {
      // No anchor yet means first boot hasn't completed — nothing to do
      return;
    }

    // Narrow to the requested window when provided, but never scan earlier
    // than the install anchor.
    DateTime cutoff = anchorDate;
    if (lastDays != null) {
      final windowStart = DateTime.now().subtract(Duration(days: lastDays));
      if (windowStart.isAfter(anchorDate)) cutoff = windowStart;
    }

    // Fetch every SMS from known senders since the cutoff
    // (subtract 1 min buffer to be safe at boundaries)
    cutoff = cutoff.subtract(const Duration(minutes: 1));
    List<sms_inbox.SmsMessage> messages =
        await SmsService().getAllMessages(since: cutoff);

    // Sort oldest-first so transactions are inserted chronologically
    messages.sort((a, b) {
      if (a.date == null || b.date == null) return 0;
      return a.date!.compareTo(b.date!);
    });

    // Enable batch mode to prevent addTransaction from calling
    // _calculateStats() + notifyListeners() for each individual message.
    // We'll do it once at the end.
    _isBatchProcessing = true;
    for (var msg in messages) {
      if (msg.sender != null && msg.body != null && msg.date != null) {
        await processNewSms(msg.sender!, msg.body!, msg.date!);
      }
    }
    _isBatchProcessing = false;

    final results = await Future.wait([
      DatabaseService.instance.getTransactions(),
      DatabaseService.instance.getExpenseDefinitions(),
      DatabaseService.instance.getCashTransactions(),
      _loadNotifications(),
      _applyRecurringCashExpenses(),
      DatabaseService.instance.getTransactionCount(),
      DatabaseService.instance.getNotificationCount(),
    ]);

    _transactions = results[0] as List<AppTransaction>;
    _expenseDefinitions = results[1] as List<ExpenseDefinition>;
    _cashTransactions = results[2] as List<CashTransaction>;
    _lastKnownTxCount = results[5] as int;
    _lastKnownNotificationCount = results[6] as int;

    _calculateStats();
    await _maybeFireLevelUpModal();
    notifyListeners();
  }

  bool _isAmharicMessage(String text) {
    if (text.isEmpty) return false;
    return RegExp(r'[\u1200-\u137F]').hasMatch(text);
  }

  Future<void> _loadNotifications() async {
    final all = await DatabaseService.instance.getNotifications();
    final Set<String> registeredMessages = _transactions
        .map((t) => t.rawMessage.trim())
        .where((msg) => msg.isNotEmpty)
        .toSet();

    final List<AppNotification> filtered = [];
    final List<String> idsToDelete = [];

    for (final n in all) {
      final isSystemAlert = n.sender.startsWith('Loan') ||
          n.sender.startsWith('System') ||
          n.sender.startsWith('⚠️') ||
          n.sender.contains('✅');

      if (!isSystemAlert) {
        final bodyTrimmed = n.body.trim();

        // 1. Ignore Amharic messages completely
        if (_isAmharicMessage(n.body)) {
          idsToDelete.add(n.id);
          continue;
        }

        // 2. Ignore password, PIN, OTP, and security authentication messages
        if (BankSenders.isSecurityOrAuthMessage(n.body)) {
          idsToDelete.add(n.id);
          continue;
        }

        // 3. Ignore non-English banking messages
        if (!_isEnglishBankingMessage(n.body)) {
          idsToDelete.add(n.id);
          continue;
        }

        // 3. Ignore messages that are ALREADY registered as transactions in the app
        if (registeredMessages.contains(bodyTrimmed)) {
          idsToDelete.add(n.id);
          continue;
        }

        // 4. Ignore messages that CAN be auto-parsed into transactions
        if (TelebirrParser.parse(n.body, n.date) != null ||
            TelebirrParser.isCreditDisbursement(n.body) ||
            TelebirrParser.isCreditRepayment(n.body) ||
            CbeParser.parse(n.body, n.date) != null ||
            CbeBirrParser.parse(n.body, n.date) != null ||
            AhaduParser.parse(n.body, n.date) != null) {
          idsToDelete.add(n.id);
          continue;
        }
      }

      filtered.add(n);
    }

    // Asynchronously delete stale/already-registered notifications from SQLite
    for (final id in idsToDelete) {
      DatabaseService.instance.deleteNotification(id);
    }

    _notifications = filtered;
    _unreadNotificationCount = _notifications.where((n) => !n.isRead).length;
    _lastKnownNotificationCount = _notifications.length;
  }

  Future<void> markNotificationsRead() async {
    await DatabaseService.instance.markAllNotificationsRead();
    _unreadNotificationCount = 0;
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = AppNotification(
        id: _notifications[i].id,
        sender: _notifications[i].sender,
        body: _notifications[i].body,
        date: _notifications[i].date,
        isRead: true,
      );
    }
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    await DatabaseService.instance.deleteNotification(id);
    _notifications.removeWhere((n) => n.id == id);
    _unreadNotificationCount =
        await DatabaseService.instance.getUnreadNotificationCount();
    notifyListeners();
  }

  /// Permanently ignores a notification — it will never reappear even after refresh.
  Future<void> ignoreNotification(String id) async {
    // 1. Delete from visible list and DB
    await deleteNotification(id);
    // 2. Persist the ignored ID so addUnrecognizedNotification skips it forever
    final prefs = await SharedPreferences.getInstance();
    final ignored = prefs.getStringList('ignored_notification_ids') ?? [];
    if (!ignored.contains(id)) {
      ignored.add(id);
      await prefs.setStringList('ignored_notification_ids', ignored);
    }
  }

  /// Returns true if [msg] looks like a banking message (contains an English
  /// banking keyword). Bilingual messages that mix Amharic with English
  /// transaction text (e.g. CBE Birr) are kept \u2014 only messages with no English
  /// banking keyword at all are dropped.
  static bool _isEnglishBankingMessage(String msg) {
    const keywords = [
      // --- Deposit & Credit Actions ---
      'deposit',
      'deposited',
      'credited',
      'credit',
      'topup',
      'top-up',
      'top up',
      'recharge',
      'recharged',
      'received',
      'receive',
      'inward',

      // --- Transfer & Send Actions ---
      'transfer',
      'transferred',
      'sent',
      'send',
      'remittance',
      'p2p',

      // --- Debit & Payment Actions ---
      'paid',
      'pay',
      'payment',
      'debited',
      'debit',
      'withdrawn',
      'withdrawal',
      'withdraw',
      'purchase',
      'purchased',
      'spent',
      'spend',
      'outward',
      'charged',
      'charge',
      'fee',
      'deducted',
      'deduction',

      // --- Balance & Account Terms ---
      'balance',
      'bal',
      'avail',
      'available',
      'remaining',
      'rem bal',
      'account',
      'acct',
      'acc',
      'wallet',

      // --- Currencies & Numbers ---
      'birr',
      'etb',
      'usd',
      'amount',
      'total',
      'sum',

      // --- Loan & Credit Line Terms ---
      'loan',
      'repay',
      'repayment',
      'borrow',
      'borrowed',
      'disbursed',
      'disbursement',
      'due',
      'overdue',
      'installment',

      // --- Transaction Reference IDs ---
      'transaction',
      'txn',
      'txnd',
      'ref',
      'reference',
      'receipt',
    ];

    final lower = msg.toLowerCase();
    return keywords.any((kw) => lower.contains(kw));
  }

  Future<void> addUnrecognizedNotification({
    required String sender,
    required String body,
    required DateTime date,
  }) async {
    // ── Loan/System messages always pass through (internal app alerts) ──────
    final isSystemAlert = sender.startsWith('Loan') ||
        sender.startsWith('System') ||
        sender.startsWith('⚠️') ||
        sender.contains('✅');

    // ── External SMS: ignore Amharic messages, security auth & non-financial messages ─────
    if (!isSystemAlert && _isAmharicMessage(body)) return;
    if (!isSystemAlert && BankSenders.isSecurityOrAuthMessage(body)) return;
    if (!isSystemAlert && !_isEnglishBankingMessage(body)) return;

    // Do NOT add if message is already registered as a transaction in the app
    if (!isSystemAlert &&
        _transactions.any((tx) => tx.rawMessage.trim() == body.trim())) {
      return;
    }

    // Do NOT add if message is auto-parsable into a transaction
    if (!isSystemAlert) {
      if (TelebirrParser.parse(body, date) != null ||
          TelebirrParser.isCreditDisbursement(body) ||
          TelebirrParser.isCreditRepayment(body) ||
          CbeParser.parse(body, date) != null ||
          CbeBirrParser.parse(body, date) != null ||
          AhaduParser.parse(body, date) != null) {
        return;
      }
    }

    final id = '${sender}_${date.millisecondsSinceEpoch}';

    // Check if this message was permanently ignored by the user
    final prefs = await SharedPreferences.getInstance();
    final ignored = prefs.getStringList('ignored_notification_ids') ?? [];
    if (ignored.contains(id)) return; // silently skip — user said ignore

    final notification = AppNotification(
      id: id,
      sender: sender,
      body: body,
      date: date,
    );
    await DatabaseService.instance.insertNotification(notification);
    _notifications.insert(0, notification);
    _unreadNotificationCount++;
    notifyListeners();

    // Show actual OS push notification for system messages
    if (sender.startsWith('Loan') || sender.startsWith('System')) {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.show(
        id: DateTime.now().millisecond,
        title: sender,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_foreground',
            'Mobile Banking Service',
            icon: 'ic_notification',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
  }

  Map<String, dynamic>? _computeTopReasonMap(Map<String, double> totals) {
    if (totals.isEmpty) return null;
    String topReason = totals.keys.first;
    double maxAmount = totals[topReason]!;
    totals.forEach((key, value) {
      if (value > maxAmount) {
        maxAmount = value;
        topReason = key;
      }
    });
    return {'reason': topReason, 'amount': maxAmount};
  }

  void _calculateStats() {
    _totalBalance = 0;
    _cashBalance = 0;
    _incomeThisMonth = 0;
    _expenseThisMonth = 0;
    _incomeForSelectedDate = 0;
    _expenseForSelectedDate = 0;
    _netForSelectedDate = 0;
    _incomePercentageChange = 0;
    _netOverall = 0;
    _percentageChangeOverall = 0;
    _todayTransactionCount = 0;

    DateTime now = DateTime.now();
    Map<String, double> latestBalances = {};
    double cashInflows = 0;
    double cashOutflows = 0;

    final pausedUpper = _pausedBanks.map((b) => b.toUpperCase()).toSet();
    final Map<String, double> todayReasonTotals = {};
    final Map<String, double> monthReasonTotals = {};
    final Map<String, double> overallReasonTotals = {};

    // Single pass through transactions to collect all necessary data
    for (var tx in _transactions) {
      // Skip transactions from paused banks entirely so they don't affect
      // balance, income/expense totals, or any other aggregation.
      if (pausedUpper.contains(tx.name.toUpperCase())) {
        continue;
      }

      // 1. Balance Tracking (Newest per bank)
      if (!latestBalances.containsKey(tx.name)) {
        if (tx.totalBalance > 0) {
          latestBalances[tx.name] = tx.totalBalance;
        }
      }

      // 2. Date checks
      bool isToday = tx.date.year == now.year &&
          tx.date.month == now.month &&
          tx.date.day == now.day;
      if (isToday) {
        _todayTransactionCount++;
      }

      bool isSelectedDay = _isShowingAll ||
          (tx.date.year == _selectedDate.year &&
              tx.date.month == _selectedDate.month &&
              tx.date.day == _selectedDate.day);

      bool isThisMonth = isDateInMonthOf(tx.date, now);

      // 3. Category & Cash Logic
      final resolvedReasonLower = tx.resolvedReason?.toLowerCase();
      bool isBounce = resolvedReasonLower == 'bounce' ||
          resolvedReasonLower == 'internal transfer';

      bool isCashTransfer = tx.reason?.toLowerCase() == 'cash' ||
          tx.customReasonText?.toLowerCase() == 'cash' ||
          resolvedReasonLower == 'cash';

      if (isCashTransfer) {
        // ATM withdrawal (bank expense) is a CASH INFLOW to the wallet.
        // Cash deposit (bank income) is a CASH OUTFLOW from the wallet.
        if (tx.type == 'expense') {
          cashInflows += tx.amount.abs();
        } else {
          cashOutflows += tx.amount.abs();
        }
      }

      if (isBounce) continue;

      // 4. Summaries (exclude cash transfers from net wealth change as they are internal)
      if (tx.type == 'income') {
        if (isThisMonth && !isCashTransfer) {
          _incomeThisMonth += tx.amount;
        }
        if (isSelectedDay && !isCashTransfer) {
          _incomeForSelectedDate += tx.amount;
        }
        if (!isCashTransfer) {
          _netOverall += tx.amount;
        }
      } else if (tx.type == 'expense') {
        if (isThisMonth && !isCashTransfer) {
          _expenseThisMonth += tx.amount;
        }
        if (isSelectedDay && !isCashTransfer) {
          _expenseForSelectedDate += tx.amount;
        }
        if (!isCashTransfer) {
          _netOverall -= tx.amount;
        }

        // Track expense reason totals for dashboard banner cards
        final key = tx.resolvedReason ?? 'Other';
        if (isToday) {
          todayReasonTotals[key] = (todayReasonTotals[key] ?? 0) + tx.amount;
        }
        if (isThisMonth) {
          monthReasonTotals[key] = (monthReasonTotals[key] ?? 0) + tx.amount;
        }
        overallReasonTotals[key] = (overallReasonTotals[key] ?? 0) + tx.amount;
      }
    }

    _cachedMostExpenseToday = _computeTopReasonMap(todayReasonTotals);
    _cachedMostExpenseThisMonth = _computeTopReasonMap(monthReasonTotals);
    _cachedTopExpenseHighlight = _computeTopReasonMap(overallReasonTotals);

    // Process latest bank balances
    _latestBalancesMap = Map.from(latestBalances);
    for (var value in latestBalances.values) {
      _totalBalance += value;
    }

    // Process Cash Transactions (Manual additions/deductions)
    for (var ctx in _cashTransactions) {
      bool isThisMonth = isDateInMonthOf(ctx.date, now);
      bool isSelectedDay = _isShowingAll ||
          (ctx.date.year == _selectedDate.year &&
              ctx.date.month == _selectedDate.month &&
              ctx.date.day == _selectedDate.day);

      if (ctx.type == 'addition') {
        cashInflows += ctx.amount; // manual injections are inflows
        _netOverall += ctx.amount;
        if (isThisMonth) _incomeThisMonth += ctx.amount;
        if (isSelectedDay) _incomeForSelectedDate += ctx.amount;
      } else if (ctx.type == 'expense') {
        cashOutflows += ctx.amount;
        _netOverall -= ctx.amount;
        if (isThisMonth) _expenseThisMonth += ctx.amount;
        if (isSelectedDay) _expenseForSelectedDate += ctx.amount;
      }
    }

    _cashBalance = cashInflows - cashOutflows;
    if (_cashBalance > 0) {
      _totalBalance += _cashBalance;
    }

    _netForSelectedDate = _incomeForSelectedDate - _expenseForSelectedDate;

    // Percentage for summary card
    if (_totalBalance > 0) {
      _incomePercentageChange = (_netForSelectedDate / _totalBalance) * 100;
      _incomePercentageChange = _incomePercentageChange.clamp(-100.0, 100.0);

      _percentageChangeOverall = (_netOverall / _totalBalance) * 100;
      _percentageChangeOverall = _percentageChangeOverall.clamp(-100.0, 100.0);
    }

    if (!_isBatchProcessing && _levelDetectionReady) {
      _maybeFireLevelUpModal();
    }
  }

  Future<void> addSender(AppSender sender) async {
    int id = await DatabaseService.instance.insertSender(sender);
    _senders.add(
      AppSender(
        id: id.toString(),
        senderName: sender.senderName,
        depositKeywords: sender.depositKeywords,
        expenseKeywords: sender.expenseKeywords,
      ),
    );
    notifyListeners();
  }

  /// Returns the current latest total balance recorded for a given bank / sender name.
  double getLatestBalanceForBank(String bankName) {
    for (final tx in _transactions) {
      if (tx.name.toUpperCase() == bankName.toUpperCase() && tx.totalBalance > 0) {
        return tx.totalBalance;
      }
    }
    return 0.0;
  }

  Future<void> addTransaction(AppTransaction transaction) async {
    AppTransaction txToInsert = transaction;

    // Auto-calculate post-balance (totalBalance) if not provided or 0
    if (txToInsert.totalBalance == 0) {
      final double currentBalance = getLatestBalanceForBank(txToInsert.name);
      final double newPostBalance = txToInsert.type == 'income'
          ? (currentBalance + txToInsert.amount)
          : (currentBalance - txToInsert.amount);
      txToInsert = txToInsert.copyWith(
          totalBalance: newPostBalance > 0 ? newPostBalance : 0.0);
    }

    // Auto-categorize: check if sender matches a linked reason rule
    if (txToInsert.reasonId == null && txToInsert.customReasonText == null) {
      final autoReason = await DatabaseService.instance
          .findAutoReason(txToInsert.sender, txToInsert.type);
      if (autoReason != null) {
        txToInsert = txToInsert.copyWith(
            reasonId: autoReason.id, reason: autoReason.name);
      }
    }

    final rowId = await DatabaseService.instance.insertTransaction(txToInsert);

    // rowId == 0 means ConflictAlgorithm.ignore silently skipped the insert
    // (the transaction already exists in the DB). Do NOT add it to the in-memory
    // list a second time, and do NOT re-trigger loan-repayment detection — that
    // would generate duplicate "approval needed" notifications on every refresh.
    if (rowId == 0) return;

    _transactions.insert(0, txToInsert);

    // ─ Auto-detect loan repayment if this is a NEW income SMS ─
    if (txToInsert.type == 'income') {
      await _checkAndApplyLoanRepayment(txToInsert);
    }

    // Skip stats recalculation during batch processing (e.g. refreshData)
    // to avoid N expensive recalculations — the caller will do it once at the end.
    if (!_isBatchProcessing) {
      _calculateStats();
      notifyListeners();
    }
  }


  /// Update a transaction with a reusable reason [reasonId] OR a one-time [customReasonText].
  /// Pass reasonId=null and customReasonText with a value for one-time.
  /// Pass reasonId with a value for a saved reason.
  Future<void> updateTransactionReason(
    String transactionId, {
    int? reasonId,
    String? customReasonText,
  }) async {
    final index = _transactions.indexWhere((t) => t.id == transactionId);
    if (index == -1) return;
    final oldTx = _transactions[index];

    String? resolvedName;
    if (reasonId != null) {
      final r = _reasons.firstWhere((r) => r.id == reasonId,
          orElse: () => AppReason(name: ''));
      resolvedName = r.name.isNotEmpty ? r.name : null;
    }

    final newTx = AppTransaction(
      id: oldTx.id,
      name: oldTx.name,
      amount: oldTx.amount,
      type: oldTx.type,
      date: oldTx.date,
      sender: oldTx.sender,
      category: oldTx.category,
      rawMessage: oldTx.rawMessage,
      isAutoDetected: oldTx.isAutoDetected,
      totalBalance: oldTx.totalBalance,
      reasonId: reasonId,
      customReasonText:
          (customReasonText != null && customReasonText.isNotEmpty)
              ? customReasonText
              : null,
      reason: resolvedName,
      linkedTransactionId: oldTx.linkedTransactionId,
    );
    await DatabaseService.instance.updateTransaction(newTx);
    _transactions[index] = newTx;
    _calculateStats();
    notifyListeners();
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

    await DatabaseService.instance.updateTransaction(newTx1);
    await DatabaseService.instance.updateTransaction(newTx2);

    _transactions[idx1] = newTx1;
    _transactions[idx2] = newTx2;

    _calculateStats();
    notifyListeners();
  }

  /// Removes the internal transfer link from a transaction (and its counterpart).
  Future<void> unlinkInternalTransfer(String txId) async {
    final idx = _transactions.indexWhere((t) => t.id == txId);
    if (idx == -1) return;

    final tx = _transactions[idx];
    final linkedId = tx.linkedTransactionId;

    // Clear this transaction's link
    final unlinkedTx = tx.copyWith(clearLinkedTransactionId: true);
    await DatabaseService.instance.updateTransaction(unlinkedTx);
    _transactions[idx] = unlinkedTx;

    // Also clear the counterpart's link
    if (linkedId != null) {
      final idx2 = _transactions.indexWhere((t) => t.id == linkedId);
      if (idx2 != -1) {
        final unlinkedTx2 =
            _transactions[idx2].copyWith(clearLinkedTransactionId: true);
        await DatabaseService.instance.updateTransaction(unlinkedTx2);
        _transactions[idx2] = unlinkedTx2;
      }
    }

    _calculateStats();
    notifyListeners();
  }


  Future<void> loadReasons() async {
    _reasons = await DatabaseService.instance.getReasons();
    _reasonLinks = await DatabaseService.instance.getReasonLinks();
    notifyListeners();
  }

  Future<AppReason> addReason(String name) async {
    final id = await DatabaseService.instance
        .insertReason(AppReason(name: name, isSystem: false));
    final newReason = AppReason(id: id, name: name, isSystem: false);
    _reasons.add(newReason);
    notifyListeners();
    return newReason;
  }

  Future<void> editReason(AppReason reason, String newName) async {
    final updated = reason.copyWith(name: newName);
    await DatabaseService.instance.updateReason(updated);
    final idx = _reasons.indexWhere((r) => r.id == reason.id);
    if (idx != -1) _reasons[idx] = updated;
    notifyListeners();
  }

  Future<void> deleteReason(int id) async {
    await DatabaseService.instance.deleteReason(id);
    _reasons.removeWhere((r) => r.id == id);
    _reasonLinks.removeWhere((l) => l.reasonId == id);
    notifyListeners();
  }

  Future<void> addReasonLink(
      {required int reasonId,
      required String linkedName,
      required String linkType}) async {
    final lowerName = linkedName.toLowerCase();

    // 1. Remove any existing link for exactly this name and type (so we override)
    final existingLinksToRemove = _reasonLinks
        .where((l) =>
            l.linkedName.toLowerCase() == lowerName && l.linkType == linkType)
        .toList();
    for (var l in existingLinksToRemove) {
      await deleteReasonLink(l.id!);
    }

    // 2. Add the new link
    final id = await DatabaseService.instance.insertReasonLink(AppReasonLink(
        reasonId: reasonId, linkedName: linkedName, linkType: linkType));
    _reasonLinks.add(AppReasonLink(
        id: id,
        reasonId: reasonId,
        linkedName: linkedName,
        linkType: linkType));

    // 3. Retroactively apply this new reason to all matching existing transactions
    final r = _reasons.firstWhere((r) => r.id == reasonId,
        orElse: () => AppReason(name: ''));
    if (r.name.isNotEmpty) {
      bool updated = false;
      for (int i = 0; i < _transactions.length; i++) {
        final tx = _transactions[i];
        final expectedLinkType = tx.type == 'income' ? 'sender' : 'receiver';

        if (tx.sender.toLowerCase() == lowerName &&
            expectedLinkType == linkType) {
          final newTx = tx.copyWith(
            reasonId: reasonId,
            reason: r.name,
            clearCustomReason: true, // override one-time reasons too
          );
          await DatabaseService.instance.updateTransaction(newTx);
          _transactions[i] = newTx;
          updated = true;
        }
      }
      if (updated) {
        _calculateStats();
      }
    }

    notifyListeners();
  }

  Future<void> deleteReasonLink(int id) async {
    await DatabaseService.instance.deleteReasonLink(id);
    _reasonLinks.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  List<AppReasonLink> linksForReason(int reasonId) =>
      _reasonLinks.where((l) => l.reasonId == reasonId).toList();

  // ── Loan Management ───────────────────────────────────────────────────────

  Future<LoanRecord> createLoan({
    required String loanType,
    required String personName,
    String? trackedSenderName,
    required double principalAmount,
    required DateTime dueDate,
    String? linkedTransactionId,
    String? note,
  }) async {
    // Determine the loan creation date
    DateTime startingDate = DateTime.now();
    if (linkedTransactionId != null) {
      final idx = _transactions.indexWhere((t) => t.id == linkedTransactionId);
      if (idx != -1) {
        startingDate = _transactions[idx].date;
      }
    }

    final loan = LoanRecord(
      loanType: loanType,
      personName: personName,
      trackedSenderName: trackedSenderName,
      principalAmount: principalAmount,
      loanDate: startingDate,
      dueDate: dueDate,
      linkedTransactionId: linkedTransactionId,
      note: note,
    );
    final id = await DatabaseService.instance.insertLoanRecord(loan);
    final withId = LoanRecord(
      id: id,
      loanType: loan.loanType,
      personName: loan.personName,
      trackedSenderName: loan.trackedSenderName,
      principalAmount: loan.principalAmount,
      paidAmount: 0,
      loanDate: loan.loanDate,
      dueDate: loan.dueDate,
      linkedTransactionId: loan.linkedTransactionId,
      status: 'active',
      note: loan.note,
    );
    _loanRecords.insert(0, withId);
    _loanPayments[id] = [];

    // Auto-assign the 'Loan' reason to the original triggering transaction
    if (linkedTransactionId != null) {
      final loanReason = _reasons.cast<AppReason?>().firstWhere(
            (r) => r?.name.toLowerCase() == 'loan',
            orElse: () => null,
          );
      await updateTransactionReason(
        linkedTransactionId,
        reasonId: loanReason?.id,
        customReasonText: loanReason == null ? 'Loan' : null,
      );
    }

    // If the loan has a tracked sender and the loan was created in the past,
    // we should scan memory for transactions that arrived AFTER the loan date
    // and BEFORE now to see if the user already paid it back.
    if (trackedSenderName != null) {
      final potentialRepayments = _transactions
          .where((tx) =>
              tx.type == 'income' &&
              tx.date.isAfter(startingDate) &&
              tx.id != linkedTransactionId)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date)); // Oldest first

      for (var tx in potentialRepayments) {
        // Run it through the exact matching logic
        final score = _nameMatchScore(
          incoming: tx.sender,
          tracked: trackedSenderName,
        );
        // Also try tx.name (bank-extracted name) if sender score is 0
        final nameScore = score == 0
            ? _nameMatchScore(incoming: tx.name, tracked: trackedSenderName)
            : 0;
        final bestScore = score > nameScore ? score : nameScore;

        if (bestScore > 0) {
          final currentLoanState = _loanRecords.firstWhere((l) => l.id == id);
          if (currentLoanState.status == 'active') {
            await _queueRepaymentRequest(
              loan: currentLoanState,
              tx: tx,
              matchType: bestScore == 2 ? 'exact' : 'partial',
            );
          }
        }
      }

      // After historical playback, make sure we reload the pending requests UI array
      _pendingRepaymentRequests =
          await DatabaseService.instance.getPendingRepaymentRequests();
    }

    notifyListeners();
    return withId;
  }

  Future<void> loadLoans() async {
    await _loadLoans();
    notifyListeners();
  }

  Future<void> deleteLoan(int id) async {
    await DatabaseService.instance.deleteLoanRecord(id);
    _loanRecords.removeWhere((l) => l.id == id);
    _loanPayments.remove(id);
    notifyListeners();
  }

  Future<void> updateLoan(LoanRecord loan) async {
    await DatabaseService.instance.updateLoanRecord(loan);
    final idx = _loanRecords.indexWhere((l) => l.id == loan.id);
    if (idx != -1) _loanRecords[idx] = loan;
    notifyListeners();
  }

  Future<void> updateLoanDueDate(int loanId, DateTime newDueDate) async {
    final idx = _loanRecords.indexWhere((l) => l.id == loanId);
    if (idx != -1) {
      final oldLoan = _loanRecords[idx];
      // Recalculate status based on new due date
      String newStatus = oldLoan.status;
      if (oldLoan.status != 'paid') {
        newStatus = DateTime.now().isAfter(newDueDate) ? 'overdue' : 'active';
      }

      final updated = oldLoan.copyWith(dueDate: newDueDate, status: newStatus);
      await DatabaseService.instance.updateLoanRecord(updated);
      _loanRecords[idx] = updated;
      notifyListeners();
    }
  }

  /// Add a manual repayment against a loan.
  Future<void> recordLoanPayment({
    required int loanId,
    required double amount,
    String? note,
    String? linkedTransactionId,
  }) async {
    final payment = LoanPayment(
      loanId: loanId,
      amount: amount,
      paymentDate: DateTime.now(),
      linkedTransactionId: linkedTransactionId,
      note: note,
    );
    await DatabaseService.instance.insertLoanPayment(payment);
    final updated = await DatabaseService.instance.recalcLoanPaid(loanId);
    if (updated != null) {
      final idx = _loanRecords.indexWhere((l) => l.id == loanId);
      if (idx != -1) _loanRecords[idx] = updated;
      _loanPayments[loanId] =
          await DatabaseService.instance.getPaymentsForLoan(loanId);

      // If just reached full payment, add a congratulatory notification
      if (updated.isPaid) {
        await addUnrecognizedNotification(
          sender: 'Loan Complete ✅',
          body: updated.loanType == 'lent'
              ? '${updated.personName} has fully repaid ${updated.principalAmount.toStringAsFixed(2)} ETB!'
              : 'You have fully repaid your loan of ${updated.principalAmount.toStringAsFixed(2)} ETB to ${updated.personName}!',
          date: DateTime.now(),
        );
      } else {
        // Progress update notification
        final pct = (updated.progressPercent * 100).toStringAsFixed(0);
        await addUnrecognizedNotification(
          sender: 'Loan Update',
          body: updated.loanType == 'lent'
              ? '${updated.personName} paid ${amount.toStringAsFixed(2)} ETB (↑$pct% of loan complete). ${updated.remainingAmount.toStringAsFixed(2)} ETB remaining.'
              : 'Payment of ${amount.toStringAsFixed(2)} ETB recorded. $pct% of your loan repaid. ${updated.remainingAmount.toStringAsFixed(2)} ETB left.',
          date: DateTime.now(),
        );
      }
    }
    notifyListeners();
  }

  Future<void> deleteLoanPaymentRecord(int paymentId, int loanId) async {
    await DatabaseService.instance.deleteLoanPayment(paymentId);
    final updated = await DatabaseService.instance.recalcLoanPaid(loanId);
    if (updated != null) {
      final idx = _loanRecords.indexWhere((l) => l.id == loanId);
      if (idx != -1) _loanRecords[idx] = updated;
      _loanPayments[loanId] =
          await DatabaseService.instance.getPaymentsForLoan(loanId);
    }
    notifyListeners();
  }

  /// Scores how well [incoming] matches [tracked].
  ///
  /// Returns:
  ///   2 = high-confidence (exact token match, or first+second names both match)
  ///   1 = low-confidence  (first name is the SAME but rest differs)
  ///   0 = no match        (first names don't match at all → NEVER show)
  ///
  /// Rule: first name MUST match, otherwise score is always 0.
  /// [incoming] and [tracked] may be comma-separated token lists.
  int _nameMatchScore({required String incoming, required String tracked}) {
    if (incoming.trim().isEmpty || tracked.trim().isEmpty) return 0;

    // Normalise: lower-case, strip extra spaces
    String norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    // Split comma-separated multi-bank token lists
    final trackedTokens = tracked
        .split(',')
        .map((t) => norm(t))
        .where((t) => t.isNotEmpty)
        .toList();

    final incomingNorm = norm(incoming);
    final incomingWords = incomingNorm.split(' ');
    final incomingFirst = incomingWords.first;

    int best = 0;

    for (final token in trackedTokens) {
      final tokenWords = token.split(' ');
      final tokenFirst = tokenWords.first;

      // ── GATE: first names must match ─────────────────────────────────────
      if (incomingFirst != tokenFirst) continue; // different first name → skip

      // First names are the same from here on.

      // Score 2: exact full-name match (or one fully contains the other)
      if (incomingNorm == token ||
          incomingNorm.contains(token) ||
          token.contains(incomingNorm)) {
        return 2; // can't do better, return immediately
      }

      // Score 2: first AND second name both match
      if (incomingWords.length >= 2 && tokenWords.length >= 2) {
        if (incomingWords[1] == tokenWords[1]) {
          best = best < 2 ? 2 : best;
          continue;
        }
      }

      // Score 1: only first name matches
      if (best < 1) best = 1;
    }

    return best;
  }

  /// Called when a new income SMS arrives — checks if the sender is tracked
  /// by any active loan and creates a pending approval request.
  ///
  /// RULE: first name MUST match. Transactions with a different first name
  /// are NEVER shown to the user regardless of any other overlap.
  Future<void> _checkAndApplyLoanRepayment(AppTransaction tx) async {
    // Only 'lent' loans are repaid via incoming money.
    // 'borrowed' loans are repaid by the user sending money OUT — those
    // cannot be auto-detected from an income SMS, so they are excluded entirely.
    final allActive = _loanRecords
        .where((l) =>
            l.status == 'active' &&
            l.trackedSenderName != null &&
            l.loanType == 'lent')
        .toList();

    if (allActive.isEmpty) return;

    for (final loan in allActive) {
      // Score against tx.sender (bank sender code) and tx.name (parsed name)
      final senderScore = _nameMatchScore(
        incoming: tx.sender,
        tracked: loan.trackedSenderName!,
      );
      final nameScore = _nameMatchScore(
        incoming: tx.name,
        tracked: loan.trackedSenderName!,
      );
      final best = senderScore > nameScore ? senderScore : nameScore;

      if (best == 0) continue; // first name doesn't match at all — skip

      await _queueRepaymentRequest(
        loan: loan,
        tx: tx,
        matchType: best == 2 ? 'exact' : 'partial',
      );
    }
  }

  /// Creates a pending repayment approval request and notifies the user.
  /// Used for BOTH exact and partial matches — nothing is auto-settled.
  Future<void> _queueRepaymentRequest({
    required LoanRecord loan,
    required AppTransaction tx,
    required String matchType, // 'exact' or 'partial'
  }) async {
    final applicable = tx.amount.clamp(0.0, loan.remainingAmount);
    if (applicable <= 0) return;

    final req = LoanRepaymentRequest(
      loanId: loan.id!,
      transactionId: tx.id ?? '${tx.sender}_${tx.date.millisecondsSinceEpoch}',
      senderFound: tx.sender,
      trackedName: loan.trackedSenderName!,
      amount: applicable,
      createdAt: DateTime.now(),
    );
    await DatabaseService.instance.insertLoanRepaymentRequest(req);
    _pendingRepaymentRequests =
        await DatabaseService.instance.getPendingRepaymentRequests();

    final matchLabel = matchType == 'exact' ? 'exact match' : 'possible match';
    await addUnrecognizedNotification(
      sender: '⚠️ Loan Match — Approval Needed',
      body: '"${tx.sender}" sent ${tx.amount.toStringAsFixed(2)} ETB '
          '($matchLabel for "${loan.trackedSenderName}" — ${loan.personName}). '
          'Go to Loans → Pending to approve or reject.',
      date: DateTime.now(),
    );
    notifyListeners();
  }

  /// Approve a pending repayment request — records the payment on the loan.
  Future<void> approveLoanRepaymentRequest(LoanRepaymentRequest req) async {
    final loan = await DatabaseService.instance.getLoanById(req.loanId);
    if (loan == null) return;

    await DatabaseService.instance
        .updateRepaymentRequestStatus(req.id!, 'approved');

    // Find the original transaction to pass to _applyRepayment
    final matchTx =
        _transactions.where((t) => t.id == req.transactionId).toList();
    if (matchTx.isNotEmpty) {
      await _applyRepayment(loan, matchTx.first);
    } else {
      // Transaction might not be in memory; apply directly by amount
      await recordLoanPayment(
        loanId: loan.id!,
        amount: req.amount,
        linkedTransactionId: req.transactionId,
        note: 'Approved via partial-match (SMS: ${req.senderFound})',
      );
    }

    _pendingRepaymentRequests =
        await DatabaseService.instance.getPendingRepaymentRequests();
    notifyListeners();
  }

  /// Reject a pending repayment request — marks it rejected so it never shows again.
  Future<void> rejectLoanRepaymentRequest(LoanRepaymentRequest req) async {
    await DatabaseService.instance
        .updateRepaymentRequestStatus(req.id!, 'rejected');
    _pendingRepaymentRequests =
        await DatabaseService.instance.getPendingRepaymentRequests();
    notifyListeners();
  }

  Future<void> _applyRepayment(LoanRecord loan, AppTransaction tx) async {
    // Only attribute up to the remaining amount
    final applicable = tx.amount.clamp(0.0, loan.remainingAmount);
    if (applicable <= 0) return;
    await recordLoanPayment(
      loanId: loan.id!,
      amount: applicable,
      linkedTransactionId: tx.id,
      note: 'Auto-detected from SMS (${tx.name})',
    );

    // Auto-assign the 'Loan' reason to this transaction so the user isn't prompted
    if (tx.id != null) {
      final loanReason = _reasons.cast<AppReason?>().firstWhere(
            (r) => r?.name.toLowerCase() == 'loan',
            orElse: () => null,
          );

      await updateTransactionReason(
        tx.id!,
        reasonId: loanReason?.id,
        customReasonText: loanReason == null ? 'Loan Settlement' : null,
      );
    }
  }

  Future<List<LoanPayment>> getPaymentsForLoan(int loanId) async {
    final payments = await DatabaseService.instance.getPaymentsForLoan(loanId);
    _loanPayments[loanId] = payments;
    return payments;
  }

  Future<void> processNewSms(
    String sender,
    String message,
    DateTime date,
  ) async {
    // If name is not yet captured, try to get it from CBE message
    if (_userName == null && sender.toUpperCase().contains('CBE')) {
      final name = CbeParser.extractOwnerName(message);
      if (name != null) {
        _userName = name;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name_v1', name);
        notifyListeners();
      }
    }

    // 0. Use modular parsers for trusted bank sender IDs only.
    final bank = BankSenders.match(sender);

    // If the matched bank is paused, skip processing the SMS entirely.
    if (bank != null &&
        _pausedBanks.any((b) => b.toUpperCase() == bank.toUpperCase())) {
      return;
    }

    if (bank == 'Telebirr') {
      AppTransaction? telebirrTx = TelebirrParser.parse(message, date);
      if (telebirrTx != null) {
        await addTransaction(telebirrTx);
      } else {
        // Parser couldn't read it — save to notifications so user sees it
        await addUnrecognizedNotification(
            sender: sender, body: message, date: date);
      }
      return;
    } else if (bank == 'CBE') {
      AppTransaction? cbeTx = CbeParser.parse(message, date);
      if (cbeTx != null) {
        await addTransaction(cbeTx);
      } else {
        // Some CBE Birr messages (e.g. ATM withdrawals) arrive with sender
        // ID "CBE" instead of "CBEBirr". If the CBE parser can't read it
        // and the body uses the "Br." CBE Birr currency marker, try the
        // CBE Birr parser as a fallback before dropping the message.
        final looksLikeCbeBirr = message.toLowerCase().contains('br.');
        if (looksLikeCbeBirr) {
          AppTransaction? cbeBirrFallbackTx =
              CbeBirrParser.parse(message, date);
          if (cbeBirrFallbackTx != null) {
            await addTransaction(cbeBirrFallbackTx);
            return;
          }
        }
        await addUnrecognizedNotification(
            sender: sender, body: message, date: date);
      }
      return;
    } else if (bank == 'CBE Birr') {
      AppTransaction? cbeBirrTx = CbeBirrParser.parse(message, date);
      if (cbeBirrTx != null) {
        await addTransaction(cbeBirrTx);
      } else {
        await addUnrecognizedNotification(
            sender: sender, body: message, date: date);
      }
      return;
    } else if (bank == 'Ahadu Bank') {
      AppTransaction? ahaduTx = AhaduParser.parse(message, date);
      if (ahaduTx != null) {
        await addTransaction(ahaduTx);
      } else {
        await addUnrecognizedNotification(
            sender: sender, body: message, date: date);
      }
      return;
    }

    // 1. Is sender selected?
    AppSender? matchedSender;
    try {
      matchedSender = _senders.firstWhere(
        (s) => s.senderName.toLowerCase() == sender.toLowerCase(),
      );
    } catch (e) {
      return; // Ignore if sender not tracked
    }

    // 2. Contains keywords?
    String lowerMsg = message.toLowerCase();
    bool hasDeposit = matchedSender.depositKeywords.any(
      (kw) => lowerMsg.contains(kw.toLowerCase()),
    );
    bool hasExpense = matchedSender.expenseKeywords.any(
      (kw) => lowerMsg.contains(kw.toLowerCase()),
    );

    double amount = SmsService.extractAmount(message);

    if (hasDeposit && !hasExpense) {
      await addTransaction(
        AppTransaction(
          id: '${sender}_${date.millisecondsSinceEpoch}',
          name: matchedSender.senderName,
          amount: amount,
          type: 'income',
          date: date,
          sender: sender,
          category: 'Auto',
          rawMessage: message,
          isAutoDetected: true,
        ),
      );
    } else if (hasExpense && !hasDeposit) {
      await addTransaction(
        AppTransaction(
          id: '${sender}_${date.millisecondsSinceEpoch}',
          name: matchedSender.senderName,
          amount: amount,
          type: 'expense',
          date: date,
          sender: sender,
          category: 'Auto',
          rawMessage: message,
          isAutoDetected: true,
        ),
      );
    } else {
      // Unrecognized: save to in-app notifications instead of pending
      await addUnrecognizedNotification(
        sender: sender,
        body: message,
        date: date,
      );
    }
  }

  // ── Expense Definitions & Cash Transactions ───────────────────────────────

  Future<void> addExpenseDefinition(ExpenseDefinition definition) async {
    final id =
        await DatabaseService.instance.insertExpenseDefinition(definition);
    _expenseDefinitions.add(definition.copyWith(id: id));
    _expenseDefinitions.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  Future<void> updateExpenseDefinition(ExpenseDefinition definition) async {
    await DatabaseService.instance.updateExpenseDefinition(definition);
    final idx = _expenseDefinitions.indexWhere((d) => d.id == definition.id);
    if (idx != -1) {
      _expenseDefinitions[idx] = definition;
      _expenseDefinitions.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    }
  }

  Future<void> deleteExpenseDefinition(int id) async {
    await DatabaseService.instance.deleteExpenseDefinition(id);
    _expenseDefinitions.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  Future<void> addCashTransaction(CashTransaction transaction) async {
    final id =
        await DatabaseService.instance.insertCashTransaction(transaction);
    final mapped = transaction.toMap();
    mapped['id'] = id;
    _cashTransactions.insert(0, CashTransaction.fromMap(mapped));

    // Update the last applied date if it's an expense linked to a definition
    if (transaction.type == 'expense' &&
        transaction.expenseDefinitionId != null) {
      final defIdx = _expenseDefinitions
          .indexWhere((d) => d.id == transaction.expenseDefinitionId);
      if (defIdx != -1) {
        final def = _expenseDefinitions[defIdx];
        if (def.isRecurring) {
          final updatedDef = def.copyWith(lastAppliedDate: transaction.date);
          await updateExpenseDefinition(updatedDef);
        }
      }
    }

    _calculateStats();
    notifyListeners();
  }

  Future<void> deleteCashTransaction(int id) async {
    await DatabaseService.instance.deleteCashTransaction(id);
    _cashTransactions.removeWhere((t) => t.id == id);
    _calculateStats();
    notifyListeners();
  }

  Future<void> updateCashTransactionAmount(int id, double newAmount) async {
    final idx = _cashTransactions.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final oldTx = _cashTransactions[idx];
      final newTx = oldTx.copyWith(amount: newAmount);
      await DatabaseService.instance.updateCashTransaction(newTx);
      _cashTransactions[idx] = newTx;
      _calculateStats();
      notifyListeners();
    }
  }

  /// Automatically applies recurring expenses that are due today or were missed.
  Future<void> _applyRecurringCashExpenses() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool anyAdded = false;

    for (int i = 0; i < _expenseDefinitions.length; i++) {
      final def = _expenseDefinitions[i];
      if (!def.isRecurring || !def.isActive) continue;

      DateTime targetDate =
          def.lastAppliedDate ?? today.subtract(const Duration(days: 1));
      DateTime nextDateToApply;

      if (def.recurringType == 'daily') {
        nextDateToApply = targetDate.add(const Duration(days: 1));
      } else if (def.recurringType == 'interval' && def.intervalDays != null) {
        nextDateToApply = targetDate.add(Duration(days: def.intervalDays!));
      } else if (def.recurringType == 'specific_day' &&
          def.specificDay != null) {
        int year = targetDate.year;
        int month = targetDate.month;
        if (targetDate.day >= def.specificDay!) {
          month += 1;
          if (month > 12) {
            month = 1;
            year += 1;
          }
        }
        nextDateToApply = DateTime(year, month, def.specificDay!);
      } else if (def.recurringType == 'days_of_week' &&
          def.selectedDaysOfWeek != null) {
        final selected = def.selectedDaysOfWeek!
            .split(',')
            .map((e) => int.tryParse(e) ?? 1)
            .toList();
        DateTime candidate = targetDate.add(const Duration(days: 1));
        int limit = 0; // fallback in case of empty array
        while (!selected.contains(candidate.weekday) && limit < 10) {
          candidate = candidate.add(const Duration(days: 1));
          limit++;
        }
        nextDateToApply = candidate;
      } else {
        continue; // Invalid recurring setup
      }

      // Apply any missed occurrences up to today
      DateTime simulateDate = nextDateToApply;
      DateTime latestApplied = targetDate;

      while (simulateDate.isBefore(today) ||
          simulateDate.isAtSameMomentAs(today)) {
        int times = def.timesPerDay;
        // Space out the times across an 8-hour window starting from morning for better UX
        for (int t = 0; t < times; t++) {
          final hourOffset = 8 + (t * (12 ~/ times));
          final dateWithHour = simulateDate.add(Duration(hours: hourOffset));

          final tx = CashTransaction(
            type: 'expense',
            amount: def.defaultAmount,
            date: dateWithHour,
            description: 'Auto-recurring: ${def.name}',
            expenseDefinitionId: def.id,
            reasonId: def.reasonId,
            reasonName: def.reasonId != null
                ? _reasons.where((r) => r.id == def.reasonId).firstOrNull?.name
                : null,
          );
          final txId = await DatabaseService.instance.insertCashTransaction(tx);
          final mapped = tx.toMap();
          mapped['id'] = txId;
          _cashTransactions.insert(0, CashTransaction.fromMap(mapped));
          anyAdded = true;
        }
        latestApplied = simulateDate;

        if (def.recurringType == 'daily') {
          simulateDate = simulateDate.add(const Duration(days: 1));
        } else if (def.recurringType == 'interval') {
          simulateDate = simulateDate.add(Duration(days: def.intervalDays!));
        } else if (def.recurringType == 'specific_day') {
          int year = simulateDate.year;
          int month = simulateDate.month + 1;
          if (month > 12) {
            month = 1;
            year += 1;
          }
          simulateDate = DateTime(year, month, def.specificDay!);
        } else if (def.recurringType == 'days_of_week') {
          final selected = def.selectedDaysOfWeek!
              .split(',')
              .map((e) => int.tryParse(e) ?? 1)
              .toList();
          simulateDate = simulateDate.add(const Duration(days: 1));
          int limit = 0;
          while (!selected.contains(simulateDate.weekday) && limit < 10) {
            simulateDate = simulateDate.add(const Duration(days: 1));
            limit++;
          }
        }
      }

      if (latestApplied.isAfter(targetDate)) {
        final updatedDef = def.copyWith(lastAppliedDate: latestApplied);
        await DatabaseService.instance.updateExpenseDefinition(updatedDef);
        _expenseDefinitions[i] = updatedDef;
      }
    }

    if (anyAdded) {
      _cashTransactions.sort((a, b) => b.date.compareTo(a.date));
    }
  }

  // ── Cache Clearing ────────────────────────────────────────────────────────

  /// FULL RESET: Deletes ALL transactions, ALL reasons/links, ALL notifications,
  /// resets the boot flag, then rescans all SMS messages from scratch.
  Future<void> fullReset() async {
    _isLoading = true;
    notifyListeners();

    // 1. Wipe everything
    await DatabaseService.instance.deleteAllTransactions();
    await DatabaseService.instance.deleteAllUserReasons();
    await DatabaseService.instance.deleteAllNotifications();

    // 2. Reset SharedPreferences flags so the app treats this as first boot
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_boot_v5', true);
    await prefs.remove('anchor_version'); // forces anchor recalculation

    // 3. Reload from cleared DB
    _transactions = [];
    _notifications = [];
    _reasons = await DatabaseService.instance.getReasons();
    _reasonLinks = await DatabaseService.instance.getReasonLinks();

    // 4. Re-run init (will detect first-boot and rescan)
    await init();
  }

  /// SMART REFRESH: Keeps all reason assignments intact.
  ///
  /// Rules:
  /// - Transactions that already have a reason (linked or custom) are LEFT ALONE.
  /// - For all other (unlinked) transactions: delete them, rescan from SMS.
  ///   - If the SMS has an embedded date  → use the SMS date.
  ///   - If the SMS has NO embedded date  → restore the previously stored date.
  Future<void> smartRefresh() async {
    _isLoading = true;
    notifyListeners();

    // 1. Keep ALL old transactions in memory mapped by ID so we can restore reasons
    final oldTxMap = <String, AppTransaction>{};
    for (final tx in _transactions) {
      if (tx.id != null) {
        oldTxMap[tx.id!] = tx;
      }
    }

    // 2. Delete ALL transactions from DB so we can rewrite them with fresh names
    await DatabaseService.instance.deleteAllTransactions();

    // 3. Also clear notifications (will be rebuilt)
    await DatabaseService.instance.deleteAllNotifications();

    // 4. Rescan SMS from the install anchor
    final prefs = await SharedPreferences.getInstance();
    final anchorStr = prefs.getString('install_anchor_date');
    final anchorDate = anchorStr != null ? DateTime.tryParse(anchorStr) : null;

    List<sms_inbox.SmsMessage> messages =
        await SmsService().getAllMessages(since: anchorDate);

    // Sort oldest-first for chronological insertion
    messages.sort((a, b) {
      if (a.date == null || b.date == null) return 0;
      return a.date!.compareTo(b.date!);
    });

    for (final msg in messages) {
      if (msg.sender == null || msg.body == null || msg.date == null) continue;
      final msgDate = msg.date!;
      final sender = msg.sender!;
      final body = msg.body!;

      // Skip non-English/Amharic messages entirely during rescan
      if (!_isEnglishBankingMessage(body)) continue;

      // Parse the SMS with the appropriate parser (trusted senders only)
      final bank = BankSenders.match(sender);
      AppTransaction? parsed;
      if (bank == 'Telebirr') {
        parsed = TelebirrParser.parse(body, msgDate);
      } else if (bank == 'CBE Birr') {
        parsed = CbeBirrParser.parse(body, msgDate);
      } else if (bank == 'CBE') {
        parsed = CbeParser.parse(body, msgDate);
      } else if (bank == 'Ahadu Bank') {
        parsed = AhaduParser.parse(body, msgDate);
      }

      if (parsed == null || parsed.id == null) continue;

      final oldTx = oldTxMap[parsed.id];

      // Honour the "preserve old date if SMS has no embedded date" rule.
      DateTime finalDate = parsed.date;
      if (oldTx != null && parsed.date == msgDate) {
        // Parser used the SMS arrival date as fallback → restore stored date
        finalDate = oldTx.date;
      }

      // Check if we can restore the reason from oldTx.
      // Rule: ONLY restore reason if the sender name hasn't changed.
      // If the parser logic changed the name (e.g. stripped numbers), the old reason is discarded
      // so the user can assign a new reason to the NEW correct name.
      int? finalReasonId;
      String? finalReason;
      String? finalCustomReasonText;

      if (oldTx != null) {
        if (oldTx.sender.toLowerCase().trim() ==
            parsed.sender.toLowerCase().trim()) {
          finalReasonId = oldTx.reasonId;
          finalReason = oldTx.reason;
          finalCustomReasonText = oldTx.customReasonText;
        }
      }

      // If no valid old manual reason, check if the NEW name matches any global auto-link
      if (finalReasonId == null &&
          (finalCustomReasonText == null || finalCustomReasonText.isEmpty)) {
        final expectedLinkType =
            parsed.type == 'income' ? 'sender' : 'receiver';
        final autoLink = _reasonLinks.cast<AppReasonLink?>().firstWhere(
            (l) =>
                l!.linkedName.toLowerCase().trim() ==
                    parsed!.sender.toLowerCase().trim() &&
                l.linkType == expectedLinkType,
            orElse: () => null);

        if (autoLink != null) {
          final autoReason = _reasons.cast<AppReason?>().firstWhere(
              (r) => r!.id == autoLink.reasonId,
              orElse: () => null);
          if (autoReason != null) {
            finalReasonId = autoReason.id;
            finalReason = autoReason.name;
          }
        }
      }

      final txToInsert = AppTransaction(
        id: parsed.id,
        name: parsed.name,
        amount: parsed.amount,
        type: parsed.type,
        date: finalDate,
        sender: parsed.sender,
        category: parsed.category,
        rawMessage: parsed.rawMessage,
        isAutoDetected: parsed.isAutoDetected,
        totalBalance: parsed.totalBalance,
        reasonId: finalReasonId,
        reason: finalReason,
        customReasonText: finalCustomReasonText,
      );

      await DatabaseService.instance.insertTransaction(txToInsert);

      // Auto-detect loan repayment if this is an income SMS and we didn't just inherit a manual reason
      if (txToInsert.type == 'income') {
        await _checkAndApplyLoanRepayment(txToInsert);
      }
    }

    // 5. Reload everything from DB
    _transactions = await DatabaseService.instance.getTransactions();
    _reasons = await DatabaseService.instance.getReasons();
    _reasonLinks = await DatabaseService.instance.getReasonLinks();
    await _loadNotifications();
    _calculateStats();

    _isLoading = false;
    notifyListeners();
  }

  // ──────────────────────────────────────────────
  // Saving Goals State Management
  // ──────────────────────────────────────────────
  Future<void> fetchSavingGoals() async {
    _savingGoals = await DatabaseService.instance.getSavingGoals();
    notifyListeners();
  }

  Future<void> addSavingGoal(SavingGoal goal) async {
    await DatabaseService.instance.insertSavingGoal(goal);
    await fetchSavingGoals();
  }

  Future<void> updateSavingGoal(SavingGoal goal) async {
    await DatabaseService.instance.updateSavingGoal(goal);
    await fetchSavingGoals();
  }

  Future<void> topUpSavingGoal(String goalId, double amount) async {
    final idx = _savingGoals.indexWhere((g) => g.id == goalId);
    if (idx != -1) {
      final updated = _savingGoals[idx].copyWith(
        savedAmount: _savingGoals[idx].savedAmount + amount,
      );
      await DatabaseService.instance.updateSavingGoal(updated);
      await fetchSavingGoals();
    }
  }

  Future<void> deleteSavingGoal(String goalId) async {
    await DatabaseService.instance.deleteSavingGoal(goalId);
    await fetchSavingGoals();
  }
}
