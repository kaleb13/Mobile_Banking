import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/transaction_split.dart';

void main() {
  group('TransactionSplit Model Tests', () {
    test('toMap and fromMap serialize and deserialize correctly', () {
      final now = DateTime(2026, 8, 30, 14, 30);
      final split = TransactionSplit(
        id: 1,
        transactionId: 'TX_300_TEST',
        amount: 100.0,
        reasonId: 5,
        reasonName: 'Mobile & Internet',
        categoryId: 5,
        subcategoryId: 501,
        customReasonText: null,
        note: 'Airtime recharge',
        createdAt: now,
      );

      final map = split.toMap();
      expect(map['id'], 1);
      expect(map['transactionId'], 'TX_300_TEST');
      expect(map['amount'], 100.0);
      expect(map['reasonId'], 5);
      expect(map['reasonName'], 'Mobile & Internet');
      expect(map['categoryId'], 5);
      expect(map['subcategoryId'], 501);
      expect(map['note'], 'Airtime recharge');
      expect(map['createdAt'], now.toIso8601String());

      final reconstituted = TransactionSplit.fromMap(map);
      expect(reconstituted.id, 1);
      expect(reconstituted.transactionId, 'TX_300_TEST');
      expect(reconstituted.amount, 100.0);
      expect(reconstituted.reasonId, 5);
      expect(reconstituted.reasonName, 'Mobile & Internet');
      expect(reconstituted.categoryId, 5);
      expect(reconstituted.subcategoryId, 501);
      expect(reconstituted.note, 'Airtime recharge');
      expect(reconstituted.createdAt.toIso8601String(), now.toIso8601String());
    });

    test('copyWith works correctly with field overrides and clear flags', () {
      final split = TransactionSplit(
        id: 2,
        transactionId: 'TX_300_TEST',
        amount: 57.0,
        reasonId: 1,
        reasonName: 'Food',
        categoryId: 1,
        subcategoryId: 102,
        note: 'Lunch',
      );

      final updated = split.copyWith(
        amount: 60.0,
        note: 'Lunch with dessert',
      );

      expect(updated.id, 2);
      expect(updated.amount, 60.0);
      expect(updated.reasonId, 1);
      expect(updated.reasonName, 'Food');
      expect(updated.note, 'Lunch with dessert');

      final cleared = split.copyWith(
        clearReasonId: true,
        clearReasonName: true,
      );
      expect(cleared.reasonId, isNull);
      expect(cleared.reasonName, isNull);
    });
  });
}
