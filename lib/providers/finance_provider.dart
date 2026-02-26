import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/sender.dart';
import '../models/transaction.dart';
import '../models/app_notification.dart';
import '../models/reason.dart';
import '../models/loan_record.dart';
import '../services/database_service.dart';
import '../services/sms_service.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart' as sms_inbox;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import '../services/telebirr_parser.dart';
import '../services/cbe_parser.dart';
import '../services/cbe_birr_parser.dart';
import '../services/background_service.dart';

class FinanceProvider with ChangeNotifier, WidgetsBindingObserver {
  List<AppSender> _senders = [];
  List<AppTransaction> _transactions = [];
  List<AppNotification> _notifications = [];
  List<AppReason> _reasons = [];
  List<AppReasonLink> _reasonLinks = [];
  List<LoanRecord> _loanRecords = [];
  Map<int, List<LoanPayment>> _loanPayments = {}; // keyed by loanId
  int _unreadNotificationCount = 0;
  bool _isLoading = true;
  double _totalBalance = 0;
  double _incomeThisMonth = 0;
  double _expenseThisMonth = 0;
  double _incomeForSelectedDate = 0;
  double _expenseForSelectedDate = 0;
  double _netForSelectedDate = 0;
  double _incomePercentageChange = 0;
  int _todayTransactionCount = 0;
  DateTime _selectedDate = DateTime.now();

  bool _hasPermission = false;
  bool _isBalanceVisible = true;
  bool _isShowingAll = false;

  List<AppSender> get senders => _senders;
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

  bool get isLoading => _isLoading;
  bool get hasPermission => _hasPermission;
  bool get isBalanceVisible => _isBalanceVisible;
  bool get isShowingAll => _isShowingAll;
  DateTime get selectedDate => _selectedDate;
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
  int get todayTransactionCount => _todayTransactionCount;
  List<AppNotification> get notifications => _notifications;
  int get unreadNotificationCount => _unreadNotificationCount;
  List<AppReason> get reasons => _reasons;
  List<AppReasonLink> get reasonLinks => _reasonLinks;
  List<LoanRecord> get loanRecords => _loanRecords;
  List<LoanPayment> paymentsForLoan(int loanId) => _loanPayments[loanId] ?? [];

  // ── Loan convenience getters ──────────────────
  List<LoanRecord> get activeLoans =>
      _loanRecords.where((l) => l.status == 'active').toList();
  List<LoanRecord> get overdueLoans =>
      _loanRecords.where((l) => l.isOverdue).toList();
  List<LoanRecord> get paidLoans =>
      _loanRecords.where((l) => l.isPaid).toList();
  int get activeLoanCount => activeLoans.length;
  int get overdueLoanCount => overdueLoans.length;

