import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/models/cash_transaction.dart';
import 'package:mobile_banking_app/domain/usecases/analytics/get_balance_history_usecase.dart';

void main() {
  group('GetBalanceHistoryUseCase', () {
    const useCase = GetBalanceHistoryUseCase();

    test('simulates day-by-day spots accurately matching ending total balance and eliminating zero-balance flat lines', () {
      final now = DateTime(2026, 8, 17);
      final transactions = [
        // Oldest transaction is from Aug 13 (5 days ago)
        AppTransaction(name: 'Dashen Bank', sender: 'ATM', amount: 5000, type: 'expense', date: DateTime(2026, 8, 13), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 31119.0),
        AppTransaction(name: 'Telebirr', sender: 'Nahom', amount: 100, type: 'income', date: DateTime(2026, 8, 17, 10), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 576.0),
        AppTransaction(name: 'CBE', sender: 'Yonas', amount: 200, type: 'income', date: DateTime(2026, 8, 17, 9), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 382.0),
        AppTransaction(name: 'Ahadu Bank', sender: 'Transfer', amount: 100, type: 'income', date: DateTime(2026, 8, 17, 8), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 463.0),
        AppTransaction(name: 'BOA', sender: 'Merchant', amount: 500, type: 'expense', date: DateTime(2026, 8, 17, 7), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 21818.0),
      ];

      final cashTransactions = [
        CashTransaction(id: 1, amount: 600, type: 'addition', date: DateTime(2026, 8, 13)),
      ];

      final result = useCase.execute(
        transactions: transactions,
        cashTransactions: cashTransactions,
        filter: '30D',
        referenceDate: now,
      );

      // Window is clamped to available 5 days (Aug 13 to Aug 17)
      expect(result.spots.length, 5);
      expect(result.latestBalance, 54958.0);

      // Verify that no spot has zero balance
      for (final spot in result.spots) {
        expect(spot.y, greaterThan(0.0));
      }
    });
  });
}
