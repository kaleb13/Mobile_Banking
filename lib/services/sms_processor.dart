import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../models/loan_record.dart';
import '../models/sender.dart';
import '../models/app_notification.dart';
import 'database_service.dart';
import 'telebirr_parser.dart';
import 'cbe_parser.dart';
import 'cbe_birr_parser.dart';
import 'ahadu_parser.dart';
import 'boa_parser.dart';
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

  // Ignore password, PIN, OTP, and security authentication messages completely
  if (BankSenders.isSecurityOrAuthMessage(body)) return;

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
  AppTransaction? tx;
  if (bank == 'Telebirr') {
    // ── Credit disbursement (loan taken from Telebirr) ─────────────────────
    if (TelebirrParser.isCreditDisbursement(body)) {
      tx = await _handleTelebirrCreditDisbursement(body, date);
    }
    // ── Credit repayment (loan paid back) ─────────────────────────────────
    else if (TelebirrParser.isCreditRepayment(body)) {
      tx = await _handleTelebirrCreditRepayment(body, date);
    }
    // ── Normal Telebirr transaction ────────────────────────────────────────
    else {
      tx = TelebirrParser.parse(body, date);
    }
  } else if (bank == 'CBE Birr') {
    tx = CbeBirrParser.parse(body, date);
  } else if (bank == 'CBE') {
    tx = CbeParser.parse(body, date);
    // Fallback: some CBE Birr ATM messages arrive with sender ID "CBE"
    if (tx == null && body.toLowerCase().contains('br.')) {
      tx = CbeBirrParser.parse(body, date);
    }
  } else if (bank == 'Ahadu Bank') {
    tx = AhaduParser.parse(body, date);
  } else if (bank == 'BOA') {
    tx = BoaParser.parse(body, date);
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
      bool hasDeposit = matchedSender.depositKeywords
          .any((kw) => lowerMsg.contains(kw.toLowerCase()));
      bool hasExpense = matchedSender.expenseKeywords
          .any((kw) => lowerMsg.contains(kw.toLowerCase()));

      final amountMatch = RegExp(r'[0-9.,]+').firstMatch(body);
      double amount = 0;
      if (amountMatch != null) {
        amount = double.tryParse(amountMatch.group(0)!.replaceAll(',', '')) ?? 0;
      }

      if (hasDeposit && !hasExpense) {
        tx = AppTransaction(
          id: sha256.convert(utf8.encode('$senderAddress|${date.millisecondsSinceEpoch}|$body')).toString(),
          name: matchedSender.senderName,
          amount: amount,
          type: 'income',
          date: date,
          sender: senderAddress,
          category: 'Auto',
          rawMessage: body,
          isAutoDetected: true,
        );
      } else if (hasExpense && !hasDeposit) {
        tx = AppTransaction(
          id: sha256.convert(utf8.encode('$senderAddress|${date.millisecondsSinceEpoch}|$body')).toString(),
          name: matchedSender.senderName,
          amount: amount,
          type: 'expense',
          date: date,
          sender: senderAddress,
          category: 'Auto',
          rawMessage: body,
          isAutoDetected: true,
        );
      }
    }
  }

  // 2. If the message was parsed into an auto-detected transaction, insert it into
  // transactions and do NOT pollute the unregistered notifications list.
  if (tx != null) {
    String? resolvedReasonName;
    int? resolvedReasonId;

    if (initialReason != null && initialReason.isNotEmpty) {
      final reasons = await DatabaseService.instance.getReasons();
      final matchedReason = reasons.cast<dynamic>().firstWhere(
        (r) => (r.name as String).toLowerCase() == initialReason.toLowerCase(),
        orElse: () => null,
      );
      resolvedReasonName = matchedReason?.name as String? ?? initialReason;
      resolvedReasonId = matchedReason?.id as int?;
      tx = tx.copyWith(
        reason: resolvedReasonName,
        reasonId: resolvedReasonId,
      );
    }

    final insertResult = await DatabaseService.instance.insertTransaction(tx);

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
  final notification = AppNotification(
    id: notificationId,
    sender: bank ?? senderAddress,
    body: body,
    date: date,
  );
  await DatabaseService.instance.insertNotification(notification);
}

