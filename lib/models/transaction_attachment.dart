class TransactionAttachment {
  final String id;
  final String transactionId;
  final String filePath;
  final String fileType; // 'image', 'pdf', 'audio'
  final String? fileName;
  final int? fileSize;
  final String createdAt;

  TransactionAttachment({
    required this.id,
    required this.transactionId,
    required this.filePath,
    required this.fileType,
    this.fileName,
    this.fileSize,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transactionId': transactionId,
      'filePath': filePath,
      'fileType': fileType,
      'fileName': fileName,
      'fileSize': fileSize,
      'createdAt': createdAt,
    };
  }

  factory TransactionAttachment.fromMap(Map<String, dynamic> map) {
    return TransactionAttachment(
      id: map['id'] as String,
      transactionId: map['transactionId'] as String,
      filePath: map['filePath'] as String,
      fileType: map['fileType'] as String,
      fileName: map['fileName'] as String?,
      fileSize: map['fileSize'] as int?,
      createdAt: map['createdAt'] as String,
    );
  }
}
