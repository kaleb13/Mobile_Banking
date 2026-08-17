import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/domain/usecases/transactions/filter_transactions_usecase.dart';

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
  });
}
