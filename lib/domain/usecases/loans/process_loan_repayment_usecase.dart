import '../../../models/loan_record.dart';
import '../../../models/transaction.dart';

class LoanRepaymentResult {
  final LoanRecord updatedLoan;
  final bool isFullyPaid;
  final double appliedAmount;

  const LoanRepaymentResult({
    required this.updatedLoan,
    required this.isFullyPaid,
    required this.appliedAmount,
  });
}

class ProcessLoanRepaymentUseCase {
  const ProcessLoanRepaymentUseCase();

  /// Applies a repayment amount against a loan record and computes the updated status.
  LoanRepaymentResult applyRepayment({
    required LoanRecord loan,
    required double paymentAmount,
  }) {
    final newPaidAmount = loan.paidAmount + paymentAmount;
    final isFullyPaid = newPaidAmount >= loan.principalAmount;
    final updatedLoan = loan.copyWith(
      paidAmount: newPaidAmount,
      status: isFullyPaid ? 'paid' : loan.status,
    );

    return LoanRepaymentResult(
      updatedLoan: updatedLoan,
      isFullyPaid: isFullyPaid,
      appliedAmount: paymentAmount,
    );
  }

  /// Finds matching active loan for a transaction by contract number or tracked sender name.
  LoanRecord? findMatchingLoan({
    required List<LoanRecord> activeLoans,
    required AppTransaction transaction,
    String? contractNumber,
  }) {
    if (contractNumber != null && contractNumber.isNotEmpty) {
      for (final loan in activeLoans) {
        if (loan.contractNumber != null &&
            loan.contractNumber!.toLowerCase() == contractNumber.toLowerCase()) {
          return loan;
        }
      }
    }

    final txSenderLower = transaction.sender.toLowerCase().trim();
    final txNameLower = transaction.name.toLowerCase().trim();
    for (final loan in activeLoans) {
      final personLower = loan.personName.toLowerCase().trim();
      if (txNameLower.isNotEmpty && (txNameLower == personLower || txNameLower.contains(personLower) || personLower.contains(txNameLower))) {
        return loan;
      }
      if (txSenderLower == personLower || txSenderLower.contains(personLower) || personLower.contains(txSenderLower)) {
        return loan;
      }
    }

    return null;
  }
}
