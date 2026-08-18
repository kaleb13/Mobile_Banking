import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

import 'bank_senders.dart';

class RawSmsData {
  final String sender;
  final String body;
  final DateTime date;

  const RawSmsData({
    required this.sender,
    required this.body,
    required this.date,
  });
}

class SmsService {
  final SmsQuery query = SmsQuery();
  static const MethodChannel _smsScannerChannel =
      MethodChannel('com.shibre/sms_scanner');

  Future<bool> requestPermission() async {
    var smsPermission = await Permission.sms.status;
    if (!smsPermission.isGranted) {
      await Permission.sms.request();
    }

    // Also explicitly request notification permission for Android 13+
    // so the persistent status bar service stays visible and doesn't get suppressed
    var notificationPermission = await Permission.notification.status;
    if (!notificationPermission.isGranted) {
      await Permission.notification.request();
    }

    return await Permission.sms.isGranted;
  }

  /// High-speed native Android query that filters by bank senders and anchor date
  /// on a background thread in native code before crossing to Dart.
  Future<List<RawSmsData>> getBankMessagesFast({
    DateTime? since,
    List<String> customSenders = const [],
  }) async {
    bool hasPermission = await requestPermission();
    if (!hasPermission) return [];

    try {
      final sinceMs = since?.millisecondsSinceEpoch;
      final List<String> allBankSenders = {
        ...BankSenders.standardBankKeywords,
        ...customSenders.map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty),
      }.toList();

      final List<dynamic>? res =
          await _smsScannerChannel.invokeMethod('getBankSmsFast', {
        'since': sinceMs,
        'senders': allBankSenders,
        'customSenders': customSenders,
      });

      if (res != null) {
        return res.map((m) {
          final map = m as Map<dynamic, dynamic>;
          final dateVal = map['date'];
          final DateTime dt = dateVal is int
              ? DateTime.fromMillisecondsSinceEpoch(dateVal)
              : (dateVal is double
                  ? DateTime.fromMillisecondsSinceEpoch(dateVal.toInt())
                  : DateTime.now());
          return RawSmsData(
            sender: map['sender'] as String? ?? '',
            body: map['body'] as String? ?? '',
            date: dt,
          );
        }).toList();
      }
    } catch (_) {
      // Fallback to flutter_sms_inbox if method channel is unavailable
    }

    final fallbackMessages = await getAllMessages(since: since);
    return fallbackMessages
        .where((m) => m.sender != null && m.body != null && m.date != null)
        .map((m) => RawSmsData(
              sender: m.sender!,
              body: m.body!,
              date: m.date!,
            ))
        .toList();
  }

  Future<List<SmsMessage>> getAllMessages({DateTime? since}) async {
    bool hasPermission = await requestPermission();
    if (!hasPermission) return [];

    List<SmsMessage> messages = await query.querySms(
      kinds: [SmsQueryKind.inbox],
    );

    // Sort newest messages first so index 0 is always the latest SMS
    messages.sort((a, b) {
      if (a.date == null || b.date == null) return 0;
      return b.date!.compareTo(a.date!);
    });

    // Filter out messages that arrived before 'since' if provided
    if (since != null) {
      final cutoff = since.subtract(const Duration(seconds: 2));
      return messages.where((msg) {
        if (msg.date == null) return false;
        return msg.date!.isAfter(cutoff);
      }).toList();
    }

    return messages;
  }

  Future<List<String>> getUniqueSenders() async {
    List<SmsMessage> messages = await getAllMessages();
    Set<String> uniqueSenders = {};

    final phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');
    final transactionRegex = RegExp(
      r'(rs\.?|inr|₹|\$|credited|debited|spent|txn|balance|a/c|account)',
      caseSensitive: false,
    );

    for (var msg in messages) {
      if (msg.sender != null && msg.sender!.isNotEmpty) {
        String sender = msg.sender!;
        String body = msg.body ?? '';

        bool looksLikeBank = !phoneRegex.hasMatch(sender);
        bool hasTxn = transactionRegex.hasMatch(body);

        if (looksLikeBank || hasTxn) {
          uniqueSenders.add(sender);
        }
      }
    }
    return uniqueSenders.toList();
  }

  // --- Smart Parser logic ---
  static double extractAmount(String message) {
    // Basic regex to find amounts, e.g., RS 500, ₹450, 20.00
    // Looks for numbers with optional decimals
    RegExp regExp = RegExp(
      r'(?:Rs|INR|₹|ETB|\$)?\s?(\d+(?:,\d{3})*(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    var matches = regExp.allMatches(message);
    if (matches.isNotEmpty) {
      // Find the first match that looks like an amount
      // or the largest amount, but first match is usually the transaction amount
      String amountStr = matches.first.group(1) ?? "0";
      amountStr = amountStr.replaceAll(',', '');
      return double.tryParse(amountStr) ?? 0.0;
    }
    return 0.0;
  }
}
