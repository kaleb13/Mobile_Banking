import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/domain/usecases/wallets/get_wallet_balances_usecase.dart';
import 'package:mobile_banking_app/presentation/viewmodels/analytics_view_model.dart';
import 'package:mobile_banking_app/models/sender.dart';
import 'package:mobile_banking_app/models/transaction.dart';

AppTransaction _createTx({
  required String bank,
  required double totalBalance,
  required int simSlot,
  required DateTime date,
}) {
  return AppTransaction(
    id: 'TX_${bank}_${simSlot}_${date.millisecondsSinceEpoch}',
    name: bank,
    sender: bank,
    amount: 50.0,
    type: 'income',
    date: date,
    category: 'General',
    rawMessage: 'SMS body',
    isAutoDetected: true,
    totalBalance: totalBalance,
    simSlot: simSlot,
  );
}

void main() {
  group('Paused SIM & Multi-Account Total Balance Tests', () {
    const useCase = GetWalletBalancesUseCase();
    final now = DateTime.now();

    final senders = [
      AppSender(senderName: 'CBE'),
      AppSender(senderName: 'Telebirr'),
    ];

    final transactions = [
      _createTx(bank: 'CBE', totalBalance: 10000.0, simSlot: 0, date: now),
      _createTx(bank: 'CBE', totalBalance: 25000.0, simSlot: 1, date: now),
      _createTx(bank: 'Telebirr', totalBalance: 5000.0, simSlot: 0, date: now),
    ];

    test('All SIMs unpaused calculates full combined balance across all accounts', () {
      final result = useCase.execute(
        senders: senders,
        transactions: transactions,
        cashTransactions: [],
        pausedBanks: {},
      );

      expect(result.totalBalance, 40000.0); // 10k (CBE SIM1) + 25k (CBE SIM2) + 5k (Telebirr)
      expect(result.latestBalancesMap['CBE'], 35000.0);
      expect(result.latestBalancesMap['Telebirr'], 5000.0);
    });

    test('Pausing SIM 2 of CBE retains SIM 1 balance in totalBalance and latestBalancesMap', () {
      final result = useCase.execute(
        senders: senders,
        transactions: transactions,
        cashTransactions: [],
        pausedBanks: {'CBE:1'}, // Pausing SIM 2 (slot 1)
      );

      // CBE SIM 1 (10,000) + Telebirr (5,000) = 15,000
      expect(result.totalBalance, 15000.0);
      expect(result.latestBalancesMap['CBE'], 10000.0);
      expect(result.latestBalancesMap['Telebirr'], 5000.0);
    });

    test('Pausing SIM 1 of CBE retains SIM 2 balance in totalBalance and latestBalancesMap', () {
      final result = useCase.execute(
        senders: senders,
        transactions: transactions,
        cashTransactions: [],
        pausedBanks: {'CBE:0'}, // Pausing SIM 1 (slot 0)
      );

      // CBE SIM 2 (25,000) + Telebirr (5,000) = 30,000
      expect(result.totalBalance, 30000.0);
      expect(result.latestBalancesMap['CBE'], 25000.0);
      expect(result.latestBalancesMap['Telebirr'], 5000.0);
    });

    test('Pausing both SIM accounts of CBE excludes CBE from totalBalance completely', () {
      final result = useCase.execute(
        senders: senders,
        transactions: transactions,
        cashTransactions: [],
        pausedBanks: {'CBE:0', 'CBE:1'},
      );

      // Telebirr only (5,000)
      expect(result.totalBalance, 5000.0);
      expect(result.latestBalancesMap.containsKey('CBE'), isFalse);
      expect(result.latestBalancesMap['Telebirr'], 5000.0);
    });

    test('Pausing whole bank via canonical name excludes all its accounts', () {
      final result = useCase.execute(
        senders: senders,
        transactions: transactions,
        cashTransactions: [],
        pausedBanks: {'CBE'}, // Whole bank pause
      );

      expect(result.totalBalance, 5000.0);
      expect(result.latestBalancesMap.containsKey('CBE'), isFalse);
      expect(result.latestBalancesMap['Telebirr'], 5000.0);
    });

    test('AnalyticsViewModel recalculates totalBalance accurately with paused SIM', () {
      final analyticsVM = AnalyticsViewModel();
      analyticsVM.getSenders = () => senders;
      analyticsVM.getTransactions = () => transactions;
      analyticsVM.getCashTransactions = () => [];

      // Recalculate with SIM 2 paused
      analyticsVM.recalculate(pausedBanks: {'CBE:1'});

      expect(analyticsVM.totalBalance, 15000.0);
      expect(analyticsVM.getLatestBalanceForBank('CBE'), 10000.0);
      expect(analyticsVM.getLatestBalanceForBank('Telebirr'), 5000.0);
    });
  });
}
