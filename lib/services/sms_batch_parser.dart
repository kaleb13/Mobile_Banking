import 'dart:convert';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import '../models/transaction.dart';
import '../models/parsed_sms_result.dart';
import '../models/app_notification.dart';
import '../models/sender.dart';
import 'sms_service.dart';
import 'bank_senders.dart';
import 'telebirr_parser.dart';
import 'cbe_parser.dart';
import 'cbe_birr_parser.dart';
import 'ahadu_parser.dart';
import 'boa_parser.dart';
import 'dashen_parser.dart';

class AutoReasonRule {
  final int id;
  final String name;
  final String sender;
  final String? type;

  const AutoReasonRule({
    required this.id,
    required this.name,
    required this.sender,
    this.type,
  });
}

class BatchParseParams {
  final List<RawSmsData> rawMessages;
  final List<String> pausedBanks;
  final List<AppSender> customSenders;
  final List<AutoReasonRule> autoReasonRules;
  final Map<String, double> initialBankBalances;

  const BatchParseParams({
    required this.rawMessages,
    required this.pausedBanks,
    required this.customSenders,
    required this.autoReasonRules,
    required this.initialBankBalances,
  });
}

class BatchParseResult {
  final List<AppTransaction> transactions;
  final List<AppNotification> unrecognizedNotifications;
  final String? extractedUserName;

  const BatchParseResult({
    required this.transactions,
    required this.unrecognizedNotifications,
    this.extractedUserName,
  });
}

class SmsBatchParser {
  static bool _isAmharicMessage(String text) {
    if (text.isEmpty) return false;
    return RegExp(r'[\u1200-\u137F]').hasMatch(text);
  }

  static bool _isEnglishBankingMessage(String msg) {
    const keywords = [
      'received',
      'sent',
      'send',
      'transferred',
      'transfer',
      'paid',
      'pay',
      'payment',
      'credited',
      'credit',
      'debited',
      'debit',
      'deposited',
      'deposit',
      'withdrawn',
      'withdrawal',
      'withdraw',
      'balance',
      'account',
      'available',
      'remaining',
      'amount',
      'total',
      'birr',
      'etb',
      'usd',
      'loan',
      'repay',
      'due',
      'transaction',
      'txn',
      'ref no',
      'reference',
      'purchase',
      'charged',
      'fee',
      'bank',
      'wallet',
      'mobile money',
      'telebirr',
      'cbe',
      'ahadu',
    ];

    final lower = msg.toLowerCase();
    return keywords.any((kw) => lower.contains(kw));
  }

  /// Spawns a background isolate to parse a large list of SMS messages.
  static Future<BatchParseResult> parseInIsolate(BatchParseParams params) async {
    return await Isolate.run(() => _parseInternal(params));
  }

  /// Synchronous batch parsing logic.
  static BatchParseResult parseSync(BatchParseParams params) => _parseInternal(params);

