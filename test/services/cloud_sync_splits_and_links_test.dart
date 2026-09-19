import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/reason.dart';
import 'package:mobile_banking_app/models/transaction_split.dart';
import 'package:mobile_banking_app/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cloud Sync: Transaction Splits & Reason Links Unit Tests', () {
    test('TransactionSplit to cloud row serialization matches Supabase PostgreSQL schema', () {
      final split = TransactionSplit(
        id: 42,
        transactionId: 'TX_SPLIT_9988',
        amount: 250.50,
        reasonId: 10,
        reasonName: 'Groceries',
        categoryId: 3,
        subcategoryId: 10,
        customReasonText: 'Fresh vegetables',
        note: 'Supermarket purchase',
        createdAt: DateTime.utc(2026, 9, 19, 10, 0),
      );

      const userId = 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d';
      const splitIndex = 0;
      const parentReasonName = 'Food & Dining';
      const categoryName = 'Food & Dining';

      final row = {
        'user_id': userId,
        'transaction_id': split.transactionId,
        'split_index': splitIndex,
        'amount': split.amount,
        'reason_name': split.reasonName,
        'parent_reason_name': parentReasonName,
        'category_name': categoryName,
        'custom_reason_text': split.customReasonText,
        'note': split.note,
        'updated_at': DateTime.utc(2026, 9, 19, 10, 0).toIso8601String(),
      };

      expect(row['user_id'], equals(userId));
      expect(row['transaction_id'], equals('TX_SPLIT_9988'));
      expect(row['split_index'], equals(0));
      expect(row['amount'], equals(250.50));
      expect(row['reason_name'], equals('Groceries'));
      expect(row['parent_reason_name'], equals('Food & Dining'));
      expect(row['category_name'], equals('Food & Dining'));
      expect(row['custom_reason_text'], equals('Fresh vegetables'));
      expect(row['note'], equals('Supermarket purchase'));

      // Reconstructing TransactionSplit from cloud row
      final reconstructed = TransactionSplit(
        transactionId: row['transaction_id'] as String,
        amount: (row['amount'] as num).toDouble(),
        reasonName: row['reason_name'] as String?,
        customReasonText: row['custom_reason_text'] as String?,
        note: row['note'] as String?,
      );

      expect(reconstructed.transactionId, equals('TX_SPLIT_9988'));
      expect(reconstructed.amount, equals(250.50));
      expect(reconstructed.reasonName, equals('Groceries'));
      expect(reconstructed.customReasonText, equals('Fresh vegetables'));
      expect(reconstructed.note, equals('Supermarket purchase'));
    });

    test('AppReasonLink copyWith and cloud row serialization preserves natural hierarchy', () {
      final link = AppReasonLink(
        id: 5,
        linkedName: 'John Doe',
        reasonId: 15,
        linkType: 'receiver',
      );

      expect(link.id, equals(5));
      expect(link.linkedName, equals('John Doe'));
      expect(link.reasonId, equals(15));
      expect(link.linkType, equals('receiver'));
      expect(link.isExpense, isTrue);
      expect(link.isIncome, isFalse);

      final copied = link.copyWith(id: 12, reasonId: 20);
      expect(copied.id, equals(12));
      expect(copied.reasonId, equals(20));
      expect(copied.linkedName, equals('John Doe'));
      expect(copied.linkType, equals('receiver'));

      const userId = 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d';
      const reasonName = 'Fuel';
      const parentReasonName = 'Transportation';

      final row = {
        'user_id': userId,
        'linked_name': link.linkedName,
        'link_type': link.linkType,
        'reason_name': reasonName,
        'parent_reason_name': parentReasonName,
        'updated_at': DateTime.utc(2026, 9, 19, 12, 0).toIso8601String(),
      };

      expect(row['user_id'], equals(userId));
      expect(row['linked_name'], equals('John Doe'));
      expect(row['link_type'], equals('receiver'));
      expect(row['reason_name'], equals('Fuel'));
      expect(row['parent_reason_name'], equals('Transportation'));
    });

    test('DatabaseService onSplitsChanged callback invokes registered listener', () {
      String? capturedTxId;
      List<TransactionSplit>? capturedSplits;

      DatabaseService.instance.onSplitsChanged = (txId, splits) {
        capturedTxId = txId;
        capturedSplits = splits;
      };

      final testSplits = [
        TransactionSplit(transactionId: 'TX_101', amount: 100.0, reasonName: 'Coffee'),
        TransactionSplit(transactionId: 'TX_101', amount: 200.0, reasonName: 'Lunch'),
      ];

      DatabaseService.instance.onSplitsChanged?.call('TX_101', testSplits);

      expect(capturedTxId, equals('TX_101'));
      expect(capturedSplits, isNotNull);
      expect(capturedSplits!.length, equals(2));
      expect(capturedSplits![0].reasonName, equals('Coffee'));
      expect(capturedSplits![1].reasonName, equals('Lunch'));

      // Test clearing splits
      DatabaseService.instance.onSplitsChanged?.call('TX_101', []);
      expect(capturedSplits!.isEmpty, isTrue);

      DatabaseService.instance.onSplitsChanged = null;
    });

    test('DatabaseService onReasonLinkChanged callback invokes registered listener on insert and delete', () {
      AppReasonLink? capturedLink;
      bool? capturedIsDeleted;

      DatabaseService.instance.onReasonLinkChanged = (link, isDeleted) {
        capturedLink = link;
        capturedIsDeleted = isDeleted;
      };

      final link = AppReasonLink(
        id: 7,
        linkedName: 'Ethio Telecom',
        reasonId: 2,
        linkType: 'receiver',
      );

      // Simulate insertion event
      DatabaseService.instance.onReasonLinkChanged?.call(link, false);
      expect(capturedLink?.linkedName, equals('Ethio Telecom'));
      expect(capturedIsDeleted, isFalse);

      // Simulate deletion event
      DatabaseService.instance.onReasonLinkChanged?.call(link, true);
      expect(capturedLink?.linkedName, equals('Ethio Telecom'));
      expect(capturedIsDeleted, isTrue);

      DatabaseService.instance.onReasonLinkChanged = null;
    });
  });
}
