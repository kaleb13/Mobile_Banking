import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/sender.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/presentation/viewmodels/transactions_view_model.dart';
import 'package:mobile_banking_app/data/repositories/transaction_repository.dart';
import 'package:mobile_banking_app/models/reason.dart';
import 'package:mobile_banking_app/models/transaction_split.dart';

class MockTxRepo implements TransactionRepository {
  List<AppSender> senders = [];
  List<AppTransaction> transactions = [];
  List<AppReason> reasons = [];
  List<AppReasonLink> reasonLinks = [];
  Set<String> pausedBanks = {};

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
  Future<void> setPausedBanks(Set<String> paused) async {
    pausedBanks = paused;
  }
  @override
  Future<int> insertSender(AppSender sender) async {
    senders.add(sender);
    return senders.length;
  }
  @override
  Future<int> insertTransaction(AppTransaction tx) async {
    transactions.add(tx);
    return 1;
  }
  @override
  Future<int> insertTransactionsBatch(List<AppTransaction> txs) async {
    transactions.addAll(txs);
    return txs.length;
  }
  @override
  Future<int> deleteUncategorizedTransactionsForBank(String bankName) async => 0;
  @override
  Future<int> deleteUncategorizedNotificationsForBank(String bankName) async => 0;
  @override
  Future<int> deleteAllTransactions() async {
    final count = transactions.length;
    transactions.clear();
    return count;
  }
  @override
  Future<int> deleteAllUserReasons() async {
    reasons.clear();
    return 0;
  }
  @override
  Future<int> deleteAllNotifications() async => 0;
  List<TransactionSplit> splits = [];

  @override
  Future<List<TransactionSplit>> getAllTransactionSplits() async => splits;

  @override
  Future<List<TransactionSplit>> getSplitsForTransaction(String transactionId) async =>
      splits.where((s) => s.transactionId == transactionId).toList();

  @override
  Future<void> saveTransactionSplits(String transactionId, List<TransactionSplit> newSplits) async {
    splits.removeWhere((s) => s.transactionId == transactionId);
    splits.addAll(newSplits);
  }

  @override
  Future<int> deleteTransactionSplits(String transactionId) async {
    final count = splits.where((s) => s.transactionId == transactionId).length;
    splits.removeWhere((s) => s.transactionId == transactionId);
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Paused Bank Preservation & Self-Healing Tests', () {
    test('Pausing Dashen Bank retains transactions in repository without wiping', () async {
      final repo = MockTxRepo();
      final dashenTx = AppTransaction(
        id: 'tx_dashen_1',
        name: 'Dashen Bank',
        amount: 1500.0,
        type: 'income',
        date: DateTime.now(),
        sender: 'DASHEN',
        category: 'Uncategorized',
        rawMessage: 'Dear Customer, your account has been credited with ETB 1500',
        isAutoDetected: true,
        totalBalance: 4500.0,
      );

      repo.transactions = [dashenTx];
      repo.senders = [
        AppSender(id: '1', senderName: 'Telebirr'),
        AppSender(id: '2', senderName: 'CBE'),
        AppSender(id: '3', senderName: 'CBE Birr'),
        AppSender(id: '4', senderName: 'Dashen Bank'),
      ];

      final txVM = TransactionsViewModel(repository: repo);
      await txVM.loadAll();

      expect(txVM.activeSenders.map((s) => s.senderName), contains('Dashen Bank'));
      expect(txVM.pausedSenders, isEmpty);

      // Pause Dashen Bank
      await txVM.pauseTracking('Dashen Bank');

      // Verify transactions are NOT deleted from repo
      expect(repo.transactions.length, 1);
      expect(repo.transactions.first.id, 'tx_dashen_1');

      // Verify UI filtered transactions exclude Dashen Bank
      expect(txVM.transactions, isEmpty);
      expect(txVM.allTransactionsUnfiltered.length, 1);

      // Verify Dashen Bank is present in pausedSenders
      expect(txVM.activeSenders.map((s) => s.senderName), isNot(contains('Dashen Bank')));
      expect(txVM.pausedSenders.map((s) => s.senderName), contains('Dashen Bank'));
      expect(txVM.isTrackingPaused('Dashen Bank'), isTrue);
      expect(txVM.isTrackingPaused('DASHEN'), isTrue);

      // Resume Dashen Bank
      await txVM.resumeTracking('Dashen Bank');
      expect(txVM.activeSenders.map((s) => s.senderName), contains('Dashen Bank'));
      expect(txVM.pausedSenders, isEmpty);
      expect(txVM.transactions.length, 1);
      expect(txVM.balanceForSender('Dashen Bank'), 4500.0);
    });

    test('Self-healing pausedSenders when senders list is initially empty or pruned', () async {
      final repo = MockTxRepo();
      // Suppose senders only contains default 3
      repo.senders = [
        AppSender(id: '1', senderName: 'Telebirr'),
        AppSender(id: '2', senderName: 'CBE'),
        AppSender(id: '3', senderName: 'CBE Birr'),
      ];
      repo.pausedBanks = {'Dashen Bank'};

      final txVM = TransactionsViewModel(repository: repo);
      await txVM.loadAll();

      // pausedSenders should self-heal and include Dashen Bank
      expect(txVM.pausedSenders.map((s) => s.senderName), contains('Dashen Bank'));
      expect(txVM.isTrackingPaused('Dashen Bank'), isTrue);

      // Unpause Dashen Bank
      await txVM.resumeTracking('Dashen Bank');
      expect(txVM.pausedSenders, isEmpty);
      expect(txVM.isTrackingPaused('Dashen Bank'), isFalse);
    });

    test('Full reset clears paused banks and restores clean slate', () async {
      final repo = MockTxRepo();
      repo.pausedBanks = {'DASHEN BANK', 'BOA'};

      final txVM = TransactionsViewModel(repository: repo);
      await txVM.loadAll();
      expect(txVM.pausedBanks, isNotEmpty);

      await txVM.fullResetStep1DeleteTransactions();
      expect(txVM.pausedBanks, isEmpty);
      expect(repo.pausedBanks, isEmpty);
    });
  });
}
