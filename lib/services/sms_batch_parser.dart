import 'dart:convert';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import '../models/transaction.dart';
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

  /// Parses a batch of SMS messages inside a dedicated background [Isolate].
  static Future<BatchParseResult> parseInIsolate(BatchParseParams params) async {
    return await Isolate.run(() => _executeParse(params));
  }

  static BatchParseResult _executeParse(BatchParseParams params) {
    final List<AppTransaction> parsedTransactions = [];
    final Set<String> seenTxIds = {};
    final List<AppNotification> unrecognizedNotifications = [];
    String? extractedUserName;

    // Track running balances per bank during parsing
    final Map<String, double> runningBalances = Map.from(params.initialBankBalances);

    // Build quick lookup for auto reason rules: key = "${sender.toLowerCase()}_${type.toLowerCase()}"
    final Map<String, AutoReasonRule> ruleLookup = {};
    for (final rule in params.autoReasonRules) {
      final s = rule.sender.toLowerCase().trim();
      final t = rule.type?.toLowerCase().trim();
      if (t != null && t.isNotEmpty) {
        ruleLookup['${s}_$t'] = rule;
      }
      ruleLookup[s] = rule; // generic fallback
    }

    final pausedSet = params.pausedBanks.map((b) => b.toUpperCase()).toSet();

    // Sort chronologically (oldest first) so running balances update correctly
    final messages = List<RawSmsData>.from(params.rawMessages)
      ..sort((a, b) => a.date.compareTo(b.date));

    for (final msg in messages) {
      final sender = msg.sender.trim();
      final body = msg.body.trim();
      final date = msg.date;

      if (_isAmharicMessage(body)) continue;
      if (BankSenders.isSecurityOrAuthMessage(body)) continue;
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

      AppTransaction? tx;

      if (bank == 'Telebirr') {
        tx = TelebirrParser.parse(body, date);
      } else if (bank == 'CBE') {
        tx = CbeParser.parse(body, date);
        if (tx == null && body.toLowerCase().contains('br.')) {
          tx = CbeBirrParser.parse(body, date);
        }
      } else if (bank == 'CBE Birr') {
        tx = CbeBirrParser.parse(body, date);
      } else if (bank == 'Ahadu Bank') {
        tx = AhaduParser.parse(body, date);
      } else if (bank == 'BOA') {
        tx = BoaParser.parse(body, date);
      } else if (bank == 'Dashen Bank') {
        tx = DashenParser.parse(body, date);
      } else {
        // Custom sender check
        final customSender = params.customSenders.firstWhere(
          (s) => s.senderName.toLowerCase() == sender.toLowerCase(),
          orElse: () => AppSender(senderName: ''),
        );
        if (customSender.senderName.isNotEmpty) {
          tx = _parseCustomSender(customSender, body, date);
        }
      }

      if (tx != null) {
        // Compute running balance if totalBalance is 0
        final bankKey = tx.name;
        final currentBal = runningBalances[bankKey] ?? 0.0;
        if (tx.totalBalance == 0) {
          final newBal = tx.type == 'income'
              ? (currentBal + tx.amount)
              : (currentBal - tx.amount);
          final finalBal = newBal > 0 ? newBal : 0.0;
          tx = tx.copyWith(totalBalance: finalBal);
          runningBalances[bankKey] = finalBal;
        } else {
          runningBalances[bankKey] = tx.totalBalance;
        }

        AppTransaction currentTx = tx;
        // Apply auto-reason categorization rules
        if (currentTx.reason != null && currentTx.reasonId == null) {
          final rName = currentTx.reason!.toLowerCase().trim();
          try {
            final matched = params.autoReasonRules.firstWhere(
              (r) => r.name.toLowerCase().trim() == rName,
            );
            currentTx = currentTx.copyWith(
              reasonId: matched.id,
              reason: matched.name,
            );
          } catch (_) {}
        } else if (currentTx.reasonId == null && currentTx.customReasonText == null) {
          final sKey = currentTx.sender.toLowerCase().trim();
          final tKey = currentTx.type.toLowerCase().trim();
          final matchedRule = ruleLookup['${sKey}_$tKey'] ?? ruleLookup[sKey];
          if (matchedRule != null) {
            currentTx = currentTx.copyWith(
              reasonId: matchedRule.id,
              reason: matchedRule.name,
            );
          }
        }

        final txId = currentTx.id ?? '${currentTx.name}_${currentTx.date.millisecondsSinceEpoch}_${currentTx.amount}';
        if (seenTxIds.add(txId)) {
          parsedTransactions.add(currentTx);
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

    return BatchParseResult(
      transactions: parsedTransactions,
      unrecognizedNotifications: unrecognizedNotifications,
      extractedUserName: extractedUserName,
    );
  }

  static AppTransaction? _parseCustomSender(
    AppSender sender,
    String body,
    DateTime date,
  ) {
    final lower = body.toLowerCase();
    String? type;

    if (sender.depositKeywords.isNotEmpty) {
      final kws = sender.depositKeywords.map((k) => k.trim().toLowerCase());
      if (kws.any((k) => k.isNotEmpty && lower.contains(k))) {
        type = 'income';
      }
    }

    if (type == null && sender.expenseKeywords.isNotEmpty) {
      final kws = sender.expenseKeywords.map((k) => k.trim().toLowerCase());
      if (kws.any((k) => k.isNotEmpty && lower.contains(k))) {
        type = 'expense';
      }
    }

    if (type == null) {
      // Default keyword heuristics
      if (lower.contains('received') || lower.contains('credited') || lower.contains('deposit')) {
        type = 'income';
      } else if (lower.contains('sent') || lower.contains('debited') || lower.contains('paid') || lower.contains('transferred')) {
        type = 'expense';
      }
    }

    if (type == null) return null;

    final amount = SmsService.extractAmount(body);
    if (amount <= 0) return null;

    return AppTransaction(
      id: sha256.convert(utf8.encode('${sender.senderName}_${date.millisecondsSinceEpoch}_$amount')).toString(),
      name: sender.senderName,
      amount: amount,
      type: type,
      date: date,
      sender: sender.senderName,
      category: 'General',
      rawMessage: body,
      isAutoDetected: true,
      totalBalance: 0.0,
    );
  }
}