// ─────────────────────────────────────────────────────────────────────────────
// Telebirr Credit Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Handles a Telebirr credit DISBURSEMENT SMS:
/// - Parses contract number, amount, fee, due date
/// - Creates an AppTransaction (income, reason=Loan, locked)
/// - Auto-creates a LoanRecord in the 'borrowed' tab
Future<AppTransaction?> _handleTelebirrCreditDisbursement(
    String body, DateTime date) async {
  final info = TelebirrParser.parseCreditDisbursement(body, date);
  if (info == null) return null;

  // Resolve the 'Loan' reason ID from the DB
  final db = DatabaseService.instance;
  final reasons = await db.getReasons();
  final loanReason = reasons.cast<dynamic>().firstWhere(
      (r) => (r.name as String).toLowerCase() == 'loan',
      orElse: () => null);

  // Build a unique transaction ID from the contract number
  final txId = 'TBI_CREDIT_${info.contractNumber}';

  // Build note string
  final noteLines = <String>[
    'Telebirr Credit — Contract: ${info.contractNumber}',
    'Facilitation fee: ETB ${info.facilitationFee.toStringAsFixed(2)}',
    if (info.availableCreditLimit != null)
      'Available credit limit: ETB ${info.availableCreditLimit!.toStringAsFixed(2)}',
  ];

  // Create the transaction (income — money received into wallet)
  final tx = AppTransaction(
    id: txId,
    name: TelebirrParser.senderName,
    amount: info.creditAmount,
    type: 'income',
    date: date,
    sender: 'Ethio Telecom / CBE',
    category: 'Auto',
    rawMessage: body,
    isAutoDetected: true,
    reasonId: loanReason?.id as int?,
    reason: loanReason?.name as String? ?? 'Loan',
    totalBalance: 0.0,
  );

  // Insert transaction (ignore if duplicate contract)
  await db.insertTransaction(tx);

  // Auto-create the LoanRecord
  final loanNote = noteLines.join('\n');
  final loan = LoanRecord(
    loanType: 'borrowed',
    personName: 'Ethio Telecom / CBE',
    trackedSenderName: 'Telebirr',
    principalAmount: info.creditAmount,
    loanDate: date,
    dueDate: info.dueDate,
    linkedTransactionId: txId,
    status: 'active',
    note: loanNote,
    contractNumber: info.contractNumber,
  );

  // Only insert if no existing active loan with this contract number
  final existingLoans = await db.getLoanRecords();
  final alreadyExists = existingLoans.any(
      (l) => l.contractNumber == info.contractNumber && l.status == 'active');
  if (!alreadyExists) {
    await db.insertLoanRecord(loan);
  }

  return tx;
}

/// Handles a Telebirr credit REPAYMENT SMS:
/// - Parses paid amount and outstanding balance
/// - Creates an AppTransaction (expense, reason=Loan, locked)
/// - Applies payment to the oldest active Telebirr credit loan
/// - Moves loan to Settled if totalOutstanding == 0
Future<AppTransaction?> _handleTelebirrCreditRepayment(
    String body, DateTime date) async {
  final info = TelebirrParser.parseCreditRepayment(body, date);
  if (info == null || info.paidAmount <= 0) return null;

  // Resolve the 'Loan' reason ID from the DB
  final db = DatabaseService.instance;
  final reasons = await db.getReasons();
  final loanReason = reasons.cast<dynamic>().firstWhere(
      (r) => (r.name as String).toLowerCase() == 'loan',
      orElse: () => null);

  // Build unique transaction ID
  final txId = 'TBI_REPAY_${date.millisecondsSinceEpoch}';

  // Create expense transaction (money left wallet)
  final tx = AppTransaction(
    id: txId,
    name: TelebirrParser.senderName,
    amount: info.paidAmount,
    type: 'expense',
    date: date,
    sender: 'Ethio Telecom / CBE',
    category: 'Auto',
    rawMessage: body,
    isAutoDetected: true,
    reasonId: loanReason?.id as int?,
    reason: loanReason?.name as String? ?? 'Loan',
    totalBalance: 0.0,
  );

  await db.insertTransaction(tx);

  // Find the oldest active Telebirr credit loan and apply the repayment
  final activeLoan = await db.findActiveTelebirrCreditLoan();
  if (activeLoan != null && activeLoan.id != null) {
    await db.applyTelebirrRepayment(
      loanId: activeLoan.id!,
      paidAmount: info.paidAmount,
      totalOutstanding: info.totalOutstanding,
      linkedTransactionId: txId,
    );
  }

  return tx;
}
