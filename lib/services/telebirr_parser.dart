import 'bank_senders.dart';
import '../models/transaction.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result types for Telebirr Credit SMS parsing
// ─────────────────────────────────────────────────────────────────────────────

/// Parsed data from a Telebirr credit DISBURSEMENT message.
/// e.g. "Your credit request with DGV0EMRXKY contract number is successful..."
class TelebirrCreditInfo {
  final String contractNumber;
  final double creditAmount;
  final double facilitationFee;
  final DateTime dueDate;
  final double? availableCreditLimit;

  const TelebirrCreditInfo({
    required this.contractNumber,
    required this.creditAmount,
    required this.facilitationFee,
    required this.dueDate,
    this.availableCreditLimit,
  });
}

/// Parsed data from a Telebirr credit REPAYMENT message.
/// e.g. "your outstanding Credit amount has been paid successfully..."
class TelebirrRepaymentInfo {
  final double paidAmount;
  final double totalOutstanding;
  final double monthlyOutstanding;

  const TelebirrRepaymentInfo({
    required this.paidAmount,
    required this.totalOutstanding,
    required this.monthlyOutstanding,
  });

  /// True when the loan is fully settled (no outstanding balance).
  bool get isFullySettled => totalOutstanding <= 0.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// TelebirrParser
// ─────────────────────────────────────────────────────────────────────────────
class TelebirrParser {
  static const String senderNumber = "127";
  static const String senderName = "Telebirr";

  // ── Quick checks ──────────────────────────────────────────────────────────

  /// Returns true if [message] looks like a Telebirr credit DISBURSEMENT SMS.
  static bool isCreditDisbursement(String message) {
    if (BankSenders.isSecurityOrAuthMessage(message)) return false;
    final lower = message.toLowerCase();
    return lower.contains('credit request') &&
        lower.contains('contract number') &&
        (lower.contains('credit amount') || lower.contains('facilitation fee'));
  }

  /// Returns true if [message] looks like a Telebirr credit REPAYMENT SMS.
  static bool isCreditRepayment(String message) {
    if (BankSenders.isSecurityOrAuthMessage(message)) return false;
    final lower = message.toLowerCase();
    return lower.contains('outstanding credit amount') &&
        lower.contains('paid successfully') &&
        lower.contains('paid amount');
  }

  // ── Credit Disbursement Parser ─────────────────────────────────────────────

  /// Parses a Telebirr credit disbursement SMS.
  /// Returns null if the message doesn't match.
  static TelebirrCreditInfo? parseCreditDisbursement(
      String message, DateTime fallbackDate) {
    if (!isCreditDisbursement(message)) return null;

    // Contract number: "with DGV0EMRXKY contract number"
    final contractMatch =
        RegExp(r'with\s+([A-Z0-9]+)\s+contract number', caseSensitive: false)
            .firstMatch(message);
    final contractNumber = contractMatch?.group(1);
    if (contractNumber == null) return null;

    // Credit amount: "credit amount is ETB 500.00"
    final creditMatch =
        RegExp(r'credit amount is ETB\s+([0-9,.]+)', caseSensitive: false)
            .firstMatch(message);
    final creditAmount =
        double.tryParse(creditMatch?.group(1)?.replaceAll(',', '') ?? '') ?? 0;
    if (creditAmount <= 0) return null;

    // Facilitation fee: "facilitation fee ETB 6.25"
    final feeMatch =
        RegExp(r'facilitation fee ETB\s+([0-9,.]+)', caseSensitive: false)
            .firstMatch(message);
    final facilitationFee =
        double.tryParse(feeMatch?.group(1)?.replaceAll(',', '') ?? '') ?? 0.0;

    // Due date: "due date 10/08/2026"
    DateTime dueDate = fallbackDate.add(const Duration(days: 30));
    final dueDateMatch =
        RegExp(r'due date\s+(\d{2}/\d{2}/\d{4})', caseSensitive: false)
            .firstMatch(message);
    if (dueDateMatch != null) {
      try {
        dueDate = DateFormat('dd/MM/yyyy').parse(dueDateMatch.group(1)!);
      } catch (_) {}
    }

    // Available credit limit (optional): "Your current available credit limit ETB400.00"
    double? availableLimit;
    final limitMatch = RegExp(
            r'available credit limit\s+ETB\s*([0-9,.]+)',
            caseSensitive: false)
        .firstMatch(message);
    if (limitMatch != null) {
      availableLimit =
          double.tryParse(limitMatch.group(1)?.replaceAll(',', '') ?? '');
    }

    return TelebirrCreditInfo(
      contractNumber: contractNumber,
      creditAmount: creditAmount,
      facilitationFee: facilitationFee,
      dueDate: dueDate,
      availableCreditLimit: availableLimit,
    );
  }

