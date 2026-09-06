import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/data/repositories/loan_repository.dart';
import 'package:mobile_banking_app/models/loan_record.dart';
import 'package:mobile_banking_app/models/loan_repayment_request.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/presentation/viewmodels/loans_view_model.dart';

class FakeLoanRepository implements LoanRepository {
  final List<LoanRecord> loans = [];
  final Map<int, List<LoanPayment>> payments = {};
  final List<LoanRepaymentRequest> requests = [];
  Set<int> hiddenIds = {};
  int _nextLoanId = 1;
  int _nextPaymentId = 1;

  @override
  Future<List<LoanRecord>> getLoans() async => List.from(loans);

  @override
  Future<LoanRecord?> getLoanById(int id) async {
    return loans.cast<LoanRecord?>().firstWhere(
          (l) => l?.id == id,
          orElse: () => null,
        );
  }

  @override
  Future<int> insertLoan(LoanRecord loan) async {
    final id = _nextLoanId++;
    final withId = LoanRecord(
      id: id,
      loanType: loan.loanType,
      personName: loan.personName,
      trackedSenderName: loan.trackedSenderName,
      principalAmount: loan.principalAmount,
      paidAmount: loan.paidAmount,
      loanDate: loan.loanDate,
      dueDate: loan.dueDate,
      linkedTransactionId: loan.linkedTransactionId,
      status: loan.status,
      note: loan.note,
      contractNumber: loan.contractNumber,
    );
    loans.add(withId);
    payments[id] = [];
    return id;
  }

  @override
  Future<void> updateLoan(LoanRecord loan) async {
    final idx = loans.indexWhere((l) => l.id == loan.id);
    if (idx != -1) loans[idx] = loan;
  }

  @override
  Future<void> deleteLoan(int id) async {
    loans.removeWhere((l) => l.id == id);
    payments.remove(id);
  }

  @override
  Future<List<LoanPayment>> getPaymentsForLoan(int loanId) async {
    return List.from(payments[loanId] ?? []);
  }

  @override
  Future<void> insertPayment(LoanPayment payment) async {
    final id = _nextPaymentId++;
    final withId = LoanPayment(
      id: id,
      loanId: payment.loanId,
      amount: payment.amount,
      paymentDate: payment.paymentDate,
      linkedTransactionId: payment.linkedTransactionId,
      note: payment.note,
    );
    payments.putIfAbsent(payment.loanId, () => []).add(withId);
  }

  @override
  Future<void> deletePayment(int paymentId) async {
    for (final pList in payments.values) {
      pList.removeWhere((p) => p.id == paymentId);
    }
  }

  @override
  Future<LoanRecord?> recalcLoanPaid(int loanId) async {
    final idx = loans.indexWhere((l) => l.id == loanId);
    if (idx == -1) return null;
    final pList = payments[loanId] ?? [];
    final total = pList.fold<double>(0.0, (sum, p) => sum + p.amount);
    final isPaid = total >= loans[idx].principalAmount;
    final updated = loans[idx].copyWith(
      paidAmount: total,
      status: isPaid ? 'paid' : loans[idx].status,
    );
    loans[idx] = updated;
    return updated;
  }

  @override
  Future<List<LoanRepaymentRequest>> getPendingRepaymentRequests() async =>
      List.from(requests.where((r) => r.isPending));

  @override
  Future<void> insertRepaymentRequest(LoanRepaymentRequest request) async {
    requests.add(request);
  }

  @override
  Future<void> updateRepaymentRequestStatus(int id, String status) async {
    final idx = requests.indexWhere((r) => r.id == id);
    if (idx != -1) {
      requests[idx] = requests[idx].copyWith(status: status);
    }
  }

  @override
  Future<Set<int>> getHiddenLoanIds() async => Set.from(hiddenIds);

  @override
  Future<void> setHiddenLoanIds(Set<int> ids) async {
    hiddenIds = Set.from(ids);
  }
}

