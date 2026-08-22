import 'package:mobile_banking_app/models/transaction.dart';

void main() {
  print('=== Simulating Dashboard Line Chart Calculation ===\n');

  final now = DateTime(2026, 8, 17);
  final chartFilter = '30D'; // 30 days
  final daysLimit = 30;
  final actualChartStart = now.subtract(Duration(days: daysLimit - 1));

  // User's transactions across all banks
  final transactions = [
    // 2024 Dashen Deposit (before chart window)
    AppTransaction(
        name: 'Dashen Bank',
        sender: 'ABREHAHSILASSIEHIRUY',
        amount: 8000,
        type: 'income',
        date: DateTime(2024, 1, 29),
        category: 'Auto',
        rawMessage: '',
        isAutoDetected: true,
        totalBalance: 368464.98),
    // 2026 Feb Dashen (before chart window)
    AppTransaction(
        name: 'Dashen Bank',
        sender: 'Nahom',
        amount: 7000,
        type: 'income',
        date: DateTime(2026, 2, 4),
        category: 'Auto',
        rawMessage: '',
        isAutoDetected: true,
        totalBalance: 39226.94),
    // 2026 Aug 13 Dashen ATM
    AppTransaction(
        name: 'Dashen Bank',
        sender: 'ATM / Cash Withdrawal',
        amount: 5000,
        type: 'expense',
        date: DateTime(2026, 8, 13, 14, 15),
        category: 'Auto',
        rawMessage: '',
        isAutoDetected: true,
        totalBalance: 31119.0),

    // Telebirr
    AppTransaction(
        name: 'Telebirr',
        sender: 'Abreham',
        amount: 50,
        type: 'expense',
        date: DateTime(2026, 8, 16),
        category: 'Auto',
        rawMessage: '',
        isAutoDetected: true,
        totalBalance: 476.0),
    AppTransaction(
        name: 'Telebirr',
        sender: 'Nahom',
        amount: 100,
        type: 'income',
        date: DateTime(2026, 8, 17, 10),
        category: 'Auto',
        rawMessage: '',
        isAutoDetected: true,
        totalBalance: 576.0),

    // CBE
    AppTransaction(
        name: 'CBE',
        sender: 'Salary',
        amount: 1000,
        type: 'income',
        date: DateTime(2026, 8, 1),
        category: 'Auto',
        rawMessage: '',
        isAutoDetected: true,
        totalBalance: 182.0),
    AppTransaction(
        name: 'CBE',
        sender: 'Yonas',
        amount: 200,
        type: 'income',
        date: DateTime(2026, 8, 17, 9),
        category: 'Auto',
        rawMessage: '',
        isAutoDetected: true,
        totalBalance: 382.0),

    // Ahadu Bank
    AppTransaction(
        name: 'Ahadu Bank',
        sender: 'Transfer',
        amount: 100,
        type: 'income',
        date: DateTime(2026, 8, 17, 8),
        category: 'Auto',
        rawMessage: '',
        isAutoDetected: true,
        totalBalance: 463.0),

    // BOA
    AppTransaction(
        name: 'BOA',
        sender: 'Merchant',
        amount: 500,
        type: 'expense',
        date: DateTime(2026, 8, 17, 7),
        category: 'Auto',
        rawMessage: '',
        isAutoDetected: true,
        totalBalance: 21818.0),
  ];

  final sortedTxs = List<AppTransaction>.from(transactions)
    ..sort((a, b) => a.date.compareTo(b.date));
  final Map<String, double> lastKnownBalance = {};
  double currentCashBalance = 600.0; // cash wallet

  // Pre-seed
  for (final tx in sortedTxs) {
    if (tx.date.isBefore(actualChartStart)) {
      if (tx.totalBalance > 0) {
        lastKnownBalance[tx.name] = tx.totalBalance;
      }
    }
  }
  print(
      'Pre-seeded balances before ${actualChartStart.toIso8601String()}: $lastKnownBalance\n');

  // Group by day
  final Map<String, List<AppTransaction>> txsByDay = {};
  for (final tx in sortedTxs) {
    if (!tx.date.isBefore(actualChartStart)) {
      final key = '${tx.date.year}-${tx.date.month}-${tx.date.day}';
      txsByDay.putIfAbsent(key, () => []).add(tx);
    }
  }

  double latestTotal = 0;
  for (int i = 0; i < daysLimit; i++) {
    final d = actualChartStart.add(Duration(days: i));
    final key = '${d.year}-${d.month}-${d.day}';

    final dayTxs = txsByDay[key];
    if (dayTxs != null) {
      for (final tx in dayTxs) {
        if (tx.totalBalance > 0) {
          lastKnownBalance[tx.name] = tx.totalBalance;
        }
      }
    }

    final bankTotal = lastKnownBalance.values.fold(0.0, (sum, v) => sum + v);
    final totalBal = bankTotal + currentCashBalance;
    latestTotal = totalBal;
    print(
        'Day ${i.toString().padLeft(2)} (${d.month}/${d.day}): Bank Total = ${bankTotal.toStringAsFixed(2).padLeft(9)} | Overall Total = ${totalBal.toStringAsFixed(2).padLeft(9)} | Bank Map = $lastKnownBalance');
  }

  print('\nFinal Point in Chart: $latestTotal');
  print('Expected Final Total: 54958.0');
  if ((latestTotal - 54958.0).abs() < 0.01) {
    print(
        '[SUCCESS] Chart calculation produces the exact 54,958.00 ETB total! 🎉');
  } else {
    throw Exception('Mismatch: $latestTotal != 54958.0');
  }
}