  // ── Credit Repayment Parser ────────────────────────────────────────────────

  /// Parses a Telebirr credit repayment/settlement SMS.
  /// Returns null if the message doesn't match.
  static TelebirrRepaymentInfo? parseCreditRepayment(
      String message, DateTime fallbackDate) {
    if (!isCreditRepayment(message)) return null;

    // Paid amount: "The paid amount is ETB 509.85"
    final paidMatch =
        RegExp(r'paid amount is ETB\s+([0-9,.]+)', caseSensitive: false)
            .firstMatch(message);
    final paidAmount =
        double.tryParse(paidMatch?.group(1)?.replaceAll(',', '') ?? '') ?? 0.0;

    // Monthly outstanding: "monthly outstanding amount is ETB 0.00"
    final monthlyMatch = RegExp(
            r'monthly outstanding amount is ETB\s+([0-9,.]+)',
            caseSensitive: false)
        .firstMatch(message);
    final monthlyOutstanding =
        double.tryParse(monthlyMatch?.group(1)?.replaceAll(',', '') ?? '') ??
            0.0;

    // Total outstanding: "total outstanding amount is ETB 0.00"
    final totalMatch = RegExp(
            r'total outstanding amount is ETB\s+([0-9,.]+)',
            caseSensitive: false)
        .firstMatch(message);
    final totalOutstanding =
        double.tryParse(totalMatch?.group(1)?.replaceAll(',', '') ?? '') ?? 0.0;

    return TelebirrRepaymentInfo(
      paidAmount: paidAmount,
      totalOutstanding: totalOutstanding,
      monthlyOutstanding: monthlyOutstanding,
    );
  }

  // ── Standard Transaction Parser ────────────────────────────────────────────

