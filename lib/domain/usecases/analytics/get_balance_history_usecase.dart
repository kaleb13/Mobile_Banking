import 'package:fl_chart/fl_chart.dart';
import '../../../models/transaction.dart';
import '../../../models/cash_transaction.dart';

class BalanceHistoryPoint {
  final DateTime date;
  final double bankBalance;
  final double cashBalance;
  final double totalBalance;

  const BalanceHistoryPoint({
    required this.date,
    required this.bankBalance,
    required this.cashBalance,
    required this.totalBalance,
  });
}

class BalanceHistoryResult {
  final List<FlSpot> spots;
  final List<BalanceHistoryPoint> points;
  final double minBalance;
  final double maxBalance;
  final double latestBalance;
  final DateTime startDate;
  final DateTime endDate;

  const BalanceHistoryResult({
    required this.spots,
    required this.points,
    required this.minBalance,
    required this.maxBalance,
    required this.latestBalance,
    required this.startDate,
    required this.endDate,
  });
}

class GetBalanceHistoryUseCase {
  const GetBalanceHistoryUseCase();

  /// Calculates day-by-day balance simulation curves across all bank accounts
  /// and cash wallet, matching the exact logic of the wallet balances.
  BalanceHistoryResult execute({
    required List<AppTransaction> transactions,
    required List<CashTransaction> cashTransactions,
    required String filter, // '1D', '7D', '30D', '180D', '360D', 'ALL'
    DateTime? referenceDate,
    Set<String>? allowedBanks,
  }) {
    final now = referenceDate ?? DateTime.now();
    final nowMidnight = DateTime(now.year, now.month, now.day);

    final List<AppTransaction> scopedTxs;
    if (allowedBanks != null && allowedBanks.isNotEmpty) {
      final upperAllowed =
          allowedBanks.map((b) => b.trim().toUpperCase()).toSet();
      scopedTxs = transactions
          .where((tx) => upperAllowed.contains(tx.name.trim().toUpperCase()))
          .toList();
    } else {
      scopedTxs = transactions;
    }

    // Determine the max number of days for the chosen filter
    int maxFilterDays = 30;
    if (filter == '1D') maxFilterDays = 2;
    if (filter == '7D') maxFilterDays = 7;
    if (filter == '30D') maxFilterDays = 30;
    if (filter == '180D') maxFilterDays = 180;
    if (filter == '360D') maxFilterDays = 360;
    if (filter == 'ALL') maxFilterDays = 3650;

    // Find the oldest recorded transaction or cash transaction
    DateTime? oldestDate;
    for (final tx in scopedTxs) {
      if (oldestDate == null || tx.date.isBefore(oldestDate)) {
        oldestDate = tx.date;
      }
    }
    for (final ctx in cashTransactions) {
      if (oldestDate == null || ctx.date.isBefore(oldestDate)) {
        oldestDate = ctx.date;
      }
    }

    int daysLimit = maxFilterDays;
    if (oldestDate != null) {
      final oldestMidnight =
          DateTime(oldestDate.year, oldestDate.month, oldestDate.day);
      final daysAvailable = nowMidnight.difference(oldestMidnight).inDays + 1;
      if (filter == '1D') {
        daysLimit = 2;
      } else {
        daysLimit = daysAvailable.clamp(2, maxFilterDays);
      }
    } else {
      daysLimit = filter == '1D' ? 2 : maxFilterDays.clamp(2, 30);
    }

    final DateTime actualChartStart =
        nowMidnight.subtract(Duration(days: daysLimit - 1));

    // Sort transactions oldest-first
    final sortedTxs = List<AppTransaction>.from(scopedTxs)
      ..sort((a, b) => a.date.compareTo(b.date));
    final sortedCashTxs = List<CashTransaction>.from(cashTransactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Walk day by day
    final Map<String, double> lastKnownBalance = {};
    double currentCashBalance = 0;

    bool isCashTransfer(AppTransaction tx) {
      return tx.reason?.toLowerCase() == 'cash' ||
          tx.customReasonText?.toLowerCase() == 'cash' ||
          tx.resolvedReason?.toLowerCase() == 'cash';
    }

    // Pre-seed all accounts with their earliest known positive balance in history
    // so that active accounts don't start at zero before their first transaction in this window.
    for (final tx in sortedTxs) {
      final accountKey = '${tx.name.trim().toUpperCase()}:${tx.simSlot}';
      if (!lastKnownBalance.containsKey(accountKey) && tx.totalBalance > 0) {
        lastKnownBalance[accountKey] = tx.totalBalance;
      }
    }

    // Accumulate cash pre-seed strictly BEFORE the chart window
    for (final tx in sortedTxs) {
      if (tx.date.isBefore(actualChartStart)) {
        final accountKey = '${tx.name.trim().toUpperCase()}:${tx.simSlot}';
        if (tx.totalBalance > 0) {
          lastKnownBalance[accountKey] = tx.totalBalance;
        } else if (lastKnownBalance.containsKey(accountKey)) {
          if (tx.type == 'income') {
            lastKnownBalance[accountKey] = lastKnownBalance[accountKey]! + tx.amount;
          } else {
            final newBal = lastKnownBalance[accountKey]! - tx.amount;
            lastKnownBalance[accountKey] = newBal > 0 ? newBal : 0.0;
          }
        }
        if (isCashTransfer(tx)) {
          if (tx.type == 'expense') {
            currentCashBalance += tx.amount.abs();
          } else {
            currentCashBalance -= tx.amount.abs();
          }
        }
      }
    }
    for (final ctx in sortedCashTxs) {
      if (ctx.date.isBefore(actualChartStart)) {
        if (ctx.type == 'addition') {
          currentCashBalance += ctx.amount;
        } else {
          currentCashBalance -= ctx.amount;
        }
      }
    }

    // Group transactions by calendar day key
    final Map<String, List<AppTransaction>> txsByDay = {};
    for (final tx in sortedTxs) {
      if (!tx.date.isBefore(actualChartStart)) {
        final key = '${tx.date.year}-${tx.date.month}-${tx.date.day}';
        txsByDay.putIfAbsent(key, () => []).add(tx);
      }
    }
    final Map<String, List<CashTransaction>> cashTxsByDay = {};
    for (final ctx in sortedCashTxs) {
      if (!ctx.date.isBefore(actualChartStart)) {
        final key = '${ctx.date.year}-${ctx.date.month}-${ctx.date.day}';
        cashTxsByDay.putIfAbsent(key, () => []).add(ctx);
      }
    }

    final List<FlSpot> spots = [];
    final List<BalanceHistoryPoint> points = [];
    double minBal = double.infinity;
    double maxBal = -double.infinity;

    for (int i = 0; i < daysLimit; i++) {
      final d = actualChartStart.add(Duration(days: i));
      final key = '${d.year}-${d.month}-${d.day}';

      // Update bank balances
      final dayTxs = txsByDay[key];
      if (dayTxs != null) {
        for (final tx in dayTxs) {
          final accountKey = '${tx.name.trim().toUpperCase()}:${tx.simSlot}';
          if (tx.totalBalance > 0) {
            lastKnownBalance[accountKey] = tx.totalBalance;
          } else if (lastKnownBalance.containsKey(accountKey)) {
            if (tx.type == 'income') {
              lastKnownBalance[accountKey] = lastKnownBalance[accountKey]! + tx.amount;
            } else {
              final newBal = lastKnownBalance[accountKey]! - tx.amount;
              lastKnownBalance[accountKey] = newBal > 0 ? newBal : 0.0;
            }
          }
          if (isCashTransfer(tx)) {
            if (tx.type == 'expense') {
              currentCashBalance += tx.amount.abs();
            } else {
              currentCashBalance -= tx.amount.abs();
            }
          }
        }
      }

      // Update cash transactions
      final dayCashTxs = cashTxsByDay[key];
      if (dayCashTxs != null) {
        for (final ctx in dayCashTxs) {
          if (ctx.type == 'addition') {
            currentCashBalance += ctx.amount;
          } else {
            currentCashBalance -= ctx.amount;
          }
        }
      }

      final bankTotal = lastKnownBalance.values.fold(0.0, (sum, v) => sum + v);
      final effectiveCash = currentCashBalance > 0 ? currentCashBalance : 0.0;
      final totalBal = bankTotal + effectiveCash;

      if (totalBal < minBal) minBal = totalBal;
      if (totalBal > maxBal) maxBal = totalBal;

      spots.add(FlSpot(i.toDouble(), totalBal));
      points.add(BalanceHistoryPoint(
        date: d,
        bankBalance: bankTotal,
        cashBalance: effectiveCash,
        totalBalance: totalBal,
      ));
    }

    final latestBal = spots.isNotEmpty ? spots.last.y : 0.0;

    return BalanceHistoryResult(
      spots: spots,
      points: points,
      minBalance: minBal == double.infinity ? 0.0 : minBal,
      maxBalance: maxBal == -double.infinity ? 0.0 : maxBal,
      latestBalance: latestBal,
      startDate: actualChartStart,
      endDate: now,
    );
  }
}
