/// Represents a single loan — either money lent OUT or money borrowed IN.
class LoanRecord {
  final int? id;

  /// 'lent'     → I gave money to someone (they owe me)
  /// 'borrowed' → I received money from someone (I owe them)
  final String loanType;

  /// Full name / identifier of the other party
  final String personName;

  /// Optional: the SMS sender address / bank sender name to watch for repayments.
  /// When an SMS income arrives from this sender, system auto-attributes it.
  final String? trackedSenderName;

  /// Original loan amount
  final double principalAmount;

  /// Sum of confirmed payments so far (recomputed from payments list)
  final double paidAmount;

  /// When the loan was created / given
  final DateTime loanDate;

  /// When full repayment is due
  final DateTime dueDate;

  /// The transaction ID that triggered this loan (optional)
  final String? linkedTransactionId;

  /// 'active' | 'paid' | 'overdue'
  final String status;

  /// Optional note
  final String? note;

  LoanRecord({
    this.id,
    required this.loanType,
    required this.personName,
    this.trackedSenderName,
    required this.principalAmount,
    this.paidAmount = 0.0,
    required this.loanDate,
    required this.dueDate,
    this.linkedTransactionId,
    this.status = 'active',
    this.note,
  });

  double get remainingAmount =>
      (principalAmount - paidAmount).clamp(0, double.infinity);
  double get progressPercent => principalAmount > 0
      ? (paidAmount / principalAmount).clamp(0.0, 1.0)
      : 0.0;
  bool get isPaid => status == 'paid' || paidAmount >= principalAmount;
  bool get isOverdue =>
      status == 'overdue' ||
      (status == 'active' && DateTime.now().isAfter(dueDate) && !isPaid);

  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;
  int get daysOverdue => DateTime.now().difference(dueDate).inDays;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'loanType': loanType,
        'personName': personName,
        'trackedSenderName': trackedSenderName,
        'principalAmount': principalAmount,
        'paidAmount': paidAmount,
        'loanDate': loanDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'linkedTransactionId': linkedTransactionId,
        'status': status,
        'note': note,
      };

  factory LoanRecord.fromMap(Map<String, dynamic> m) => LoanRecord(
        id: m['id'] as int?,
        loanType: m['loanType'] as String,
        personName: m['personName'] as String,
        trackedSenderName: m['trackedSenderName'] as String?,
        principalAmount: (m['principalAmount'] as num).toDouble(),
        paidAmount: (m['paidAmount'] as num? ?? 0).toDouble(),
        loanDate: DateTime.parse(m['loanDate'] as String),
        dueDate: DateTime.parse(m['dueDate'] as String),
        linkedTransactionId: m['linkedTransactionId'] as String?,
        status: m['status'] as String? ?? 'active',
        note: m['note'] as String?,
      );

  LoanRecord copyWith({
    double? paidAmount,
    String? status,
    String? trackedSenderName,
    String? note,
    DateTime? dueDate,
  }) =>
      LoanRecord(
        id: id,
        loanType: loanType,
        personName: personName,
        trackedSenderName: trackedSenderName ?? this.trackedSenderName,
        principalAmount: principalAmount,
        paidAmount: paidAmount ?? this.paidAmount,
        loanDate: loanDate,
        dueDate: dueDate ?? this.dueDate,
        linkedTransactionId: linkedTransactionId,
        status: status ?? this.status,
        note: note ?? this.note,
      );
}

/// Represents a single repayment event against a loan.
class LoanPayment {
  final int? id;
  final int loanId;
  final double amount;
  final DateTime paymentDate;

  /// Optional: the transaction ID that triggered this payment
  final String? linkedTransactionId;
  final String? note;

  LoanPayment({
    this.id,
    required this.loanId,
    required this.amount,
    required this.paymentDate,
    this.linkedTransactionId,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'loanId': loanId,
        'amount': amount,
        'paymentDate': paymentDate.toIso8601String(),
        'linkedTransactionId': linkedTransactionId,
        'note': note,
      };

  factory LoanPayment.fromMap(Map<String, dynamic> m) => LoanPayment(
        id: m['id'] as int?,
        loanId: m['loanId'] as int,
        amount: (m['amount'] as num).toDouble(),
        paymentDate: DateTime.parse(m['paymentDate'] as String),
        linkedTransactionId: m['linkedTransactionId'] as String?,
        note: m['note'] as String?,
      );
}
