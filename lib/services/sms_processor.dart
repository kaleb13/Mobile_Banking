import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../models/parsed_sms_result.dart';
import '../models/sender.dart';
import '../models/app_notification.dart';
import 'database_service.dart';
import 'telebirr_parser.dart';
import 'cbe_parser.dart';
import 'cbe_birr_parser.dart';
import 'ahadu_parser.dart';
import 'boa_parser.dart';
import 'dashen_parser.dart';
import 'bank_senders.dart';

/// Returns true if [msg] looks like a banking message (contains an English
/// banking keyword). Bilingual messages that mix Amharic with English
/// transaction text (e.g. CBE Birr) are kept — only messages with no English
/// banking keyword at all are dropped.
bool _isEnglishBankingMessage(String msg) {
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

bool _isAmharicMessage(String text) {
  if (text.isEmpty) return false;
  return RegExp(r'[\u1200-\u137F]').hasMatch(text);
}

Future<void> processSmsRaw({
  required String senderAddress,
  required String body,
  required DateTime date,
  String? initialReason,
}) async {
  // ── Global Active SMS Listening Guard ──────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  final isSmsListeningEnabled = prefs.getBool('is_sms_listening_enabled') ?? true;
  if (!isSmsListeningEnabled) {
    return; // User turned off active real-time SMS listening in Settings
  }
  // ── Sender Allowlist Guard (first and most important gate) ────────────────
  // Only process messages from:
  //   1. Known registered bank senders (CBE, Telebirr, CBE Birr, Ahadu Bank)
  //   2. User-added custom senders from the DB
  // Any message from a personal contact or unknown address is dropped silently here,
  // preventing unrelated personal messages from ever appearing in notifications.
  final bank = BankSenders.match(senderAddress);
  if (bank == null) {
    final senders = await DatabaseService.instance.getSenders();
    final isCustomSender = senders.any(
      (s) => s.senderName.toLowerCase() == senderAddress.toLowerCase(),
    );
    if (!isCustomSender) {
      return; // Not a registered or custom sender — drop silently
    }
  }

  // Ignore Amharic messages completely
  if (_isAmharicMessage(body)) return;

  // Ignore password, PIN, OTP, loans, marketing, and non-transactional messages completely
  if (BankSenders.isIgnoredMessage(body)) return;

  // Ignore non-English banking messages entirely
  if (!_isEnglishBankingMessage(body)) return;

  // If the matched bank is paused, do not process the message.
  if (bank != null) {
    final pausedBanks = await DatabaseService.instance.getPausedBanks();
    if (pausedBanks.any((b) => b.toUpperCase() == bank.toUpperCase())) {
      return; // Silently skip — tracking is paused for this bank
    }
  }


  // 1. Try to parse transaction if matched
  ParsedSmsResult? parsedResult;
  if (bank == 'Telebirr') {
    parsedResult = TelebirrParser.parse(body, date);
    if (TelebirrParser.isSavingsMessage(body)) {
      final savingBal = TelebirrParser.extractSavingBalance(body);
      if (savingBal != null) {
        await DatabaseService.instance
            .setAppSetting('telebirr_saving_balance', savingBal.toString());
      }
    }
  } else if (bank == 'CBE Birr') {
    parsedResult = CbeBirrParser.parse(body, date);
  } else if (bank == 'CBE') {
    parsedResult = CbeParser.parse(body, date);
    // Fallback: some CBE Birr ATM messages arrive with sender ID "CBE"
    if (parsedResult == null && body.toLowerCase().contains('br.')) {
      parsedResult = CbeBirrParser.parse(body, date);
    }
  } else if (bank == 'Ahadu Bank') {
    parsedResult = AhaduParser.parse(body, date);
  } else if (bank == 'BOA') {
    parsedResult = BoaParser.parse(body, date);
  } else if (bank == 'Dashen Bank') {
    parsedResult = DashenParser.parse(body, date);
  } else {
    // Custom Senders matching
    final senders = await DatabaseService.instance.getSenders();
    AppSender? matchedSender;
    try {
      matchedSender = senders.firstWhere(
          (s) => s.senderName.toLowerCase() == senderAddress.toLowerCase());
    } catch (_) {}

    if (matchedSender != null) {
      final lowerMsg = body.toLowerCase();
      bool hasDeposit = lowerMsg.contains('received') ||
          lowerMsg.contains('credited') ||
          lowerMsg.contains('deposit');
      bool hasExpense = lowerMsg.contains('sent') ||
          lowerMsg.contains('debited') ||
          lowerMsg.contains('paid') ||
          lowerMsg.contains('transferred');

      final amountMatch = RegExp(r'[0-9.,]+').firstMatch(body);
      double amount = 0;
      if (amountMatch != null) {
        amount = double.tryParse(amountMatch.group(0)!.replaceAll(',', '')) ?? 0;
      }

      if (hasDeposit && !hasExpense) {
        parsedResult = ParsedSmsResult(
          id: sha256.convert(utf8.encode('$senderAddress|${date.millisecondsSinceEpoch}|$body')).toString(),
          bankName: matchedSender.senderName,
          amount: amount,
          type: 'income',
          date: date,
          counterparty: senderAddress,
          totalBalance: 0.0,
          rawMessage: body,
        );
      } else if (hasExpense && !hasDeposit) {
        parsedResult = ParsedSmsResult(
          id: sha256.convert(utf8.encode('$senderAddress|${date.millisecondsSinceEpoch}|$body')).toString(),
          bankName: matchedSender.senderName,
          amount: amount,
          type: 'expense',
          date: date,
          counterparty: senderAddress,
          totalBalance: 0.0,
          rawMessage: body,
        );
      }
    }
  }

  // 2. If the message was parsed into an auto-detected transaction, insert it into
  // transactions and do NOT pollute the unregistered notifications list.
  if (parsedResult != null) {
    String? resolvedReasonName;
    int? resolvedReasonId;

    final reasons = await DatabaseService.instance.getReasons();

    if (initialReason != null && initialReason.isNotEmpty) {
      final matchedReason = reasons.cast<dynamic>().firstWhere(
        (r) => (r.name as String).toLowerCase() == initialReason.toLowerCase(),
        orElse: () => null,
      );
      resolvedReasonName = matchedReason?.name as String? ?? initialReason;
      resolvedReasonId = matchedReason?.id as int?;
    } else if (parsedResult.isSystemLocked) {
      final lockedName = parsedResult.lockedReasonName;
      if (lockedName != null) {
        final matchedReason = reasons.cast<dynamic>().firstWhere(
          (r) => (r.name as String).toLowerCase() == lockedName.toLowerCase(),
          orElse: () => null,
        );
        resolvedReasonName = matchedReason?.name as String? ?? lockedName;
        resolvedReasonId = matchedReason?.id as int?;
      }
    } else {
      final autoReason = await DatabaseService.instance.findAutoReason(parsedResult.counterparty, parsedResult.type);
      if (autoReason != null) {
        resolvedReasonName = autoReason.name;
        resolvedReasonId = autoReason.id;
      }
    }

    String? linkedTxId;

    // Check if this incoming transaction matches an existing counterpart (Dual-SIM Internal Transfer)
    final refCode = parsedResult.id;
    if (refCode.isNotEmpty && refCode.length >= 4) {
      final existingMatches = await DatabaseService.instance.getTransactionsByBankReference(refCode);
      final counterpart = existingMatches.where(
        (t) => t.amount == parsedResult!.amount && t.type != parsedResult!.type,
      ).firstOrNull;

      if (counterpart != null) {
        final itReason = reasons.cast<dynamic>().where(
          (r) => (r.name as String).toLowerCase() == 'internal transfer',
        ).firstOrNull;
        resolvedReasonName = 'Internal Transfer';
        resolvedReasonId = itReason?.id as int?;
        linkedTxId = counterpart.id;
      }
    }

    final tx = AppTransaction.fromParsedResult(
      parsedResult,
      reason: resolvedReasonName,
      reasonId: resolvedReasonId,
      linkedTransactionId: linkedTxId,
      customReasonText: null,
      note: null,
    );

    final insertResult = await DatabaseService.instance.insertTransaction(tx);

    // If counterpart existed, update its linkedTransactionId to this newly inserted tx
    if (linkedTxId != null && tx.id != null) {
      final existingMatches = await DatabaseService.instance.getTransactionsByBankReference(refCode);
      final counterpart = existingMatches.where((t) => t.id == linkedTxId).firstOrNull;
      if (counterpart != null) {
        await DatabaseService.instance.updateTransaction(
          counterpart.copyWith(
            reason: 'Internal Transfer',
            reasonId: resolvedReasonId,
            linkedTransactionId: tx.id,
          ),
        );
      }
    }

    // INSERT OR IGNORE returns 0 if the transaction already existed.
    // If we have a reason to attach, UPDATE the existing row's reason.
    if (insertResult == 0 &&
        resolvedReasonName != null &&
        tx.id != null) {
      await DatabaseService.instance.updateTransactionReason(
        tx.id!,
        resolvedReasonName,
        resolvedReasonId,
      );
    }

    return;
  }

  // 3. ONLY if the message was NOT parsed (tx == null), insert an In-App Notification
  // so it appears in the top Notification Panel as an UNREGISTERED message for manual setup!
  final notificationId = sha256.convert(utf8.encode('$senderAddress|${date.millisecondsSinceEpoch}|$body')).toString();
  final ignored = prefs.getStringList('ignored_notification_ids') ?? [];
  if (ignored.contains(notificationId)) return;

  final notification = AppNotification(
    id: notificationId,
    sender: bank ?? senderAddress,
    body: body,
    date: date,
  );
  await DatabaseService.instance.insertNotification(notification);
}
