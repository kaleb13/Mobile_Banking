import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../data/repositories/loan_repository.dart';
import '../../models/loan_record.dart';
import '../../models/loan_repayment_request.dart';
import '../../models/transaction.dart';
import '../../models/sender.dart';
import '../../models/reason.dart';
import '../../domain/usecases/loans/calculate_loan_progress_usecase.dart';
import '../../domain/usecases/loans/process_loan_repayment_usecase.dart';

/// Callback to update a transaction's reason from the Transactions domain.
/// Used by loan creation and repayment to auto-assign the 'Loan' reason.
typedef UpdateTransactionReasonFn = Future<void> Function(
  String transactionId, {
  int? reasonId,
  String? customReasonText,
});

/// Callback to add a notification from the Notifications domain.
typedef AddNotificationFn = Future<void> Function({
  required String sender,
  required String body,
  required DateTime date,
});

/// LoansViewModel — owns all loan-related state and actions.
///
/// Cross-domain dependencies (transactions, senders, reasons) are injected as
/// read-only getters or callbacks so this ViewModel never imports or directly
/// depends on TransactionsViewModel or DatabaseService.
class LoansViewModel extends ChangeNotifier {
  final LoanRepository _repository;

  // Use cases
  final CalculateLoanProgressUseCase _calculateLoanProgressUseCase =
      const CalculateLoanProgressUseCase();
  final ProcessLoanRepaymentUseCase _processLoanRepaymentUseCase =
      const ProcessLoanRepaymentUseCase();

  // Cross-domain callbacks (injected from main.dart via ProxyProvider bridge)
  UpdateTransactionReasonFn? updateTransactionReason;
  AddNotificationFn? addNotification;

  // Cross-domain read-only accessors (set by ProxyProvider bridge)
  List<AppTransaction> Function()? getTransactions;
  List<AppSender> Function()? getSenders;
  List<AppReason> Function()? getReasons;

  LoansViewModel({
    required LoanRepository repository,
  })  : _repository = repository;

  // ── State ─────────────────────────────────────────────────────────────────

  List<LoanRecord> _loanRecords = [];
  UnmodifiableListView<LoanRecord> get loanRecords =>
      UnmodifiableListView(_loanRecords);

  Map<int, List<LoanPayment>> _loanPayments = {};
  List<LoanPayment> paymentsForLoan(int loanId) =>
      _loanPayments[loanId] ?? [];

  List<LoanRepaymentRequest> _pendingRepaymentRequests = [];
  UnmodifiableListView<LoanRepaymentRequest> get pendingRepaymentRequests =>
      UnmodifiableListView(_pendingRepaymentRequests);

  Set<int> _hiddenLoanIds = {};
  Set<int> get hiddenLoanIds => Set.unmodifiable(_hiddenLoanIds);
  bool isLoanHidden(int id) => _hiddenLoanIds.contains(id);

  int _activeLoanTabIndex = 0;
  int get activeLoanTabIndex => _activeLoanTabIndex;

  // ── Computed Getters ──────────────────────────────────────────────────────

  List<LoanRecord> get activeLoans =>
      _loanRecords.where((l) => l.status == 'active').toList();

  List<LoanRecord> get overdueLoans =>
      _loanRecords.where((l) => l.isOverdue).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<LoanRecord> get paidLoans =>
      _loanRecords.where((l) => l.isPaid).toList();

  int get activeLoanCount => activeLoans.length;
  int get overdueLoanCount => overdueLoans.length;

  /// Total outstanding liability from borrowed money.
  double get totalBorrowedLiability {
    return _loanRecords
        .where((l) => l.loanType == 'borrowed' && !l.isPaid)
        .fold(0.0, (sum, l) => sum + l.remainingAmount);
  }

  /// Aggregated loan portfolio summary via pure domain use case.
  LoanSummary get loanSummary =>
      _calculateLoanProgressUseCase.calculateSummary(_loanRecords);