  static AppTransaction? parse(String message, DateTime fallbackDate) {
    if (message.isEmpty) return null;
    if (BankSenders.isSecurityOrAuthMessage(message)) return null;

    final lowerMsg = message.toLowerCase();

    // 1. Airtime Check: Ignore airtime messages completely
    if (RegExp(r'received etb [0-9.]+\s*airtime').hasMatch(lowerMsg)) {
      return null;
    }

    // 2. Identify Category & Amount
    String type = '';
    String category = 'Auto';
    double amount = 0.0;
    String senderOrRecipient = '';

    // A helper to extract amount safely
    double extractAmount(RegExp regex) {
      final match = regex.firstMatch(message);
      if (match != null) {
        return double.tryParse(match.group(1)?.replaceAll(',', '') ?? '0') ??
            0.0;
      }
      return 0.0;
    }

    if (lowerMsg.contains('received')) {
      type = 'income';
      amount = extractAmount(RegExp(r'received\s+ETB\s+([0-9,.]+)'));

      // NEW template: "from Commercial Bank of Ethiopia to your telebirr Account"
      // Note: We search the whole message since the order might vary
      final bankDepositMatch = RegExp(
              r'from\s+(.*?)\s+to your telebirr Account',
              caseSensitive: false)
          .firstMatch(message);

      if (bankDepositMatch != null) {
        senderOrRecipient = bankDepositMatch.group(1)?.trim() ?? '';
      } else {
        // Check for "from" appearing elsewhere if the specific "to your telebirr Account" isn't strictly after it
        final fromMatch =
            RegExp(r'from\s+(.*?)(?=\s*\(|on\s+\d{2}/\d{2}|to\s+your|$)')
                .firstMatch(message);
        if (fromMatch != null) {
          senderOrRecipient = fromMatch.group(1)?.trim() ?? '';
        }
      }
    } else if (lowerMsg.contains('transferred')) {
      type = 'expense';
      amount = extractAmount(RegExp(r'transferred ETB ([0-9,.]+)'));

      // Extract to: "to Ahadu Bank SC account number 0087364810101 on "
      final toMatch =
          RegExp(r'to\s+(.*?)\s+on\s+\d{2}/\d{2}').firstMatch(message);
      if (toMatch != null) {
        senderOrRecipient = toMatch.group(1)?.trim() ?? '';
      }
    } else if (lowerMsg.contains('debited')) {
      type = 'expense';
      amount = extractAmount(RegExp(r'debited\s+with\s+ETB\s+([0-9,.]+)'));

      // Extract at: "at telebirr Agent 248168. Your transaction number"
      final atMatch = RegExp(r'at\s+(.*?)\.\s+Your\s+transaction\s+number',
              caseSensitive: false)
          .firstMatch(message);
      if (atMatch != null) {
        senderOrRecipient = atMatch.group(1)?.trim() ?? '';
      }
    } else if (lowerMsg.contains('paid')) {
      type = 'expense';
      amount = extractAmount(RegExp(r'paid ETB ([0-9,.]+)'));

      // Extract for: "for package Hourly unlimited Internet purchase made for 972665987 on "
      final forMatch =
          RegExp(r'for\s+(.*?)\s+on\s+\d{2}/\d{2}').firstMatch(message);
      if (forMatch != null) {
        senderOrRecipient = forMatch.group(1)?.trim() ?? '';
      }
    } else {
      // Must contain received, transferred, or paid
      return null;
    }

    if (amount <= 0) return null; // Safety check

    // 3. Extract Transaction ID
    // Supports both:
    //   OLD: "transaction number is XXXXX"
    //   NEW: "transaction number XXXXX"  (no "is")
    String? id;
    final idRegex = RegExp(r'transaction number(?:\s+is)?\s+([A-Z0-9]+)',
        caseSensitive: false);
    final idMatch = idRegex.firstMatch(message);
    if (idMatch != null) {
      id = idMatch.group(1);
    } else {
      return null; // A valid Telebirr message must have a transaction ID
    }

    // 4. Extract Current Balance
    double totalBalance = 0.0;
    // Strip newlines to make tracing easier
    String singleLineMsg = message.replaceAll('\n', ' ').replaceAll('\r', ' ');
    final balanceMatch =
        RegExp(r'balance is\s+ETB\s+([0-9.,]+)', caseSensitive: false)
            .firstMatch(singleLineMsg);
    if (balanceMatch != null) {
      String strippedBalance =
          balanceMatch.group(1)?.replaceAll(',', '') ?? '0';
      // Safety drop trailing dots if present incorrectly
      if (strippedBalance.endsWith('.')) {
        strippedBalance =
            strippedBalance.substring(0, strippedBalance.length - 1);
      }
      totalBalance = double.tryParse(strippedBalance) ?? 0.0;
    }

    // 5. Extract Date
    // Supports both:
    //   OLD: "on DD/MM/YYYY HH:mm:ss"
    //   NEW: "on YYYY-MM-DD HH:mm:ss"  (ISO-style from bank deposit messages)
    DateTime txDate = fallbackDate;

    // Try OLD format first: dd/MM/yyyy HH:mm:ss
    final oldDateRegex =
        RegExp(r'on\s+(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2})');
    final oldDateMatch = oldDateRegex.firstMatch(message);
    if (oldDateMatch != null) {
      try {
        final format = DateFormat('dd/MM/yyyy HH:mm:ss');
        txDate = format.parse(oldDateMatch.group(1)!);
      } catch (e) {
        // use fallbackDate
      }
    } else {
      // Try NEW ISO format: yyyy-MM-dd HH:mm:ss
      final newDateRegex =
          RegExp(r'on\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})');
      final newDateMatch = newDateRegex.firstMatch(message);
      if (newDateMatch != null) {
        try {
          final format = DateFormat('yyyy-MM-dd HH:mm:ss');
          txDate = format.parse(newDateMatch.group(1)!);
        } catch (e) {
          // use fallbackDate
        }
      }
    }

    return AppTransaction(
      id: id,
      name: senderName,
      amount: amount,
      type: type,
      date: txDate,
      sender: senderOrRecipient.isNotEmpty ? senderOrRecipient : senderNumber,
      category: category,
      rawMessage: message,
      isAutoDetected: true,
      totalBalance: totalBalance,
    );
  }
}
