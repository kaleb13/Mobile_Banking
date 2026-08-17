import '../../../models/transaction.dart';

class TopExpensesResult {
  final Map<String, dynamic>? mostExpenseToday;
  final Map<String, dynamic>? mostExpenseThisMonth;
  final Map<String, dynamic>? topExpenseHighlight;

  const TopExpensesResult({
    this.mostExpenseToday,
    this.mostExpenseThisMonth,
    this.topExpenseHighlight,
  });
}

class GetTopExpensesUseCase {
  const GetTopExpensesUseCase();

  TopExpensesResult execute({
    required List<AppTransaction> transactions,
    required String Function(AppTransaction) getTopLevelCategory,
    required bool Function(DateTime, DateTime) isDateInMonthOf,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();

    final Map<String, double> todayTotals = {};
    final Map<String, double> monthTotals = {};
    final Map<String, double> overallTotals = {};

    for (final tx in transactions) {
      if (tx.type != 'expense') continue;

      final resolvedReasonLower = tx.resolvedReason?.toLowerCase();
      if (resolvedReasonLower == 'bounce' || resolvedReasonLower == 'internal transfer') {
        continue;
      }

      final isToday = tx.date.year == now.year &&
          tx.date.month == now.month &&
          tx.date.day == now.day;
      final isThisMonth = isDateInMonthOf(tx.date, now);

      final key = getTopLevelCategory(tx);

      if (isToday) {
        todayTotals[key] = (todayTotals[key] ?? 0) + tx.amount;
      }
      if (isThisMonth) {
        monthTotals[key] = (monthTotals[key] ?? 0) + tx.amount;
      }
      overallTotals[key] = (overallTotals[key] ?? 0) + tx.amount;
    }

    return TopExpensesResult(
      mostExpenseToday: _computeTopReason(todayTotals),
      mostExpenseThisMonth: _computeTopReason(monthTotals),
      topExpenseHighlight: _computeTopReason(overallTotals),
    );
  }

  Map<String, dynamic>? _computeTopReason(Map<String, double> totals) {
    if (totals.isEmpty) return null;
    String topKey = '';
    double maxAmt = -1;
    totals.forEach((key, amt) {
      if (amt > maxAmt) {
        maxAmt = amt;
        topKey = key;
      }
    });
    if (maxAmt <= 0) return null;
    return {'reason': topKey, 'amount': maxAmt};
  }
}
