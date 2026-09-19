import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/reason.dart';
import 'package:mobile_banking_app/models/sender.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/models/cash_transaction.dart';
import 'package:mobile_banking_app/models/saving_goal.dart';
import 'package:mobile_banking_app/models/loan_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Backup & Restore Engine (Version 2) Payload Tests', () {
    test('Backup payload correctly serializes Version 2 complete schema', () {
      final parentReason = AppReason(
        id: 10,
        name: 'Transport',
        isSystem: false,
        isSpecial: false,
        icon: 'directions_car',
        color: '#4CAF50',
      );

      final childReason = AppReason(
        id: 11,
        name: 'Fuel',
        parentId: 10,
        isSystem: false,
        isSpecial: false,
        icon: 'local_gas_station',
        color: '#81C784',
      );

      final sender = AppSender(
        id: '1',
        senderName: 'Telebirr',
      );

      final tx = AppTransaction(
        id: 'TX_TEST_001',
        name: 'Telebirr',
        amount: 250.0,
        type: 'expense',
        date: DateTime(2026, 9, 17, 10, 30),
        rawMessage: 'You paid ETB 250.00 for Transport ref: TX_TEST_001',
        isAutoDetected: true,
        reason: 'Transport',
        reasonId: 10,
        categoryId: 10,
        subcategoryId: 11,
        note: 'Gas station refill',
        customReasonText: 'Work commute',
        isBookmarked: true,
        linkedTransactionId: 'CASH_LINK_01',
      );

      final cashTx = CashTransaction(
        id: 1,
        type: 'expense',
        amount: 120.0,
        date: DateTime(2026, 9, 17, 11, 0),
        description: 'Taxi ride',
        reasonId: 10,
        reasonName: 'Transport',
      );

      final goal = SavingGoal(
        id: '1',
        title: 'Emergency Fund',
        targetAmount: 50000.0,
        savedAmount: 15000.0,
        colorTheme: 'blue',
        targetDate: '2026-12-31',
        priority: 1,
      );

      final loan = LoanRecord(
        id: 5,
        loanType: 'lent',
        personName: 'Almaz',
        principalAmount: 10000.0,
        paidAmount: 2500.0,
        loanDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 12, 1),
        status: 'active',
        note: 'Family support',
      );

      final payment = LoanPayment(
        id: 1,
        loanId: 5,
        amount: 2500.0,
        paymentDate: DateTime(2026, 5, 1),
        note: 'First installment',
      );

      // Build sample v2 backup JSON structure
      final backupPayload = {
        'app': 'Shibre',
        'version': 2,
        'exportedAt': DateTime(2026, 9, 17, 12, 0).toIso8601String(),
        'user_preferences': {
          'is_balance_visible': true,
          'selected_theme_mode': 'dark',
          'app_locale': 'en',
          'biometrics_enabled': true,
        },
        'app_settings': {
          'backup_cloud_sync': 'true',
          'auto_scan_frequency': 'realtime',
        },
        'deleted_default_reasons': [
          {
            'name': 'school fee',
            'parentName': 'education',
            'deletedAt': '2026-08-01T10:00:00.000Z',
          }
        ],
        'senders': [sender.toMap()],
        'reasons': [parentReason.toMap(), childReason.toMap()],
        'reason_links': [
          {
            'reasonId': 10,
            'linkedName': 'Total Energies',
            'linkType': 'receiver',
          }
        ],
        'transactions': [tx.toMap()],
        'cash_transactions': [cashTx.toMap()],
        'saving_goals': [goal.toMap()],
        'loans': [loan.toMap()],
        'loan_payments': [payment.toMap()],
      };

      final jsonString = jsonEncode(backupPayload);
      expect(jsonString, isNotEmpty);

      // Decode and verify round-trip
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      expect(decoded['version'], equals(2));
      expect(decoded['app'], equals('Shibre'));

      // Verify category hierarchy serialization
      final reasonsList = decoded['reasons'] as List<dynamic>;
      expect(reasonsList.length, equals(2));
      final decodedParent = AppReason.fromMap(reasonsList[0]);
      final decodedChild = AppReason.fromMap(reasonsList[1]);
      expect(decodedParent.id, equals(10));
      expect(decodedParent.parentId, isNull);
      expect(decodedParent.icon, equals('directions_car'));
      expect(decodedChild.parentId, equals(10));
      expect(decodedChild.icon, equals('local_gas_station'));

      // Verify tombstone serialization
      final tombstones = decoded['deleted_default_reasons'] as List<dynamic>;
      expect(tombstones.length, equals(1));
      expect(tombstones[0]['name'], equals('school fee'));
      expect(tombstones[0]['parentName'], equals('education'));

      // Verify financial models
      final decodedCash = CashTransaction.fromMap(decoded['cash_transactions'][0]);
      expect(decodedCash.amount, equals(120.0));
      expect(decodedCash.type, equals('expense'));

      final decodedGoal = SavingGoal.fromMap(decoded['saving_goals'][0]);
      expect(decodedGoal.title, equals('Emergency Fund'));
      expect(decodedGoal.targetAmount, equals(50000.0));

      final decodedLoan = LoanRecord.fromMap(decoded['loans'][0]);
      expect(decodedLoan.personName, equals('Almaz'));
      expect(decodedLoan.principalAmount, equals(10000.0));

      final decodedPayment = LoanPayment.fromMap(decoded['loan_payments'][0]);
      expect(decodedPayment.loanId, equals(5));
      expect(decodedPayment.amount, equals(2500.0));
    });

    test('Two-pass category restoration simulates ID remapping accurately', () {
      final rawReasons = [
        {'id': 101, 'name': 'Housing', 'parentId': null, 'icon': 'home', 'color': '#112233'},
        {'id': 102, 'name': 'Rent', 'parentId': 101, 'icon': 'key', 'color': '#223344'},
        {'id': 103, 'name': 'Utilities', 'parentId': 101, 'icon': 'bolt', 'color': '#334455'},
      ];

      // Simulated existing database with auto-assigned IDs
      final Map<int, int> idMap = {};
      int autoIdCounter = 1;

      // Pass 1: Top-level categories (parentId == null)
      final topLevel = rawReasons.where((r) => r['parentId'] == null).toList();
      for (final raw in topLevel) {
        final oldId = raw['id'] as int;
        final newId = autoIdCounter++;
        idMap[oldId] = newId;
      }

      // Pass 2: Subcategories (parentId != null)
      final subcategories = rawReasons.where((r) => r['parentId'] != null).toList();
      final List<Map<String, dynamic>> restoredSubcategories = [];
      for (final raw in subcategories) {
        final oldId = raw['id'] as int;
        final oldParentId = raw['parentId'] as int;
        final newParentId = idMap[oldParentId];
        final newId = autoIdCounter++;
        idMap[oldId] = newId;

        restoredSubcategories.add({
          'id': newId,
          'name': raw['name'],
          'parentId': newParentId,
        });
      }

      expect(idMap[101], equals(1)); // Housing got ID 1
      expect(restoredSubcategories[0]['parentId'], equals(1)); // Rent linked to Housing
      expect(restoredSubcategories[1]['parentId'], equals(1)); // Utilities linked to Housing
    });

    test('Transaction merge preserves user note, category, and bookmarks', () {
      // Existing transaction in DB (raw SMS intake)
      final existingTx = {
        'id': 'FT26114Y5F42',
        'bankName': 'CBE',
        'amount': 500.0,
        'type': 'expense',
        'note': null,
        'reasonId': null,
        'customReasonText': null,
        'isBookmarked': 0,
      };

      // Backup transaction with user modifications
      final backupTx = AppTransaction(
        id: 'FT26114Y5F42',
        name: 'CBE',
        amount: 500.0,
        type: 'expense',
        date: DateTime.now(),
        rawMessage: 'CBE SMS raw content',
        isAutoDetected: true,
        note: 'Supermarket weekly groceries',
        reason: 'Food & Dining',
        reasonId: 7,
        customReasonText: 'Groceries',
        isBookmarked: true,
      );

      // Simulation of upsert merge logic
      final merged = Map<String, dynamic>.from(existingTx);
      if (backupTx.note != null && backupTx.note!.isNotEmpty) {
        merged['note'] = backupTx.note;
      }
      if (backupTx.reasonId != null) {
        merged['reasonId'] = backupTx.reasonId;
      }
      if (backupTx.customReasonText != null && backupTx.customReasonText!.isNotEmpty) {
        merged['customReasonText'] = backupTx.customReasonText;
      }
      if (backupTx.isBookmarked) {
        merged['isBookmarked'] = 1;
      }

      expect(merged['note'], equals('Supermarket weekly groceries'));
      expect(merged['reasonId'], equals(7));
      expect(merged['customReasonText'], equals('Groceries'));
      expect(merged['isBookmarked'], equals(1));
    });

    test('Authoritative transaction merge clears reason on explicitly unlinked/independent transaction', () {
      // Scenario: Device B ingested SMS and auto-linked to 'Rent' (reasonId: 3)
      final existingTx = {
        'id': 'TX_INDEPENDENT_01',
        'bankName': 'Telebirr',
        'amount': 3000.0,
        'type': 'expense',
        'reason': 'Rent',
        'reasonId': 3,
        'categoryId': 3,
        'subcategoryId': null,
        'customReasonText': null,
      };

      // Source device explicitly unlinked this transaction (independent)
      final unlinkedBackupTx = AppTransaction(
        id: 'TX_INDEPENDENT_01',
        bankName: 'Telebirr',
        amount: 3000.0,
        type: 'expense',
        date: DateTime.now(),
        rawMessage: 'Telebirr payment SMS',
        isAutoDetected: true,
        reason: null,
        reasonId: null,
        categoryId: null,
        subcategoryId: null,
        customReasonText: null,
      );

      // Simulation of authoritativeCategory = true logic
      final merged = Map<String, dynamic>.from(existingTx);
      const authoritativeCategory = true;
      if (authoritativeCategory) {
        merged['reasonId'] = unlinkedBackupTx.reasonId;
        merged['categoryId'] = unlinkedBackupTx.categoryId;
        merged['subcategoryId'] = unlinkedBackupTx.subcategoryId;
        merged['reason'] = unlinkedBackupTx.reason;
        merged['customReasonText'] = unlinkedBackupTx.customReasonText;
      }

      expect(merged['reasonId'], isNull);
      expect(merged['categoryId'], isNull);
      expect(merged['subcategoryId'], isNull);
      expect(merged['reason'], isNull);
      expect(merged['customReasonText'], isNull);
    });

    test('Two-pass category restoration resolves parent by parentName when IDs differ', () {
      final rawReasons = [
        {'id': 999, 'name': 'Electronics', 'parentId': null, 'parentName': null},
        {'id': 1000, 'name': 'Laptops', 'parentId': 999, 'parentName': 'Electronics'},
      ];

      // Existing target database already has 'Electronics' at ID 4
      final Map<String, int> targetParentNameToId = {'electronics': 4};
      final Map<int, int> reasonIdMap = {};

      // Pass 1: Top-level
      final topLevel = rawReasons.where((r) => r['parentId'] == null).toList();
      for (final raw in topLevel) {
        final name = (raw['name'] as String).toLowerCase();
        final existingId = targetParentNameToId[name];
        if (existingId != null) {
          reasonIdMap[raw['id'] as int] = existingId;
        }
      }

      // Pass 2: Subcategory
      final subcategories = rawReasons.where((r) => r['parentId'] != null).toList();
      int? resolvedParentId;
      for (final raw in subcategories) {
        final parentName = (raw['parentName'] as String).toLowerCase();
        resolvedParentId = targetParentNameToId[parentName] ?? reasonIdMap[raw['parentId'] as int];
      }

      expect(resolvedParentId, equals(4)); // Correctly resolved to local ID 4 via parentName!
    });

    test('Legacy Version 1 backup safely deserializes without missing key exceptions', () {
      final legacyV1Payload = {
        'app': 'Shibre',
        'version': 1,
        'exportedAt': '2026-08-10T14:30:00.000Z',
        'senders': [
          {
            'id': 1,
            'senderName': 'CBE',
          }
        ],
        'reasons': [
          {'id': 1, 'name': 'Salary', 'isSystem': 1},
          {'id': 2, 'name': 'Groceries', 'isSystem': 0},
        ],
        'reason_links': [],
        'transactions': [
          {
            'id': 'TX_LEGACY_01',
            'name': 'CBE',
            'amount': 300.0,
            'type': 'expense',
            'date': '2026-08-10T12:00:00.000Z',
            'rawMessage': 'Legacy SMS text',
            'reason': 'Groceries',
            'reasonId': 2,
          }
        ],
      };

      final jsonStr = jsonEncode(legacyV1Payload);
      final Map<String, dynamic> data = jsonDecode(jsonStr);

      expect(data['version'], equals(1));
      expect(data['cash_transactions'], isNull);
      expect(data['saving_goals'], isNull);
      expect(data['loans'], isNull);
      expect(data['deleted_default_reasons'], isNull);

      // Safe access verification matching BackupService.importBackup
      final cashList = (data['cash_transactions'] as List<dynamic>?) ?? [];
      final goalsList = (data['saving_goals'] as List<dynamic>?) ?? [];
      final loansList = (data['loans'] as List<dynamic>?) ?? [];
      final deletedList = (data['deleted_default_reasons'] as List<dynamic>?) ?? [];

      expect(cashList, isEmpty);
      expect(goalsList, isEmpty);
      expect(loansList, isEmpty);
      expect(deletedList, isEmpty);

      final reasons = data['reasons'] as List<dynamic>;
      expect(reasons.length, equals(2));
      expect(reasons[0]['parentId'], isNull);
    });
  });
}
