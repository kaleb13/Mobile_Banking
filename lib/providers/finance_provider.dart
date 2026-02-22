import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/sender.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/sms_service.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/telebirr_parser.dart';
import '../services/cbe_parser.dart';

class FinanceProvider with ChangeNotifier {
  List<AppSender> _senders = [];
  List<AppTransaction> _transactions = [];
  bool _isLoading = true;
  double _totalBalance = 0;
  double _incomeThisMonth = 0;
  double _expenseThisMonth = 0;
  double _incomeForSelectedDate = 0;
  double _expenseForSelectedDate = 0;
  double _incomePercentageChange = 0;
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
  double get incomePercentageChange => _incomePercentageChange;

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
    ];

    _transactions = await DatabaseService.instance.getTransactions();

    // 2. Discover last fetch time & Install state
    final prefs = await SharedPreferences.getInstance();
    bool isFirstBoot = prefs.getBool('is_first_boot_v3') ?? true;

    DateTime? lastTxDate =
        await DatabaseService.instance.getLastTransactionDate();

    if (isFirstBoot && lastTxDate == null) {
      // 1. Fetch recent messages
      List<SmsMessage> allMessages = await SmsService().getAllMessages();

      // 2. Sort descending by date (newest first)
      allMessages.sort((a, b) {
        if (a.date == null || b.date == null) return 0;
        return b.date!.compareTo(a.date!);
      });

      // 3. Find the exact single latest valid Telebirr AND CBE message and process ONLY it
      Set<String> processedSenders = {};
      for (var msg in allMessages) {
        if (msg.sender != null && msg.body != null && msg.date != null) {
          if ((msg.sender == TelebirrParser.senderNumber ||
                  msg.sender!.toLowerCase() ==
                      TelebirrParser.senderName.toLowerCase()) &&
              !processedSenders.contains('Telebirr')) {
            AppTransaction? telebirrTx =
                TelebirrParser.parse(msg.body!, msg.date!);
            if (telebirrTx != null) {
              await addTransaction(telebirrTx);
              processedSenders.add('Telebirr');
            }
          } else if (msg.sender!.toUpperCase() == CbeParser.senderName &&
              !processedSenders.contains('CBE')) {
            AppTransaction? cbeTx = CbeParser.parse(msg.body!, msg.date!);
            if (cbeTx != null) {
              await addTransaction(cbeTx);
              processedSenders.add('CBE');
            }
          }
        }
        if (processedSenders.contains('Telebirr') &&
            processedSenders.contains('CBE')) {
          break;
        }
      }
      await prefs.setBool('is_first_boot_v3', false);
    } else if (lastTxDate != null) {
      // Subsequent runs: Fetch missing messages ONLY since that last message's date
      List<SmsMessage> newMessages =
          await SmsService().getAllMessages(since: lastTxDate);

      // Sort ascending to add them chronologically
      newMessages.sort((a, b) {
        if (a.date == null || b.date == null) return 0;
        return a.date!.compareTo(b.date!);
      });

      for (var msg in newMessages) {
        if (msg.sender != null && msg.body != null && msg.date != null) {
          await processNewSms(msg.sender!, msg.body!, msg.date!);
        }
      }
    }

    // Refresh after all updates inserted
    _transactions = await DatabaseService.instance.getTransactions();
    _calculateStats();
    _isLoading = false;
    notifyListeners();
  }

  void _calculateStats() {
    _totalBalance = 0;
    _incomeThisMonth = 0;
    _expenseThisMonth = 0;
    _incomeForSelectedDate = 0;
    _expenseForSelectedDate = 0;
    _incomePercentageChange = 0;
    double incomeForYesterday = 0;

    DateTime now = DateTime.now();

    // The bank already pre-calculates the total current balance.
    // We sum the precise balance from the single newest transaction per bank!
    Map<String, double> latestBalances = {};
    for (var tx in _transactions) {
      if (!latestBalances.containsKey(tx.name)) {
        latestBalances[tx.name] = tx.totalBalance;
      }
    }

    for (var value in latestBalances.values) {
      _totalBalance += value;
    }

    DateTime yesterday = _selectedDate.subtract(const Duration(days: 1));

    for (var tx in _transactions) {
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
        if (!_isShowingAll &&
            tx.date.year == yesterday.year &&
            tx.date.month == yesterday.month &&
            tx.date.day == yesterday.day) {
          incomeForYesterday += tx.amount;
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

    if (incomeForYesterday > 0) {
      _incomePercentageChange =
          ((_incomeForSelectedDate - incomeForYesterday) / incomeForYesterday) *
              100;
    } else if (_incomeForSelectedDate > 0) {
      // if we went from 0 to something, conceptually it's a 100% gain,
      // but strictly speaking let's cap it or just show 100
      _incomePercentageChange = 100;
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
    await DatabaseService.instance.insertTransaction(transaction);
    _transactions.insert(0, transaction);
    _calculateStats();
    notifyListeners();
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
      }
      return;
    } else if (sender.toUpperCase() == CbeParser.senderName) {
      AppTransaction? cbeTx = CbeParser.parse(message, date);
      if (cbeTx != null) {
        await addTransaction(cbeTx);
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
      // Auto classify as deposit
      await addTransaction(
        AppTransaction(
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
      // Auto classify as expense
      await addTransaction(
        AppTransaction(
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
      // Unsure -> Could trigger a confirmation dialog callback here or save as pending
      // For now, save as 'unclassified' and user can confirm it later
      await addTransaction(
        AppTransaction(
          name: matchedSender.senderName,
          amount: amount,
          type: 'pending', // Special type to signify requires confirmation
          date: date,
          sender: sender,
          category: 'Unclassified',
          rawMessage: message,
          isAutoDetected: false,
        ),
      );
    }
  }
}
