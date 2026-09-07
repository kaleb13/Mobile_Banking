/// A pending loan repayment that needs user approval.
/// Created when an SMS sender name partially matches (first two words)
/// the trackedSenderName of an active loan but is not a 100% exact match.
class LoanRepaymentRequest {
  final int? id;

  /// The loan this request is attributed to
  final int loanId;

  /// The SMS transaction ID that triggered this
  final String transactionId;

  /// The counterparty name found in the SMS (e.g. "NAHOM Abreham Hailesilase")
  final String counterpartyFound;

  /// Backward-compatibility alias for [counterpartyFound].
  String get senderFound => counterpartyFound;

  /// The name that was being tracked (e.g. "Nahom Abreham")
  final String trackedName;

  /// The amount from the SMS transaction
  final double amount;

  /// When the SMS arrived
  final DateTime createdAt;

  /// 'pending' | 'approved' | 'rejected'
  final String status;

  LoanRepaymentRequest({
    this.id,
    required this.loanId,
    required this.transactionId,
    String? counterpartyFound,
    String? senderFound,
    required this.trackedName,
    required this.amount,
    required this.createdAt,
    this.status = 'pending',
  }) : counterpartyFound = counterpartyFound ?? senderFound ?? '';

  bool get isPending => status == 'pending';

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'loanId': loanId,
        'transactionId': transactionId,
        'senderFound': counterpartyFound,
        'trackedName': trackedName,
        'amount': amount,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
      };

  factory LoanRepaymentRequest.fromMap(Map<String, dynamic> m) =>
      LoanRepaymentRequest(
        id: m['id'] as int?,
        loanId: m['loanId'] as int,
        transactionId: m['transactionId'] as String,
        counterpartyFound:
            (m['counterpartyFound'] ?? m['senderFound'] ?? '') as String,
        trackedName: m['trackedName'] as String,
        amount: (m['amount'] as num).toDouble(),
        createdAt: DateTime.parse(m['createdAt'] as String),
        status: m['status'] as String? ?? 'pending',
      );

  LoanRepaymentRequest copyWith({
    String? status,
    String? counterpartyFound,
    String? senderFound,
  }) =>
      LoanRepaymentRequest(
        id: id,
        loanId: loanId,
        transactionId: transactionId,
        counterpartyFound:
            counterpartyFound ?? senderFound ?? this.counterpartyFound,
        trackedName: trackedName,
        amount: amount,
        createdAt: createdAt,
        status: status ?? this.status,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoanRepaymentRequest && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
