import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/domain/usecases/analytics/calculate_pnl_usecase.dart';
import 'package:mobile_banking_app/models/cash_transaction.dart';
import 'package:mobile_banking_app/models/transaction.dart';

AppTransaction _createTx({
  required String name,
  required String sender,
  required double amount,
  required String type,
  required DateTime date,
  double totalBalance = 0.0,
  int simSlot = 0,
  String? reason,
}) {
  return AppTransaction(
    name: name,
    sender: sender,
    amount: amount,
    type: type,
    date: date,
    category: 'Auto',
    rawMessage: '',
    isAutoDetected: true,
    totalBalance: totalBalance,
    simSlot: simSlot,
    reason: reason,
  );
}

void main() {
  group('CalculatePnlUseCase', () {
    const useCase = CalculatePnlUseCase();

    test('calculates bipolar PnL (profit and loss) against baseline', () {
      final transactions = [
        _createTx(
          name: 'Telebirr',
          sender: 'Transfer',
          amount: 500,
          type: 'income',
          date: DateTime(2026, 1, 1),
          totalBalance: 1000.0,
        ),
      ];

      // Current assets higher than baseline: profit
      final profit = useCase.calculateOverallPnl(
        transactions: transactions,
        currentAssets: 1500.0,
        totalBorrowedLiability: 0.0,
      );
      expect(profit, 500.0);

      // Current assets lower than baseline: deficit / loss (must NOT clamp to 0)
      final loss = useCase.calculateOverallPnl(
        transactions: transactions,
        currentAssets: 700.0,
        totalBorrowedLiability: 0.0,
      );
      expect(loss, -300.0);

      // Deficit with borrowed liability
      final lossWithLiability = useCase.calculateOverallPnl(
        transactions: transactions,
        currentAssets: 1000.0,
        totalBorrowedLiability: 400.0,
      );
      expect(lossWithLiability, -400.0);
    });

    test('falls back to net flow when earliest SMS baseline is zero', () {
      final transactions = [
        _createTx(
          name: 'Telebirr',
          sender: 'Salary',
          amount: 5000,
          type: 'income',
          date: DateTime(2026, 2, 1),
          totalBalance: 0.0,
        ),
        _createTx(
          name: 'Telebirr',
          sender: 'Groceries',
          amount: 2000,
          type: 'expense',
          date: DateTime(2026, 2, 5),
          totalBalance: 0.0,
        ),
      ];

      final cashTransactions = [
        CashTransaction(
          id: 1,
          type: 'expense',
          amount: 500,
          date: DateTime(2026, 2, 6),
        ),
      ];

      // Net income: 5000 - 2000 (SMS) - 500 (Cash) = 2500
      final netPnl = useCase.calculateOverallPnl(
        transactions: transactions,
        cashTransactions: cashTransactions,
        currentAssets: 2500.0,
        totalBorrowedLiability: 0.0,
      );
      expect(netPnl, 2500.0);
    });

    test('calculates 30-day net PnL properly', () {
      final now = DateTime(2026, 3, 15);
      final transactions = [
        _createTx(
          name: 'CBE',
          sender: 'Abebe',
          amount: 1000,
          type: 'income',
          date: DateTime(2026, 3, 10), // within 30 days
        ),
        _createTx(
          name: 'CBE',
          sender: 'Fuel',
          amount: 400,
          type: 'expense',
          date: DateTime(2026, 3, 12), // within 30 days
        ),
        _createTx(
          name: 'CBE',
          sender: 'Old',
          amount: 10000,
          type: 'income',
          date: DateTime(2026, 1, 1), // older than 30 days
        ),
      ];

      final net30 = useCase.calculate30DayNet(
        transactions: transactions,
        referenceDate: now,
      );
      expect(net30, 600.0);
    });

    test('calculatePeriodPnl filters transactions across 1D, 7D, 30D, 180D and cash entries', () {
      final now = DateTime(2026, 4, 20, 14, 0); // Reference: April 20, 2026
      final transactions = [
        _createTx(
          name: 'Telebirr',
          sender: 'Transfer Today',
          amount: 200,
          type: 'income',
          date: DateTime(2026, 4, 20, 10, 0), // 1D (Today)
        ),
        _createTx(
          name: 'Telebirr',
          sender: 'Lunch Today',
          amount: 50,
          type: 'expense',
          date: DateTime(2026, 4, 20, 12, 0), // 1D (Today)
        ),
        _createTx(
          name: 'CBE',
          sender: 'Dinner 3 Days Ago',
          amount: 150,
          type: 'expense',
          date: DateTime(2026, 4, 17), // within 7D
        ),
        _createTx(
          name: 'CBE',
          sender: 'Bonus 15 Days Ago',
          amount: 1000,
          type: 'income',
          date: DateTime(2026, 4, 5), // within 30D
        ),
        _createTx(
          name: 'BOA',
          sender: 'Contract 60 Days Ago',
          amount: 5000,
          type: 'income',
          date: DateTime(2026, 2, 20), // within 180D
        ),
      ];

      final cashTransactions = [
        CashTransaction(
          id: 1,
          type: 'expense',
          amount: 30,
          date: DateTime(2026, 4, 20, 11, 0), // 1D (Today cash)
        ),
        CashTransaction(
          id: 2,
          type: 'income',
          amount: 200,
          date: DateTime(2026, 4, 18), // within 7D cash
        ),
      ];

      // 1D: (200 income - 50 expense) - 30 cash expense = +120
      final pnl1D = useCase.calculatePeriodPnl(
        transactions: transactions,
        cashTransactions: cashTransactions,
        filter: '1D',
        currentAssets: 10000.0,
        referenceDate: now,
      );
      expect(pnl1D, 120.0);

      // 7D: 1D (+120) - 150 (CBE 3d) + 200 (cash 2d) = +170
      final pnl7D = useCase.calculatePeriodPnl(
        transactions: transactions,
        cashTransactions: cashTransactions,
        filter: '7D',
        currentAssets: 10000.0,
        referenceDate: now,
      );
      expect(pnl7D, 170.0);

      // 30D: 7D (+170) + 1000 (CBE 15d) = +1170
      final pnl30D = useCase.calculatePeriodPnl(
        transactions: transactions,
        cashTransactions: cashTransactions,
        filter: '30D',
        currentAssets: 10000.0,
        referenceDate: now,
      );
      expect(pnl30D, 1170.0);

      // 180D: 30D (+1170) + 5000 (BOA 60d) = +6170
      final pnl180D = useCase.calculatePeriodPnl(
        transactions: transactions,
        cashTransactions: cashTransactions,
        filter: '180D',
        currentAssets: 10000.0,
        referenceDate: now,
      );
      expect(pnl180D, 6170.0);
    });

    test('calculatePercentageChange computes correct signed percentage', () {
      expect(useCase.calculatePercentageChange(pnl: 500.0, totalAssets: 10000.0), 5.0);
      expect(useCase.calculatePercentageChange(pnl: -300.0, totalAssets: 10000.0), -3.0);
      expect(useCase.calculatePercentageChange(pnl: 0.0, totalAssets: 10000.0), 0.0);
      expect(useCase.calculatePercentageChange(pnl: 100.0, totalAssets: 0.0), 0.0);
    });

    test('calculateAccountPeriodPnl computes correct change and percent for an individual account', () {
      final now = DateTime(2026, 3, 20, 15, 0, 0);
      final accountTx = [
        _createTx(
          name: 'CBE',
          sender: 'Salary',
          amount: 5000,
          type: 'income',
          date: now.subtract(const Duration(days: 10)),
        ),
        _createTx(
          name: 'CBE',
          sender: 'Pass-through test',
          amount: 3000,
          type: 'income',
          date: now.subtract(const Duration(days: 5)),
          reason: 'pass-through',
        ),
        _createTx(
          name: 'CBE',
          sender: 'Groceries',
          amount: 1500,
          type: 'expense',
          date: now.subtract(const Duration(days: 2)),
        ),
        _createTx(
          name: 'CBE',
          sender: 'Coffee',
          amount: 100,
          type: 'expense',
          date: now.subtract(const Duration(hours: 3)),
        ),
      ];

      // 1D: only coffee (-100)
      final (pnl1D, pct1D) = useCase.calculateAccountPeriodPnl(
        transactions: accountTx,
        filter: '1D',
        currentBalance: 10000.0,
        referenceDate: now,
      );
      expect(pnl1D, -100.0);
      expect(pct1D < 0, true);

      // 7D: groceries (-1500) + coffee (-100) = -1600 (pass-through is ignored)
      final (pnl7D, _) = useCase.calculateAccountPeriodPnl(
        transactions: accountTx,
        filter: '7D',
        currentBalance: 10000.0,
        referenceDate: now,
      );
      expect(pnl7D, -1600.0);

      // 30D: salary (+5000) - groceries (-1500) - coffee (-100) = +3400
      final (pnl30D, _) = useCase.calculateAccountPeriodPnl(
        transactions: accountTx,
        filter: '30D',
        currentBalance: 10000.0,
        referenceDate: now,
      );
      expect(pnl30D, 3400.0);
    });
  });
}
