# Comparative SMS Parsing Analysis & Integration Guide: ZamZam Bank & Siket Bank

This document provides an in-depth architectural and pattern comparison between **PennyWise AI** (`sarim2000/pennywiseai-tracker`) and our application (**Mobile_Banking**). It analyzes the parsing logic for **Commercial Bank of Ethiopia (CBE)** and **Telebirr**, details the exact SMS patterns used for **ZamZam Bank** and **Siket Bank**, and outlines the specific adaptations required to integrate both banks into our **pure-fact dual-engine** architecture without regressing existing bank parsers.

> **Note on App Integrity**: In accordance with project rules, no application source code (`lib/`, `android/`, `test/`) has been modified. This document serves as the architectural reference alongside the generated XML test files in `docs/`.

---

## Table of Contents
1. [Architectural Comparison: PennyWise AI vs. Mobile_Banking](#1-architectural-comparison-pennywise-ai-vs-mobile_banking)
2. [Comparative Deep Dive: CBE & Telebirr Parsers](#2-comparative-deep-dive-cbe--telebirr-parsers)
   - [2.1 Commercial Bank of Ethiopia (CBE)](#21-commercial-bank-of-ethiopia-cbe)
   - [2.2 Telebirr (Ethio Telecom)](#22-telebirr-ethio-telecom)
3. [ZamZam Bank: SMS Patterns & Parsing Blueprint](#3-zamzam-bank-sms-patterns--parsing-blueprint)
   - [3.1 Analysis of PennyWise's ZamZam Parser](#31-analysis-of-pennywises-zamzam-parser)
   - [3.2 Necessary Adjustments for Our App](#32-necessary-adjustments-for-our-app)
   - [3.3 Pure Fact Regex & Pattern Definitions](#33-pure-fact-regex--pattern-definitions)
   - [3.4 Dart Parser Implementation Blueprint](#34-dart-parser-implementation-blueprint)
   - [3.5 Native Kotlin Extractor Blueprint](#35-native-kotlin-extractor-blueprint)
4. [Siket Bank: SMS Patterns & Parsing Blueprint](#4-siket-bank-sms-patterns--parsing-blueprint)
   - [4.1 Analysis of PennyWise's Siket Parser](#41-analysis-of-pennywises-siket-parser)
   - [4.2 Necessary Adjustments for Our App](#42-necessary-adjustments-for-our-app)
   - [4.3 Pure Fact Regex & Pattern Definitions](#43-pure-fact-regex--pattern-definitions)
   - [4.4 Dart Parser Implementation Blueprint](#44-dart-parser-implementation-blueprint)
   - [4.5 Native Kotlin Extractor Blueprint](#45-native-kotlin-extractor-blueprint)
5. [Phone Debugging & XML Import Guide](#5-phone-debugging--xml-import-guide)
6. [Non-Regression & Verification Matrix](#6-non-regression--verification-matrix)

---

## 1. Architectural Comparison: PennyWise AI vs. Mobile_Banking

While both applications parse SMS messages locally on-device without cloud dependencies, their underlying paradigms, execution engines, and output contracts differ substantially:

| Dimension | PennyWise AI (`sarim2000/pennywiseai-tracker`) | Our App (`Mobile_Banking`) |
|---|---|---|
| **Platform & Language** | Single-Engine: Kotlin on Android (Jetpack Compose, Room, WorkManager). | **Dual-Engine**: Dart in Flutter (`lib/services/`) + Native Kotlin (`SmsBroadcastReceiver.kt`). |
| **Parser Class Design** | **Inheritance model**: Each bank inherits from an abstract `BankParser` base class. | **Compositional / Functional**: Independent static parser classes evaluated top-down. |
| **Field Extraction Strategy** | **Decentralized attribute extraction**: Independent methods (`extractAmount`, `extractTransactionType`, `extractMerchant`, `extractBalance`, `extractAccountLast4`). | **Cohesive Pattern-Based Fact Extraction**: Unified regexes that extract amounts, counterparties, accounts, and references within their syntactic context. |
| **Output Data Contract** | Flexible `ParsedTransaction` with mutable/nullable fields (`merchant`, `reference`, `accountLast4`, `isMobileWallet`, `currency`, `timestamp`). | **Strict 8-Field `ParsedSmsResult` DTO**: `id`, `bankName`, `amount`, `type`, `date`, `counterparty`, `totalBalance`, `patternType`. |
| **Transaction ID / Deduplication** | Generated synthetic hash: `md5Hex("$sender|$normalizedAmount|$smsBodyHash")`. | **Deterministic Bank Reference Code** (e.g. `FT...`, `PP...`, `CH...`), with timestamped hash fallback `"${bank}_${date.ms}_${amount}"`. |
| **Service Charge / VAT Separation** | Uses priority ordering in `extractAmount` to avoid capturing fees, but does not store fees. | Isolates fees completely; principal transfer amount is strictly preserved without fee mixing. |
| **Layer Separation & Receipts** | Parses raw strings; no strict lock flag separation. | **Strict 4-layer separation**: Parsers output facts only; lock flags set in Layer 2; receipt URLs generated on-the-fly in Layer 4 via `LinkExtractor`. |

---

## 2. Comparative Deep Dive: CBE & Telebirr Parsers

### 2.1 Commercial Bank of Ethiopia (CBE)

#### How PennyWise AI Parses CBE (`CBEBankParser.kt`)
- **Amount Extraction**:
  - Checks `with a total of ETB <amount>` first (for fee summaries).
  - Contains a special workaround for older debit alerts containing `?id=` receipt links where tests expected the current balance as the amount.
  - Fallback verb regexes: `(?:Credited|debited|transfered)\s+(?:with\s+)?ETB\s*([0-9,]+(?:\.[0-9]{2})?)`.
- **Transaction Type**:
  - String contains checks: `"has been credited"` / `"credited with"` $\rightarrow$ `INCOME`; `"has been debited"` / `"you have transfered"` $\rightarrow$ `EXPENSE`.
- **Merchant / Counterparty**:
  - Checks `"has been credited by (.+?) with ETB"` or `"to (.+?) on \d{2}/\d{2}"`.
- **Limitations**:
  - Does not extract unique bank reference codes (such as `FT...` numbers) as a first-class citizen; relies on MD5 body hash.
  - Does not parse modern CBE multi-format recipient syntax such as `to account 1****1234 (Recipient Name)`.

#### How Our App Parses CBE (`cbe_parser.dart` + `SmsBroadcastReceiver.kt`)
- Direct, prioritized full-sentence matchers distinguishing:
  1. **Credited**: Standard deposits and modern company deposits (`credited by QELEM MEDA TECHNOLOGIES PLC with ETB...`).
  2. **Received**: P2P incoming transfers with account and parenthesized names (`from account 1****4239 (Nathnael Tesfaye)`).
  3. **Transferred**: Outgoing transfers distinguishing `"to <Name> on DD/MM"` vs `"to account 1****1234 (<Name>)"`.
  4. **Debited**: Standard ATM/POS debits.
- **Reference Extraction**: Extracts clean `FT...` codes from `transaction/trans ref` or query parameter links.
- **Dual-Engine Coherence**: Both Dart and Kotlin handle edge cases identically with 100% test parity.

---

### 2.2 Telebirr (Ethio Telecom)

#### How PennyWise AI Parses Telebirr (`TelebirrParser.kt`)
- **Sender Identification**: `127`, `127-XXX`, `XXX-127`, `XX-127-X`.
- **Savings Flow Handling**:
  - `"deposited ETB ... to your saving account"` $\rightarrow$ Marked as `EXPENSE` (funds leaving main wallet).
  - `"withdraw ETB ... from your saving account"` $\rightarrow$ Marked as `INCOME` (funds entering main wallet).
- **Merchant Extraction**:
  - Bank transfer in: `"from <Bank> to your telebirr Account"`.
  - Utility / Government payments: `"paid ETB X to 519680 - City Government..."`.
- **Limitations**:
  - Treats all transactions as generic income/expense without distinguishing airtime, internet packages, or Sanduq micro-savings.
  - Does not attach system locks (`isReasonLocked`), requiring downstream heuristics to avoid incorrect user re-categorization.

#### How Our App Parses Telebirr (`telebirr_parser.dart` + `SmsBroadcastReceiver.kt`)
- **Strict Pattern Classification**: Classifies every transaction into `SmsPatternType`:
  - `standardTransfer` (P2P transfers, merchant payments)
  - `telebirrAirtime` (Airtime top-ups)
  - `telebirrPackage` (Voice, SMS, and data packages)
  - `telebirrSanduq` (Savings deposits and withdrawals)
- **Domain Layer Lock Flags**: In Layer 2 (`AppTransaction.fromParsedResult`), Airtime, Package, and Sanduq transactions are automatically locked (`isReasonLocked = true`), preventing accidental user modifications.
- **Reference IDs**: Deterministically extracts `PP...` (P2P), `CH...` (Cash In/Out), and alphanumeric payment reference IDs.

---

## 3. ZamZam Bank: SMS Patterns & Parsing Blueprint

### 3.1 Analysis of PennyWise's ZamZam Parser
PennyWise's `ZamZamBankParser.kt` supports two core SMS formats:
1. **Credit with Counterparty**:
   `"Dear Customer, your account ****1234 has been credited by John Doe with ETB 5,000.00 on 2025-12-02. Your current balance is ETB 5,000.00. Thank you for banking with us!"`
2. **Debit with Whole Amount (No Decimals)**:
   `"Dear John Doe, your account ***1234 has been debited with ETB 32000 on 2026-01-14 00:00:00.0. Your current balance is ETB 2000. Thank you for banking with us!"`

### 3.2 Necessary Adjustments for Our App
To conform to our app's **Pure Fact Contract** (`ParsedSmsResult`), the following adjustments must be made to PennyWise's logic:
1. **Deterministic Reference IDs**:
   - ZamZam SMS messages often omit a standard `FT` reference number. PennyWise relies on an MD5 body hash.
   - For our app, we must extract reference numbers if present (e.g., `Ref: ZAM...` or `Trx ID: ...`); otherwise, provide the standard deterministic fallback:
     `"ZamZam Bank_${date.millisecondsSinceEpoch}_${amount}"`.
2. **Counterparty Capture for Debits**:
   - PennyWise's parser extracts `merchant = null` for debit messages.
   - For our app, we can extract the masked account (e.g. `Account ****1234`) or recipient name as the `counterparty` so the UI does not show an empty tile.
3. **Number Formatting (Whole Numbers & Commas)**:
   - Amounts like `ETB 32000` and `ETB 2000` (without `.00`) and standard `ETB 5,000.00` must be handled cleanly.
4. **Timestamp Parsing**:
   - Dates may appear as ISO dates (`2025-12-02`) or with timestamp strings (`2026-01-14 00:00:00.0`). The parser must handle both gracefully.

---

### 3.3 Pure Fact Regex & Pattern Definitions

```dart
// 1. Credit Pattern
// "Dear Customer, your account ****1234 has been credited by <Counterparty> with ETB <Amount> on <Date>. Your current balance is ETB <Balance>..."
static final RegExp _creditPattern = RegExp(
  r'your\s+account\s+([*\d]+)\s+has\s+been\s+credited\s+by\s+(.+?)\s+with\s+ETB\s*([\d,]+(?:\.\d+)?)\s+on\s+([0-9-]{10}(?:\s+[0-9:.]+)?).*?balance\s+is\s+ETB\s*([\d,]+(?:\.\d+)?)',
  caseSensitive: false,
);

// 2. Debit Pattern
// "Dear <Name>, your account ***1234 has been debited with ETB <Amount> on <Date>. Your current balance is ETB <Balance>..."
static final RegExp _debitPattern = RegExp(
  r'your\s+account\s+([*\d]+)\s+has\s+been\s+debited\s+with\s+ETB\s*([\d,]+(?:\.\d+)?)\s+on\s+([0-9-]{10}(?:\s+[0-9:.]+)?).*?balance\s+is\s+ETB\s*([\d,]+(?:\.\d+)?)',
  caseSensitive: false,
);
```

---

### 3.4 Dart Parser Implementation Blueprint (`lib/services/zamzam_parser.dart`)

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import '../models/parsed_sms_result.dart';

class ZamZamParser {
  static const String senderName = "ZamZam Bank";

  static final RegExp _creditRegex = RegExp(
    r'your\s+account\s+([*\d]+)\s+has\s+been\s+credited\s+by\s+(.+?)\s+with\s+ETB\s*([\d,]+(?:\.\d+)?)\s+on\s+([0-9-]{10}(?:\s+[0-9:.]+)?).*?current\s+balance\s+is\s+ETB\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static final RegExp _debitRegex = RegExp(
    r'your\s+account\s+([*\d]+)\s+has\s+been\s+debited\s+with\s+ETB\s*([\d,]+(?:\.\d+)?)\s+on\s+([0-9-]{10}(?:\s+[0-9:.]+)?).*?current\s+balance\s+is\s+ETB\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static final RegExp _refRegex = RegExp(
    r'(?:Ref|Trx|Txn|Reference)[:\s]+([A-Z0-9]+)',
    caseSensitive: false,
  );

  static ParsedSmsResult? parse(String message, DateTime fallbackDate) {
    if (message.isEmpty) return null;

    final creditMatch = _creditRegex.firstMatch(message);
    if (creditMatch != null) {
      final account = creditMatch.group(1)?.trim() ?? '';
      final counterparty = creditMatch.group(2)?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
      final amount = _parseAmount(creditMatch.group(3));
      final date = _parseDate(creditMatch.group(4)) ?? fallbackDate;
      final balance = _parseAmount(creditMatch.group(5));
      final ref = _extractRef(message) ?? _generateFallbackId(senderName, date, amount);

      return ParsedSmsResult(
        id: ref,
        bankName: senderName,
        amount: amount,
        type: 'income',
        date: date,
        counterparty: counterparty.isNotEmpty ? counterparty : account,
        totalBalance: balance,
        patternType: SmsPatternType.standardTransfer,
      );
    }

    final debitMatch = _debitRegex.firstMatch(message);
    if (debitMatch != null) {
      final account = debitMatch.group(1)?.trim() ?? '';
      final amount = _parseAmount(debitMatch.group(2));
      final date = _parseDate(debitMatch.group(3)) ?? fallbackDate;
      final balance = _parseAmount(debitMatch.group(4));
      final ref = _extractRef(message) ?? _generateFallbackId(senderName, date, amount);

      return ParsedSmsResult(
        id: ref,
        bankName: senderName,
        amount: amount,
        type: 'expense',
        date: date,
        counterparty: account.isNotEmpty ? 'Account $account' : 'Debited Account',
        totalBalance: balance,
        patternType: SmsPatternType.standardTransfer,
      );
    }

    return null;
  }

  static double _parseAmount(String? val) {
    if (val == null) return 0.0;
    return double.tryParse(val.replaceAll(',', '')) ?? 0.0;
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    try {
      final clean = raw.trim();
      if (clean.length == 10) {
        return DateTime.parse(clean);
      }
      return DateTime.parse(clean.split('.')[0].replaceAll(' ', 'T'));
    } catch (_) {
      return null;
    }
  }

  static String? _extractRef(String msg) {
    final m = _refRegex.firstMatch(msg);
    return m?.group(1);
  }

  static String _generateFallbackId(String bank, DateTime date, double amount) {
    return '${bank}_${date.millisecondsSinceEpoch}_$amount';
  }
}
```

---

### 3.5 Native Kotlin Extractor Blueprint (`SmsBroadcastReceiver.kt`)

```kotlin
private fun parseZamZamSms(body: String): NativeParsedSms? {
    val creditRegex = Regex(
        """your\s+account\s+([*\d]+)\s+has\s+been\s+credited\s+by\s+(.+?)\s+with\s+ETB\s*([\d,]+(?:\.\d+)?)\s+on\s+([0-9-]{10}(?:\s+[0-9:.]+)?).*?current\s+balance\s+is\s+ETB\s*([\d,]+(?:\.\d+)?)""",
        RegexOption.IGNORE_CASE
    )
    val debitRegex = Regex(
        """your\s+account\s+([*\d]+)\s+has\s+been\s+debited\s+with\s+ETB\s*([\d,]+(?:\.\d+)?)\s+on\s+([0-9-]{10}(?:\s+[0-9:.]+)?).*?current\s+balance\s+is\s+ETB\s*([\d,]+(?:\.\d+)?)""",
        RegexOption.IGNORE_CASE
    )

    creditRegex.find(body)?.let { match ->
        val account = match.groupValues[1].trim()
        val counterparty = match.groupValues[2].replace(Regex("""\s+"""), " ").trim()
        val amount = parseDouble(match.groupValues[3]) ?: return null
        val balance = parseDouble(match.groupValues[5]) ?: 0.0
        val id = extractReference(body) ?: "ZamZam Bank_${System.currentTimeMillis()}_$amount"

        return NativeParsedSms(
            id = id,
            bankName = "ZamZam Bank",
            amount = amount,
            type = "income",
            date = System.currentTimeMillis(),
            counterparty = if (counterparty.isNotEmpty()) counterparty else account,
            totalBalance = balance,
            patternType = "standardTransfer"
        )
    }

    debitRegex.find(body)?.let { match ->
        val account = match.groupValues[1].trim()
        val amount = parseDouble(match.groupValues[2]) ?: return null
        val balance = parseDouble(match.groupValues[4]) ?: 0.0
        val id = extractReference(body) ?: "ZamZam Bank_${System.currentTimeMillis()}_$amount"

        return NativeParsedSms(
            id = id,
            bankName = "ZamZam Bank",
            amount = amount,
            type = "expense",
            date = System.currentTimeMillis(),
            counterparty = if (account.isNotEmpty()) "Account $account" else "Debited Account",
            totalBalance = balance,
            patternType = "standardTransfer"
        )
    }

    return null
}
```

---

## 4. Siket Bank: SMS Patterns & Parsing Blueprint

### 4.1 Analysis of PennyWise's Siket Parser
PennyWise's `SiketBankParser.kt` supports three distinct message formats:
1. **Credit Transaction**:
   `"Dear Siket Bank Family, Your Account 1****1234 has been Credited with ETB 30,000.00. Your Current Balance is ETB 577,453.30. Thank you for Banking with Siket Bank! For any queries call 8342."`
2. **Regular Debit Transaction**:
   `"Dear Siket Bank Family, Your Account 1****1234 has been Debited with ETB 50,000.00. Your Current Balance is ETB 315,022.41. Thank you for Banking with Siket Bank!"`
3. **Transfer Debit with Service Charge, VAT & Reference**:
   `"Dear Siket Bank Family, You have transferred ETB 10,012.00 from your account 1****1234 to telebirr account 251900000000 on 06 MAR 26 with Reference number FT00000000000. The Service Charge is ETB10.00 and VAT of ETB1.50. Your Current Balance is ETB 128,330.87. Thank you for Banking with Siket Bank."`

### 4.2 Necessary Adjustments for Our App
1. **Strict Exclusion of Service Charge and VAT**:
   - In transfer messages, the string contains three amounts: Transfer (`ETB 10,012.00`), Service Charge (`ETB10.00`), and VAT (`ETB1.50`).
   - The regex must explicitly bind to `transferred ETB <amount>` so the parser never extracts `10.00` or `1.50` as the principal transaction amount.
2. **First-Class Reference Number Extraction**:
   - For transfer messages, extract `Reference number (FT[A-Z0-9]+)` directly as the transaction `id`.
   - For standard credit/debit alerts that do not contain a reference code, fall back to the deterministic timestamp hash `"${bank}_${date.ms}_${amount}"`.
3. **Transfer Counterparty Isolation**:
   - Extract `"to (.+?) on "` (e.g., `"telebirr account 251900000000"` or destination bank account).
4. **Date Format Adaptation**:
   - Siket Bank formats transfer dates as `06 MAR 26` (Day, Month 3-letter abbreviation, 2-digit Year) or standard `DD/MM/YYYY`. The parser must handle both formats.

---

### 4.3 Pure Fact Regex & Pattern Definitions

```dart
// 1. Transfer Pattern (Highest Priority)
// "Dear Siket Bank Family, You have transferred ETB 10,012.00 from your account 1****1234 to <Counterparty> on <Date> with Reference number <Ref>. The Service Charge is ETB10.00 and VAT of ETB1.50. Your Current Balance is ETB <Balance>..."
static final RegExp _transferPattern = RegExp(
  r'transferred\s+ETB\s*([\d,]+(?:\.\d+)?)\s+from\s+your\s+account\s+([*\d]+)\s+to\s+(.+?)\s+on\s+([0-9A-Za-z\s/]+?)\s+with\s+Reference\s+number\s+([A-Z0-9]+).*?Current\s+Balance\s+is\s+ETB\s*([\d,]+(?:\.\d+)?)',
  caseSensitive: false,
);

// 2. Credit Pattern
// "Dear Siket Bank Family, Your Account 1****1234 has been Credited with ETB <Amount>(?: by <Counterparty>)?(?: on <Date>)?.*?Current Balance is ETB <Balance>..."
static final RegExp _creditPattern = RegExp(
  r'Your\s+Account\s+([*\d]+)\s+has\s+been\s+Credited\s+with\s+ETB\s*([\d,]+(?:\.\d+)?)(?:\s+by\s+(.+?)(?=\s+on|\.))?.*?Current\s+Balance\s+is\s+ETB\s*([\d,]+(?:\.\d+)?)',
  caseSensitive: false,
);

// 3. Debit Pattern
// "Dear Siket Bank Family, Your Account 1****1234 has been Debited with ETB <Amount>.*?Current Balance is ETB <Balance>..."
static final RegExp _debitPattern = RegExp(
  r'Your\s+Account\s+([*\d]+)\s+has\s+been\s+Debited\s+with\s+ETB\s*([\d,]+(?:\.\d+)?).*?Current\s+Balance\s+is\s+ETB\s*([\d,]+(?:\.\d+)?)',
  caseSensitive: false,
);
```

---

### 4.4 Dart Parser Implementation Blueprint (`lib/services/siket_parser.dart`)

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import '../models/parsed_sms_result.dart';

class SiketParser {
  static const String senderName = "Siket Bank";

  static final RegExp _transferRegex = RegExp(
    r'transferred\s+ETB\s*([\d,]+(?:\.\d+)?)\s+from\s+your\s+account\s+([*\d]+)\s+to\s+(.+?)\s+on\s+([0-9A-Za-z\s/]+?)\s+with\s+Reference\s+number\s+([A-Z0-9]+).*?Current\s+Balance\s+is\s+ETB\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static final RegExp _creditRegex = RegExp(
    r'Your\s+Account\s+([*\d]+)\s+has\s+been\s+Credited\s+with\s+ETB\s*([\d,]+(?:\.\d+)?)(?:\s+by\s+(.+?)(?=\s+on|\.))?.*?Current\s+Balance\s+is\s+ETB\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static final RegExp _debitRegex = RegExp(
    r'Your\s+Account\s+([*\d]+)\s+has\s+been\s+Debited\s+with\s+ETB\s*([\d,]+(?:\.\d+)?).*?Current\s+Balance\s+is\s+ETB\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static ParsedSmsResult? parse(String message, DateTime fallbackDate) {
    if (message.isEmpty) return null;

    // 1. Transfer check first (contains fees & VAT)
    final transferMatch = _transferRegex.firstMatch(message);
    if (transferMatch != null) {
      final amount = _parseAmount(transferMatch.group(1));
      final account = transferMatch.group(2)?.trim() ?? '';
      final counterparty = transferMatch.group(3)?.trim() ?? '';
      final rawDate = transferMatch.group(4)?.trim();
      final ref = transferMatch.group(5)?.trim() ?? '';
      final balance = _parseAmount(transferMatch.group(6));
      final date = _parseSiketDate(rawDate) ?? fallbackDate;

      return ParsedSmsResult(
        id: ref.isNotEmpty ? ref : _generateFallbackId(senderName, date, amount),
        bankName: senderName,
        amount: amount,
        type: 'expense',
        date: date,
        counterparty: counterparty.isNotEmpty ? counterparty : 'Account $account',
        totalBalance: balance,
        patternType: SmsPatternType.standardTransfer,
      );
    }

    // 2. Credit check
    final creditMatch = _creditRegex.firstMatch(message);
    if (creditMatch != null) {
      final account = creditMatch.group(1)?.trim() ?? '';
      final amount = _parseAmount(creditMatch.group(2));
      final counterparty = creditMatch.group(3)?.trim();
      final balance = _parseAmount(creditMatch.group(4));

      return ParsedSmsResult(
        id: _generateFallbackId(senderName, fallbackDate, amount),
        bankName: senderName,
        amount: amount,
        type: 'income',
        date: fallbackDate,
        counterparty: (counterparty != null && counterparty.isNotEmpty)
            ? counterparty
            : 'Account $account',
        totalBalance: balance,
        patternType: SmsPatternType.standardTransfer,
      );
    }

    // 3. Regular Debit check
    final debitMatch = _debitRegex.firstMatch(message);
    if (debitMatch != null) {
      final account = debitMatch.group(1)?.trim() ?? '';
      final amount = _parseAmount(debitMatch.group(2));
      final balance = _parseAmount(debitMatch.group(3));

      return ParsedSmsResult(
        id: _generateFallbackId(senderName, fallbackDate, amount),
        bankName: senderName,
        amount: amount,
        type: 'expense',
        date: fallbackDate,
        counterparty: account.isNotEmpty ? 'Account $account' : 'Debited Account',
        totalBalance: balance,
        patternType: SmsPatternType.standardTransfer,
      );
    }

    return null;
  }

  static double _parseAmount(String? val) {
    if (val == null) return 0.0;
    return double.tryParse(val.replaceAll(',', '')) ?? 0.0;
  }

  static DateTime? _parseSiketDate(String? raw) {
    if (raw == null) return null;
    try {
      final clean = raw.trim();
      // Format: "06 MAR 26"
      final parts = clean.split(RegExp(r'\s+'));
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]) ?? 1;
        final monthStr = parts[1].toUpperCase();
        final year2Digit = int.tryParse(parts[2]) ?? 26;
        final year = 2000 + year2Digit;

        final months = {
          'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
          'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
        };
        final month = months[monthStr] ?? 1;
        return DateTime(year, month, day);
      }
      return DateFormat("dd/MM/yyyy").parse(clean);
    } catch (_) {
      return null;
    }
  }

  static String _generateFallbackId(String bank, DateTime date, double amount) {
    return '${bank}_${date.millisecondsSinceEpoch}_$amount';
  }
}
```

---

### 4.5 Native Kotlin Extractor Blueprint (`SmsBroadcastReceiver.kt`)

```kotlin
private fun parseSiketSms(body: String): NativeParsedSms? {
    val transferRegex = Regex(
        """transferred\s+ETB\s*([\d,]+(?:\.\d+)?)\s+from\s+your\s+account\s+([*\d]+)\s+to\s+(.+?)\s+on\s+([0-9A-Za-z\s/]+?)\s+with\s+Reference\s+number\s+([A-Z0-9]+).*?Current\s+Balance\s+is\s+ETB\s*([\d,]+(?:\.\d+)?)""",
        RegexOption.IGNORE_CASE
    )
    val creditRegex = Regex(
        """Your\s+Account\s+([*\d]+)\s+has\s+been\s+Credited\s+with\s+ETB\s*([\d,]+(?:\.\d+)?)(?:\s+by\s+(.+?)(?=\s+on|\.))?.*?Current\s+Balance\s+is\s+ETB\s*([\d,]+(?:\.\d+)?)""",
        RegexOption.IGNORE_CASE
    )
    val debitRegex = Regex(
        """Your\s+Account\s+([*\d]+)\s+has\s+been\s+Debited\s+with\s+ETB\s*([\d,]+(?:\.\d+)?).*?Current\s+Balance\s+is\s+ETB\s*([\d,]+(?:\.\d+)?)""",
        RegexOption.IGNORE_CASE
    )

    transferRegex.find(body)?.let { match ->
        val amount = parseDouble(match.groupValues[1]) ?: return null
        val account = match.groupValues[2].trim()
        val counterparty = match.groupValues[3].trim()
        val ref = match.groupValues[5].trim()
        val balance = parseDouble(match.groupValues[6]) ?: 0.0

        return NativeParsedSms(
            id = if (ref.isNotEmpty()) ref else "Siket Bank_${System.currentTimeMillis()}_$amount",
            bankName = "Siket Bank",
            amount = amount,
            type = "expense",
            date = System.currentTimeMillis(),
            counterparty = if (counterparty.isNotEmpty()) counterparty else "Account $account",
            totalBalance = balance,
            patternType = "standardTransfer"
        )
    }

    creditRegex.find(body)?.let { match ->
        val account = match.groupValues[1].trim()
        val amount = parseDouble(match.groupValues[2]) ?: return null
        val counterparty = match.groupValues[3].trim()
        val balance = parseDouble(match.groupValues[4]) ?: 0.0

        return NativeParsedSms(
            id = "Siket Bank_${System.currentTimeMillis()}_$amount",
            bankName = "Siket Bank",
            amount = amount,
            type = "income",
            date = System.currentTimeMillis(),
            counterparty = if (counterparty.isNotEmpty()) counterparty else "Account $account",
            totalBalance = balance,
            patternType = "standardTransfer"
        )
    }

    debitRegex.find(body)?.let { match ->
        val account = match.groupValues[1].trim()
        val amount = parseDouble(match.groupValues[2]) ?: return null
        val balance = parseDouble(match.groupValues[3]) ?: 0.0

        return NativeParsedSms(
            id = "Siket Bank_${System.currentTimeMillis()}_$amount",
            bankName = "Siket Bank",
            amount = amount,
            type = "expense",
            date = System.currentTimeMillis(),
            counterparty = if (account.isNotEmpty()) "Account $account" else "Debited Account",
            totalBalance = balance,
            patternType = "standardTransfer"
        )
    }

    return null
}
```

---

## 5. Phone Debugging & XML Import Guide

To test and debug these transactions directly on your Android phone using your preferred SMS restore workflow, two XML backup files have been created in the `docs/` directory:

| Bank | File Location | Sender Address | Record Count | Key Scenarios Covered |
|---|---|---|:---:|---|
| **ZamZam Bank** | [`docs/ZamZam Bank.xml`](file:///c:/Users/kaleb/Documents/Mobile_Banking/docs/ZamZam%20Bank.xml) | `ZamZam Bank` | 8 | P2P Credit, Salary Credit, Whole-number Debits (`ETB 32000`), Decimal Debits, POS Payments. |
| **Siket Bank** | [`docs/Siket Bank.xml`](file:///c:/Users/kaleb/Documents/Mobile_Banking/docs/Siket%20Bank.xml) | `Siket Bank` | 8 | Large Credits, Debits, Telebirr Transfers with Service Charge + VAT isolation, Reference IDs (`FT...`). |

### How to Import on Your Phone:
1. **Transfer the Files**: Copy `ZamZam Bank.xml` and `Siket Bank.xml` to your phone's internal storage (e.g. `Downloads` or `SMSBackupRestore` folder).
2. **Open SMS Backup & Restore**: Launch the app on your phone.
3. **Select Restore**: Tap **Restore** and select the local `.xml` file.
4. **Restore Messages**: Check **Messages** and confirm.
5. **Open Mobile_Banking**: Verify that the transactions appear in the sync stream or import listener with the exact amounts, counterparties, and balances.

---

## 6. Non-Regression & Verification Matrix

When integrating `ZamZamParser` and `SiketParser` into the production codebase in future iterations, the following test verification checklist must be executed:

- [ ] **Dual-Engine Test**: Ensure Dart tests (`flutter test`) and Kotlin tests (`./gradlew :app:testDebugUnitTest`) pass with 100% success.
- [ ] **Untouchable User Space**: Verify that `note` and `customReasonText` remain unmodified during batch parsing.
- [ ] **Fee Isolation**: In Siket transfer messages, verify that `amount` equals the transfer amount (`10,012.00`) and NOT `10.00` (Service Charge) or `1.50` (VAT).
- [ ] **Zero-Decimal Handling**: In ZamZam debits, verify that `32000` is parsed as `32000.0` and balance `2000` as `2000.0`.
- [ ] **Other Banks Integrity**: Verify that CBE, Telebirr, BOA, Dashen, Ahadu, and CBE Birr parsers experience zero regressions.