  /// Synchronous internal batch parsing logic run entirely inside the isolate.
  static BatchParseResult _parseInternal(BatchParseParams params) {
    final List<AppTransaction> parsedTransactions = [];
    final List<AppNotification> unrecognizedNotifications = [];
    final Set<String> seenTxIds = {};
    String? extractedUserName;

    // Fast O(1) lookup map for auto-reason rules
    final Map<String, AutoReasonRule> ruleLookup = {};
    for (final rule in params.autoReasonRules) {
      final sKey = rule.sender.toLowerCase().trim();
      final tKey = rule.type?.toLowerCase().trim();
      if (tKey != null && tKey.isNotEmpty) {
        ruleLookup['${sKey}_$tKey'] = rule;
      } else {
        ruleLookup[sKey] = rule;
      }
    }

    final Set<String> pausedSet = params.pausedBanks
        .map((b) => b.toUpperCase())
        .toSet();

    final Map<String, double> runningBalances = Map.from(params.initialBankBalances);

    // Sort chronologically (oldest first) so running balances update correctly
    final messages = List<RawSmsData>.from(params.rawMessages)
      ..sort((a, b) => a.date.compareTo(b.date));

    for (final msg in messages) {
      final sender = msg.sender.trim();
      final body = msg.body.trim();
      final date = msg.date;

      if (_isAmharicMessage(body)) continue;
      if (BankSenders.isIgnoredMessage(body)) continue;
      if (!_isEnglishBankingMessage(body)) continue;

      // Extract user owner name if not yet found
      extractedUserName ??= CbeParser.extractOwnerName(body) ??
          AhaduParser.extractOwnerName(body) ??
          BoaParser.extractOwnerName(body) ??
          DashenParser.extractOwnerName(body);

      final bank = BankSenders.match(sender);

      if (bank != null && pausedSet.contains(bank.toUpperCase())) {
        continue; // Paused bank
      }

      ParsedSmsResult? parsed;

      if (bank == 'Telebirr') {
        parsed = TelebirrParser.parse(body, date);
      } else if (bank == 'CBE') {
        parsed = CbeParser.parse(body, date);
        if (parsed == null && body.toLowerCase().contains('br.')) {
          parsed = CbeBirrParser.parse(body, date);
        }
      } else if (bank == 'CBE Birr') {
        parsed = CbeBirrParser.parse(body, date);
      } else if (bank == 'Ahadu Bank') {
        parsed = AhaduParser.parse(body, date);
      } else if (bank == 'BOA') {
        parsed = BoaParser.parse(body, date);
      } else if (bank == 'Dashen Bank') {
        parsed = DashenParser.parse(body, date);
      } else {
        // Custom sender check
        final customSender = params.customSenders.firstWhere(
          (s) => s.senderName.toLowerCase() == sender.toLowerCase(),
          orElse: () => AppSender(senderName: ''),
        );
        if (customSender.senderName.isNotEmpty) {
          parsed = _parseCustomSender(customSender, body, date);
        }
      }

      if (parsed != null) {
        // Compute running balance if totalBalance is 0
        final bankKey = '${parsed.bankName}:${msg.simSlot}';
        final currentBal = runningBalances[bankKey] ?? runningBalances[parsed.bankName] ?? 0.0;
        double effectiveBal = parsed.totalBalance;
        if (effectiveBal == 0) {
          final newBal = parsed.type == 'income'
              ? (currentBal + parsed.amount)
              : (currentBal - parsed.amount);
          effectiveBal = newBal > 0 ? newBal : 0.0;
          runningBalances[bankKey] = effectiveBal;
        } else {
          runningBalances[bankKey] = effectiveBal;
        }

        int? resolvedReasonId;
        String? resolvedReasonName;

        // Apply reason linking based on pattern or counterparty
        if (parsed.isSystemLocked) {
          final lockedName = parsed.lockedReasonName;
          if (lockedName != null) {
            resolvedReasonName = lockedName;
            try {
              final matched = params.autoReasonRules.firstWhere(
                (r) => r.name.toLowerCase().trim() == lockedName.toLowerCase().trim(),
              );
              resolvedReasonId = matched.id;
            } catch (_) {}
          }
        } else {
          final sKey = parsed.counterparty.toLowerCase().trim();
          final tKey = parsed.type.toLowerCase().trim();
          final matchedRule = ruleLookup['${sKey}_$tKey'] ?? ruleLookup[sKey];
          if (matchedRule != null) {
            resolvedReasonId = matchedRule.id;
            resolvedReasonName = matchedRule.name;
          }
        }

        final tx = AppTransaction.fromParsedResult(
          parsed,
          reasonId: resolvedReasonId,
          reason: resolvedReasonName,
          simSlot: msg.simSlot,
          accountIdentifier: msg.accountIdentifier,
        ).copyWith(totalBalance: effectiveBal);

        final txId = tx.id ?? '${tx.name}_${tx.date.millisecondsSinceEpoch}_${tx.amount}';
        if (seenTxIds.add(txId)) {
          parsedTransactions.add(tx);
        }
      } else if (bank != null) {
        // Unrecognized banking SMS -> save to notifications
        final bodyNorm = body.replaceAll(RegExp(r'\s+'), ' ').trim();
        final bodyHash = sha256.convert(utf8.encode(bodyNorm)).toString();
        unrecognizedNotifications.add(
          AppNotification(
            id: bodyHash,
            sender: sender,
            body: body,
            date: date,
            isRead: false,
          ),
        );
      }
    }

    // ── High-speed Auto-Pairing & Locking for Dual-SIM Internal Transfers ──
    int? internalTransferReasonId;
    try {
      final itRule = params.autoReasonRules.firstWhere(
        (r) => r.name.toLowerCase().trim() == 'internal transfer',
      );
      internalTransferReasonId = itRule.id;
    } catch (_) {}

    final Map<String, List<int>> refIndex = {};
    for (int i = 0; i < parsedTransactions.length; i++) {
      final tx = parsedTransactions[i];
      final ref = tx.bankReference?.trim().toUpperCase();
      if (ref != null && ref.isNotEmpty && ref.length >= 4) {
        final key = '${tx.name.toUpperCase()}_${ref}_${tx.amount.toStringAsFixed(2)}';
        refIndex.putIfAbsent(key, () => []).add(i);
      }
    }

    for (final indices in refIndex.values) {
      if (indices.length >= 2) {
        final expIdx = indices.where((i) => parsedTransactions[i].type == 'expense').firstOrNull;
        final incIdx = indices.where((i) => parsedTransactions[i].type == 'income').firstOrNull;
        if (expIdx != null && incIdx != null && expIdx != incIdx) {
          final expTx = parsedTransactions[expIdx];
          final incTx = parsedTransactions[incIdx];

          parsedTransactions[expIdx] = expTx.copyWith(
            reason: 'Internal Transfer',
            reasonId: internalTransferReasonId,
            linkedTransactionId: incTx.id,
          );
          parsedTransactions[incIdx] = incTx.copyWith(
            reason: 'Internal Transfer',
            reasonId: internalTransferReasonId,
            linkedTransactionId: expTx.id,
          );
        }
      }
    }

    return BatchParseResult(
      transactions: parsedTransactions,
      unrecognizedNotifications: unrecognizedNotifications,
      extractedUserName: extractedUserName,
    );
  }

  static ParsedSmsResult? _parseCustomSender(
    AppSender sender,
    String body,
    DateTime date,
  ) {
    final lower = body.toLowerCase();
    String? type;

    if (lower.contains('received') ||
        lower.contains('credited') ||
        lower.contains('deposit')) {
      type = 'income';
    } else if (lower.contains('sent') ||
        lower.contains('debited') ||
        lower.contains('paid') ||
        lower.contains('transferred')) {
      type = 'expense';
    }

    if (type == null) return null;

    final amount = SmsService.extractAmount(body);
    if (amount <= 0) return null;

    final id = sha256.convert(utf8.encode('${sender.senderName}|${date.millisecondsSinceEpoch}|$body')).toString();

    return ParsedSmsResult(
      id: id,
      bankName: sender.senderName,
      amount: amount,
      type: type,
      date: date,
      counterparty: sender.senderName,
      totalBalance: 0.0,
      rawMessage: body,
      patternType: SmsPatternType.standardTransfer,
    );
  }
}