void main() {
  late FakeLoanRepository repo;
  late LoansViewModel vm;

  setUp(() async {
    repo = FakeLoanRepository();
    vm = LoansViewModel(repository: repo);
    await vm.loadLoans();
  });

  group('LoansViewModel - Repayment Linking & MVVM Coordination', () {
    test('getEligibleTransactionsForLoan filters by loanType and excludes used txs', () async {
      // Create a lent loan
      final loan = await vm.createLoan(
        loanType: 'lent',
        personName: 'Abebe',
        principalAmount: 2000,
        dueDate: DateTime(2026, 9, 30),
      );

      final tx1 = AppTransaction(
        id: 'tx_income_1',
        sender: 'CBE',
        amount: 500,
        type: 'income',
        date: DateTime(2026, 9, 2),
        name: 'Friend',
        category: 'Transfer',
        rawMessage: 'credited with 500',
        isAutoDetected: false,
      );
      final tx2 = AppTransaction(
        id: 'tx_expense_1',
        sender: 'Telebirr',
        amount: 300,
        type: 'expense',
        date: DateTime(2026, 9, 3),
        name: 'Merchant',
        category: 'Shopping',
        rawMessage: 'debited with 300',
        isAutoDetected: false,
      );
      final tx3 = AppTransaction(
        id: 'tx_income_2',
        sender: 'BOA',
        amount: 1500,
        type: 'income',
        date: DateTime(2026, 9, 4),
        name: 'Brother',
        category: 'Transfer',
        rawMessage: 'credited with 1500',
        isAutoDetected: false,
      );

      // Injected transactions
      vm.getTransactions = () => [tx1, tx2, tx3];

      // Lent loan should only see income transactions (tx1 and tx3), sorted descending by date
      final eligible = vm.getEligibleTransactionsForLoan(loan);
      expect(eligible.length, 2);
      expect(eligible[0].id, 'tx_income_2'); // newer date
      expect(eligible[1].id, 'tx_income_1');
    });

    test('attachTransactionRepayment records payment, updates loan balance, and syncs reason', () async {
      final loan = await vm.createLoan(
        loanType: 'lent',
        personName: 'Nahom',
        principalAmount: 1000,
        dueDate: DateTime(2026, 9, 30),
      );

      final paymentTx = AppTransaction(
        id: 'tx_repay_100',
        sender: 'Telebirr',
        amount: 400,
        type: 'income',
        date: DateTime(2026, 9, 5),
        name: 'ThirdParty Account',
        category: 'Transfer',
        rawMessage: 'credited with 400',
        isAutoDetected: false,
      );

      String? reasonUpdatedTxId;
      String? customReasonAssigned;
      vm.updateTransactionReason = (txId, {reasonId, customReasonText}) async {
        reasonUpdatedTxId = txId;
        customReasonAssigned = customReasonText;
      };

      await vm.attachTransactionRepayment(
        loanId: loan.id!,
        transaction: paymentTx,
        customAmount: 400,
      );

      // 1. Verify loan balance updated
      final updatedLoan = vm.loanRecords.firstWhere((l) => l.id == loan.id);
      expect(updatedLoan.paidAmount, 400.0);
      expect(updatedLoan.remainingAmount, 600.0);
      expect(updatedLoan.isPaid, false);

      // 2. Verify cross-domain reason was assigned
      expect(reasonUpdatedTxId, 'tx_repay_100');
      expect(customReasonAssigned, 'Loan Repayment');

      // 3. Verify getRepaymentForTransaction resolves the link
      final resolved = vm.getRepaymentForTransaction('tx_repay_100');
      expect(resolved, isNotNull);
      expect(resolved!.loan.id, loan.id);
      expect(resolved.payment.amount, 400.0);
      expect(resolved.payment.linkedTransactionId, 'tx_repay_100');

      // 4. Verify transaction is no longer in eligible list
      vm.getTransactions = () => [paymentTx];
      final eligibleAfter = vm.getEligibleTransactionsForLoan(updatedLoan);
      expect(eligibleAfter, isEmpty);
    });

    test('full repayment via attachTransactionRepayment settles loan status', () async {
      final loan = await vm.createLoan(
        loanType: 'borrowed',
        personName: 'Bank',
        principalAmount: 500,
        dueDate: DateTime(2026, 9, 30),
      );

      final fullTx = AppTransaction(
        id: 'tx_expense_full',
        sender: 'CBE',
        amount: 500,
        type: 'expense',
        date: DateTime(2026, 9, 5),
        name: 'CBE Payment',
        category: 'Transfer',
        rawMessage: 'debited with 500',
        isAutoDetected: false,
      );

      await vm.attachTransactionRepayment(
        loanId: loan.id!,
        transaction: fullTx,
      );

      final settledLoan = vm.loanRecords.firstWhere((l) => l.id == loan.id);
      expect(settledLoan.paidAmount, 500.0);
      expect(settledLoan.remainingAmount, 0.0);
      expect(settledLoan.isPaid, true);
    });

    test('getEligibleTransactionsForLoan supports allowAll fallback', () async {
      final loan = await vm.createLoan(
        loanType: 'lent',
        personName: 'Chala',
        principalAmount: 1000,
        dueDate: DateTime(2026, 9, 30),
      );

      final expTx = AppTransaction(
        id: 'tx_exp_fallback',
        sender: 'Store',
        amount: 250,
        type: 'expense',
        date: DateTime(2026, 9, 5),
        name: 'Telebirr',
        category: 'Shopping',
        rawMessage: 'debited with 250',
        isAutoDetected: false,
      );

      vm.getTransactions = () => [expTx];

      // Strict recommended: empty
      expect(vm.getEligibleTransactionsForLoan(loan, allowAll: false), isEmpty);
      // allowAll: includes all unlinked transactions
      expect(vm.getEligibleTransactionsForLoan(loan, allowAll: true).length, 1);
    });
  });
}
