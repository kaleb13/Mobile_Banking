import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/saving_goal.dart';
import 'package:mobile_banking_app/models/loan_record.dart';
import 'package:mobile_banking_app/models/cash_transaction.dart';
import 'package:mobile_banking_app/models/transaction.dart';

void main() {
  group('SavingGoal Model', () {
    test('calculates progress percentage correctly', () {
      final goal = SavingGoal(
        id: '1',
        title: 'New Laptop',
        targetAmount: 50000.0,
        savedAmount: 25000.0,
      );

      expect(goal.progressPercentage, equals(50.0));
      expect(goal.remainingAmount, equals(25000.0));
      expect(goal.isCompleted, isFalse);
    });

    test('detects completed goal', () {
      final goal = SavingGoal(
        id: '2',
        title: 'Emergency Fund',
        targetAmount: 10000.0,
        savedAmount: 10000.0,
      );

      expect(goal.progressPercentage, equals(100.0));
      expect(goal.remainingAmount, equals(0.0));
      expect(goal.isCompleted, isTrue);
    });

    test('serializes to and from Map', () {
      final goal = SavingGoal(
        id: '3',
        title: 'Vacation',
        targetAmount: 15000.0,
        savedAmount: 3000.0,
        colorTheme: 'purple',
      );

      final map = goal.toMap();
      final restored = SavingGoal.fromMap(map);

      expect(restored.id, equals(goal.id));
      expect(restored.title, equals(goal.title));
      expect(restored.targetAmount, equals(goal.targetAmount));
      expect(restored.savedAmount, equals(goal.savedAmount));
    });
  });

  group('LoanRecord Model', () {
    final now = DateTime.now();

    test('calculates remaining amount and progress percentage', () {
      final loan = LoanRecord(
        id: 1,
        loanType: 'lent',
        personName: 'Abebe',
        principalAmount: 1000.0,
        paidAmount: 400.0,
        loanDate: now,
        dueDate: now.add(const Duration(days: 30)),
      );

      expect(loan.remainingAmount, equals(600.0));
      expect(loan.progressPercent, equals(0.4));
      expect(loan.isPaid, isFalse);
    });

    test('detects fully paid loan', () {
      final loan = LoanRecord(
        id: 2,
        loanType: 'borrowed',
        personName: 'Kebede',
        principalAmount: 2000.0,
        paidAmount: 2000.0,
        loanDate: now,
        dueDate: now.add(const Duration(days: 30)),
      );

      expect(loan.remainingAmount, equals(0.0));
      expect(loan.progressPercent, equals(1.0));
      expect(loan.isPaid, isTrue);
    });

    test('serializes to and from Map', () {
      final loan = LoanRecord(
        id: 10,
        loanType: 'lent',
        personName: 'Chala',
        principalAmount: 500.0,
        paidAmount: 100.0,
        loanDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 2, 1),
        note: 'Test loan',
      );

      final map = loan.toMap();
      final restored = LoanRecord.fromMap(map);

      expect(restored.id, equals(loan.id));
      expect(restored.personName, equals(loan.personName));
      expect(restored.principalAmount, equals(loan.principalAmount));
      expect(restored.paidAmount, equals(loan.paidAmount));
    });

    test('supports monitoredBanks with backward-compatible trackedSenderName alias', () {
      final loan = LoanRecord(
        id: 11,
        loanType: 'lent',
        personName: 'Almaz',
        monitoredBanks: 'Telebirr, CBE',
        principalAmount: 1200.0,
        paidAmount: 200.0,
        loanDate: now,
        dueDate: now.add(const Duration(days: 15)),
      );

      expect(loan.monitoredBanks, equals('Telebirr, CBE'));
      expect(loan.trackedSenderName, equals('Telebirr, CBE'));

      final map = loan.toMap();
      expect(map['trackedSenderName'], equals('Telebirr, CBE'));
      expect(map.containsKey('monitoredBanks'), isFalse);

      final fromLegacyMap = LoanRecord.fromMap({
        'id': 12,
        'loanType': 'borrowed',
        'personName': 'Daniel',
        'trackedSenderName': 'BOA',
        'principalAmount': 3000.0,
        'paidAmount': 0.0,
        'loanDate': now.toIso8601String(),
        'dueDate': now.add(const Duration(days: 30)).toIso8601String(),
      });
      expect(fromLegacyMap.monitoredBanks, equals('BOA'));
      expect(fromLegacyMap.trackedSenderName, equals('BOA'));
    });
  });

  group('CashTransaction Model', () {
    test('serializes to and from Map', () {
      final tx = CashTransaction(
        id: 1,
        type: 'expense',
        amount: 250.0,
        date: DateTime(2026, 4, 1),
        description: 'Lunch expense',
        reasonName: 'Food',
      );

      final map = tx.toMap();
      final restored = CashTransaction.fromMap(map);

      expect(restored.id, equals(tx.id));
      expect(restored.amount, equals(250.0));
      expect(restored.type, equals('expense'));
      expect(restored.description, equals('Lunch expense'));
      expect(restored.reasonName, equals('Food'));
    });
  });

  group('AppTransaction Model (Bank vs Counterparty)', () {
    test('exposes bankName and counterparty with non-breaking name and sender aliases', () {
      final tx = AppTransaction(
        id: 'tx_1',
        bankName: 'Bunna Bank',
        counterparty: 'Telebirr Transfer',
        amount: 500.0,
        type: 'income',
        date: DateTime(2026, 9, 7),
        category: 'Auto',
        rawMessage: 'You received ETB 500 from Telebirr Transfer',
        isAutoDetected: true,
      );

      // Primary fields
      expect(tx.bankName, equals('Bunna Bank'));
      expect(tx.counterparty, equals('Telebirr Transfer'));

      // Backward-compatible aliases
      expect(tx.name, equals('Bunna Bank'));
      expect(tx.sender, equals('Telebirr Transfer'));
    });

    test('accepts legacy constructor parameters name and sender', () {
      final tx = AppTransaction(
        id: 'tx_legacy',
        name: 'Commercial Bank of Ethiopia',
        sender: 'Abebe Bikila',
        amount: 1500.0,
        type: 'income',
        date: DateTime(2026, 9, 7),
        category: 'Auto',
        rawMessage: 'Credit 1500',
        isAutoDetected: true,
      );

      expect(tx.bankName, equals('Commercial Bank of Ethiopia'));
      expect(tx.counterparty, equals('Abebe Bikila'));
      expect(tx.name, equals('Commercial Bank of Ethiopia'));
      expect(tx.sender, equals('Abebe Bikila'));
    });

    test('serializes to Map with exact SQLite schema column names', () {
      final tx = AppTransaction(
        id: 'tx_2',
        bankName: 'Telebirr',
        counterparty: 'Ethio Telecom',
        amount: 100.0,
        type: 'expense',
        date: DateTime(2026, 9, 7),
        sourceTag: 'Airtime',
        rawMessage: 'Airtime recharge 100',
        isAutoDetected: true,
      );

      final map = tx.toMap();

      // SQLite column keys
      expect(map['name'], equals('Telebirr'));
      expect(map['sender'], equals('Ethio Telecom'));
      expect(map['category'], equals('Airtime'));

      // Non-schema alias keys must NOT be present in toMap to avoid SQLite crashing
      expect(map.containsKey('bankName'), isFalse);
      expect(map.containsKey('counterparty'), isFalse);
      expect(map.containsKey('sourceTag'), isFalse);
    });

    test('deserializes from Map supporting legacy SQLite column names', () {
      final legacyMap = {
        'id': 'tx_legacy_map',
        'name': 'Dashen Bank',
        'sender': 'Kebede',
        'amount': 2500.0,
        'type': 'expense',
        'date': DateTime(2026, 9, 7).toIso8601String(),
        'category': 'Auto',
        'rawMessage': 'Paid 2500',
        'isAutoDetected': 1,
        'totalBalance': 10000.0,
      };

      final tx = AppTransaction.fromMap(legacyMap);

      expect(tx.bankName, equals('Dashen Bank'));
      expect(tx.counterparty, equals('Kebede'));
      expect(tx.name, equals('Dashen Bank'));
      expect(tx.sender, equals('Kebede'));
      expect(tx.sourceTag, equals('Auto'));
      expect(tx.category, equals('Auto'));
    });

    test('supports sourceTag as primary property with category alias and resolvedCategory helper', () {
      final txAuto = AppTransaction(
        id: 'tx_auto',
        bankName: 'Telebirr',
        counterparty: 'Ethio Telecom',
        amount: 50.0,
        type: 'expense',
        date: DateTime(2026, 9, 7),
        sourceTag: 'Auto',
        rawMessage: 'Airtime 50',
        isAutoDetected: true,
      );

      expect(txAuto.sourceTag, equals('Auto'));
      expect(txAuto.category, equals('Auto')); // Alias
      expect(txAuto.resolvedCategory, equals('Uncategorized')); // Not 'Auto'!

      final txCategorized = txAuto.copyWith(
        reason: 'Telecommunication',
      );
      expect(txCategorized.resolvedCategory, equals('Telecommunication'));

      final txManual = AppTransaction(
        id: 'tx_manual',
        bankName: 'CBE',
        counterparty: 'Grocery Store',
        amount: 300.0,
        type: 'expense',
        date: DateTime(2026, 9, 7),
        sourceTag: 'Manual',
        rawMessage: 'Manual entry',
        isAutoDetected: false,
        customReasonText: 'Groceries',
      );
      expect(txManual.sourceTag, equals('Manual'));
      expect(txManual.resolvedCategory, equals('Groceries'));
    });
  });

  group('CashTransaction Model (Income / Expense unification)', () {
    test('standardizes type to income and supports legacy addition deserialization', () {
      final ctxNew = CashTransaction(
        id: 10,
        type: 'income',
        amount: 500.0,
        date: DateTime(2026, 9, 7),
      );
      expect(ctxNew.type, equals('income'));
      expect(ctxNew.isIncome, isTrue);
      expect(ctxNew.isExpense, isFalse);

      final legacyMap = {
        'id': 11,
        'type': 'addition',
        'amount': 350.0,
        'date': DateTime(2026, 9, 7).toIso8601String(),
      };
      final ctxRestored = CashTransaction.fromMap(legacyMap);
      expect(ctxRestored.type, equals('income'));
      expect(ctxRestored.isIncome, isTrue);
      expect(ctxRestored.isExpense, isFalse);

      final outMap = ctxRestored.toMap();
      expect(outMap['type'], equals('income'));
    });
  });
}
