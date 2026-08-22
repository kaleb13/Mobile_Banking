import 'package:flutter/foundation.dart';
import '../../models/transaction.dart';
import '../../models/cash_transaction.dart';
import '../../models/sender.dart';
import '../../domain/usecases/analytics/calculate_pnl_usecase.dart';
import '../../domain/usecases/analytics/get_top_expenses_usecase.dart';
import '../../domain/usecases/wallets/get_wallet_balances_usecase.dart';

/// AnalyticsViewModel — owns all P&L, wallet balance, and expense highlight
/// computations.
///
/// This ViewModel does NOT own transaction or sender state — it receives them
/// via setter callbacks from the orchestrating layer. All business logic is
/// delegated to pure domain use cases.
class AnalyticsViewModel extends ChangeNotifier {
  final CalculatePnlUseCase _calculatePnlUseCase =
      const CalculatePnlUseCase();
  final GetTopExpensesUseCase _getTopExpensesUseCase =
      const GetTopExpensesUseCase();
  final GetWalletBalancesUseCase _getWalletBalancesUseCase =
      const GetWalletBalancesUseCase();

  // Cross-domain data accessors (set by main.dart bridge)
  List<AppTransaction> Function()? getTransactions;
  List<CashTransaction> Function()? getCashTransactions;
  List<AppSender> Function()? getSenders;
  double Function()? getTotalBalance;
  double Function()? getTotalBorrowedLiability;

  // ── Cached Analytics State ────────────────────────────────────────────────

  Map<String, dynamic>? _cachedMostExpenseToday;
  Map<String, dynamic>? _cachedMostExpenseThisMonth;
  Map<String, dynamic>? _cachedTopExpenseHighlight;

  Map<String, dynamic>? get mostExpenseToday => _cachedMostExpenseToday;
  Map<String, dynamic>? get mostExpenseThisMonth => _cachedMostExpenseThisMonth;
  Map<String, dynamic>? get topExpenseHighlight => _cachedTopExpenseHighlight;

