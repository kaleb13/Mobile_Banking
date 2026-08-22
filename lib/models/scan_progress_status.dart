class ScannedBankProgress {
  final String bankName;
  final int transactionCount;
  final double? latestBalance;

  const ScannedBankProgress({
    required this.bankName,
    required this.transactionCount,
    this.latestBalance,
  });
}

class ScanProgressStatus {
  final double progress;
  final String stage;
  final List<ScannedBankProgress> scannedBanks;
  final bool isComplete;

  const ScanProgressStatus({
    required this.progress,
    required this.stage,
    this.scannedBanks = const [],
    this.isComplete = false,
  });

  const ScanProgressStatus.idle()
      : progress = 0.0,
        stage = '',
        scannedBanks = const [],
        isComplete = false;
}
