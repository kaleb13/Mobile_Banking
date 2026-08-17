import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/sender.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/models/cash_transaction.dart';
import 'package:mobile_banking_app/domain/usecases/wallets/get_wallet_balances_usecase.dart';

void main() {
  group('GetWalletBalancesUseCase', () {
    const useCase = GetWalletBalancesUseCase();

    test('correctly sums latest balances across active banks and cash wallet', () {
      final senders = [
        AppSender(id: '1', senderName: 'Telebirr'),
        AppSender(id: '2', senderName: 'CBE'),
        AppSender(id: '3', senderName: 'CBE Birr'),
        AppSender(id: '4', senderName: 'Ahadu Bank'),
        AppSender(id: '5', senderName: 'BOA'),
        AppSender(id: '6', senderName: 'Dashen Bank'),
      ];

      final transactions = [
        AppTransaction(name: 'Telebirr', sender: 'Nahom', amount: 100, type: 'income', date: DateTime(2026, 8, 17), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 576.0),
        AppTransaction(name: 'CBE', sender: 'Yonas', amount: 200, type: 'income', date: DateTime(2026, 8, 17), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 382.0),
        AppTransaction(name: 'CBE Birr', sender: 'Airtime', amount: 50, type: 'expense', date: DateTime(2026, 8, 15), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 0.0),
        AppTransaction(name: 'Ahadu Bank', sender: 'Transfer', amount: 100, type: 'income', date: DateTime(2026, 8, 17), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 463.0),
        AppTransaction(name: 'BOA', sender: 'Merchant', amount: 500, type: 'expense', date: DateTime(2026, 8, 17), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 21818.0),
        AppTransaction(name: 'Dashen Bank', sender: 'ATM / Cash Withdrawal', amount: 5000, type: 'expense', date: DateTime(2026, 8, 13), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 31119.0),
      ];

      final cashTransactions = [
        CashTransaction(id: 1, amount: 1000, type: 'addition', date: DateTime(2026, 8, 1)),
        CashTransaction(id: 2, amount: 400, type: 'expense', date: DateTime(2026, 8, 10)),
      ]; // Net cash = 600

      final result = useCase.execute(
        senders: senders,
        transactions: transactions,
        cashTransactions: cashTransactions,
        pausedBanks: {},
      );

      expect(result.cashBalance, 600.0);
      expect(result.totalBalance, 54958.0);
      expect(result.latestBalancesMap['Telebirr'], 576.0);
      expect(result.latestBalancesMap['CBE'], 382.0);
      expect(result.latestBalancesMap['Ahadu Bank'], 463.0);
      expect(result.latestBalancesMap['BOA'], 21818.0);
      expect(result.latestBalancesMap['Dashen Bank'], 31119.0);
      expect(result.latestBalancesMap['Cash Wallet'], 600.0);
    });

    test('excludes paused banks from total balance calculation', () {
      final senders = [
        AppSender(id: '1', senderName: 'Telebirr'),
        AppSender(id: '2', senderName: 'CBE'),
      ];

      final transactions = [
        AppTransaction(name: 'Telebirr', sender: 'Nahom', amount: 100, type: 'income', date: DateTime(2026, 8, 17), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 576.0),
        AppTransaction(name: 'CBE', sender: 'Yonas', amount: 200, type: 'income', date: DateTime(2026, 8, 17), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 382.0),
      ];

      final result = useCase.execute(
        senders: senders,
        transactions: transactions,
        cashTransactions: [],
        pausedBanks: {'CBE'},
      );

      expect(result.totalBalance, 576.0);
      expect(result.latestBalancesMap.containsKey('CBE'), isFalse);
    });
  });
}
