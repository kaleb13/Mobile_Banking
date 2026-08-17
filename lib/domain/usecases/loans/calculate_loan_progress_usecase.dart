import '../../../models/loan_record.dart';

class LoanSummary {
  final double totalLent;
  final double totalBorrowed;
  final double totalLentCollected;
  final double totalBorrowedRepaid;
  final double outstandingLent;
  final double outstandingBorrowed;
  final int activeLoansCount;
  final int overdueLoansCount;

  const LoanSummary({
    required this.totalLent,
    required this.totalBorrowed,
    required this.totalLentCollected,
    required this.totalBorrowedRepaid,
    required this.outstandingLent,
    required this.outstandingBorrowed,
    required this.activeLoansCount,
    required this.overdueLoansCount,
  });
}

class CalculateLoanProgressUseCase {
  const CalculateLoanProgressUseCase();

  /// Calculates aggregated portfolio summaries across all lent and borrowed loans.
  LoanSummary calculateSummary(List<LoanRecord> loans, {DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();

    double totalLent = 0.0;
    double totalBorrowed = 0.0;
    double totalLentCollected = 0.0;
    double totalBorrowedRepaid = 0.0;
    int activeCount = 0;
    int overdueCount = 0;

    for (final loan in loans) {
      final isPaid = loan.paidAmount >= loan.principalAmount || loan.status == 'paid';
      final isOverdue = !isPaid && now.isAfter(loan.dueDate);

      if (loan.loanType == 'lent') {
        totalLent += loan.principalAmount;
        totalLentCollected += loan.paidAmount;
      } else {
        totalBorrowed += loan.principalAmount;
        totalBorrowedRepaid += loan.paidAmount;
      }

      if (!isPaid) {
        activeCount++;
        if (isOverdue) {
          overdueCount++;
        }
      }
    }

    final outstandingLent = (totalLent - totalLentCollected).clamp(0.0, double.infinity);
    final outstandingBorrowed = (totalBorrowed - totalBorrowedRepaid).clamp(0.0, double.infinity);

    return LoanSummary(
      totalLent: totalLent,
      totalBorrowed: totalBorrowed,
      totalLentCollected: totalLentCollected,
      totalBorrowedRepaid: totalBorrowedRepaid,
      outstandingLent: outstandingLent,
      outstandingBorrowed: outstandingBorrowed,
      activeLoansCount: activeCount,
      overdueLoansCount: overdueCount,
    );
  }
}
