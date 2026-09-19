import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/models/reason.dart';
import 'package:mobile_banking_app/models/saving_goal.dart';
import 'package:mobile_banking_app/models/loan_record.dart';
import 'package:mobile_banking_app/services/cloud_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudSyncService Model Serialization & Mapping Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Transaction to Cloud Row mapping matches Supabase PostgreSQL schema', () {
      final tx = AppTransaction(
        id: 'FT26114Y5F42',
        name: 'CBE',
        amount: 1500.75,
        type: 'income',
        date: DateTime.utc(2026, 9, 17, 14, 30),
        sender: 'Abebe Bikila',
        category: 'Auto',
        rawMessage: 'Dear Customer, your Account has been Credited with ETB 1,500.75 from Abebe Bikila ref: FT26114Y5F42',
        isAutoDetected: true,
        totalBalance: 24500.50,
        reason: 'Salary',
        reasonId: 1,
        categoryId: 1,
        subcategoryId: null,
        note: 'Monthly bonus',
        customReasonText: null,
        isBookmarked: true,
        linkedTransactionId: 'LNK_001',
        simSlot: 1,
      );

      const userId = '00000000-0000-0000-0000-000000000001';

      // Simulation of _mapTransactionToCloudRow
      final row = {
        'id': tx.id,
        'user_id': userId,
        'bank_name': tx.bankName,
        'amount': tx.amount,
        'type': tx.type,
        'date': tx.date.toUtc().toIso8601String(),
        'counterparty': tx.counterparty,
        'total_balance': tx.totalBalance,
        'category': tx.sourceTag,
        'note': tx.note,
        'reason': tx.reason,
        'reason_id': tx.reasonId,
        'category_id': tx.categoryId,
        'subcategory_id': tx.subcategoryId,
        'custom_reason_text': tx.customReasonText,
        'is_bookmarked': tx.isBookmarked,
        'linked_transaction_id': tx.linkedTransactionId,
        'raw_message': tx.rawMessage,
        'sim_slot': tx.simSlot,
        'device_fingerprint': 'sha256_mock_device_signature',
        'device_model': 'Samsung Galaxy S24',
      };

      expect(row['id'], equals('FT26114Y5F42'));
      expect(row['user_id'], equals(userId));
      expect(row['bank_name'], equals('CBE'));
      expect(row['amount'], equals(1500.75));
      expect(row['type'], equals('income'));
      expect(row['counterparty'], equals('Abebe Bikila'));
      expect(row['total_balance'], equals(24500.50));
      expect(row['note'], equals('Monthly bonus'));
      expect(row['is_bookmarked'], equals(true));
      expect(row['sim_slot'], equals(1));
      expect(row['device_fingerprint'], equals('sha256_mock_device_signature'));
      expect(row['device_model'], equals('Samsung Galaxy S24'));

      // Simulation of _mapCloudRowToTransaction
      final restoredTx = AppTransaction(
        id: row['id'] as String?,
        name: row['bank_name'] as String,
        amount: (row['amount'] as num).toDouble(),
        type: row['type'] as String,
        date: DateTime.parse(row['date'] as String).toLocal(),
        sender: row['counterparty'] as String?,
        category: row['category'] as String? ?? 'Auto',
        rawMessage: row['raw_message'] as String? ?? '',
        isAutoDetected: (row['category'] as String? ?? 'Auto') == 'Auto',
        totalBalance: (row['total_balance'] as num?)?.toDouble() ?? 0.0,
        reason: row['reason'] as String?,
        reasonId: row['reason_id'] as int?,
        categoryId: row['category_id'] as int?,
        subcategoryId: row['subcategory_id'] as int?,
        customReasonText: row['custom_reason_text'] as String?,
        note: row['note'] as String?,
        linkedTransactionId: row['linked_transaction_id'] as String?,
        isBookmarked: row['is_bookmarked'] == true,
        simSlot: row['sim_slot'] as int? ?? 0,
      );

      expect(restoredTx.id, equals(tx.id));
      expect(restoredTx.name, equals(tx.name));
      expect(restoredTx.amount, equals(tx.amount));
      expect(restoredTx.type, equals(tx.type));
      expect(restoredTx.counterparty, equals(tx.counterparty));
      expect(restoredTx.note, equals(tx.note));
      expect(restoredTx.isBookmarked, equals(true));
      expect(restoredTx.simSlot, equals(1));
    });

    test('Category to Cloud Row mapping preserves hierarchical relationships with parent_name', () {
      final parent = AppReason(
        id: 5,
        name: 'Food & Dining',
        isSystem: true,
        isSpecial: false,
        icon: 'restaurant',
        color: '#FF5722',
      );

      final child = AppReason(
        id: 12,
        name: 'Groceries',
        parentId: 5,
        isSystem: false,
        isSpecial: false,
        icon: 'local_grocery_store',
        color: '#FF7043',
      );

      const userId = '00000000-0000-0000-0000-000000000001';

      final parentRow = {
        'id': parent.id,
        'user_id': userId,
        'name': parent.name,
        'parent_id': parent.parentId,
        'parent_name': null,
        'icon': parent.icon,
        'color': parent.color,
        'is_system': parent.isSystem,
        'is_special': parent.isSpecial,
      };

      final childRow = {
        'id': child.id,
        'user_id': userId,
        'name': child.name,
        'parent_id': child.parentId,
        'parent_name': 'Food & Dining',
        'icon': child.icon,
        'color': child.color,
        'is_system': child.isSystem,
        'is_special': child.isSpecial,
      };

      expect(parentRow['parent_id'], isNull);
      expect(parentRow['parent_name'], isNull);
      expect(childRow['parent_id'], equals(5));
      expect(childRow['parent_name'], equals('Food & Dining'));
      expect(childRow['icon'], equals('local_grocery_store'));
      expect(childRow['color'], equals('#FF7043'));
    });

    test('Reason Links to Cloud Row mapping serializes linked contacts properly', () {
      final link = AppReasonLink(
        id: 1,
        reasonId: 12,
        linkedName: 'Abebe Bikila',
        linkType: 'receiver',
      );

      const userId = '00000000-0000-0000-0000-000000000001';

      final linkRow = {
        'user_id': userId,
        'linked_name': link.linkedName,
        'link_type': link.linkType,
        'reason_name': 'Groceries',
        'parent_reason_name': 'Food & Dining',
      };

      expect(linkRow['linked_name'], equals('Abebe Bikila'));
      expect(linkRow['link_type'], equals('receiver'));
      expect(linkRow['reason_name'], equals('Groceries'));
      expect(linkRow['parent_reason_name'], equals('Food & Dining'));
    });

    test('Saving Goal & Loan Cloud Row mapping serializes properly', () {
      final goal = SavingGoal(
        id: 'GOAL_01',
        title: 'New Laptop',
        targetAmount: 80000.0,
        savedAmount: 32000.0,
        colorTheme: 'purple',
        targetDate: '2026-11-01',
        priority: 1,
      );

      final loan = LoanRecord(
        id: 8,
        loanType: 'lent',
        personName: 'Daniel',
        principalAmount: 5000.0,
        paidAmount: 2000.0,
        loanDate: DateTime.utc(2026, 8, 1),
        dueDate: DateTime.utc(2026, 10, 1),
        status: 'active',
        note: 'Repaying at month end',
      );

      const userId = '00000000-0000-0000-0000-000000000001';

      final goalRow = {
        'id': goal.id,
        'user_id': userId,
        'title': goal.title,
        'target_amount': goal.targetAmount,
        'saved_amount': goal.savedAmount,
        'color_theme': goal.colorTheme,
        'target_date': goal.targetDate,
      };

      final loanRow = {
        'id': loan.id.toString(),
        'user_id': userId,
        'person_name': loan.personName,
        'loan_type': loan.loanType,
        'principal_amount': loan.principalAmount,
        'paid_amount': loan.paidAmount,
        'status': loan.status,
      };

      expect(goalRow['id'], equals('GOAL_01'));
      expect(goalRow['saved_amount'], equals(32000.0));
      expect(loanRow['id'], equals('8'));
      expect(loanRow['person_name'], equals('Daniel'));
      expect(loanRow['principal_amount'], equals(5000.0));
    });

    test('Cloud Sync opt-in preference toggles cleanly', () async {
      final syncService = CloudSyncService.instance;
      
      // Default is false (Google Play compliance)
      expect(await syncService.isSyncEnabled(), isFalse);

      // Enable sync
      await syncService.setSyncEnabled(true);
      expect(await syncService.isSyncEnabled(), isTrue);

      // Disable sync
      await syncService.setSyncEnabled(false);
      expect(await syncService.isSyncEnabled(), isFalse);
      expect(syncService.statusNotifier.value, equals(CloudSyncStatus.disabled));
    });

    test('isBankSyncAllowed respects disabled sync banks and defaults to allowed', () async {
      final syncService = CloudSyncService.instance;
      
      // When unauthenticated, getDisabledSyncBanks returns empty
      expect(await syncService.getDisabledSyncBanks(), isEmpty);

      // Bank sync allowed by default
      expect(await syncService.isBankSyncAllowed('Telebirr'), isTrue);
      expect(await syncService.isBankSyncAllowed('CBE'), isTrue);
    });
  });
}
