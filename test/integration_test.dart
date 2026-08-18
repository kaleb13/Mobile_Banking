import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/services/bank_senders.dart';
import 'package:mobile_banking_app/services/cbe_parser.dart';
import 'package:mobile_banking_app/services/telebirr_parser.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/models/saving_goal.dart';
import 'package:mobile_banking_app/models/loan_record.dart';

void main() {
  group('Integration Flow 1: End-to-End SMS Processing Pipeline', () {
    test('authenticates sender and parses CBE income SMS into transaction', () {
      const rawSender = 'CBE';
      const rawSms =
          'Dear Kaleb your Account 1*********2757 has been Credited with ETB 207.50 from Kaleab Afesha, on 24/04/2026 at 13:44:16 with Ref No FT26114Y5F42 Your Current Balance is ETB 556.87. Thank you for Banking with CBE!';

      // Step 1: Bank sender verification
      final bankName = BankSenders.match(rawSender);
      expect(bankName, equals('CBE'));

      // Step 2: Parser extraction
      final AppTransaction? tx = CbeParser.parse(rawSms, DateTime.now());
      expect(tx, isNotNull);
      expect(tx!.amount, equals(207.50));
      expect(tx.type, equals('income'));
      expect(tx.totalBalance, equals(556.87));
      expect(tx.isAutoDetected, isTrue);

      // Step 3: Verify integrated transaction attributes
      expect(tx.name, equals('CBE'));
      expect(tx.sender, equals('Kaleab Afesha'));
    });

    test('rejects unverified sender SMS even if message looks like bank receipt', () {
      const fakeSender = '+251911998877';
      const fakeSms =
          'Dear Customer, your Account 1000123456789 has been Credited with ETB 50,000.00.';

      final bankName = BankSenders.match(fakeSender);
      expect(bankName, isNull);
      expect(fakeSms.isNotEmpty, isTrue);
    });

    test('detects Telebirr sender matching pipeline', () {
      const telebirrSender = '127';

      // Step 1: Verify shortcode sender
      expect(BankSenders.match(telebirrSender), equals('Telebirr'));
    });
  });

  group('Integration Flow 2: Gamification & User Level System', () {
    double computeTotalBalance(List<AppTransaction> transactions) {
      double total = 0.0;
      for (final tx in transactions) {
        if (tx.type == 'income') {
          total += tx.amount;
        } else if (tx.type == 'expense') {
          total -= tx.amount;
        }
      }
      return total;
    }

    int getUserLevel(double balance) {
      if (balance <= 100000) return 1; // Survivor
      if (balance <= 500000) return 2; // Builder
      if (balance <= 1000000) return 3; // Flourishing
      if (balance <= 5000000) return 4; // Prospering
      return 5; // Elite
    }

    test('calculates total balance and advances user level as balance grows', () {
      final transactions = <AppTransaction>[];

      // Initial state: 0 balance -> Level 1 (Survivor)
      expect(computeTotalBalance(transactions), equals(0.0));
      expect(getUserLevel(0.0), equals(1));

      // Deposit 50,000 ETB -> Level 1 (Survivor)
      transactions.add(AppTransaction(
        name: 'CBE',
        amount: 50000.0,
        type: 'income',
        date: DateTime.now(),
        sender: 'Salary',
        category: 'Income',
        rawMessage: '',
        isAutoDetected: true,
      ));
      expect(computeTotalBalance(transactions), equals(50000.0));
      expect(getUserLevel(50000.0), equals(1));

      // Additional deposit of 200,000 ETB -> Total 250,000 ETB -> Level 2 (Builder)
      transactions.add(AppTransaction(
        name: 'CBE',
        amount: 200000.0,
        type: 'income',
        date: DateTime.now(),
        sender: 'Business Income',
        category: 'Income',
        rawMessage: '',
        isAutoDetected: true,
      ));
      expect(computeTotalBalance(transactions), equals(250000.0));
      expect(getUserLevel(250000.0), equals(2));

      // Additional deposit of 400,000 ETB -> Total 650,000 ETB -> Level 3 (Flourishing)
      transactions.add(AppTransaction(
        name: 'CBE',
        amount: 400000.0,
        type: 'income',
        date: DateTime.now(),
        sender: 'Investment Return',
        category: 'Income',
        rawMessage: '',
        isAutoDetected: true,
      ));
      expect(computeTotalBalance(transactions), equals(650000.0));
      expect(getUserLevel(650000.0), equals(3));
    });
  });

  group('Integration Flow 3: Saving Goal & Allocation Feasibility Pipeline', () {
    test('tracks multiple goals and allocates total available savings', () {
      final goals = [
        SavingGoal(
          id: 'g1',
          title: 'Emergency Fund',
          targetAmount: 100000.0,
          savedAmount: 40000.0,
        ),
        SavingGoal(
          id: 'g2',
          title: 'New Car Downpayment',
          targetAmount: 300000.0,
          savedAmount: 150000.0,
        ),
      ];

      final totalTarget = goals.fold<double>(0.0, (sum, g) => sum + g.targetAmount);
      final totalSaved = goals.fold<double>(0.0, (sum, g) => sum + g.savedAmount);
      final overallProgress = (totalSaved / totalTarget) * 100;

      expect(totalTarget, equals(400000.0));
      expect(totalSaved, equals(190000.0));
      expect(overallProgress, equals(47.5));
    });
  });

  group('Integration Flow 4: Loan Lifecycle & Repayment Pipeline', () {
    test('updates loan status from active to paid upon full repayment', () {
      final now = DateTime.now();
      var loan = LoanRecord(
        id: 100,
        loanType: 'lent',
        personName: 'Tewodros',
        principalAmount: 10000.0,
        paidAmount: 0.0,
        loanDate: now,
        dueDate: now.add(const Duration(days: 60)),
        status: 'active',
      );

      expect(loan.remainingAmount, equals(10000.0));
      expect(loan.isPaid, isFalse);

      // Partial repayment of 4000 ETB
      loan = LoanRecord(
        id: loan.id,
        loanType: loan.loanType,
        personName: loan.personName,
        principalAmount: loan.principalAmount,
        paidAmount: 4000.0,
        loanDate: loan.loanDate,
        dueDate: loan.dueDate,
        status: 'active',
      );
      expect(loan.remainingAmount, equals(6000.0));
      expect(loan.progressPercent, equals(0.4));
      expect(loan.isPaid, isFalse);

      // Final repayment of 6000 ETB
      loan = LoanRecord(
        id: loan.id,
        loanType: loan.loanType,
        personName: loan.personName,
        principalAmount: loan.principalAmount,
        paidAmount: 10000.0,
        loanDate: loan.loanDate,
        dueDate: loan.dueDate,
        status: 'paid',
      );
      expect(loan.remainingAmount, equals(0.0));
      expect(loan.progressPercent, equals(1.0));
      expect(loan.isPaid, isTrue);
    });

    test('verifies Telebirr credit disbursement SMS does not create a loan or transaction', () {
      const creditSms =
          'Your credit request with DGV0EMRXKY contract number has been approved. The credit amount is ETB 500.00, facilitation fee ETB 6.25, due date 10/08/2026. Your current available credit limit ETB400.00.';

      final tx = TelebirrParser.parse(creditSms, DateTime.now());
      // Must return null so no transaction or loan is automatically inserted
      expect(tx, isNull);
    });
  });
}
