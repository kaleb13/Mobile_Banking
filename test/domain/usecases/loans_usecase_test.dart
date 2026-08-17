import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/loan_record.dart';
import 'package:mobile_banking_app/domain/usecases/loans/calculate_loan_progress_usecase.dart';
import 'package:mobile_banking_app/domain/usecases/loans/process_loan_repayment_usecase.dart';

void main() {
  group('CalculateLoanProgressUseCase', () {
    const useCase = CalculateLoanProgressUseCase();

    test('calculates correct portfolio summaries for lent and borrowed loans', () {
      final now = DateTime(2026, 8, 17);
      final loans = [
        LoanRecord(
          id: 1,
          loanType: 'lent',
          personName: 'Nahom',
          principalAmount: 5000,
          paidAmount: 2000,
          loanDate: DateTime(2026, 8, 1),
          dueDate: DateTime(2026, 8, 30),
          status: 'active',
        ),
        LoanRecord(
          id: 2,
          loanType: 'borrowed',
          personName: 'Telebirr',
          principalAmount: 10000,
          paidAmount: 10000,
          loanDate: DateTime(2026, 7, 1),
          dueDate: DateTime(2026, 8, 1),
          status: 'paid',
        ),
        LoanRecord(
          id: 3,
          loanType: 'borrowed',
          personName: 'CBE',
          principalAmount: 4000,
          paidAmount: 1000,
          loanDate: DateTime(2026, 7, 15),
          dueDate: DateTime(2026, 8, 10), // Overdue
          status: 'active',
        ),
      ];

      final summary = useCase.calculateSummary(loans, referenceDate: now);

      expect(summary.totalLent, 5000.0);
      expect(summary.totalLentCollected, 2000.0);
      expect(summary.outstandingLent, 3000.0);

      expect(summary.totalBorrowed, 14000.0);
      expect(summary.totalBorrowedRepaid, 11000.0);
      expect(summary.outstandingBorrowed, 3000.0);

      expect(summary.activeLoansCount, 2);
      expect(summary.overdueLoansCount, 1);
    });
  });

  group('ProcessLoanRepaymentUseCase', () {
    const useCase = ProcessLoanRepaymentUseCase();

    test('applies partial repayment correctly', () {
      final loan = LoanRecord(
        id: 1,
        loanType: 'lent',
        personName: 'Nahom',
        principalAmount: 5000,
        paidAmount: 1000,
        loanDate: DateTime(2026, 8, 1),
        dueDate: DateTime(2026, 8, 30),
        status: 'active',
      );

      final result = useCase.applyRepayment(loan: loan, paymentAmount: 2000);

      expect(result.updatedLoan.paidAmount, 3000.0);
      expect(result.updatedLoan.status, 'active');
      expect(result.isFullyPaid, isFalse);
    });

    test('advances status to paid on full repayment', () {
      final loan = LoanRecord(
        id: 1,
        loanType: 'lent',
        personName: 'Nahom',
        principalAmount: 5000,
        paidAmount: 4000,
        loanDate: DateTime(2026, 8, 1),
        dueDate: DateTime(2026, 8, 30),
        status: 'active',
      );

      final result = useCase.applyRepayment(loan: loan, paymentAmount: 1000);

      expect(result.updatedLoan.paidAmount, 5000.0);
      expect(result.updatedLoan.status, 'paid');
      expect(result.isFullyPaid, isTrue);
    });
  });

  group('Loan Visibility & Filtering', () {
    test('settled loans are properly identified and filtered by hidden IDs', () {
      final loans = [
        LoanRecord(
          id: 101,
          loanType: 'borrowed',
          personName: 'Ethio Telecom / CBE',
          trackedSenderName: 'Telebirr',
          contractNumber: 'DGV0EMRXKY',
          principalAmount: 10000,
          paidAmount: 10000,
          loanDate: DateTime(2026, 8, 1),
          dueDate: DateTime(2026, 8, 10),
          status: 'paid',
        ),
        LoanRecord(
          id: 102,
          loanType: 'lent',
          personName: 'Kaleb',
          principalAmount: 3000,
          paidAmount: 0,
          loanDate: DateTime(2026, 8, 1),
          dueDate: DateTime(2026, 8, 20),
          status: 'active',
        ),
      ];

      final hiddenIds = {101};

      final visiblePaid =
          loans.where((l) => l.isPaid && !hiddenIds.contains(l.id)).toList();
      final visibleActive =
          loans.where((l) => !l.isPaid && !hiddenIds.contains(l.id)).toList();

      expect(visiblePaid.isEmpty, isTrue);
      expect(visibleActive.length, 1);
      expect(visibleActive.first.personName, 'Kaleb');
    });
  });
}
