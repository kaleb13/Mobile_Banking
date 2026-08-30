import '../../../models/transaction.dart';

class CalculatePnlUseCase {
  const CalculatePnlUseCase();

  /// Calculates overall P/L against earliest known baseline and liabilities.
  double calculateOverallPnl({
    required List<AppTransaction> transactions,
    required double currentAssets,
    required double totalBorrowedLiability,
  }) {
    double baseline = 0;
    if (transactions.isNotEmpty) {
      final Map<String, double> earliestBalances = {};
      final sorted = List<AppTransaction>.from(transactions)
        ..sort((a, b) => a.date.compareTo(b.date));
      for (final tx in sorted) {
        final accountKey = '${tx.name.trim().toUpperCase()}:${tx.simSlot}';
        if (!earliestBalances.containsKey(accountKey) && tx.totalBalance > 0) {
          earliestBalances[accountKey] = tx.totalBalance;
        }
      }
      baseline = earliestBalances.values.fold(0.0, (s, v) => s + v);
    }

    final rawPnl = currentAssets - baseline;
    final adjustedPnl = rawPnl - totalBorrowedLiability;
    if (totalBorrowedLiability > currentAssets) {
      return adjustedPnl;
    }
    return adjustedPnl.clamp(0.0, double.infinity);
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
}