  Future<void> requestPermission() async {
    _hasPermission = await SmsService().requestPermission();
    if (_hasPermission) {
      // Re-init when permission is granted
      await init();
    } else {
      notifyListeners();
    }
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

    _isLoading = true;
    notifyListeners();

    _hasPermission = await Permission.sms.status.isGranted;

    if (!_hasPermission) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Hardcode parsed providers here
    _senders = [
      AppSender(
        id: '1',
        senderName: 'Telebirr',
      ),
      AppSender(
        id: '2',
        senderName: 'CBE',
      ),
      AppSender(
        id: '3',
        senderName: 'CBE Birr',
      ),
    ];

    _transactions = await DatabaseService.instance.getTransactions();
    _reasons = await DatabaseService.instance.getReasons();
    _reasonLinks = await DatabaseService.instance.getReasonLinks();
    await _loadLoans();
    await _refreshOverdueStatuses();

    // 2. Discover last fetch time & Install state
    final prefs = await SharedPreferences.getInstance();
    bool isFirstBoot = prefs.getBool('is_first_boot_v3') ?? true;

    // The install_anchor_date marks the oldest boundary for message scanning.
    // Refresh NEVER looks at messages older than this date.
    // anchor_version guards against upgrades that stored wrong anchor dates.
    const anchorVersion = 'v2';
    final bool needsAnchorReset =
        prefs.getString('anchor_version') != anchorVersion;
    if (needsAnchorReset) {
      // Anchor = install date MINUS 2 days exactly.
      // The app will never access messages older than 2 days before first launch.
      await prefs.setString('install_anchor_date',
          DateTime.now().subtract(const Duration(days: 2)).toIso8601String());
      await prefs.setString('anchor_version', anchorVersion);
    }

    DateTime? lastTxDate =
        await DatabaseService.instance.getLastTransactionDate();

    if (isFirstBoot && lastTxDate == null) {
      // First boot: fetch messages within the 2-day window before install.
      // Consistent with the install_anchor_date = now - 2 days.
      final installAnchor = DateTime.now().subtract(const Duration(days: 2));
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

          if ((msg.sender == TelebirrParser.senderNumber ||
                  msg.sender!.toLowerCase() ==
                      TelebirrParser.senderName.toLowerCase()) &&
              !processedSenders.contains('Telebirr')) {
            AppTransaction? tx = TelebirrParser.parse(msg.body!, msgDate);
            if (tx != null) {
              await addTransaction(tx);
              processedSenders.add('Telebirr');
            }
          } else if (msg.sender!.toUpperCase() == CbeParser.senderName &&
              !processedSenders.contains('CBE')) {
            AppTransaction? tx = CbeParser.parse(msg.body!, msgDate);
            if (tx != null) {
              await addTransaction(tx);
              processedSenders.add('CBE');
            }
          } else if (msg.sender!.toUpperCase() ==
                  CbeBirrParser.senderName.toUpperCase() &&
              !processedSenders.contains('CBE Birr')) {
            AppTransaction? tx = CbeBirrParser.parse(msg.body!, msgDate);
            if (tx != null) {
              await addTransaction(tx);
              processedSenders.add('CBE Birr');
            }
          }
        }
        if (processedSenders.contains('Telebirr') &&
            processedSenders.contains('CBE') &&
            processedSenders.contains('CBE Birr')) {
          break;
        }
      }
      await prefs.setBool('is_first_boot_v3', false);
    } else {
      // Not first boot: gap-fill scan from anchor to now
      await refreshData();
    }

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
    await _loadNotifications();
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
    await _loadNotifications();
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

  Future<void> addUnrecognizedNotification({
    required String sender,
    required String body,
    required DateTime date,
  }) async {
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
  }

  void _calculateStats() {
    _totalBalance = 0;
    _incomeThisMonth = 0;
    _expenseThisMonth = 0;
    _incomeForSelectedDate = 0;
    _expenseForSelectedDate = 0;
    _netForSelectedDate = 0;
    _incomePercentageChange = 0;
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

    for (var tx in _transactions) {
      if (tx.date.year == now.year &&
          tx.date.month == now.month &&
          tx.date.day == now.day) {
        _todayTransactionCount++;
      }

      if (tx.type == 'income') {
        if (tx.date.month == now.month && tx.date.year == now.year) {
          _incomeThisMonth += tx.amount;
        }
        if (_isShowingAll ||
            (tx.date.year == _selectedDate.year &&
                tx.date.month == _selectedDate.month &&
                tx.date.day == _selectedDate.day)) {
          _incomeForSelectedDate += tx.amount;
        }
      } else if (tx.type == 'expense') {
        if (tx.date.month == now.month && tx.date.year == now.year) {
          _expenseThisMonth += tx.amount;
        }
        if (_isShowingAll ||
            (tx.date.year == _selectedDate.year &&
                tx.date.month == _selectedDate.month &&
                tx.date.day == _selectedDate.day)) {
          _expenseForSelectedDate += tx.amount;
        }
      }
    }

    _netForSelectedDate = _incomeForSelectedDate - _expenseForSelectedDate;

    // Percentage = net / total-flow x 100
    // Tells you what fraction of all money moved is yours (net).
    // income=90000, expense=5   => (89995/90005)*100 = +99.98%
    // income=5,     expense=90  => (-85/95)*100       = -89.47%
    // income=100,   expense=0   => +100%
    // income=0,     expense=100 => -100%
    // income=0,     expense=0   =>  0%
    final double totalFlow = _incomeForSelectedDate + _expenseForSelectedDate;
    if (totalFlow > 0) {
      _incomePercentageChange = (_netForSelectedDate / totalFlow) * 100;
      _incomePercentageChange = _incomePercentageChange.clamp(-100.0, 100.0);
    } else {
      _incomePercentageChange = 0;
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
    );
    await DatabaseService.instance.updateTransaction(newTx);
    _transactions[index] = newTx;
    notifyListeners();
  }

  // ── Reason CRUD ──────────────────────────────────
  Future<void> loadReasons() async {
    _reasons = await DatabaseService.instance.getReasons();
    _reasonLinks = await DatabaseService.instance.getReasonLinks();
    notifyListeners();
  }

  Future<void> addReason(String name) async {
    final id = await DatabaseService.instance
        .insertReason(AppReason(name: name, isSystem: false));
    _reasons.add(AppReason(id: id, name: name, isSystem: false));
    notifyListeners();
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
    final loan = LoanRecord(
      loanType: loanType,
      personName: personName,
      trackedSenderName: trackedSenderName,
      principalAmount: principalAmount,
      loanDate: DateTime.now(),
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
    // Look for active loans whose trackedSenderName matches sender or name
    final matchingLoans =
        await DatabaseService.instance.findActiveLoansForSender(tx.sender);
    if (matchingLoans.isEmpty) {
      // Also try matching by bank name
      final byName =
          await DatabaseService.instance.findActiveLoansForSender(tx.name);
      if (byName.isEmpty) return;
      for (final loan in byName) {
        await _applyRepayment(loan, tx);
      }
      return;
    }
    for (final loan in matchingLoans) {
      await _applyRepayment(loan, tx);
    }
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
}
