import '../../models/loan_record.dart';
import '../../models/loan_repayment_request.dart';
import '../../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract Interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class LoanRepository {
  // ── Loan Records ──
  Future<List<LoanRecord>> getLoans();
  Future<LoanRecord?> getLoanById(int id);
  Future<int> insertLoan(LoanRecord loan);
  Future<void> updateLoan(LoanRecord loan);
  Future<void> deleteLoan(int id);

  // ── Loan Payments ──
  Future<List<LoanPayment>> getPaymentsForLoan(int loanId);
  Future<void> insertPayment(LoanPayment payment);
  Future<void> deletePayment(int paymentId);
  Future<LoanRecord?> recalcLoanPaid(int loanId);

  // ── Repayment Requests ──
  Future<List<LoanRepaymentRequest>> getPendingRepaymentRequests();
  Future<void> insertRepaymentRequest(LoanRepaymentRequest request);
  Future<void> updateRepaymentRequestStatus(int id, String status);

  // ── Hidden Loans (Preferences) ──
  Future<Set<int>> getHiddenLoanIds();
  Future<void> setHiddenLoanIds(Set<int> ids);
}

// ─────────────────────────────────────────────────────────────────────────────
// Concrete SQLite + SharedPreferences Implementation
// ─────────────────────────────────────────────────────────────────────────────

class LoanRepositoryImpl implements LoanRepository {
  final DatabaseService _db;

  LoanRepositoryImpl({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  // ── Loan Records ──────────────────────────────────────────────────────────

  @override
  Future<List<LoanRecord>> getLoans() => _db.getLoanRecords();

  @override
  Future<LoanRecord?> getLoanById(int id) => _db.getLoanById(id);

  @override
  Future<int> insertLoan(LoanRecord loan) => _db.insertLoanRecord(loan);

  @override
  Future<void> updateLoan(LoanRecord loan) => _db.updateLoanRecord(loan);

  @override
  Future<void> deleteLoan(int id) => _db.deleteLoanRecord(id);

  // ── Loan Payments ─────────────────────────────────────────────────────────

  @override
  Future<List<LoanPayment>> getPaymentsForLoan(int loanId) =>
      _db.getPaymentsForLoan(loanId);

  @override
  Future<void> insertPayment(LoanPayment payment) =>
      _db.insertLoanPayment(payment);

  @override
  Future<void> deletePayment(int paymentId) =>
      _db.deleteLoanPayment(paymentId);

  @override
  Future<LoanRecord?> recalcLoanPaid(int loanId) =>
      _db.recalcLoanPaid(loanId);

  // ── Repayment Requests ────────────────────────────────────────────────────

  @override
  Future<List<LoanRepaymentRequest>> getPendingRepaymentRequests() =>
      _db.getPendingRepaymentRequests();

  @override
  Future<void> insertRepaymentRequest(LoanRepaymentRequest request) =>
      _db.insertLoanRepaymentRequest(request);

  @override
  Future<void> updateRepaymentRequestStatus(int id, String status) =>
      _db.updateRepaymentRequestStatus(id, status);

  // ── Hidden Loans (SharedPreferences) ──────────────────────────────────────

  @override
  Future<Set<int>> getHiddenLoanIds() async {
    final prefs = await SharedPreferences.getInstance();
    final hiddenList = prefs.getStringList('hidden_loan_ids') ?? [];
    return hiddenList.map((e) => int.tryParse(e)).whereType<int>().toSet();
  }

  @override
  Future<void> setHiddenLoanIds(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'hidden_loan_ids', ids.map((e) => e.toString()).toList());
  }
}
