import '../models/transaction.dart';

/// Utility class for robust, cross-bank counterparty matching and name normalization.
/// Handles bank variations, parenthetical account numbers, prefixes, dates, and token overlap.
class CounterpartyMatcher {
  const CounterpartyMatcher._();

  static final RegExp _accountInParensRegex =
      RegExp(r'\((?:account\s*)?[\d*]+\)', caseSensitive: false);
  static final RegExp _nameInParensRegex =
      RegExp(r'account\s+[\d*]+\s*\(([^)]+)\)', caseSensitive: false);
  static final RegExp _trailingDateRegex =
      RegExp(r'\s+on\s+\d{2}[/-]\d{2}(?:[/-]\d{2,4})?.*$', caseSensitive: false);
  static final RegExp _leadingPrefixRegex = RegExp(
    r'^(?:to|from|credited\s+by|debited\s+for|account|ato|dr\.?|w/ro|w/rt|mr\.?|mrs\.?|ms\.?)\s+',
    caseSensitive: false,
  );
  static final RegExp _trailingSuffixRegex = RegExp(
    r'\s+(?:plc|s\.?c\.?|ltd\.?|inc\.?)$',
    caseSensitive: false,
  );
  static final RegExp _nonWordChars =
      RegExp(r'[^\w\s/]', unicode: true);

  /// Normalizes a counterparty/sender string into a clean, canonical name.
  static String normalize(String raw) {
    String s = raw.trim();
    if (s.isEmpty) return '';

    // Extract name inside parentheses if format is "account 1****4239 (Name)"
    final nameInParensMatch = _nameInParensRegex.firstMatch(s);
    if (nameInParensMatch != null) {
      final inner = nameInParensMatch.group(1)?.trim();
      if (inner != null && inner.isNotEmpty) {
        s = inner;
      }
    }

    // Strip trailing "(1****4239)" or "(account 1234)"
    s = s.replaceAll(_accountInParensRegex, '').trim();

    // Strip trailing " on DD/MM/YYYY..."
    s = s.replaceAll(_trailingDateRegex, '').trim();

    // Strip common leading noise prefixes (e.g. "to ", "from ", "Ato ")
    s = s.replaceAll(_leadingPrefixRegex, '').trim();

    // Strip common trailing corporate suffixes (e.g. " PLC", " S.C.")
    s = s.replaceAll(_trailingSuffixRegex, '').trim();

    // Strip punctuation except slashes used in Ethiopian names like "T/mariam"
    s = s.replaceAll(_nonWordChars, ' ');

    // Normalize multiple spaces
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }

  /// Evaluates whether two sender/counterparty strings represent the same entity.
  static bool matches(String a, String b) {
    final rawA = a.trim().toLowerCase();
    final rawB = b.trim().toLowerCase();

    if (rawA.isEmpty || rawB.isEmpty) return false;
    if (rawA == rawB) return true;
    if (rawA.contains(rawB) || rawB.contains(rawA)) return true;

    final normA = normalize(a).toLowerCase();
    final normB = normalize(b).toLowerCase();

    if (normA.isEmpty || normB.isEmpty) return false;
    if (normA == normB) return true;
    if (normA.contains(normB) || normB.contains(normA)) return true;

    // Token-based matching: check if all words from the shorter name are present in the longer name
    final tokensA = normA
        .split(' ')
        .where((t) => t.length >= 2)
        .toList();
    final tokensB = normB
        .split(' ')
        .where((t) => t.length >= 2)
        .toList();

    if (tokensA.isNotEmpty && tokensB.isNotEmpty) {
      final shorter = tokensA.length <= tokensB.length ? tokensA : tokensB;
      final longer = tokensA.length <= tokensB.length ? tokensB : tokensA;

      final matchCount = shorter.where((t) => longer.contains(t)).length;
      if (matchCount == shorter.length && shorter.length >= 2) {
        return true;
      }
    }

    return false;
  }

  /// Filters a list of transactions for all records matching the given counterparty.
  static List<AppTransaction> filterForCounterparty(
    List<AppTransaction> transactions,
    String targetName,
  ) {
    if (targetName.trim().isEmpty) return const [];
    return transactions.where((tx) => matches(tx.sender, targetName)).toList();
  }
}
