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

    test('correctly sums multiple SIM accounts of the same bank without collision', () {
      final now = DateTime(2026, 8, 17);
      final transactions = [
        // Telebirr on SIM 0 has 5,000 ETB
        AppTransaction(name: 'Telebirr', sender: 'Sender A', amount: 1000, type: 'income', date: DateTime(2026, 8, 15), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 5000.0, simSlot: 0),
        // Telebirr on SIM 1 has 2,500 ETB
        AppTransaction(name: 'Telebirr', sender: 'Sender B', amount: 500, type: 'income', date: DateTime(2026, 8, 16), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 2500.0, simSlot: 1),
      ];

      final result = useCase.execute(
        transactions: transactions,
        cashTransactions: const [],
        filter: '30D',
        referenceDate: now,
      );

      // Latest combined balance should be 5000 (SIM 0) + 2500 (SIM 1) = 7500.0
      expect(result.latestBalance, 7500.0);
    });

    test('isolates allowedBanks strictly and ignores foreign or unassigned bank transactions', () {
      final now = DateTime(2026, 8, 17);
      final transactions = [
        // Active Telebirr on SIM 0 has 17,000 ETB
        AppTransaction(name: 'Telebirr', sender: 'Sender A', amount: 1000, type: 'income', date: DateTime(2026, 8, 15), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 17000.0, simSlot: 0),
        // Active Telebirr on SIM 1 has 34 ETB
        AppTransaction(name: 'Telebirr', sender: 'Sender B', amount: 34, type: 'income', date: DateTime(2026, 8, 16), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 34.0, simSlot: 1),
        // Foreign/Imported CBE from external backup has 28,000 ETB
        AppTransaction(name: 'CBE', sender: 'External Account', amount: 5000, type: 'income', date: DateTime(2026, 8, 16), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 28000.0, simSlot: 0),
      ];

      // When only Telebirr is an active wallet
      final result = useCase.execute(
        transactions: transactions,
        cashTransactions: const [],
        filter: '30D',
        referenceDate: now,
        allowedBanks: {'Telebirr'},
      );

      // Latest combined balance should ONLY be 17000 + 34 = 17034.0 (ignoring CBE 28000)
      expect(result.latestBalance, 17034.0);
    });
  });
}
