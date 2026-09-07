import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/domain/usecases/transactions/filter_transactions_usecase.dart';
import 'package:mobile_banking_app/widgets/app_date_filter.dart';

void main() {
  group('FilterTransactionsUseCase Sorting Tests', () {
    const useCase = FilterTransactionsUseCase();

    final tx1 = AppTransaction(
      id: 'TX1',
      name: 'Telebirr',
      amount: 100.0,
      type: 'expense',
      date: DateTime(2026, 8, 1, 10, 0),
      sender: 'Alice',
      category: 'Auto',
      rawMessage: 'test',
      isAutoDetected: true,
    );

    final tx2 = AppTransaction(
      id: 'TX2',
      name: 'CBE',
      amount: 5000.0,
      type: 'income',
      date: DateTime(2026, 8, 10, 15, 0),
      sender: 'Charlie',
      category: 'Auto',
      rawMessage: 'test',
      isAutoDetected: true,
    );

    final tx3 = AppTransaction(
      id: 'TX3',
      name: 'BOA',
      amount: 1500.0,
      type: 'expense',
      date: DateTime(2026, 8, 5, 12, 0),
      sender: 'Bob',
      category: 'Auto',
      rawMessage: 'test',
      isAutoDetected: true,
    );

    final List<AppTransaction> transactions = [tx1, tx2, tx3];

    test('sorts by Date: Newest First (default)', () {
      final result = useCase.execute(
        transactions: transactions,
        params: const FilterTransactionsParams(sortBy: 'Date: Newest'),
      );
      expect(result.map((t) => t.id).toList(), ['TX2', 'TX3', 'TX1']);
    });

    test('sorts by Date: Oldest First', () {
      final result = useCase.execute(
        transactions: transactions,
        params: const FilterTransactionsParams(sortBy: 'Date: Oldest'),
      );
      expect(result.map((t) => t.id).toList(), ['TX1', 'TX3', 'TX2']);
    });

    test('sorts by Amount: High to Low', () {
      final result = useCase.execute(
        transactions: transactions,
        params: const FilterTransactionsParams(sortBy: 'Amount: High-Low'),
      );
      expect(result.map((t) => t.id).toList(), ['TX2', 'TX3', 'TX1']);
      expect(result.first.amount, 5000.0);
      expect(result.last.amount, 100.0);
    });

    test('sorts by Amount: Low to High', () {
      final result = useCase.execute(
        transactions: transactions,
        params: const FilterTransactionsParams(sortBy: 'Amount: Low-High'),
      );
      expect(result.map((t) => t.id).toList(), ['TX1', 'TX3', 'TX2']);
      expect(result.first.amount, 100.0);
      expect(result.last.amount, 5000.0);
    });

    test('sorts by Name / Sender: A to Z', () {
      final result = useCase.execute(
        transactions: transactions,
        params: const FilterTransactionsParams(sortBy: 'Name: A-Z'),
      );
      expect(result.map((t) => t.sender).toList(), ['Alice', 'Bob', 'Charlie']);
    });

    test('filters by Last 30 Days correctly', () {
      final now = DateTime.now();
      final recentTx = AppTransaction(
        id: 'RECENT',
        name: 'Telebirr',
        amount: 200.0,
        type: 'expense',
        date: now.subtract(const Duration(days: 5)),
        sender: 'Store',
        category: 'Auto',
        rawMessage: 'msg',
        isAutoDetected: true,
      );
      final oldTx = AppTransaction(
        id: 'OLD',
        name: 'CBE',
        amount: 300.0,
        type: 'income',
        date: now.subtract(const Duration(days: 45)),
        sender: 'Old Job',
        category: 'Auto',
        rawMessage: 'msg',
        isAutoDetected: true,
      );

      final result = useCase.execute(
        transactions: [recentTx, oldTx],
        params: const FilterTransactionsParams(
          dateFilter: AppDateFilterValue.last30Days(),
        ),
      );
      expect(result.length, 1);
      expect(result.first.id, 'RECENT');
    });
  });

  group('FilterTransactionsUseCase Bank and Counterparty Tests', () {
    const useCase = FilterTransactionsUseCase();

    final txTelebirrAlice = AppTransaction(
      id: 'TX1',
      name: 'Telebirr',
      amount: 100.0,
      type: 'expense',
      date: DateTime(2026, 8, 1),
      sender: 'Alice',
      counterparty: 'Alice Smith',
      category: 'Auto',
      rawMessage: 'msg',
      isAutoDetected: true,
    );

    final txCbeAlice = AppTransaction(
      id: 'TX2',
      name: 'CBE',
      amount: 200.0,
      type: 'income',
      date: DateTime(2026, 8, 2),
      sender: 'Alice',
      counterparty: 'Alice Smith',
      category: 'Auto',
      rawMessage: 'msg',
      isAutoDetected: true,
    );

    final txTelebirrBob = AppTransaction(
      id: 'TX3',
      name: 'Telebirr',
      amount: 300.0,
      type: 'expense',
      date: DateTime(2026, 8, 3),
      sender: 'Bob',
      counterparty: 'Bob Jones',
      category: 'Auto',
      rawMessage: 'msg',
      isAutoDetected: true,
    );

    final list = [txTelebirrAlice, txCbeAlice, txTelebirrBob];

    test('treats "All Counterparties" and "All Senders" as no-op filters', () {
      final res1 = useCase.execute(
        transactions: list,
        params: const FilterTransactionsParams(counterpartyFilter: 'All Counterparties'),
      );
      expect(res1.length, 3);

      final res2 = useCase.execute(
        transactions: list,
        params: const FilterTransactionsParams(counterpartyFilter: 'All Senders'),
      );
      expect(res2.length, 3);
    });

    test('filters by counterpartyFilter alone', () {
      final res = useCase.execute(
        transactions: list,
        params: const FilterTransactionsParams(counterpartyFilter: 'Alice Smith'),
      );
      expect(res.map((t) => t.id).toList(), ['TX2', 'TX1']);
    });

    test('filters simultaneously by bankFilter and counterpartyFilter', () {
      final res = useCase.execute(
        transactions: list,
        params: const FilterTransactionsParams(
          bankFilter: 'Telebirr',
          counterpartyFilter: 'Alice Smith',
        ),
      );
      expect(res.length, 1);
      expect(res.first.id, 'TX1');
      expect(res.first.name, 'Telebirr');
      expect(res.first.counterparty, 'Alice Smith');
    });
  });
}
