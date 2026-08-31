import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

import 'bank_senders.dart';

class SimCardInfo {
  final int subscriptionId;
  final int simSlot; // 0 = SIM 1, 1 = SIM 2
  final String displayName;
  final String carrierName;

  const SimCardInfo({
    required this.subscriptionId,
    required this.simSlot,
    required this.displayName,
    required this.carrierName,
  });

  factory SimCardInfo.fromMap(Map<dynamic, dynamic> map) {
    return SimCardInfo(
      subscriptionId: (map['subscriptionId'] as int?) ?? 0,
      simSlot: (map['simSlot'] as int?) ?? 0,
      displayName: (map['displayName'] as String?) ?? 'SIM ${(map['simSlot'] as int? ?? 0) + 1}',
      carrierName: (map['carrierName'] as String?) ?? '',
    );
  }
}

class RawSmsData {
  final String sender;
  final String body;
  final DateTime date;
  final int simSlot;
  final String? accountIdentifier;

  const RawSmsData({
    required this.sender,
    required this.body,
    required this.date,
    this.simSlot = 0,
    this.accountIdentifier,
  });
}

class SmsService {
  final SmsQuery query = SmsQuery();
  static const MethodChannel _smsScannerChannel =
      MethodChannel('com.shibre/sms_scanner');

  /// Queries active hardware SIM subscriptions on the device (Android SubscriptionManager).
  Future<List<SimCardInfo>> getSimCards() async {
    final bool hasPermission = await Permission.sms.status.isGranted;
    if (!hasPermission) return [];

    try {
      final List<dynamic>? res =
          await _smsScannerChannel.invokeMethod('getSimCards');
      if (res != null) {
        return res
            .map((m) => SimCardInfo.fromMap(m as Map<dynamic, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> requestPermission() async {
    var smsPermission = await Permission.sms.status;
    if (!smsPermission.isGranted) {
      await Permission.sms.request();
    }

    // Explicitly request notification permission for Android 13+
    // so the persistent status bar service stays visible and doesn't get suppressed
    var notificationPermission = await Permission.notification.status;
    if (!notificationPermission.isGranted) {
      await Permission.notification.request();
    }

    return await Permission.sms.isGranted;
  }

  /// Queries the device for distinct bank senders present in the SMS inbox across all-time history.
  Future<List<String>> detectBankingSendersInInbox({
    List<String> customSenders = const [],
  }) async {
    bool hasPermission = await requestPermission();
    if (!hasPermission) return [];

    try {
      final List<String> allKeywords = {
        ...BankSenders.standardBankKeywords,
        ...customSenders.map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty),
      }.toList();

      final List<dynamic>? res = await _smsScannerChannel.invokeMethod('detectBankSenders', {
        'senders': allKeywords,
      });

      if (res != null) {
        final rawAddresses = res.map((e) => e.toString()).toList();
        final Set<String> detectedBanks = {};
        for (final addr in rawAddresses) {
          final matched = BankSenders.match(addr);
          if (matched != null) {
            detectedBanks.add(matched);
          } else {
            for (final cs in customSenders) {
              if (cs.trim().toLowerCase() == addr.trim().toLowerCase()) {
                detectedBanks.add(cs.trim());
              }
            }
          }
        }
        return detectedBanks.toList();
      }
    } catch (_) {}
    return [];
  }

  /// High-speed native Android query that filters by bank senders and anchor date
  /// on a background thread in native code before crossing to Dart.
  Future<List<RawSmsData>> getBankMessagesFast({
    DateTime? since,
    List<String> customSenders = const [],
    List<String>? overrideSenders,
  }) async {
    bool hasPermission = await requestPermission();
    if (!hasPermission) return [];

    try {
      final sinceMs = since?.millisecondsSinceEpoch;
      final List<String> allBankSenders = (overrideSenders != null && overrideSenders.isNotEmpty)
          ? overrideSenders.map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList()
          : {
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
          final int simSlot = (map['simSlot'] as int?) ?? (map['slot'] as int?) ?? 0;
          final String? accountId = map['accountIdentifier'] as String?;
          return RawSmsData(
            sender: map['sender'] as String? ?? '',
            body: map['body'] as String? ?? '',
            date: dt,
            simSlot: simSlot,
            accountIdentifier: accountId,
          );
        }).toList();
      }
    } catch (_) {
      // Fallback to flutter_sms_inbox if method channel is unavailable
    }

    final fallbackMessages = await getAllMessages(since: since);
    var filtered = fallbackMessages.where((m) => m.sender != null && m.body != null && m.date != null);
    if (overrideSenders != null && overrideSenders.isNotEmpty) {
      final lowerSenders = overrideSenders.map((s) => s.trim().toLowerCase()).toSet();
      filtered = filtered.where((m) {
        final s = m.sender!.toLowerCase();
        return lowerSenders.contains(s) || lowerSenders.any((k) => s.contains(k));
      });
    }
    return filtered
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
