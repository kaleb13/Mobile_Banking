import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/sender.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/models/transaction_split.dart';
import 'package:mobile_banking_app/models/reason.dart';
import 'package:mobile_banking_app/data/repositories/transaction_repository.dart';
import 'package:mobile_banking_app/presentation/viewmodels/transactions_view_model.dart';

class MockTransactionsRepo implements TransactionRepository {
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
  Future<int> updateTransaction(AppTransaction transaction) async {
    final idx = transactions.indexWhere((t) => t.id == transaction.id);
    if (idx != -1) {
      transactions[idx] = transaction;
    }
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppTransaction _createTx({
  required String id,
  required String name,
  required String sender,
  required double amount,
  required String type,
  required DateTime date,
  String? linkedTransactionId,
}) {
  return AppTransaction(
    id: id,
    name: name,
    sender: sender,
    amount: amount,
    type: type,
    date: date,
    category: 'Transfer',
    rawMessage: 'Transaction test message',
    isAutoDetected: true,
    linkedTransactionId: linkedTransactionId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TransactionsViewModel - getInternalTransferCandidates (±7 Days Range)', () {
    late MockTransactionsRepo repo;
    late TransactionsViewModel viewModel;

    final baseDate = DateTime(2026, 5, 15, 14, 0);

    final sourceExpense = _createTx(
      id: 'tx_src_expense',
      name: 'CBE',
      sender: 'CBE',
      amount: 1500.0,
      type: 'expense',
      date: baseDate,
    );

    setUp(() async {
      repo = MockTransactionsRepo();
      repo.transactions = [
        sourceExpense,
        // 1. Candidate 7 days before (Boundary inside)
        _createTx(
          id: 'tx_income_7d_before',
          name: 'Telebirr',
          sender: 'Telebirr',
          amount: 1500.0,
          type: 'income',
          date: baseDate.subtract(const Duration(days: 7)),
        ),
        // 2. Candidate 3 days before (Inside)
        _createTx(
          id: 'tx_income_3d_before',
          name: 'Telebirr',
          sender: 'Telebirr',
          amount: 1500.0,
          type: 'income',
          date: baseDate.subtract(const Duration(days: 3)),
        ),
        // 3. Candidate 5 days after (Inside)
        _createTx(
          id: 'tx_income_5d_after',
          name: 'Telebirr',
          sender: 'Telebirr',
          amount: 1500.0,
          type: 'income',
          date: baseDate.add(const Duration(days: 5)),
        ),
        // 4. Candidate 7 days after (Boundary inside)
        _createTx(
          id: 'tx_income_7d_after',
          name: 'Telebirr',
          sender: 'Telebirr',
          amount: 1500.0,
          type: 'income',
          date: baseDate.add(const Duration(days: 7)),
        ),
        // 5. Candidate 8 days before (Outside range)
        _createTx(
          id: 'tx_income_8d_before',
          name: 'Telebirr',
          sender: 'Telebirr',
          amount: 1500.0,
          type: 'income',
          date: baseDate.subtract(const Duration(days: 8)),
        ),
        // 6. Candidate 8 days after (Outside range)
        _createTx(
          id: 'tx_income_8d_after',
          name: 'Telebirr',
          sender: 'Telebirr',
          amount: 1500.0,
          type: 'income',
          date: baseDate.add(const Duration(days: 8)),
        ),
        // 7. Same amount & date, but same type (expense - should be excluded)
        _createTx(
          id: 'tx_expense_same_type',
          name: 'BOA',
          sender: 'BOA',
          amount: 1500.0,
          type: 'expense',
          date: baseDate.subtract(const Duration(days: 2)),
        ),
        // 8. Opposite type & date inside, different amount (should be included, ranked by closeness)
        _createTx(
          id: 'tx_diff_amount',
          name: 'Telebirr',
          sender: 'Telebirr',
          amount: 2000.0,
          type: 'income',
          date: baseDate.subtract(const Duration(days: 2)),
        ),
        // 9. Matching amount & date, but already linked (should be excluded)
        _createTx(
          id: 'tx_already_linked',
          name: 'Telebirr',
          sender: 'Telebirr',
          amount: 1500.0,
          type: 'income',
          linkedTransactionId: 'tx_other_123',
          date: baseDate.subtract(const Duration(days: 1)),
        ),
      ];

      viewModel = TransactionsViewModel(repository: repo);
      await viewModel.loadAll();
    });

    test('retrieves candidates within 7 days before and after source transaction ordered by closeness', () {
      final candidates = viewModel.getInternalTransferCandidates(sourceExpense);

      final ids = candidates.map((c) => c.id).toList();

      // Should include transactions from -7 days to +7 days
      expect(ids, contains('tx_income_7d_before'));
      expect(ids, contains('tx_income_3d_before'));
      expect(ids, contains('tx_income_5d_after'));
      expect(ids, contains('tx_income_7d_after'));
      expect(ids, contains('tx_diff_amount'));

      // Should NOT include outside the 7-day range
      expect(ids, isNot(contains('tx_income_8d_before')));
      expect(ids, isNot(contains('tx_income_8d_after')));

      // Should NOT include same type, or already linked, or self
      expect(ids, isNot(contains('tx_expense_same_type')));
      expect(ids, isNot(contains('tx_already_linked')));
      expect(ids, isNot(contains(sourceExpense.id)));

      // Total 5 candidates within 7 days
      expect(candidates.length, equals(5));

      // Exact matches (amount = 1500.0) must come before different amount (2000.0)
      for (int i = 0; i < 4; i++) {
        expect(candidates[i].amount, equals(1500.0));
      }
      expect(candidates.last.id, equals('tx_diff_amount'));
      expect(candidates.last.amount, equals(2000.0));
    });

    test('supports custom daysRange parameter override', () {
      // With 3-day range override, 7d and 5d are excluded
      final candidates3Days = viewModel.getInternalTransferCandidates(
        sourceExpense,
        daysRange: 3,
      );
      final ids3Days = candidates3Days.map((c) => c.id).toList();

      expect(ids3Days, contains('tx_income_3d_before'));
      expect(ids3Days, contains('tx_diff_amount')); // 2 days before
      expect(ids3Days, isNot(contains('tx_income_7d_before')));
      expect(ids3Days, isNot(contains('tx_income_5d_after')));
      expect(ids3Days, isNot(contains('tx_income_7d_after')));
      expect(candidates3Days.length, equals(2));
      // First must be exact match (1500.0)
      expect(candidates3Days.first.id, equals('tx_income_3d_before'));
    });

    test('ranks candidates with fee discrepancies (e.g. 2,000 vs 2,004) closest to target', () async {
      repo.transactions = [
        sourceExpense, // 1500.0
        _createTx(
          id: 'tx_far',
          name: 'Telebirr',
          sender: 'Telebirr',
          amount: 5.0,
          type: 'income',
          date: baseDate,
        ),
        _createTx(
          id: 'tx_fee_diff',
          name: 'Telebirr',
          sender: 'Telebirr',
          amount: 1504.0, // only 4 ETB fee difference
          type: 'income',
          date: baseDate,
        ),
        _createTx(
          id: 'tx_exact',
          name: 'Telebirr',
          sender: 'Telebirr',
          amount: 1500.0, // exact match
          type: 'income',
          date: baseDate,
        ),
      ];
      await viewModel.loadAll();

      final candidates = viewModel.getInternalTransferCandidates(sourceExpense);
      expect(candidates.length, equals(3));
      expect(candidates[0].id, equals('tx_exact')); // diff 0
      expect(candidates[1].id, equals('tx_fee_diff')); // diff 4
      expect(candidates[2].id, equals('tx_far')); // diff 1495
    });

    test('works for source income matching target expense', () {
      final sourceIncome = _createTx(
        id: 'tx_src_income',
        name: 'Telebirr',
        sender: 'Telebirr',
        amount: 1500.0,
        type: 'income',
        date: baseDate,
      );

      final candidates = viewModel.getInternalTransferCandidates(sourceIncome);
      final ids = candidates.map((c) => c.id).toList();

      // Source is income -> looks for matching expense
      expect(ids, contains('tx_src_expense'));
      expect(ids, contains('tx_expense_same_type'));
      expect(ids, isNot(contains('tx_income_3d_before')));
    });
  });
}
