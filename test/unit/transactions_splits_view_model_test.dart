import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/sender.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/models/transaction_split.dart';
import 'package:mobile_banking_app/models/reason.dart';
import 'package:mobile_banking_app/data/repositories/transaction_repository.dart';
import 'package:mobile_banking_app/presentation/viewmodels/transactions_view_model.dart';

class MockTransactionSplitsRepo implements TransactionRepository {
  List<AppSender> senders = [];
  List<AppTransaction> transactions = [];
  List<AppReason> reasons = [];
  List<AppReasonLink> reasonLinks = [];
  Set<String> pausedBanks = {};
  Map<String, List<TransactionSplit>> splitsMap = {};

  @override
  Future<List<AppTransaction>> getTransactions({int? limit, int? offset}) async => transactions;
  @override
  Future<List<AppSender>> getSenders() async => senders;
  @override
  Future<List<AppReason>> getReasons() async => reasons;
  @override
  Future<List<AppReasonLink>> getReasonLinks() async => reasonLinks;
  @override
  Future<Set<String>> getPausedBanks() async => pausedBanks;
  @override
  Future<void> setPausedBanks(Set<String> paused) async => pausedBanks = paused;

  @override
  Future<List<TransactionSplit>> getAllTransactionSplits() async {
    final all = <TransactionSplit>[];
    for (final list in splitsMap.values) {
      all.addAll(list);
    }
    return all;
  }

  @override
  Future<List<TransactionSplit>> getSplitsForTransaction(String transactionId) async =>
      splitsMap[transactionId] ?? [];

  @override
  Future<void> saveTransactionSplits(String transactionId, List<TransactionSplit> splits) async {
    if (splits.isEmpty) {
      splitsMap.remove(transactionId);
    } else {
      splitsMap[transactionId] = List.from(splits);
    }
  }

  @override
  Future<int> deleteTransactionSplits(String transactionId) async {
    final removed = splitsMap.remove(transactionId);
    return removed?.length ?? 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TransactionsViewModel Splits Management Tests', () {
    late MockTransactionSplitsRepo repo;
    late TransactionsViewModel viewModel;

    setUp(() {
      repo = MockTransactionSplitsRepo();
      viewModel = TransactionsViewModel(repository: repo);
    });

    test('Loads and caches splits correctly on loadAll()', () async {
      final tx = AppTransaction(
        id: 'tx_300',
        name: 'Telebirr',
        amount: 300.0,
        type: 'expense',
        date: DateTime.now(),
        sender: '0935389104',
        category: 'Transfer',
        rawMessage: 'You have transferred 300 ETB',
        isAutoDetected: true,
        totalBalance: 1200.0,
      );

      final splits = [
        TransactionSplit(
          id: 1,
          transactionId: 'tx_300',
          amount: 100.0,
          reasonName: 'Mobile & Internet',
          note: 'Airtime',
        ),
        TransactionSplit(
          id: 2,
          transactionId: 'tx_300',
          amount: 57.0,
          reasonName: 'Food',
          note: 'Lunch',
        ),
        TransactionSplit(
          id: 3,
          transactionId: 'tx_300',
          amount: 143.0,
          reasonName: 'Transportation',
          note: 'Taxi',
        ),
      ];

      repo.transactions = [tx];
      repo.splitsMap = {'tx_300': splits};

      await viewModel.loadAll();

      expect(viewModel.hasSplits('tx_300'), isTrue);
      expect(viewModel.hasSplits('tx_non_existent'), isFalse);

      final loadedSplits = viewModel.getSplitsForTransaction('tx_300');
      expect(loadedSplits.length, 3);
      expect(loadedSplits[0].amount, 100.0);
      expect(loadedSplits[1].amount, 57.0);
      expect(loadedSplits[2].amount, 143.0);
      expect(viewModel.getSplitTotal('tx_300'), 300.0);
    });

    test('Saving and deleting splits updates state and notifies listeners', () async {
      await viewModel.loadAll();

      final splits = [
        TransactionSplit(
          transactionId: 'tx_500',
          amount: 250.0,
          reasonName: 'Groceries',
        ),
        TransactionSplit(
          transactionId: 'tx_500',
          amount: 250.0,
          reasonName: 'Utilities',
        ),
      ];

      bool notified = false;
      viewModel.addListener(() => notified = true);

      await viewModel.saveTransactionSplits('tx_500', splits);

      expect(notified, isTrue);
      expect(viewModel.hasSplits('tx_500'), isTrue);
      expect(viewModel.getSplitsForTransaction('tx_500').length, 2);
      expect(viewModel.getSplitTotal('tx_500'), 500.0);
      expect(viewModel.totalSplitsCount, 2);

      notified = false;
      await viewModel.deleteTransactionSplits('tx_500');

      expect(notified, isTrue);
      expect(viewModel.hasSplits('tx_500'), isFalse);
      expect(viewModel.getSplitsForTransaction('tx_500'), isEmpty);
      expect(viewModel.getSplitTotal('tx_500'), 0.0);
      expect(viewModel.totalSplitsCount, 0);
    });
  });
}
