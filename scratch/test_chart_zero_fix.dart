import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/models/cash_transaction.dart';
import 'package:mobile_banking_app/domain/usecases/analytics/get_balance_history_usecase.dart';

void main() {
  print('=== Testing Chart Zero-Balance Fix ===\n');

  final now = DateTime(2026, 8, 17);

  // User only has 13 days of history (oldest is Aug 4, 2026)
  final transactions = [
    // Aug 4 (13 days ago)
    AppTransaction(
        name: 'Dashen Bank',
        sender: 'Nahom',
        amount: 7000,
        type: 'income',
        date: DateTime(2026, 8, 4),
        category: 'Auto',
        rawMessage: '',
        isAutoDetected: true,
        totalBalance: 39226.94),
    // Aug 13
    AppTransaction(
        name: 'Dashen Bank',
        sender: 'ATM',
        amount: 5000,
        type: 'expense',
        date: DateTime(2026, 8, 13),
        category: 'Auto',
        rawMessage: '',
        isAutoDetected: true,
        totalBalance: 31119.0),
    // Aug 16
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
    // Aug 17
    AppTransaction(
        name: 'Telebirr',
        sender: 'Nahom',
        amount: 100,
        type: 'income',
        date: DateTime(2026, 8, 17),
        category: 'Auto',
        rawMessage: '',
        isAutoDetected: true,
        totalBalance: 576.0),
    AppTransaction(
        name: 'CBE',
        sender: 'Yonas',
        amount: 200,
        type: 'income',
        date: DateTime(2026, 8, 17),
        category: 'Auto',
        rawMessage: '',
        isAutoDetected: true,
        totalBalance: 382.0),
    AppTransaction(
        name: 'Ahadu Bank',
        sender: 'Transfer',
        amount: 100,
        type: 'income',
        date: DateTime(2026, 8, 17),
        category: 'Auto',
        rawMessage: '',
        isAutoDetected: true,
        totalBalance: 463.0),
    AppTransaction(
        name: 'BOA',
        sender: 'Merchant',
        amount: 500,
        type: 'expense',
        date: DateTime(2026, 8, 17),
        category: 'Auto',
        rawMessage: '',
        isAutoDetected: true,
        totalBalance: 21818.0),
  ];

  final cashTransactions = [
    CashTransaction(
        id: 1, amount: 600, type: 'addition', date: DateTime(2026, 8, 1)),
  ];

  const useCase = GetBalanceHistoryUseCase();
  final result = useCase.execute(
    transactions: transactions,
    cashTransactions: cashTransactions,
    filter: '30D',
    referenceDate: now,
  );

  print('Total spots generated: ${result.spots.length}');
  for (int i = 0; i < result.spots.length; i++) {
    final spot = result.spots[i];
    final pt = result.points[i];
    print(
        'Spot $i (${pt.date.month}/${pt.date.day}): totalBalance = ${spot.y.toStringAsFixed(2)}');
  }

  // Check if any spot has 0.0
  final zeroSpots = result.spots.where((s) => s.y == 0.0).toList();
  print('\nZero balance spots count: ${zeroSpots.length}');
}
