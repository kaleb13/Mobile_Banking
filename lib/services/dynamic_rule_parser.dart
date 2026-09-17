import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import '../models/bank_definition.dart';
import '../models/parsed_sms_result.dart';

/// Pure-fact SMS parser driven by declarative [BankDefinition] rules.
///
/// Strictly conforms to Layer 1 architecture:
/// - Extracts ONLY the 8 objective facts in [ParsedSmsResult]
/// - Zero database, UI, or reason logic
class DynamicRuleParser {
  DynamicRuleParser._();

  static RegExp _safeRegExp(String rawPattern, {bool caseSensitive = false}) {
    String p = rawPattern;
    bool cs = caseSensitive;
    if (p.startsWith('(?i)')) {
      p = p.substring(4);
      cs = false;
    }
    return RegExp(p, caseSensitive: cs);
  }

  /// Parses an SMS [message] using the rules defined in [bank].
  ///
  /// Returns a valid [ParsedSmsResult] if a pattern matches, or null if no
  /// pattern matches or the message matches a security/ignore filter.
  static ParsedSmsResult? parse(
    BankDefinition bank,
    String message,
    DateTime fallbackDate,
  ) {
    if (message.isEmpty) return null;

    final singleLine = message.replaceAll('\n', ' ').replaceAll('\r', ' ');
    final lowerMsg = singleLine.toLowerCase();

    // 1. Security / OTP noise filter
    if (bank.parsing.securityFilterRegex != null &&
        bank.parsing.securityFilterRegex!.isNotEmpty) {
      try {
        final secRegex = _safeRegExp(bank.parsing.securityFilterRegex!);
        if (secRegex.hasMatch(singleLine)) {
          return null;
        }
      } catch (_) {}
    }

    // 2. Ignore / Promo noise filter
    if (bank.parsing.ignoreFilterRegex != null &&
        bank.parsing.ignoreFilterRegex!.isNotEmpty) {
      try {
        final ignRegex = _safeRegExp(bank.parsing.ignoreFilterRegex!);
        if (ignRegex.hasMatch(singleLine)) {
          return null;
        }
      } catch (_) {}
    }

    // 3. Evaluate Patterns in declaration order
    for (final pattern in bank.parsing.patterns) {
      // Fast check: All trigger keywords must be present
      if (pattern.triggerKeywords.isNotEmpty) {
        bool allPresent = true;
        for (final kw in pattern.triggerKeywords) {
          if (!lowerMsg.contains(kw)) {
            allPresent = false;
            break;
          }
        }
        if (!allPresent) continue;
      }

      if (pattern.regex.isEmpty) continue;

      try {
        final regExp = _safeRegExp(pattern.regex);
        final match = regExp.firstMatch(singleLine);
        if (match == null) continue;

        // Extract Amount
        double amount = 0.0;
        if (pattern.amountGroup > 0 && pattern.amountGroup <= match.groupCount) {
          final amtStr = match.group(pattern.amountGroup)?.replaceAll(',', '').trim() ?? '0';
          final cleanAmt = amtStr.endsWith('.') ? amtStr.substring(0, amtStr.length - 1) : amtStr;
          amount = double.tryParse(cleanAmt) ?? 0.0;
        }
        if (amount <= 0.0) continue;

        // Extract Counterparty
        String counterparty = pattern.counterpartyDefault ?? '';
        if (pattern.counterpartyGroup > 0 && pattern.counterpartyGroup <= match.groupCount) {
          final cp = match.group(pattern.counterpartyGroup)?.trim();
          if (cp != null && cp.isNotEmpty) {
            counterparty = cp;
          }
        }
        if (counterparty.isEmpty) {
          counterparty = bank.bankName;
        }

        // Extract Balance
        double balance = 0.0;
        if (pattern.balanceGroup != null &&
            pattern.balanceGroup! > 0 &&
            pattern.balanceGroup! <= match.groupCount) {
          final balStr = match.group(pattern.balanceGroup!)?.replaceAll(',', '').trim() ?? '0';
          final cleanBal = balStr.endsWith('.') ? balStr.substring(0, balStr.length - 1) : balStr;
          balance = double.tryParse(cleanBal) ?? 0.0;
        }

        // Extract Transaction Reference ID
        String? id;
        if (pattern.idGroup != null &&
            pattern.idGroup! > 0 &&
            pattern.idGroup! <= match.groupCount) {
          final rawId = match.group(pattern.idGroup!)?.trim();
          if (rawId != null && rawId.isNotEmpty) {
            id = rawId;
          }
        }

        // Extract Date if present
        DateTime txDate = fallbackDate;
        if (pattern.dateGroup != null &&
            pattern.dateGroup! > 0 &&
            pattern.dateGroup! <= match.groupCount &&
            pattern.dateFormat != null) {
          final dateStr = match.group(pattern.dateGroup!)?.trim();
          if (dateStr != null && dateStr.isNotEmpty) {
            try {
              final parsed = DateFormat(pattern.dateFormat!).parse(dateStr);
              txDate = DateTime(
                parsed.year < 2000 ? fallbackDate.year : parsed.year,
                parsed.month,
                parsed.day,
                parsed.hour,
                parsed.minute,
                parsed.second,
              );
            } catch (_) {}
          }
        }

        // Generate synthetic reference ID if absent
        if (id == null || id.isEmpty) {
          final content = '${bank.bankName}_${amount}_${pattern.type}_${txDate.millisecondsSinceEpoch}_$counterparty';
          id = 'SYN_${sha256.convert(utf8.encode(content)).toString().substring(0, 16)}';
        }

        return ParsedSmsResult(
          id: id,
          bankName: bank.bankName,
          amount: amount,
          type: pattern.type,
          date: txDate,
          counterparty: counterparty,
          totalBalance: balance,
          rawMessage: message,
          patternType: pattern.resolvedPatternType,
        );
      } catch (_) {
        // Safe regex error handling; fall through to next pattern
        continue;
      }
    }

    return null;
  }
}