  /// Applies loan repayment via pure domain use case.
  LoanRepaymentResult applyLoanRepayment(LoanRecord loan, double amount) =>
      _processLoanRepaymentUseCase.applyRepayment(
          loan: loan, paymentAmount: amount);

  // ── Tab Index ─────────────────────────────────────────────────────────────

  void setLoanTabIndex(int index) {
    if (_activeLoanTabIndex == index) return;
    _activeLoanTabIndex = index;
    notifyListeners();
  }

  // ── Data Loading ──────────────────────────────────────────────────────────

  Future<void> loadLoans() async {
    _loanRecords = await _repository.getLoans();
    _loanPayments = {};
    for (final loan in _loanRecords) {
      _loanPayments[loan.id!] =
          await _repository.getPaymentsForLoan(loan.id!);
    }
    _pendingRepaymentRequests =
        await _repository.getPendingRepaymentRequests();
    _hiddenLoanIds = await _repository.getHiddenLoanIds();
    notifyListeners();
  }

  /// Refresh statuses for active loans whose due date has passed.
  Future<void> refreshOverdueStatuses() async {
    bool changed = false;
    for (int i = 0; i < _loanRecords.length; i++) {
      final loan = _loanRecords[i];
      if (loan.status == 'active' &&
          DateTime.now().isAfter(loan.dueDate) &&
          !loan.isPaid) {
        final updated = loan.copyWith(status: 'overdue');
        await _repository.updateLoan(updated);
        _loanRecords[i] = updated;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<LoanRecord> createLoan({
    required String loanType,
    required String personName,
    String? trackedSenderName,
    required double principalAmount,
    required DateTime dueDate,
    String? linkedTransactionId,
    String? note,
  }) async {
    // Determine the loan creation date
    DateTime startingDate = DateTime.now();
    if (linkedTransactionId != null && getTransactions != null) {
      final txList = getTransactions!();
      final idx = txList.indexWhere((t) => t.id == linkedTransactionId);
      if (idx != -1) {
        startingDate = txList[idx].date;
      }
    }

    final loan = LoanRecord(
      loanType: loanType,
      personName: personName,
      trackedSenderName: trackedSenderName,
      principalAmount: principalAmount,
      loanDate: startingDate,
      dueDate: dueDate,
      linkedTransactionId: linkedTransactionId,
      note: note,
    );
    final id = await _repository.insertLoan(loan);
    final withId = LoanRecord(
      id: id,
      loanType: loan.loanType,
      personName: loan.personName,
      trackedSenderName: loan.trackedSenderName,
      principalAmount: loan.principalAmount,
      paidAmount: 0,
      loanDate: loan.loanDate,
      dueDate: loan.dueDate,
      linkedTransactionId: loan.linkedTransactionId,
      status: 'active',
      note: loan.note,
    );
    _loanRecords.insert(0, withId);
    _loanPayments[id] = [];

    // Auto-assign the 'Loan' reason to the original triggering transaction
    if (linkedTransactionId != null && updateTransactionReason != null) {
      final reasons = getReasons?.call() ?? [];
      final loanReason = reasons.cast<AppReason?>().firstWhere(
            (r) => r?.name.toLowerCase() == 'loan',
            orElse: () => null,
          );
      await updateTransactionReason!(
        linkedTransactionId,
        reasonId: loanReason?.id,
        customReasonText: loanReason == null ? 'Loan' : null,
      );
    }

    // If the loan is 'lent' and was created in the past, scan memory for
    // historical repayments.
    if (loanType == 'lent' && getTransactions != null && getSenders != null) {
      final txList = getTransactions!();
      final senders = getSenders!();
      final potentialRepayments = txList
          .where((tx) =>
              tx.type == 'income' &&
              tx.date.isAfter(startingDate) &&
              tx.id != linkedTransactionId)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      for (var tx in potentialRepayments) {
        if (trackedSenderName != null && trackedSenderName.trim().isNotEmpty) {
          final watchedChannels = trackedSenderName
              .split(',')
              .map((c) => c.trim().toLowerCase())
              .where((c) => c.isNotEmpty)
              .toList();
          final txSenderLower = tx.sender.trim().toLowerCase();
          final txNameLower = tx.name.trim().toLowerCase();
          final channelMatches = watchedChannels.any((channel) =>
              txSenderLower.contains(channel) ||
              channel.contains(txSenderLower) ||
              txNameLower.contains(channel) ||
              channel.contains(txNameLower));
          if (!channelMatches) continue;
        }

        final candidateName =
            tx.name.trim().isNotEmpty ? tx.name.trim() : tx.sender.trim();
        final isBank = senders.any(
            (s) => s.senderName.toLowerCase() == candidateName.toLowerCase());
        if (isBank && tx.name.trim().isEmpty) continue;

        final score = _nameMatchScore(
          incoming:
              tx.name.trim().isNotEmpty ? tx.name.trim() : candidateName,
          tracked: personName,
        );

        if (score > 0) {
          final currentLoanState =
              _loanRecords.firstWhere((l) => l.id == id);
          if (currentLoanState.status == 'active') {
            await _queueRepaymentRequest(
              loan: currentLoanState,
              tx: tx,
              matchType: score == 2 ? 'exact' : 'partial',
            );
          }
        }
      }

      _pendingRepaymentRequests =
          await _repository.getPendingRepaymentRequests();
    }

    notifyListeners();
    return withId;
  }

  Future<void> deleteLoan(int id) async {
    await _repository.deleteLoan(id);
    _loanRecords.removeWhere((l) => l.id == id);
    _loanPayments.remove(id);
    _hiddenLoanIds.remove(id);
    notifyListeners();
  }

  Future<void> hideLoan(int id) async {
    _hiddenLoanIds = {..._hiddenLoanIds, id};
    await _repository.setHiddenLoanIds(_hiddenLoanIds);
    notifyListeners();
  }

  Future<void> unhideLoan(int id) async {
    _hiddenLoanIds = _hiddenLoanIds.where((e) => e != id).toSet();
    await _repository.setHiddenLoanIds(_hiddenLoanIds);
    notifyListeners();
  }

  Future<void> updateLoan(LoanRecord loan) async {
    await _repository.updateLoan(loan);
    final idx = _loanRecords.indexWhere((l) => l.id == loan.id);
    if (idx != -1) _loanRecords[idx] = loan;
    notifyListeners();
  }

  Future<void> updateLoanDueDate(int loanId, DateTime newDueDate) async {
    final idx = _loanRecords.indexWhere((l) => l.id == loanId);
    if (idx != -1) {
      final oldLoan = _loanRecords[idx];
      String newStatus = oldLoan.status;
      if (oldLoan.status != 'paid') {
        newStatus = DateTime.now().isAfter(newDueDate) ? 'overdue' : 'active';
      }
      final updated = oldLoan.copyWith(dueDate: newDueDate, status: newStatus);
      await _repository.updateLoan(updated);
      _loanRecords[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> recordLoanPayment({
    required int loanId,
    required double amount,
    String? note,
    String? linkedTransactionId,
  }) async {
    final payment = LoanPayment(
      loanId: loanId,
      amount: amount,
      paymentDate: DateTime.now(),
      linkedTransactionId: linkedTransactionId,
      note: note,
    );
    await _repository.insertPayment(payment);
    final updated = await _repository.recalcLoanPaid(loanId);
    if (updated != null) {
      final idx = _loanRecords.indexWhere((l) => l.id == loanId);
      if (idx != -1) _loanRecords[idx] = updated;
      _loanPayments[loanId] =
          await _repository.getPaymentsForLoan(loanId);

      // Add congratulatory or progress notification
      if (addNotification != null) {
        if (updated.isPaid) {
          await addNotification!(
            sender: 'Loan Complete ✅',
            body: updated.loanType == 'lent'
                ? '${updated.personName} has fully repaid ${updated.principalAmount.toStringAsFixed(2)} ETB!'
                : 'You have fully repaid your loan of ${updated.principalAmount.toStringAsFixed(2)} ETB to ${updated.personName}!',
            date: DateTime.now(),
          );
        } else {
          final pct = (updated.progressPercent * 100).toStringAsFixed(0);
          await addNotification!(
            sender: 'Loan Update',
            body: updated.loanType == 'lent'
                ? '${updated.personName} paid ${amount.toStringAsFixed(2)} ETB (↑$pct% of loan complete). ${updated.remainingAmount.toStringAsFixed(2)} ETB remaining.'
                : 'Payment of ${amount.toStringAsFixed(2)} ETB recorded. $pct% of your loan repaid. ${updated.remainingAmount.toStringAsFixed(2)} ETB left.',
            date: DateTime.now(),
          );
        }
      }
    }
    notifyListeners();
  }

  Future<void> deleteLoanPaymentRecord(int paymentId, int loanId) async {
    await _repository.deletePayment(paymentId);
    final updated = await _repository.recalcLoanPaid(loanId);
    if (updated != null) {
      final idx = _loanRecords.indexWhere((l) => l.id == loanId);
      if (idx != -1) _loanRecords[idx] = updated;
      _loanPayments[loanId] =
          await _repository.getPaymentsForLoan(loanId);
    }
    notifyListeners();
  }

  Future<List<LoanPayment>> getPaymentsForLoan(int loanId) async {
    final payments = await _repository.getPaymentsForLoan(loanId);
    _loanPayments[loanId] = payments;
    return payments;
  }

  // ── Repayment Detection & Approval ────────────────────────────────────────

  /// Called when a new income SMS arrives — checks if the sender is tracked
  /// by any active loan and creates a pending approval request.
  Future<void> checkAndApplyLoanRepayment(AppTransaction tx) async {
    if (tx.type != 'income') return;

    final allActive = _loanRecords
        .where((l) => l.status == 'active' && l.loanType == 'lent')
        .toList();

    if (allActive.isEmpty) return;

    final senders = getSenders?.call() ?? [];

    for (final loan in allActive) {
      if (loan.trackedSenderName != null &&
          loan.trackedSenderName!.trim().isNotEmpty) {
        final watchedChannels = loan.trackedSenderName!
            .split(',')
            .map((c) => c.trim().toLowerCase())
            .where((c) => c.isNotEmpty)
            .toList();
        final txSenderLower = tx.sender.trim().toLowerCase();
        final txNameLower = tx.name.trim().toLowerCase();
        final channelMatches = watchedChannels.any((channel) =>
            txSenderLower.contains(channel) ||
            channel.contains(txSenderLower) ||
            txNameLower.contains(channel) ||
            channel.contains(txNameLower));
        if (!channelMatches) continue;
      }

      final candidateName =
          tx.name.trim().isNotEmpty ? tx.name.trim() : tx.sender.trim();
      final isBank = senders.any(
          (s) => s.senderName.toLowerCase() == candidateName.toLowerCase());
      if (isBank && tx.name.trim().isEmpty) continue;

      final best = _nameMatchScore(
        incoming:
            tx.name.trim().isNotEmpty ? tx.name.trim() : candidateName,
        tracked: loan.personName,
      );

      if (best == 0) continue;

      await _queueRepaymentRequest(
        loan: loan,
        tx: tx,
        matchType: best == 2 ? 'exact' : 'partial',
      );
    }
  }

  Future<void> approveLoanRepaymentRequest(LoanRepaymentRequest req) async {
    final loan = await _repository.getLoanById(req.loanId);
    if (loan == null) return;

    await _repository.updateRepaymentRequestStatus(req.id!, 'approved');

    final txList = getTransactions?.call() ?? [];
    final matchTx = txList.where((t) => t.id == req.transactionId).toList();
    if (matchTx.isNotEmpty) {
      await _applyRepayment(loan, matchTx.first);
    } else {
      await recordLoanPayment(
        loanId: loan.id!,
        amount: req.amount,
        linkedTransactionId: req.transactionId,
        note: 'Approved via partial-match (SMS: ${req.senderFound})',
      );
    }

    _pendingRepaymentRequests =
        await _repository.getPendingRepaymentRequests();
    notifyListeners();
  }

  Future<void> rejectLoanRepaymentRequest(LoanRepaymentRequest req) async {
    await _repository.updateRepaymentRequestStatus(req.id!, 'rejected');
    _pendingRepaymentRequests =
        await _repository.getPendingRepaymentRequests();
    notifyListeners();
  }

  // ── Private Helpers ───────────────────────────────────────────────────────

  Future<void> _applyRepayment(LoanRecord loan, AppTransaction tx) async {
    final applicable = tx.amount.clamp(0.0, loan.remainingAmount);
    if (applicable <= 0) return;
    await recordLoanPayment(
      loanId: loan.id!,
      amount: applicable,
      linkedTransactionId: tx.id,
      note: 'Auto-detected from SMS (${tx.name})',
    );

    if (tx.id != null && updateTransactionReason != null) {
      final reasons = getReasons?.call() ?? [];
      final loanReason = reasons.cast<AppReason?>().firstWhere(
            (r) => r?.name.toLowerCase() == 'loan',
            orElse: () => null,
          );
      await updateTransactionReason!(
        tx.id!,
        reasonId: loanReason?.id,
        customReasonText: loanReason == null ? 'Loan Settlement' : null,
      );
    }
  }

  Future<void> _queueRepaymentRequest({
    required LoanRecord loan,
    required AppTransaction tx,
    required String matchType,
  }) async {
    final applicable = tx.amount.clamp(0.0, loan.remainingAmount);
    if (applicable <= 0) return;

    final candidateName =
        tx.name.trim().isNotEmpty ? tx.name.trim() : tx.sender.trim();

    final req = LoanRepaymentRequest(
      loanId: loan.id!,
      transactionId: tx.id ?? '${tx.sender}_${tx.date.millisecondsSinceEpoch}',
      senderFound: candidateName,
      trackedName: loan.personName,
      amount: applicable,
      createdAt: DateTime.now(),
    );
    await _repository.insertRepaymentRequest(req);
    _pendingRepaymentRequests =
        await _repository.getPendingRepaymentRequests();

    if (addNotification != null) {
      final matchLabel =
          matchType == 'exact' ? 'exact match' : 'possible match';
      await addNotification!(
        sender: '⚠️ Loan Match — Approval Needed',
        body: '"$candidateName" sent ${tx.amount.toStringAsFixed(2)} ETB '
            '($matchLabel for borrower "${loan.personName}"). '
            'Go to Loans → Pending to approve or reject.',
        date: DateTime.now(),
      );
    }
    notifyListeners();
  }

  /// Scores how well [incoming] matches [tracked].
  int _nameMatchScore({required String incoming, required String tracked}) {
    if (incoming.trim().isEmpty || tracked.trim().isEmpty) return 0;

    String norm(String s) =>
        s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    final trackedTokens = tracked
        .split(',')
        .map((t) => norm(t))
        .where((t) => t.isNotEmpty)
        .toList();

    final incomingNorm = norm(incoming);
    final incomingWords = incomingNorm.split(' ');
    final incomingFirst = incomingWords.first;

    int best = 0;

    for (final token in trackedTokens) {
      final tokenWords = token.split(' ');
      final tokenFirst = tokenWords.first;

      if (incomingFirst != tokenFirst) continue;

      if (incomingNorm == token ||
          incomingNorm.contains(token) ||
          token.contains(incomingNorm)) {
        return 2;
      }

      if (incomingWords.length >= 2 && tokenWords.length >= 2) {
        if (incomingWords[1] == tokenWords[1]) {
          best = best < 2 ? 2 : best;
          continue;
        }
      }

      if (best < 1) best = 1;
    }

    return best;
  }
}
