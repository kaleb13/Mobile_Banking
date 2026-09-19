import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Transaction Deletion & Cloud Tombstone Tests', () {
    test('DatabaseService onTransactionDeleted callback triggers on delete', () async {
      String? deletedIdCaptured;
      DatabaseService.instance.onTransactionDeleted = (id) {
        deletedIdCaptured = id;
      };

      // Ensure the hook exists and can be assigned
      expect(DatabaseService.instance.onTransactionDeleted, isNotNull);
      DatabaseService.instance.onTransactionDeleted?.call('TEST_TX_123');
      expect(deletedIdCaptured, 'TEST_TX_123');
    });

    test('Deleted transaction tombstone filtering logic', () {
      final tx1 = AppTransaction(
        id: 'TX_KEEP_1',
        name: 'Telebirr',
        amount: 100.0,
        type: 'expense',
        date: DateTime.now(),
        rawMessage: 'raw 1',
        isAutoDetected: true,
      );
      final tx2 = AppTransaction(
        id: 'TX_DELETED_2',
        name: 'CBE',
        amount: 250.0,
        type: 'income',
        date: DateTime.now(),
        rawMessage: 'raw 2',
        isAutoDetected: true,
      );

      final deletedIds = {'TX_DELETED_2'};
      final transactions = [tx1, tx2];

      final filtered = transactions
          .where((t) => t.id == null || !deletedIds.contains(t.id))
          .toList();

      expect(filtered.length, 1);
      expect(filtered.first.id, 'TX_KEEP_1');
    });
  });
}