  AppSender? get mostAffectedAccount {
    final senders = getSenders?.call() ?? [];
    final transactions = getTransactions?.call() ?? [];
    if (senders.isEmpty) return null;

    Map<String, int> counts = {};
    Map<String, DateTime> latestTimes = {};

    for (var tx in transactions) {
      final bankKey = tx.name.trim();
      counts[bankKey] = (counts[bankKey] ?? 0) + 1;
      if (latestTimes[bankKey] == null ||
          tx.date.isAfter(latestTimes[bankKey]!)) {
        latestTimes[bankKey] = tx.date;
      }
    }

    AppSender? winner;
    int maxCount = -1;
    DateTime? maxDate;

    for (var sender in senders) {
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

    return winner ?? (senders.isNotEmpty ? senders.first : null);
  }

  AppSender? get lessAffectedAccount {
    final senders = getSenders?.call() ?? [];
    final transactions = getTransactions?.call() ?? [];
    if (senders.isEmpty) return null;

    Map<String, int> counts = {};
    for (var tx in transactions) {
      final bankKey = tx.name.trim();
      counts[bankKey] = (counts[bankKey] ?? 0) + 1;
    }

    AppSender? winner;
    int minCount = 999999;

    for (var sender in senders) {
      int count = counts[sender.senderName] ?? 0;
      if (count < minCount) {
        minCount = count;
        winner = sender;
      }
    }

    return winner;
  }

  // ── Wallet Balances ───────────────────────────────────────────────────────

  Map<String, double> _latestBalancesMap = {};
  Map<String, double> get latestBalancesMap =>
      Map.unmodifiable(_latestBalancesMap);

  double _totalBalance = 0;
  double get totalBalance => _totalBalance;

  List<String> get allAccountNames =>
      _latestBalancesMap.keys.where((k) => (_latestBalancesMap[k] ?? 0) > 0).toList()
        ..sort();

  double getLatestBalanceForBank(String bankName) =>
      _latestBalancesMap[bankName] ?? 0.0;

  // ── Gamification / User Level Getters ──────────────────────────────────────

  int get userLevel {
    if (_totalBalance <= 100000) return 1;
    if (_totalBalance <= 500000) return 2;
    if (_totalBalance <= 1000000) return 3;
    if (_totalBalance <= 5000000) return 4;
    return 5;
  }

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

  double get remainingToNextLevel {
    final target = nextLevelTargetBalance;
    if (target == null) return 0.0;
    final diff = target - _totalBalance;
    return diff < 0 ? 0.0 : diff;
  }

  double get nextLevelProgress {
    final target = nextLevelTargetBalance;
    if (target == null) return 1.0;
    final min = currentLevelMinBalance;
    final range = target - min;
    if (range <= 0) return 1.0;
    final current = _totalBalance - min;
    return (current / range).clamp(0.0, 1.0);
  }

  // ── P&L Getters ───────────────────────────────────────────────────────────

  double get dailyPnl {
    final transactions = getTransactions?.call() ?? [];
    final cashTxns = getCashTransactions?.call() ?? [];
    final now = DateTime.now();
    double income = 0;
    double expense = 0;
    for (final tx in transactions) {
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
    for (final ctx in cashTxns) {
      if (ctx.date.year == now.year &&
          ctx.date.month == now.month &&
          ctx.date.day == now.day) {
        if (ctx.type == 'addition') income += ctx.amount;
        if (ctx.type == 'expense') expense += ctx.amount;
      }
    }
    return income - expense;
  }

  double get monthlyPnl {
    final transactions = getTransactions?.call() ?? [];
    final cashTxns = getCashTransactions?.call() ?? [];
    final now = DateTime.now();
    double income = 0;
    double expense = 0;
    for (final tx in transactions) {
      if (tx.date.year != now.year || tx.date.month != now.month) continue;
      final isCash = tx.resolvedReason?.toLowerCase() == 'cash';
      final isBounce = tx.resolvedReason?.toLowerCase() == 'bounce' ||
          tx.resolvedReason?.toLowerCase() == 'internal transfer';
      if (!isCash && !isBounce) {
        if (tx.type == 'income') income += tx.amount;
        if (tx.type == 'expense') expense += tx.amount;
      }
    }
    for (final ctx in cashTxns) {
      if (ctx.date.year != now.year || ctx.date.month != now.month) continue;
      if (ctx.type == 'addition') income += ctx.amount;
      if (ctx.type == 'expense') expense += ctx.amount;
    }
    final rawPnl = income - expense;
    final liabilityDrag = getTotalBorrowedLiability?.call() ?? 0.0;
    if (liabilityDrag > income) {
      return rawPnl - liabilityDrag;
    }
    return rawPnl.clamp(0.0, double.infinity);
  }

  double get overallPnl => _calculatePnlUseCase.calculateOverallPnl(
        transactions: getTransactions?.call() ?? [],
        currentAssets: _totalBalance,
        totalBorrowedLiability: getTotalBorrowedLiability?.call() ?? 0.0,
      );

  double get netOverall => monthlyPnl;

  double get percentageChangeOverall {
    if (_totalBalance <= 0) return 0.0;
    return ((netOverall / _totalBalance) * 100).clamp(-100.0, 100.0);
  }

  double get netForSelectedDate => dailyPnl;

  double get incomePercentageChange {
    if (_totalBalance <= 0) return 0.0;
    return ((dailyPnl / _totalBalance) * 100).clamp(-100.0, 100.0);
  }

  // ── Recalculation ─────────────────────────────────────────────────────────

  /// Recalculate wallet balances and expense highlights.
  /// Called after transactions are loaded or modified.
  void recalculate({
    Set<String> pausedBanks = const {},
    String Function(AppTransaction)? getTopLevelCategory,
    bool Function(DateTime, DateTime)? isDateInMonthOf,
  }) {
    final transactions = getTransactions?.call() ?? [];
    final cashTxns = getCashTransactions?.call() ?? [];
    final senders = getSenders?.call() ?? [];

    // Wallet balances
    final walletResult = _getWalletBalancesUseCase.execute(
      senders: senders,
      transactions: transactions,
      cashTransactions: cashTxns,
      pausedBanks: pausedBanks,
    );

    bool hasChanged = (_totalBalance != walletResult.totalBalance) ||
        !mapEquals(_latestBalancesMap, walletResult.latestBalancesMap);

    _totalBalance = walletResult.totalBalance;
    _latestBalancesMap = walletResult.latestBalancesMap;

    // Expense highlights — only calculate if category function is provided
    if (getTopLevelCategory != null && isDateInMonthOf != null) {
      final topResult = _getTopExpensesUseCase.execute(
        transactions: transactions,
        getTopLevelCategory: getTopLevelCategory,
        isDateInMonthOf: isDateInMonthOf,
      );
      if (!mapEquals(_cachedMostExpenseToday, topResult.mostExpenseToday) ||
          !mapEquals(_cachedMostExpenseThisMonth, topResult.mostExpenseThisMonth) ||
          !mapEquals(_cachedTopExpenseHighlight, topResult.topExpenseHighlight)) {
        hasChanged = true;
      }
      _cachedMostExpenseToday = topResult.mostExpenseToday;
      _cachedMostExpenseThisMonth = topResult.mostExpenseThisMonth;
      _cachedTopExpenseHighlight = topResult.topExpenseHighlight;
    }

    if (hasChanged) {
      notifyListeners();
    }
  }
}
