import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/parsed_sms_result.dart';
import 'package:intl/intl.dart';

class AwashParser {
  static const String senderName = "Awash Bank";

  static ParsedSmsResult? parse(String message, DateTime fallbackDate) {
    if (message.isEmpty) return null;

    final lowerMsg = message.toLowerCase();

    // Must be related to Awash Bank transactions or contain transactional cues
    if (!lowerMsg.contains('awash') &&
        !lowerMsg.contains('credited') &&
        !lowerMsg.contains('transferred') &&
        !lowerMsg.contains('transfer') &&
        !lowerMsg.contains('sent etb') &&
        !lowerMsg.contains('airtime')) {
      return null;
    }

    String type = '';
    double amount = 0.0;
    String counterparty = '';
    double totalBalance = 0.0;
    String? id;
    DateTime txDate = fallbackDate;
    SmsPatternType patternType = SmsPatternType.standardTransfer;

    final singleLine = message.replaceAll('\n', ' ').replaceAll('\r', ' ');

    double parseAmount(RegExp regex) {
      final match = regex.firstMatch(singleLine);
      if (match != null) {
        String amtStr = match.group(1)?.replaceAll(',', '').trim() ?? '0';
        if (amtStr.endsWith('.')) {
          amtStr = amtStr.substring(0, amtStr.length - 1);
        }
        return double.tryParse(amtStr) ?? 0.0;
      }
      return 0.0;
    }

    // ── 1. Inbound Credit Pattern A (Account ... has been Credited with ETB ...) ──
    if (lowerMsg.contains('has been credited with etb')) {
      type = 'income';
      amount = parseAmount(RegExp(r'credited\s+with\s+ETB\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      if (amount <= 0) return null;

      // Counterparty: "by BISRAT TESFAYE ADEM via IPS Bank of Abyssinia" or "by TeleBirr C2B to Awash"
      final byMatch = RegExp(r'by\s+(.*?)\s+(?:on\s+\d{4}-\d{2}-\d{2}|with\s+reference|\.\s*Your|\.\s*For)', caseSensitive: false)
          .firstMatch(singleLine);
      if (byMatch != null) {
        counterparty = byMatch.group(1)?.trim() ?? '';
      } else {
        final fallbackByMatch = RegExp(r'by\s+(.*?)(?=\.\s*Your|\.\s*For|\.\s*Subscribe|\.|\n|$)', caseSensitive: false)
            .firstMatch(singleLine);
        counterparty = fallbackByMatch?.group(1)?.trim() ?? 'Deposit';
      }
      if (counterparty.contains(RegExp(r'\s+via\s+IPS', caseSensitive: false))) {
        counterparty = counterparty.split(RegExp(r'\s+via\s+IPS', caseSensitive: false)).first.trim();
      }

      // Ref ID: "with reference DFC2TV0K20"
      final refMatch = RegExp(r'reference\s+([A-Za-z0-9]+)', caseSensitive: false).firstMatch(singleLine);
      if (refMatch != null) {
        id = refMatch.group(1)?.trim();
      }

      // Date: "on 2026-03-21 07:17:06"
      final dateMatch = RegExp(r'on\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})', caseSensitive: false).firstMatch(singleLine);
      if (dateMatch != null) {
        try {
          txDate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateMatch.group(1)!);
        } catch (_) {}
      }
    }
    // ── 2. Inbound Credit Pattern B (ETB ... has been credited to your account from ...) ──
    else if (lowerMsg.contains('has been credited to your account from')) {
      type = 'income';
      amount = parseAmount(RegExp(r'ETB\s*([0-9,]+(?:\.[0-9]+)?)\s+has\s+been\s+credited', caseSensitive: false));
      if (amount <= 0) return null;

      // Counterparty: "from Alpha Dawit on :"
      final fromMatch = RegExp(r'from\s+(.*?)\s+on\s*:', caseSensitive: false).firstMatch(singleLine);
      counterparty = fromMatch?.group(1)?.trim() ?? 'Deposit';

      // Ref ID: "with Txn ID: 260328103874225"
      final txnMatch = RegExp(r'Txn\s+ID:\s*([A-Za-z0-9]+)', caseSensitive: false).firstMatch(singleLine);
      if (txnMatch != null) {
        id = txnMatch.group(1)?.trim();
      }

      // Date: "on : 2026-03-28 10:38:47"
      final dateMatch = RegExp(r'on\s*:\s*(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})', caseSensitive: false).firstMatch(singleLine);
      if (dateMatch != null) {
        try {
          txDate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateMatch.group(1)!);
        } catch (_) {}
      }
    }
    // ── 3. Outbound P2P Transfer (You have sent ETB ... To (...) - Name by Transaction ID) ──
    else if (lowerMsg.contains('you have sent etb')) {
      type = 'expense';
      amount = parseAmount(RegExp(r'You\s+have\s+sent\s+ETB\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      if (amount <= 0) return null;

      // Counterparty: "To (01335625418100) - BEREKET LIBIYOS BERGENE by"
      final toMatch = RegExp(r'To\s+(?:\([0-9]+\)\s*-\s*)?([A-Za-z\s]+?)\s+by\s+Transaction', caseSensitive: false).firstMatch(singleLine)
          ?? RegExp(r'To\s+(.*?)\s+by\s+Transaction', caseSensitive: false).firstMatch(singleLine);
      counterparty = toMatch?.group(1)?.replaceAll(RegExp(r'^\([0-9]+\)\s*-\s*'), '').trim() ?? 'Awash Transfer';

      // Ref ID: "by Transaction ID: 260615193827946"
      final txnMatch = RegExp(r'Transaction\s+ID:\s*([A-Za-z0-9]+)', caseSensitive: false).firstMatch(singleLine);
      if (txnMatch != null) {
        id = txnMatch.group(1)?.trim();
      }

      // Date: "Date 2026-06-15 19:38:24"
      final dateMatch = RegExp(r'Date\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})', caseSensitive: false).firstMatch(singleLine);
      if (dateMatch != null) {
        try {
          txDate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateMatch.group(1)!);
        } catch (_) {}
      }
    }
    // ── 4. Outbound Other Bank Transfer (You have transferred to other bank ETB ... To ...) ──
    else if (lowerMsg.contains('transferred to other bank')) {
      type = 'expense';
      amount = parseAmount(RegExp(r'transferred\s+to\s+other\s+bank\s+ETB\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      if (amount <= 0) return null;

      // Counterparty: "To 1000711508736 (MRS EYERUS MENGESHA MOLLA) In Commercial Bank of Ethiopia"
      final toMatch = RegExp(r'transferred\s+to\s+other\s+bank\s+ETB\s*[0-9,.]+\s+To\s+(?:[0-9]+\s+)?(?:\((.*?)\)|(.*?))\s+In\s+(.*?)(?=\s+VAT:|\s+with\s+charge|\.\s*Your)', caseSensitive: false).firstMatch(singleLine);
      if (toMatch != null) {
        final recipient = (toMatch.group(1) ?? toMatch.group(2))?.trim() ?? '';
        counterparty = recipient.isNotEmpty ? recipient : 'Other Bank Transfer';
      } else {
        final simpleToMatch = RegExp(r'transferred\s+to\s+other\s+bank\s+ETB\s*[0-9,.]+\s+To\s+(.*?)(?=\s+In\s+|\s+VAT:|\s+with\s+charge|\.\s*Your)', caseSensitive: false).firstMatch(singleLine);
        counterparty = simpleToMatch?.group(1)?.trim() ?? 'Other Bank Transfer';
      }
    }
    // ── 5. Outbound Telebirr Transfer (Telebirr Transfer of ... ETB to ... from ...) ──
    else if (lowerMsg.contains('telebirr transfer of')) {
      type = 'expense';
      amount = parseAmount(RegExp(r'Telebirr\s+Transfer\s+of\s*([0-9,]+(?:\.[0-9]+)?)\s*ETB', caseSensitive: false));
      if (amount <= 0) return null;

      // Counterparty: "to Bisrat Tesfaye Adem - 251984163455 from"
      final toMatch = RegExp(r'to\s+(.*?)\s+from\s+', caseSensitive: false).firstMatch(singleLine);
      var rawTo = toMatch?.group(1)?.trim() ?? 'Telebirr Transfer';
      counterparty = rawTo.replaceAll(RegExp(r'\s*-\s*[0-9+]+$'), '').trim();
    }
    // ── 6. Outbound MPESA Transfer (MPESA transfer of ... ETB for ... Ref ... Date ...) ──
    else if (lowerMsg.contains('mpesa transfer of')) {
      type = 'expense';
      amount = parseAmount(RegExp(r'MPESA\s+transfer\s+of\s*([0-9,]+(?:\.[0-9]+)?)\s*ETB', caseSensitive: false));
      if (amount <= 0) return null;

      // Counterparty: "for 0705043455 ,Bisrat Tesfaye Adam Ref"
      final forMatch = RegExp(r'for\s+(?:[0-9+]+\s*,\s*)?(.*?)\s+Ref\s+', caseSensitive: false).firstMatch(singleLine);
      counterparty = forMatch?.group(1)?.trim() ?? 'MPESA Transfer';

      // Ref ID: "Ref 260721215098790"
      final refMatch = RegExp(r'Ref\s+([A-Za-z0-9]+)', caseSensitive: false).firstMatch(singleLine);
      if (refMatch != null) {
        id = refMatch.group(1)?.trim();
      }

      // Date: "Date 2026-07-21 09:50:54 PM"
      final dateMatch = RegExp(r'Date\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s*(?:[AP]M)?)', caseSensitive: false).firstMatch(singleLine);
      if (dateMatch != null) {
        try {
          final dateStr = dateMatch.group(1)!.trim();
          if (dateStr.toUpperCase().contains('AM') || dateStr.toUpperCase().contains('PM')) {
            txDate = DateFormat('yyyy-MM-dd hh:mm:ss a').parse(dateStr);
          } else {
            txDate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateStr);
          }
        } catch (_) {}
      }
    }
    // ── 7. Airtime Purchase (You have bought airtime worth ETB ... for ...) ──
    else if (lowerMsg.contains('bought airtime worth etb')) {
      type = 'expense';
      patternType = SmsPatternType.telebirrAirtime;
      amount = parseAmount(RegExp(r'bought\s+airtime\s+worth\s+ETB\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      if (amount <= 0) return null;

      final forMatch = RegExp(r'for\s+([0-9+]+)', caseSensitive: false).firstMatch(singleLine);
      counterparty = forMatch != null ? 'Airtime (${forMatch.group(1)})' : 'Airtime';
    }
    // ── 8. Telebirr Agent Transfer (Telebirr Agent Transfer of ... to Ac : ...) ──
    else if (lowerMsg.contains('telebirr agent transfer of')) {
      type = 'expense';
      amount = parseAmount(RegExp(r'Telebirr\s+Agent\s+Transfer\s+of\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      if (amount <= 0) return null;

      final agentMatch = RegExp(r'at\s+agent:\s*(.*?)(?:Agent\s+Code:|Transaction\s+Id:|\.Receipt)', caseSensitive: false).firstMatch(singleLine);
      counterparty = agentMatch?.group(1)?.trim() ?? 'Telebirr Agent';

      final txnMatch = RegExp(r'Transaction\s+Id:\s*([A-Za-z0-9]+)', caseSensitive: false).firstMatch(singleLine);
      if (txnMatch != null) {
        id = txnMatch.group(1)?.trim();
      }
    } else {
      return null;
    }

    if (amount <= 0) return null;

    // ── Extract Receipt Link / Ref if ID is not yet found ──
    if (id == null || id.isEmpty) {
      final receiptMatch = RegExp(r'awashpay\.awashbank\.com:\d+/(-[A-Za-z0-9-]+)', caseSensitive: false).firstMatch(singleLine);
      if (receiptMatch != null) {
        id = receiptMatch.group(1)?.trim();
      }
    }

    // Fallback hash ID
    if (id == null || id.isEmpty) {
      final normalised = message.replaceAll(RegExp(r'\s+'), ' ').trim();
      final hash = sha256.convert(utf8.encode('AWASH|$normalised')).toString();
      id = 'AWASH-${hash.substring(0, 16).toUpperCase()}';
    }

    // ── Extract Total / Available Balance ──
    final balanceMatch = RegExp(
            r'(?:Your\s+(?:available\s+)?[Bb]alance\s+(?:now\s+)?is\s+(?:now\s+)?(?:ETB\s*)?|Your\s+[Bb]alance\s+now\s+is\s+ETB\s*)([0-9,]+(?:\.[0-9]+)?)',
            caseSensitive: false)
        .firstMatch(singleLine);
    if (balanceMatch != null) {
      String strippedBalance = balanceMatch.group(1)?.replaceAll(',', '') ?? '0';
      if (strippedBalance.endsWith('.')) {
        strippedBalance = strippedBalance.substring(0, strippedBalance.length - 1);
      }
      totalBalance = double.tryParse(strippedBalance) ?? 0.0;
    }

    return ParsedSmsResult(
      id: id,
      bankName: senderName,
      amount: amount,
      type: type,
      date: txDate,
      counterparty: counterparty,
      totalBalance: totalBalance,
      rawMessage: message,
      patternType: patternType,
    );
  }

  /// Extracts account holder's name from harmonization or linking SMS
  static String? extractOwnerName(String message) {
    if (message.isEmpty) return null;
    final singleLine = message.replaceAll('\n', ' ').replaceAll('\r', ' ');

    final dearNameMatch = RegExp(
            r'Dear\s+([A-Z\s]{4,35}),\s+(?:Thank you for submitting|Your National ID|Your account)',
            caseSensitive: true)
        .firstMatch(singleLine);
    if (dearNameMatch != null) {
      final name = dearNameMatch.group(1)?.trim();
      if (name != null && name.isNotEmpty && !name.toLowerCase().contains('customer') && !name.toLowerCase().contains('valued')) {
        return name;
      }
    }
    return null;
  }
}
