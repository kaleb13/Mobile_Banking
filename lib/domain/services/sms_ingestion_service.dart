import 'package:flutter/foundation.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../models/app_notification.dart';
import '../../models/scan_progress_status.dart';
import '../../models/scan_window_option.dart';
import '../../models/sender.dart';
import '../../services/sms_batch_parser.dart';
import '../../services/sms_service.dart';

class SmsScanResult {
  final int insertedCount;
  final List<ScannedBankProgress> scannedBanks;
  final List<AppSender> updatedSenders;

  const SmsScanResult({
    required this.insertedCount,
    required this.scannedBanks,
    required this.updatedSenders,
  });
}

/// Domain Service encapsulating phone SMS scanning, content-resolver queries,
/// background isolate batch parsing, and batch transaction persistence.
class SmsIngestionService {
  final TransactionRepository _repository;
  final SettingsRepository? _settingsRepository;
  final SmsService _smsService;

  SmsIngestionService({
    required TransactionRepository repository,
    SettingsRepository? settingsRepository,
    SmsService? smsService,
  })  : _repository = repository,
        _settingsRepository = settingsRepository,
        _smsService = smsService ?? SmsService();

  /// Discovers bank senders physically present in the phone's SMS inbox across all time and syncs them to SQLite.
  Future<List<AppSender>> discoverAndSyncPhoneSenders({
    required List<AppSender> currentSenders,
  }) async {
    try {
      final detected = await _smsService.detectBankingSendersInInbox(
        customSenders: currentSenders.map((s) => s.senderName).toList(),
      );
      for (final bankName in detected) {
        await _repository.insertSender(AppSender(senderName: bankName));
      }
      return await _repository.getSenders();
    } catch (_) {
      return currentSenders;
    }
  }

  /// High-speed SMS batch scanner that parses messages within the active scan window in a background isolate.
  Future<SmsScanResult> scanSms({
    ScanWindowOption? scanWindowOption,
    DateTime? since,
    void Function(ScanProgressStatus)? onProgress,
    required List<AppSender> currentSenders,
    required Set<String> pausedBanks,
    required double Function(String bankName) getBalanceForSender,
    Future<void> Function(List<AppNotification>)? insertNotificationsBatch,
  }) async {
    var senders = currentSenders;

    final activeOption = scanWindowOption ??
        await _settingsRepository?.getScanWindow() ??
        ScanWindowOption.allTime;

    onProgress?.call(const ScanProgressStatus(
      progress: 0.05,
      stage: 'Connecting to secure SMS inbox…',
    ));

    // Discover bank senders present on device across all time
    try {
      final detectedPhoneBanks = await _smsService.detectBankingSendersInInbox(
        customSenders: senders.map((s) => s.senderName).toList(),
      );
      for (final bankName in detectedPhoneBanks) {
        await _repository.insertSender(AppSender(senderName: bankName));
      }
      senders = await _repository.getSenders();
    } catch (_) {}

    // Strictly clamp since/anchorDate to never reach beyond active scan window fixed inception date
    DateTime? boundaryAnchor;
    if (activeOption != ScanWindowOption.allTime) {
      boundaryAnchor = (await _settingsRepository?.getEffectiveScanWindowAnchorDate()) ??
          activeOption.anchorDate;
    }
    DateTime? effectiveSince;
    if (since != null) {
      if (boundaryAnchor != null && since.isBefore(boundaryAnchor)) {
        effectiveSince = boundaryAnchor;
      } else {
        effectiveSince = since;
      }
    } else {
      effectiveSince = boundaryAnchor;
    }
    final cutoff = effectiveSince?.subtract(const Duration(minutes: 1));

    final customSenderNames = senders.map((s) => s.senderName).toList();
    final rawMessages = await _smsService.getBankMessagesFast(
      since: cutoff,
      customSenders: customSenderNames,
    );

    if (rawMessages.isEmpty) {
      onProgress?.call(const ScanProgressStatus(
        progress: 1.0,
        stage: 'No banking messages found in window',
        scannedBanks: [],
        isComplete: true,
      ));
      return SmsScanResult(
        insertedCount: 0,
        scannedBanks: const [],
        updatedSenders: senders,
      );
    }

    onProgress?.call(const ScanProgressStatus(
      progress: 0.35,
      stage: 'Reading & analyzing bank records…',
    ));

    final autoRules = await _repository.getAutoReasonRules();
    final initialBalances = <String, double>{};
    for (final s in senders) {
      initialBalances[s.senderName] = getBalanceForSender(s.senderName);
    }

    // Diagnostic logging
    final sim0Raw = rawMessages.where((m) => m.simSlot == 0).length;
    final sim1Raw = rawMessages.where((m) => m.simSlot == 1).length;
    debugPrint('[ShibreSIM-Dart] Raw messages: total=${rawMessages.length} SIM1(slot0)=$sim0Raw SIM2(slot1)=$sim1Raw');

    final parseResult = await SmsBatchParser.parseInIsolate(BatchParseParams(
      rawMessages: rawMessages,
      pausedBanks: pausedBanks.toList(),
      customSenders: senders,
      autoReasonRules: autoRules,
      initialBankBalances: initialBalances,
    ));

    final sim0Parsed = parseResult.transactions.where((t) => t.simSlot == 0).length;
    final sim1Parsed = parseResult.transactions.where((t) => t.simSlot == 1).length;
    debugPrint('[ShibreSIM-Dart] Parsed transactions: total=${parseResult.transactions.length} SIM1(slot0)=$sim0Parsed SIM2(slot1)=$sim1Parsed');

    final Map<String, int> bankCounts = {};
    final Map<String, double> bankLatestBalances = {};
    for (final tx in parseResult.transactions) {
      bankCounts[tx.bankName] = (bankCounts[tx.bankName] ?? 0) + 1;
      if (tx.totalBalance > 0) {
        bankLatestBalances[tx.bankName] = tx.totalBalance;
      }
    }
    final List<ScannedBankProgress> scannedBankList = bankCounts.entries.map((e) {
      return ScannedBankProgress(
        bankName: e.key,
        transactionCount: e.value,
        latestBalance: bankLatestBalances[e.key],
      );
    }).toList();

    onProgress?.call(ScanProgressStatus(
      progress: 0.80,
      stage: 'Storing verified transactions in database…',
      scannedBanks: scannedBankList,
    ));

    final insertedCount = await _repository
        .insertTransactionsBatch(parseResult.transactions);

    await _repository.reconcilePendingNotificationReasons();

    if (parseResult.unrecognizedNotifications.isNotEmpty) {
      await insertNotificationsBatch?.call(
          parseResult.unrecognizedNotifications);
    }

    onProgress?.call(ScanProgressStatus(
      progress: 1.0,
      stage: 'Calculated financial balance & tier',
      scannedBanks: scannedBankList,
      isComplete: true,
    ));

    return SmsScanResult(
      insertedCount: insertedCount,
      scannedBanks: scannedBankList,
      updatedSenders: senders,
    );
  }
}
