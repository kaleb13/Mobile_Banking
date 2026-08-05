import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/saving_goal.dart';
import 'package:mobile_banking_app/models/loan_record.dart';
import 'package:mobile_banking_app/models/cash_transaction.dart';

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
}
