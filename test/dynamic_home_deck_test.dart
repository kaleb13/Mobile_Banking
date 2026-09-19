import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/sender.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/models/reason.dart';
import 'package:mobile_banking_app/models/transaction_split.dart';
import 'package:mobile_banking_app/presentation/viewmodels/transactions_view_model.dart';
import 'package:mobile_banking_app/data/repositories/transaction_repository.dart';

class FakeTxRepo implements TransactionRepository {
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
    return senders.length + 1;
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

  group('Dynamic Home Deck & Sender Activation Tests', () {
    test('Default senders seed contains only top 3 core banks: Telebirr, CBE, and CBE Birr', () async {
      final repo = FakeTxRepo();
      repo.senders = [
        AppSender(id: '1', senderName: 'Telebirr'),
        AppSender(id: '2', senderName: 'CBE'),
        AppSender(id: '3', senderName: 'CBE Birr'),
      ];

      final txVM = TransactionsViewModel(repository: repo);
      await txVM.loadAll();

      expect(txVM.senders.length, 3);
      expect(txVM.activeSenders.take(3).map((s) => s.senderName).toList(), [
        'Telebirr',
        'CBE',
        'CBE Birr',
      ]);
    });

    test('Home deck dynamically displays whichever top 3 banks are active and unpaused', () async {
      final repo = FakeTxRepo();
      repo.senders = [
        AppSender(id: '1', senderName: 'Telebirr'),
        AppSender(id: '2', senderName: 'CBE'),
        AppSender(id: '3', senderName: 'CBE Birr'),
        AppSender(id: '4', senderName: 'Dashen Bank'),
        AppSender(id: '5', senderName: 'BOA'),
      ];

      final txVM = TransactionsViewModel(repository: repo);
      await txVM.loadAll();

      // Initially top 3 active are Telebirr, CBE, CBE Birr
      expect(txVM.activeSenders.take(3).map((s) => s.senderName).toList(), [
        'Telebirr',
        'CBE',
        'CBE Birr',
      ]);

      // When CBE is paused, top 3 active becomes Telebirr, CBE Birr, Dashen Bank
      await txVM.pauseTracking('CBE');
      expect(txVM.activeSenders.take(3).map((s) => s.senderName).toList(), [
        'Telebirr',
        'CBE Birr',
        'Dashen Bank',
      ]);

      // When Telebirr is also paused, top 3 active becomes CBE Birr, Dashen Bank, BOA
      await txVM.pauseTracking('Telebirr');
      expect(txVM.activeSenders.take(3).map((s) => s.senderName).toList(), [
        'CBE Birr',
        'Dashen Bank',
        'BOA',
      ]);

      // When CBE is resumed, top 3 active dynamically updates
      await txVM.resumeTracking('CBE');
      expect(txVM.activeSenders.take(3).map((s) => s.senderName).toList(), [
        'CBE',
        'CBE Birr',
        'Dashen Bank',
      ]);
    });

    test('User with only 2 accounts dynamically supplies both to home deck', () async {
      final repo = FakeTxRepo();
      repo.senders = [
        AppSender(id: '1', senderName: 'Telebirr'),
        AppSender(id: '2', senderName: 'Dashen Bank'),
      ];

      final txVM = TransactionsViewModel(repository: repo);
      await txVM.loadAll();

      expect(txVM.activeSenders.take(3).map((s) => s.senderName).toList(), [
        'Telebirr',
        'Dashen Bank',
      ]);
    });

    test('New transactions from other banks (e.g. Dashen, BOA) dynamically register new senders', () async {
      final repo = FakeTxRepo();
      repo.senders = [
        AppSender(id: '1', senderName: 'Telebirr'),
        AppSender(id: '2', senderName: 'CBE'),
        AppSender(id: '3', senderName: 'CBE Birr'),
      ];

      final txVM = TransactionsViewModel(repository: repo);
      await txVM.loadAll();
      expect(txVM.senders.length, 3);

      // Add a transaction for Dashen Bank
      await txVM.addTransaction(AppTransaction(
        id: 'dashen_01',
        name: 'Dashen Bank',
        amount: 2500.0,
        type: 'income',
        date: DateTime.now(),
        sender: 'Employer',
        category: 'Salary',
        rawMessage: 'You received ETB 2,500.00 from Employer',
        isAutoDetected: true,
      ));

      // Dashen Bank is now dynamically added to senders
      expect(txVM.senders.length, 4);
      expect(txVM.senders.any((s) => s.senderName == 'Dashen Bank'), isTrue);
    });

    test('Arbitrary database order places Telebirr #1, CBE #2, and low-activity banks like Nib on bottom', () async {
      final repo = FakeTxRepo();
      // Simulate raw SQLite insertion order where Nib Bank is first and Telebirr is last
      repo.senders = [
        AppSender(id: '1', senderName: 'Nib Bank'),
        AppSender(id: '2', senderName: 'CBE'),
        AppSender(id: '3', senderName: 'Ahadu Bank'),
        AppSender(id: '4', senderName: 'Telebirr'),
      ];

      // Give Telebirr and CBE transactions and balances
      repo.transactions = [
        AppTransaction(
          id: 'tx_telebirr',
          bankName: 'Telebirr',
          amount: 500.0,
          type: 'income',
          date: DateTime.now(),
          counterparty: 'Sender',
          totalBalance: 2480.0,
          rawMessage: 'Telebirr income',
          isAutoDetected: true,
        ),
        AppTransaction(
          id: 'tx_cbe',
          bankName: 'CBE',
          amount: 100.0,
          type: 'income',
          date: DateTime.now(),
          counterparty: 'Sender',
          totalBalance: 100.0,
          rawMessage: 'CBE income',
          isAutoDetected: true,
        ),
        AppTransaction(
          id: 'tx_ahadu',
          bankName: 'Ahadu Bank',
          amount: 50.0,
          type: 'income',
          date: DateTime.now(),
          counterparty: 'Sender',
          totalBalance: 50.0,
          rawMessage: 'Ahadu income',
          isAutoDetected: true,
        ),
      ];

      final txVM = TransactionsViewModel(repository: repo);
      await txVM.loadAll();

      // Telebirr MUST be at index 0 (#1), CBE at index 1 (#2), Ahadu at index 2, and Nib Bank at index 3
      final activeNames = txVM.activeSenders.map((s) => s.senderName).toList();
      expect(activeNames, [
        'Telebirr',
        'CBE',
        'Ahadu Bank',
        'Nib Bank',
      ]);
      expect(txVM.activeSenders.first.senderName, 'Telebirr');
      expect(txVM.activeSenders.last.senderName, 'Nib Bank');
    });
  });
}
