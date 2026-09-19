import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/presentation/viewmodels/transactions_view_model.dart';
import 'package:mobile_banking_app/data/repositories/transaction_repository.dart';
import 'package:mobile_banking_app/data/repositories/settings_repository.dart';

class _FakeTransactionRepository implements TransactionRepository {
  final List<AppTransaction> dbTransactions = [];

  @override
  Future<List<AppTransaction>> getTransactions({int? limit, int? offset}) async =>
      List.from(dbTransactions);

  @override
  Future<int> deleteTransaction(String id) async {
    dbTransactions.removeWhere((t) => t.id == id);
    return 1;
  }

  @override
  Future<int> insertTransaction(AppTransaction transaction) async {
    dbTransactions.add(transaction);
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<Set<String>> getHiddenBalanceBanks() async => <String>{};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Cash Wallet Synchronization & Balance Contract', () {
    test('balanceForSender respects legitimate 0.0 cash balance without falling back to stale caches', () {
      final repo = _FakeTransactionRepository();
      final settingsRepo = _FakeSettingsRepository();
      final vm = TransactionsViewModel(repository: repo, settingsRepository: settingsRepo);

      // When cashBalance is explicitly 0.0, balanceForSender must return 0.0
      expect(vm.balanceForSender('Cash Wallet', cashBalance: 0.0), 0.0);

      // When cashBalance is positive, balanceForSender must return that amount
      expect(vm.balanceForSender('Cash Wallet', cashBalance: 1250.50), 1250.50);
    });
  });
}
