import '../../../models/cash_transaction.dart';
import '../../../models/transaction.dart';

class CalculatePnlUseCase {
  const CalculatePnlUseCase();

  /// Calculates overall P/L against earliest known baseline and liabilities.
  double calculateOverallPnl({
    required List<AppTransaction> transactions,
    List<CashTransaction>? cashTransactions,
    required double currentAssets,
    required double totalBorrowedLiability,
  }) {
    double baseline = 0;
    if (transactions.isNotEmpty) {
      final Map<String, double> earliestBalances = {};
      final sorted = List<AppTransaction>.from(transactions)
        ..sort((a, b) => a.date.compareTo(b.date));
      for (final tx in sorted) {
        final accountKey = '${tx.bankName.trim().toUpperCase()}:${tx.simSlot}';
        if (!earliestBalances.containsKey(accountKey) && tx.totalBalance > 0) {
          earliestBalances[accountKey] = tx.totalBalance;
        }
      }
      baseline = earliestBalances.values.fold(0.0, (s, v) => s + v);
    }

    double rawPnl;
    if (baseline > 0) {
      rawPnl = currentAssets - baseline;
    } else {
      double inc = 0;
      double exp = 0;
      for (final tx in transactions) {
        final isPassThrough = tx.resolvedReason?.toLowerCase() == 'pass-through' ||
            tx.resolvedReason?.toLowerCase() == 'pass through' ||
            tx.resolvedReason?.toLowerCase() == 'bounce' ||
            tx.resolvedReason?.toLowerCase() == 'internal transfer';
        if (!isPassThrough) {
          if (tx.type == 'income') inc += tx.amount;
          if (tx.type == 'expense') exp += tx.amount;
        }
      }
      if (cashTransactions != null) {
        for (final ctx in cashTransactions) {
          if (ctx.isIncome) inc += ctx.amount;
          if (ctx.isExpense) exp += ctx.amount;
        }
      }
      rawPnl = inc - exp;
    }

    final adjustedPnl = rawPnl - totalBorrowedLiability;
    return adjustedPnl;
  }

  /// Calculates 30-day net P/L for a specific account or overall:
  /// (Deposits - Expenditures) in the last 30 days.
  double calculate30DayNet({
    required List<AppTransaction> transactions,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final cutoff = now.subtract(const Duration(days: 30));

    double income = 0;
    double expense = 0;

    for (final tx in transactions) {
      if (tx.date.isAfter(cutoff)) {
        if (tx.type == 'income') {
          income += tx.amount;
        } else if (tx.type == 'expense') {
          expense += tx.amount;
        }
      }
    }

    return income - expense;
  }

  /// Calculates net P/L for a given time window filter ('1D', '7D', '30D', '180D', '360D', 'ALL').
  double calculatePeriodPnl({
    required List<AppTransaction> transactions,
    List<CashTransaction>? cashTransactions,
    required String filter,
    required double currentAssets,
    double totalBorrowedLiability = 0.0,
    DateTime? referenceDate,
  }) {
    if (filter.toUpperCase() == 'ALL') {
      return calculateOverallPnl(
        transactions: transactions,
        cashTransactions: cashTransactions,
        currentAssets: currentAssets,
        totalBorrowedLiability: totalBorrowedLiability,
      );
    }

    final now = referenceDate ?? DateTime.now();
    final DateTime cutoff;
    if (filter == '1D') {
      cutoff = DateTime(now.year, now.month, now.day);
    } else {
      int days = 30;
      if (filter == '7D') days = 7;
      if (filter == '30D') days = 30;
      if (filter == '180D') days = 180;
      if (filter == '360D') days = 360;
      cutoff = now.subtract(Duration(days: days));
    }

    double inc = 0;
    double exp = 0;

    for (final tx in transactions) {
      if (tx.date.isAfter(cutoff) || tx.date.isAtSameMomentAs(cutoff)) {
        final isPassThrough = tx.resolvedReason?.toLowerCase() == 'pass-through' ||
            tx.resolvedReason?.toLowerCase() == 'pass through' ||
            tx.resolvedReason?.toLowerCase() == 'bounce' ||
            tx.resolvedReason?.toLowerCase() == 'internal transfer';
        final isAtmOrCashTransfer = tx.resolvedReason?.toLowerCase() == 'cash' ||
            tx.resolvedReason?.toLowerCase() == 'cash withdrawal' ||
            tx.resolvedReason?.toLowerCase() == 'atm';
        if (!isPassThrough && !isAtmOrCashTransfer) {
          if (tx.type == 'income') inc += tx.amount;
          if (tx.type == 'expense') exp += tx.amount;
        }
      }
    }

    if (cashTransactions != null) {
      for (final ctx in cashTransactions) {
        if (ctx.date.isAfter(cutoff) || ctx.date.isAtSameMomentAs(cutoff)) {
          if (ctx.isIncome) inc += ctx.amount;
          if (ctx.isExpense) exp += ctx.amount;
        }
      }
    }

    return inc - exp;
  }

  /// Calculates percentage change for a given PnL value relative to total assets.
  double calculatePercentageChange({
    required double pnl,
    required double totalAssets,
  }) {
    if (totalAssets <= 0) return 0.0;
    return ((pnl / totalAssets) * 100).clamp(-100.0, 100.0);
  }

  /// Calculates (change, percent) for a specific bank account or sender over a given filter timeframe.
  (double change, double percent) calculateAccountPeriodPnl({
    required List<AppTransaction> transactions,
    required String filter,
    required double currentBalance,
    DateTime? referenceDate,
  }) {
    if (transactions.isEmpty) return (0.0, 0.0);

    final now = referenceDate ?? DateTime.now();
    final DateTime cutoff;
    if (filter == '1D') {
      cutoff = DateTime(now.year, now.month, now.day);
    } else {
      int days = 30;
      if (filter == '7D') days = 7;
      if (filter == '30D') days = 30;
      if (filter == '180D') days = 180;
      if (filter == '360D') days = 360;
      cutoff = now.subtract(Duration(days: days));
    }

    double change = 0.0;
    for (final tx in transactions) {
      if (tx.date.isAfter(cutoff) || tx.date.isAtSameMomentAs(cutoff)) {
        final isPassThrough = tx.resolvedReason?.toLowerCase() == 'pass-through' ||
            tx.resolvedReason?.toLowerCase() == 'pass through' ||
            tx.resolvedReason?.toLowerCase() == 'bounce' ||
            tx.resolvedReason?.toLowerCase() == 'internal transfer';
        if (!isPassThrough) {
          if (tx.type == 'income') {
            change += tx.amount;
          } else {
            change -= tx.amount;
          }
        }
      }
    }

    double percent = 0.0;
    final baseline = (currentBalance - change).abs();
    if (baseline > 0) {
      percent = (change / baseline) * 100;
    } else if (currentBalance.abs() > 0) {
      percent = (change / currentBalance.abs()) * 100;
    }
    if (percent.isInfinite || percent.isNaN) percent = 0.0;

    return (change, percent);
  }
}
