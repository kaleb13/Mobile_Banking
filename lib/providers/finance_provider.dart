import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/sender.dart';
import '../models/transaction.dart';
import '../models/app_notification.dart';
import '../models/reason.dart';
import '../models/loan_record.dart';
import '../models/loan_repayment_request.dart';
import '../models/expense_definition.dart';
import '../models/cash_transaction.dart';
import '../services/database_service.dart';
import '../services/sms_service.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart' as sms_inbox;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import '../services/telebirr_parser.dart';
import '../services/cbe_parser.dart';
import '../services/cbe_birr_parser.dart';
import '../services/background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  int _unreadNotificationCount = 0;
  bool _isLoading = true;
  double _totalBalance = 0;
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

  bool _hasPermission = false;
  bool _isOnboardingComplete;
  bool _isBalanceVisible = false;
  bool _isShowingAll = false;
  bool _isMenuOpen = false;
  int _currentScreenIndex = 0;
  String? _userName;
  Timer? _refreshTimer;
  DateTime? _lastPollTime;

  /// [initialOnboardingComplete] should be read from SharedPreferences in
  /// main() BEFORE runApp() so the first frame is always correct.
  FinanceProvider({bool initialOnboardingComplete = false})
      : _isOnboardingComplete = initialOnboardingComplete;

  String? get userName => _userName;

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

  List<AppTransaction> get transactions => _transactions;

  List<AppTransaction> get transactionsForSelectedDate {
    if (_isShowingAll) return _transactions;
    return _transactions
        .where((tx) =>
            tx.date.year == _selectedDate.year &&
            tx.date.month == _selectedDate.month &&
            tx.date.day == _selectedDate.day)
        .toList();
  }

  List<AppTransaction> get transactionsForSelectedMonth {
    return _transactions
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

  bool get isSelectedDateToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  double get totalBalance => _totalBalance;
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
  Map<String, dynamic>? get mostExpenseToday {
    final now = DateTime.now();
    final todayExpenses = _transactions
        .where((tx) =>
            tx.type == 'expense' &&
            tx.date.year == now.year &&
            tx.date.month == now.month &&
            tx.date.day == now.day &&
            tx.resolvedReason?.toLowerCase() != 'bounce' &&
            tx.resolvedReason?.toLowerCase() != 'internal transfer')
        .toList();

    if (todayExpenses.isEmpty) return null;

    Map<String, double> reasonSubtotals = {};
    for (var tx in todayExpenses) {
      final key = tx.resolvedReason ?? 'Other';
      reasonSubtotals[key] = (reasonSubtotals[key] ?? 0) + tx.amount;
    }

    String topReason = reasonSubtotals.keys.first;
    double maxAmount = reasonSubtotals[topReason]!;
    reasonSubtotals.forEach((key, value) {
      if (value > maxAmount) {
        maxAmount = value;
        topReason = key;
      }
    });

    return {'reason': topReason, 'amount': maxAmount};
  }

  Map<String, dynamic>? get mostExpenseThisMonth {
    final now = DateTime.now();
    final monthExpenses = _transactions
        .where((tx) =>
            tx.type == 'expense' &&
            isDateInMonthOf(tx.date, now) &&
            tx.resolvedReason?.toLowerCase() != 'bounce' &&
            tx.resolvedReason?.toLowerCase() != 'internal transfer')
        .toList();

    if (monthExpenses.isEmpty) return null;

    Map<String, double> reasonSubtotals = {};
    for (var tx in monthExpenses) {
      final key = tx.resolvedReason ?? 'Other';
      reasonSubtotals[key] = (reasonSubtotals[key] ?? 0) + tx.amount;
    }

    String topReason = reasonSubtotals.keys.first;
    double maxAmount = reasonSubtotals[topReason]!;
    reasonSubtotals.forEach((key, value) {
      if (value > maxAmount) {
        maxAmount = value;
        topReason = key;
      }
    });

    return {'reason': topReason, 'amount': maxAmount};
  }

  Map<String, dynamic>? get topExpenseHighlight {
    if (_transactions.isEmpty) return null;

    final expenses = _transactions
        .where((t) =>
            t.type == 'expense' &&
            t.resolvedReason?.toLowerCase() != 'bounce' &&
            t.resolvedReason?.toLowerCase() != 'internal transfer')
        .toList();
    if (expenses.isEmpty) return null;

    Map<String, double> totals = {};
    for (var tx in expenses) {
      final key = tx.resolvedReason ?? 'Other';
      totals[key] = (totals[key] ?? 0) + tx.amount;
    }

    String topKey = totals.keys.first;
    double maxVal = totals[topKey]!;
    totals.forEach((k, v) {
      if (v > maxVal) {
        maxVal = v;
        topKey = k;
      }
    });

    return {'reason': topKey, 'amount': maxVal};
  }

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
    // Now run init() to load all financial data.
    // Since _isOnboardingComplete is now true, init() will show the
    // loading spinner correctly and then route to MainShell.
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

    // Load senders from DB or seed defaults
    final dbSenders = await DatabaseService.instance.getSenders();
    if (dbSenders.isNotEmpty) {
      _senders = dbSenders;
    } else {
      _senders = [
        AppSender(id: '1', senderName: 'Telebirr'),
        AppSender(id: '2', senderName: 'CBE'),
        AppSender(id: '3', senderName: 'CBE Birr'),
      ];
      // Seed them into DB for future persistent updates
      for (var s in _senders) {
        await DatabaseService.instance.insertSender(s);
      }
    }

    _transactions = await DatabaseService.instance.getTransactions();
    _reasons = await DatabaseService.instance.getReasons();
    _reasonLinks = await DatabaseService.instance.getReasonLinks();
    _expenseDefinitions =
        await DatabaseService.instance.getExpenseDefinitions();
    _cashTransactions = await DatabaseService.instance.getCashTransactions();
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
      for (var msg in allMessages) {
        if (msg.sender != null && msg.body != null && msg.date != null) {
          final msgDate = msg.date!;
          final upSender = msg.sender!.toUpperCase();
          final upBody = msg.body!.toUpperCase();

          if (!_isEnglishBankingMessage(msg.body!)) continue;

          if ((upSender.contains('TELEBIRR') ||
                  msg.sender == TelebirrParser.senderNumber) &&
              !processedSenders.contains('Telebirr')) {
            AppTransaction? tx = TelebirrParser.parse(msg.body!, msgDate);
            if (tx != null) {
              await addTransaction(tx);
              processedSenders.add('Telebirr');
            }
          } else if (upSender.contains('CBE') &&
              upSender.contains('BIRR') &&
              !processedSenders.contains('CBE Birr')) {
            AppTransaction? tx = CbeBirrParser.parse(msg.body!, msgDate);
            if (tx != null) {
              await addTransaction(tx);
              processedSenders.add('CBE Birr');
            }
          } else if ((upSender.contains('CBE') ||
                  upBody.contains('BANKING WITH CBE')) &&
              !processedSenders.contains('CBE')) {
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
          }
        }
        if (processedSenders.contains('Telebirr') &&
            processedSenders.contains('CBE') &&
            processedSenders.contains('CBE Birr')) {
          break;
        }
      }
      await prefs.setBool('is_first_boot_v5', false);
    }
    // On subsequent opens we do NOT rescan SMS — the background service
    // keeps the database up to date silently. We just load from DB below.

    // Refresh after all updates inserted
    _transactions = await DatabaseService.instance.getTransactions();
    await _loadNotifications();

    // Real-time SMS listener (foreground)
    final Telephony telephony = Telephony.instance;
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage msg) async {
        if (msg.address != null && msg.body != null) {
          final date = msg.date != null
              ? DateTime.fromMillisecondsSinceEpoch(msg.date!)
              : DateTime.now();
          await processNewSms(msg.address!, msg.body!, date);
          // Refresh transactions & stats
          _transactions = await DatabaseService.instance.getTransactions();
          await _loadNotifications();
          _calculateStats();
          notifyListeners();
        }
      },
      onBackgroundMessage: backgroundMessageHandler,
      listenInBackground: true,
    );

    _calculateStats();
    _isLoading = false;

    // Initialize _lastPollTime for periodic refresh
    // We take the latest transaction date or the install anchor as starting point
    _lastPollTime = lastTxDate ??
        DateTime.tryParse(prefs.getString('install_anchor_date') ?? '');
    _lastPollTime ??= DateTime.now().subtract(const Duration(days: 30));

    _startPeriodicRefresh();

    notifyListeners();
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _pollForNewMessages();
    });
  }

  Future<void> _pollForNewMessages() async {
    if (!_hasPermission || _lastPollTime == null) return;

    final newMessages = await SmsService().getAllMessages(since: _lastPollTime);
    if (newMessages.isEmpty) {
      // Just update poll time to now to keep the window narrow
      _lastPollTime = DateTime.now();
      return;
    }

    // Sort oldest first to maintain sequence if multiple messages arrived
    newMessages.sort((a, b) =>
        (a.date ?? DateTime.now()).compareTo(b.date ?? DateTime.now()));

    bool foundNew = false;
    for (var msg in newMessages) {
      if (msg.address != null && msg.body != null) {
        final date = msg.date ?? DateTime.now();
        await processNewSms(msg.address!, msg.body!, date);
        foundNew = true;
        if (date.isAfter(_lastPollTime!)) {
          _lastPollTime = date;
        }
      }
    }

    if (foundNew) {
      _transactions = await DatabaseService.instance.getTransactions();
      await _loadNotifications();
      _calculateStats();
      notifyListeners();
    } else {
      _lastPollTime = DateTime.now();
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
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The app just came to the foreground. Background service might have
      // inserted new transactions. Load them from DB.
      _reloadFromDatabase();
    }
  }

  Future<void> _reloadFromDatabase() async {
    _transactions = await DatabaseService.instance.getTransactions();
    _expenseDefinitions =
        await DatabaseService.instance.getExpenseDefinitions();
    _cashTransactions = await DatabaseService.instance.getCashTransactions();
    await _loadNotifications();
    await _applyRecurringCashExpenses();
    _calculateStats();
    notifyListeners();
  }

  Future<void> refreshData() async {
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

    // Fetch every SMS from known senders since the install anchor
    // (subtract 1 min buffer to be safe at boundaries)
    final cutoff = anchorDate.subtract(const Duration(minutes: 1));
    List<sms_inbox.SmsMessage> messages =
        await SmsService().getAllMessages(since: cutoff);

    // Sort oldest-first so transactions are inserted chronologically
    messages.sort((a, b) {
      if (a.date == null || b.date == null) return 0;
      return a.date!.compareTo(b.date!);
    });

    for (var msg in messages) {
      if (msg.sender != null && msg.body != null && msg.date != null) {
        await processNewSms(msg.sender!, msg.body!, msg.date!);
      }
    }

    _transactions = await DatabaseService.instance.getTransactions();
    _expenseDefinitions =
        await DatabaseService.instance.getExpenseDefinitions();
    _cashTransactions = await DatabaseService.instance.getCashTransactions();
    await _loadNotifications();
    await _applyRecurringCashExpenses();
    _calculateStats();
    notifyListeners();
  }

  Future<void> _loadNotifications() async {
    _notifications = await DatabaseService.instance.getNotifications();
    _unreadNotificationCount =
        await DatabaseService.instance.getUnreadNotificationCount();
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

  /// Returns true if [msg] is primarily English and doesn't contain Ethiopic script.
  static bool _isEnglishBankingMessage(String msg) {
    // Reject messages with any Ethiopic/Amharic characters immediately
    final hasEthiopic = RegExp(r'[\u1200-\u137F\uAB01-\uAB2F]').hasMatch(msg);
    if (hasEthiopic) return false;

    const keywords = [
      'received',
      'sent',
      'send',
      'transferred',
      'transfer',
      'paid',
      'pay',
      'payment',
      'credited',
      'credit',
      'debited',
      'debit',
      'deposited',
      'deposit',
      'withdrawn',
      'withdrawal',
      'withdraw',
      'balance',
      'account',
      'available',
      'remaining',
      'amount',
      'total',
      'birr',
      'etb',
      'usd',
      'loan',
      'repay',
      'due',
      'transaction',
      'txn',
      'ref no',
      'reference',
      'purchase',
      'charged',
      'fee',
      'bank',
      'wallet',
      'mobile money',
      'telebirr',
      'cbe',
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

    // ── External SMS: only save if it looks like a financial message ────────
    if (!isSystemAlert && !_isEnglishBankingMessage(body)) return;

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

    // The bank already pre-calculates the total current balance.
    // We sum the precise balance from the single newest transaction per bank!
    Map<String, double> latestBalances = {};
    for (var tx in _transactions) {
      if (!latestBalances.containsKey(tx.name)) {
        if (tx.totalBalance > 0) {
          latestBalances[tx.name] = tx.totalBalance;
        }
      }
    }

    for (var value in latestBalances.values) {
      _totalBalance += value;
    }

    // Cash Wallet Balance Calculation
    double cashInflows = 0;
    double manualInflows = 0;
    double cashOutflows = 0;

    // 1. Sum from SMS bank txns where reason == 'Cash'
    for (var tx in _transactions) {
      if (tx.reason?.toLowerCase() == 'cash' ||
          tx.customReasonText?.toLowerCase() == 'cash' ||
          tx.resolvedReason?.toLowerCase() == 'cash') {
        // ATM withdrawal (bank expense) is a CASH INFLOW to the wallet.
        // Cash deposit (bank income) is a CASH OUTFLOW from the wallet.
        if (tx.type == 'expense') {
          cashInflows += tx.amount.abs();
        } else {
          cashOutflows += tx.amount.abs();
        }
      }
    }
    // 2. Add manual additions and minus deductions
    for (var ctx in _cashTransactions) {
      if (ctx.type == 'addition') {
        manualInflows += ctx.amount;
        // Manual additions to cash (not from bank) increase wealth
        _netOverall += ctx.amount;
        if (isDateInMonthOf(ctx.date, now)) {
          _incomeThisMonth += ctx.amount;
        }
        if (_isShowingAll ||
            (ctx.date.year == _selectedDate.year &&
                ctx.date.month == _selectedDate.month &&
                ctx.date.day == _selectedDate.day)) {
          _incomeForSelectedDate += ctx.amount;
        }
      } else if (ctx.type == 'expense') {
        cashOutflows += ctx.amount;
        // Manual cash expenses decrease wealth
        _netOverall -= ctx.amount;
        if (isDateInMonthOf(ctx.date, now)) {
          _expenseThisMonth += ctx.amount;
        }
        if (_isShowingAll ||
            (ctx.date.year == _selectedDate.year &&
                ctx.date.month == _selectedDate.month &&
                ctx.date.day == _selectedDate.day)) {
          _expenseForSelectedDate += ctx.amount;
        }
      }
    }

    _cashBalance = cashInflows + manualInflows - cashOutflows;

    // Add cash balance to the grand total balance
    if (_cashBalance > 0) {
      _totalBalance += _cashBalance;
    }

    for (var tx in _transactions) {
      if (tx.date.year == now.year &&
          tx.date.month == now.month &&
          tx.date.day == now.day) {
        _todayTransactionCount++;
      }

      bool isBounce = tx.resolvedReason?.toLowerCase() == 'bounce' ||
          tx.resolvedReason?.toLowerCase() == 'internal transfer';
      if (isBounce) continue;

      bool isCashTransfer = tx.reason?.toLowerCase() == 'cash' ||
          tx.customReasonText?.toLowerCase() == 'cash' ||
          tx.resolvedReason?.toLowerCase() == 'cash';

      if (tx.type == 'income') {
        if (isDateInMonthOf(tx.date, now)) {
          if (!isCashTransfer) {
            _incomeThisMonth += tx.amount;
          }
        }
        if (_isShowingAll ||
            (tx.date.year == _selectedDate.year &&
                tx.date.month == _selectedDate.month &&
                tx.date.day == _selectedDate.day)) {
          if (!isCashTransfer) {
            _incomeForSelectedDate += tx.amount;
          }
        }
        if (!isCashTransfer) {
          _netOverall += tx.amount;
        }
      } else if (tx.type == 'expense') {
        if (isDateInMonthOf(tx.date, now)) {
          if (!isCashTransfer) {
            _expenseThisMonth += tx.amount;
          }
        }
        if (_isShowingAll ||
            (tx.date.year == _selectedDate.year &&
                tx.date.month == _selectedDate.month &&
                tx.date.day == _selectedDate.day)) {
          if (!isCashTransfer) {
            _expenseForSelectedDate += tx.amount;
          }
        }
        if (!isCashTransfer) {
          _netOverall -= tx.amount;
        }
      }
    }

    _netForSelectedDate = _incomeForSelectedDate - _expenseForSelectedDate;

    // Percentage for summary card (Today or Selected Date)
    if (_totalBalance > 0) {
      _incomePercentageChange = (_netForSelectedDate / _totalBalance) * 100;
      _incomePercentageChange = _incomePercentageChange.clamp(-100.0, 100.0);

      _percentageChangeOverall = (_netOverall / _totalBalance) * 100;
      _percentageChangeOverall = _percentageChangeOverall.clamp(-100.0, 100.0);
    } else {
      _incomePercentageChange = 0;
      _percentageChangeOverall = 0;
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

  Future<void> addTransaction(AppTransaction transaction) async {
    // Auto-categorize: check if sender matches a linked reason rule
    AppTransaction txToInsert = transaction;
    if (transaction.reasonId == null && transaction.customReasonText == null) {
      final autoReason = await DatabaseService.instance
          .findAutoReason(transaction.sender, transaction.type);
      if (autoReason != null) {
        txToInsert = transaction.copyWith(
            reasonId: autoReason.id, reason: autoReason.name);
      }
    }
    await DatabaseService.instance.insertTransaction(txToInsert);
    _transactions.insert(0, txToInsert);

    // ─ Auto-detect loan repayment if this is an income SMS ─
    if (txToInsert.type == 'income') {
      await _checkAndApplyLoanRepayment(txToInsert);
    }

    _calculateStats();
    notifyListeners();
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

  // ── Reason CRUD ──────────────────────────────────
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
        final senderLower = tx.sender.trim().toLowerCase();
        final exactMatch = (senderLower == trackedSenderName.toLowerCase() ||
            tx.name.toLowerCase() == trackedSenderName.toLowerCase());

        if (exactMatch) {
          // We have to fetch the most up-to-date loan state from memory
          // since previous iterations in this loop might have paid it down
          final currentLoanState = _loanRecords.firstWhere((l) => l.id == id);
          if (currentLoanState.status == 'active') {
            // Queue as pending approval instead of auto-settling
            await _queueRepaymentRequest(
              loan: currentLoanState,
              tx: tx,
              matchType: 'exact',
            );
          }
        } else {
          // Pass 2: First-two-words partial match
          final senderWords = senderLower.trim().split(RegExp(r'\s+'));
          final trackedWords =
              trackedSenderName.toLowerCase().trim().split(RegExp(r'\s+'));

          if (senderWords.length >= 2 && trackedWords.length >= 2) {
            final incomingPrefix = '${senderWords[0]} ${senderWords[1]}';
            final trackedPrefix = '${trackedWords[0]} ${trackedWords[1]}';

            if (incomingPrefix == trackedPrefix) {
              final currentLoanState =
                  _loanRecords.firstWhere((l) => l.id == id);
              if (currentLoanState.status == 'active') {
                // Create pending request
                final req = LoanRepaymentRequest(
                  loanId: id,
                  transactionId:
                      tx.id ?? '${tx.sender}_${tx.date.millisecondsSinceEpoch}',
                  senderFound: tx.sender,
                  trackedName: trackedSenderName,
                  amount:
                      tx.amount.clamp(0.0, currentLoanState.remainingAmount),
                  createdAt: DateTime.now(),
                );
                await DatabaseService.instance.insertLoanRepaymentRequest(req);
              }
            }
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

  /// Called when a new income SMS arrives — checks if the sender is tracked
  /// by any active loan and auto-records a payment.
  Future<void> _checkAndApplyLoanRepayment(AppTransaction tx) async {
    final senderLower = tx.sender.trim().toLowerCase();
    final nameLower = tx.name.trim().toLowerCase();

    // ── Pass 1: Exact match (case-insensitive) against each tracked token ──
    // Now creates a PENDING REQUEST instead of auto-settling, even for exact matches.
    final allActive = _loanRecords
        .where((l) => l.status == 'active' && l.trackedSenderName != null)
        .toList();

    final exactMultiMatches = allActive.where((loan) {
      final tokens = loan.trackedSenderName!
          .split(',')
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toList();
      return tokens.any((t) =>
          senderLower.contains(t) ||
          nameLower.contains(t) ||
          t.contains(senderLower) ||
          t.contains(nameLower));
    }).toList();

    if (exactMultiMatches.isNotEmpty) {
      for (final loan in exactMultiMatches) {
        await _queueRepaymentRequest(
          loan: loan,
          tx: tx,
          matchType: 'exact',
        );
      }
      return;
    }

    // Fall back to DB exact query (handles legacy single-value tracked names)
    final exactLoans =
        await DatabaseService.instance.findActiveLoansForSender(senderLower);
    if (exactLoans.isNotEmpty) {
      for (final loan in exactLoans) {
        await _queueRepaymentRequest(
          loan: loan,
          tx: tx,
          matchType: 'exact',
        );
      }
      return;
    }

    final byBankName =
        await DatabaseService.instance.findActiveLoansForSender(nameLower);
    if (byBankName.isNotEmpty) {
      for (final loan in byBankName) {
        await _queueRepaymentRequest(
          loan: loan,
          tx: tx,
          matchType: 'exact',
        );
      }
      return;
    }

    // ── Pass 2: First-two-words partial match → ask for approval ──────────
    final senderWords = senderLower.trim().split(RegExp(r'\s+'));
    if (senderWords.length < 2) return;

    final incomingPrefix = '${senderWords[0]} ${senderWords[1]}';

    for (final loan in allActive) {
      final trackedTokens = loan.trackedSenderName!
          .split(',')
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toList();

      bool alreadyQueued = false;
      for (final token in trackedTokens) {
        if (alreadyQueued) break;
        final trackedWords = token.split(RegExp(r'\s+'));

        if (trackedWords.isEmpty) continue;
        final trackedPrefix = trackedWords.length >= 2
            ? '${trackedWords[0]} ${trackedWords[1]}'
            : trackedWords[0];

        if (incomingPrefix == trackedPrefix ||
            (trackedWords.length >= 2 &&
                '${senderWords[0]} ${senderWords[1]}' == trackedPrefix)) {
          await _queueRepaymentRequest(
            loan: loan,
            tx: tx,
            matchType: 'partial',
          );
          alreadyQueued = true;
        }
      }
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

    // 0. Use modular parsers for specific senders
    if (sender == TelebirrParser.senderNumber ||
        sender.toLowerCase() == TelebirrParser.senderName.toLowerCase()) {
      AppTransaction? telebirrTx = TelebirrParser.parse(message, date);
      if (telebirrTx != null) {
        await addTransaction(telebirrTx);
      } else {
        // Parser couldn't read it — save to notifications so user sees it
        await addUnrecognizedNotification(
            sender: sender, body: message, date: date);
      }
      return;
    } else if (sender.toUpperCase() == CbeParser.senderName) {
      AppTransaction? cbeTx = CbeParser.parse(message, date);
      if (cbeTx != null) {
        await addTransaction(cbeTx);
      } else {
        await addUnrecognizedNotification(
            sender: sender, body: message, date: date);
      }
      return;
    } else if (sender.toUpperCase() == CbeBirrParser.senderName.toUpperCase()) {
      AppTransaction? cbeBirrTx = CbeBirrParser.parse(message, date);
      if (cbeBirrTx != null) {
        await addTransaction(cbeBirrTx);
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

      final upSender = sender.toUpperCase();
      final upBody = body.toUpperCase();

      // Parse the SMS with the appropriate parser
      AppTransaction? parsed;
      if (upSender.contains('TELEBIRR') ||
          sender == TelebirrParser.senderNumber) {
        parsed = TelebirrParser.parse(body, msgDate);
      } else if (upSender.contains('CBE') && upSender.contains('BIRR')) {
        parsed = CbeBirrParser.parse(body, msgDate);
      } else if (upSender.contains('CBE') ||
          upBody.contains('BANKING WITH CBE')) {
        parsed = CbeParser.parse(body, msgDate);
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
}
