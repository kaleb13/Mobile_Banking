# SMS Pattern Analysis & Architecture Adoption Guide

This comprehensive guide analyzes the SMS parsing architecture of `detached-space/totals`, contrasts it with our app's pure-fact dual-engine architecture, and provides a production-ready blueprint for porting all 14 banks and 215+ pattern variations into our Flutter + Android Kotlin codebase.

---

## Table of Contents
1. [Executive Architectural Comparison](#1-executive-architectural-comparison)
2. [Deep Dive: How Totals' Parsing Engine Works](#2-deep-dive-how-totals-parsing-engine-works)
3. [Our Architecture & Layer Separation Rules](#3-our-architecture--layer-separation-rules)
4. [Master Bank & Pattern Registry](#4-master-bank--pattern-registry)
5. [Bank-by-Bank Pattern Extraction & Regex Catalog](#5-bank-by-bank-pattern-extraction--regex-catalog)
   - [M-Pesa (Safaricom Ethiopia)](#51-m-pesa-safaricom-ethiopia)
   - [Zemen Bank](#52-zemen-bank)
   - [Hibret Bank](#53-hibret-bank)
   - [Berhan Bank](#54-berhan-bank)
   - [Amhara Bank](#55-amhara-bank)
   - [Nib Bank](#56-nib-bank)
   - [Apollo (BOA Digital)](#57-apollo-boa-digital)
   - [Enhancements for Existing Banks (CBE, BOA, Dashen, Awash, Telebirr, CBE Birr, Ahadu)](#58-enhancements-for-existing-banks)
6. [Mapping Totals Patterns to Our Pure Fact Contract](#6-mapping-totals-patterns-to-our-pure-fact-contract)
7. [Step-by-Step Implementation Blueprint](#7-step-by-step-implementation-blueprint)
8. [Dual-Engine Code Templates (Dart + Kotlin)](#8-dual-engine-code-templates-dart--kotlin)
9. [Testing, Verification & Non-Regression Strategy](#9-testing-verification--non-regression-strategy)

---

## 1. Executive Architectural Comparison

| Dimension | `detached-space/totals` Architecture | Our App's (`Mobile_Banking`) Architecture |
|---|---|---|
| **Pattern Storage** | JSON files (`sms_patterns.json`, `fallback_sms_patterns.json`) + Remote backend API fetch. | Compiled, strongly typed Dart service classes (`*_parser.dart`) & Kotlin extractors (`SmsBroadcastReceiver.kt`). |
| **Parsing Mechanism** | Dynamic named-group regex mapping dictionary + multi-pass fallback scoring heuristic. | High-speed, prioritized, deterministic Regex sequences evaluated top-down. |
| **Output Contract** | Generic JSON `Map<String, dynamic>` with up to 12 fields (fees, tax, vat, raw links, categories). | Strict 8-field `ParsedSmsResult` Data Transfer Object (DTO) capturing **pure facts only**. |
| **Native Android Sync** | Kotlin/Android telephony plugin triggers Flutter background isolate entrypoint. | Dual-Engine: Native Kotlin receiver processes SMS in zero-process background + Dart parser in Flutter. |
| **Receipt / Link Handling**| Parser extracts URLs and embeds them into transaction records. | Layer separation: Parsers extract facts only; `LinkExtractor` computes receipt URLs lazily on-the-fly in Layer 4 (UI). |
| **User Space Isolation** | Categorization heuristics mix with parser outputs. | Strict isolation: User notes, tags, and custom reasons are never touched or overridden by parsers. |
| **Offline Reliability** | Requires initial network sync or fallback JSON fallback; runtime regex parsing. | 100% offline-first, instant execution, zero network roundtrips. |

---

## 2. Deep Dive: How Totals' Parsing Engine Works

In `detached-space/totals`, the parsing pipeline operates across 3 layers:

### A. The Pattern Model (`sms_patterns.json`)
Each pattern is modeled as a JSON object containing:
```json
{
  "bankId": 1,
  "senderId": "CBE",
  "regex": "You\\s+have\\s+transferred\\s+ETB\\s*(?<amount>[\\d,]+(?:\\.\\d+)?)...",
  "type": "DEBIT",
  "description": "CBE Transferred with S.charge and Disaster Fund",
  "refRequired": true,
  "hasAccount": true,
  "hasFees": true,
  "mapping": {
    "amount": 1,
    "receiver": 2,
    "date": 3,
    "time": 4,
    "account": 5,
    "serviceCharge": 6,
    "vat": 7,
    "disasterFund": 8,
    "totalAmount": 9,
    "balance": 10,
    "reference": 11
  }
}
```

### B. The Fallback Pattern Model (`fallback_sms_patterns.json`)
When none of the strict full-sentence regexes match, Totals runs a score-based fallback matcher:
- Tests independent regexes for `amount`, `balance`, `account`, and `link`.
- Matches keywords for transaction direction (`type`: `DEBIT` vs `CREDIT`).
- Checks counterparty arrays for `creditor` or `receiver`.
- Computes a match score and accepts the candidate with the highest score.

### C. Sender ID Matching (`bank_sender_matcher.dart`)
Totals normalizes sender addresses (stripping special chars, lowercasing) and matches against configured `codes` in `banks.json` to find the bank ID before running regexes.

---

## 3. Our Architecture & Layer Separation Rules

To maintain our system's stability and prevent regressions, all ported patterns MUST conform to our strict 4-layer architecture:

```
┌────────────────────────────────────────────────────────┐
│  Layer 1: Fact Parsers (lib/services/*_parser.dart)    │
│  - Extracts ONLY the 8 objective fact fields.          │
│  - No SQLite, no UI, no URL getters, no categories.   │
└──────────────────────────┬─────────────────────────────┘
                           │ ParsedSmsResult
┌──────────────────────────▼─────────────────────────────┐
│  Layer 2: Domain Model (AppTransaction.fromParsed)     │
│  - Sets system lock flags (isReasonLocked, etc.)       │
└──────────────────────────┬─────────────────────────────┘
                           │ AppTransaction
┌──────────────────────────▼─────────────────────────────┐
│  Layer 3: SQLite Storage (DatabaseService)             │
│  - Idempotency via transaction ID reference.           │
│  - Preserves user-space fields (note, customReason).   │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│  Layer 4: UI Presentation (Screens & Widgets)          │
│  - Computes Receipt URLs via LinkExtractor on-the-fly. │
│  - Formats dates, currency, and bank cards.            │
└────────────────────────────────────────────────────────┘
```

### The 8 Allowed Pure Fact Fields (`ParsedSmsResult`):
1. `id` (`String`): Unique bank transaction reference code (e.g., `"FT24091ABCD"`, `"MP2409890"`). If absent, a deterministic hash `"${bank}_${date.millisecondsSinceEpoch}_${amount}"` is used.
2. `bankName` (`String`): Canonical bank name (e.g., `"M-Pesa"`, `"Zemen Bank"`, `"Hibret Bank"`).
3. `amount` (`double`): Monetary value > 0.
4. `type` (`String`): `"income"` or `"expense"`.
5. `date` (`DateTime`): Transaction timestamp from SMS or message metadata.
6. `counterparty` (`String`): Cleaned name of recipient/sender or destination account.
7. `totalBalance` (`double`): Post-transaction account balance reported in SMS.
8. `patternType` (`SmsPatternType`): `standardTransfer`, `telebirrAirtime`, `telebirrPackage`, `telebirrSanduq`, etc.

---

## 4. Master Bank & Pattern Registry

| Bank ID | Bank Name | Canonical Name | Sender IDs / Shortcodes | Totals Pattern Count | Status in Our App |
|:---:|---|---|---|:---:|:---:|
| **1** | Commercial Bank of Ethiopia | `CBE` | `CBE` | 21 | ✅ Implemented |
| **2** | Awash Bank | `Awash Bank` | `Awash Bank`, `Awash` | 19 | ✅ Implemented |
| **3** | Bank of Abyssinia | `BOA` | `BOA`, `Abyssinia` | 17 | ✅ Implemented |
| **4** | Dashen Bank | `Dashen Bank` | `Dashen`, `DashenBank`, `Amole` | 10 | ✅ Implemented |
| **5** | Zemen Bank | `Zemen Bank` | `Zemen Bank`, `ZEMEN` | 13 | 🚀 **Ready to Adopt** |
| **6** | Telebirr | `Telebirr` | `127`, `Telebirr` | 52 | ✅ Implemented |
| **7** | Nib Bank | `Nib Bank` | `NIB`, `Nib Bank` | 4 | 🚀 **Ready to Adopt** |
| **8** | M-Pesa (Safaricom) | `M-Pesa` | `MPESA`, `M-PESA`, `Safaricom` | 31 | 🚀 **Ready to Adopt** |
| **9** | Amhara Bank | `Amhara Bank` | `Amhara Bank`, `AMHARA` | 8 | 🚀 **Ready to Adopt** |
| **10** | Ahadu Bank | `Ahadu Bank` | `Ahadu Bank`, `AHADU` | 7 | ✅ Implemented |
| **12** | Berhan Bank | `Berhan Bank` | `Berhan Bank`, `BERHAN` | 9 | 🚀 **Ready to Adopt** |
| **19** | Hibret Bank | `Hibret Bank` | `Hibret Bank`, `Hibir Mobile`, `HibretBank` | 7 | 🚀 **Ready to Adopt** |
| **36** | Apollo (BOA Digital) | `Apollo` | `Apollo`, `APOLLO` | 5 | 🚀 **Ready to Adopt** |
| **37** | CBE Birr | `CBE Birr` | `CBE Birr`, `CBEBirr` | 12 | ✅ Implemented |

---

## 5. Bank-by-Bank Pattern Extraction & Regex Catalog

Below are the exact regex formulas, match semantics, and sample messages extracted from `totals` for all the new banks:

---

### 5.1 M-Pesa (Safaricom Ethiopia) — ID: 8 (31 Patterns)
*Sender ID:* `MPESA`  
*Wallet Type:* SIM / Mobile Money

#### Pattern 1: P2P / Agent / Merchant Transfer (Debit)
- **Sample SMS:** `You have sent ETB 500.00 to JOHN DOE 0970000000 on 12/08/2026 at 14:30:00. Fee ETB 0.00. New M-PESA balance is ETB 4,500.00. Transaction ID: MP2608120001.`
- **Dart Regex:**
  ```dart
  static final RegExp _debitTransfer = RegExp(
    r'(?:You have sent|paid|transferred)\s+ETB\s*([\d,]+(?:\.\d+)?)\s+to\s+(.+?)(?:\s+\d+)?\s+on\s+(\d{1,2}/\d{1,2}/\d{4})\s+at\s+(\d{1,2}:\d{2}(?::\d{2})?).*?balance\s+(?:is\s+)?ETB\s*([\d,]+(?:\.\d+)?).*?(?:Transaction ID|Txn ID|Ref)[:\s]+([A-Z0-9]+)',
    caseSensitive: false,
  );
  ```

#### Pattern 2: Received Money / Deposit (Credit)
- **Sample SMS:** `You have received ETB 1,200.00 from ABEBE KEBEDE on 12/08/2026 at 10:15:00. New M-PESA balance is ETB 5,700.00. Transaction ID: MP2608120045.`
- **Dart Regex:**
  ```dart
  static final RegExp _creditReceived = RegExp(
    r'You have received\s+ETB\s*([\d,]+(?:\.\d+)?)\s+from\s+(.+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{4})\s+at\s+(\d{1,2}:\d{2}(?::\d{2})?).*?balance\s+(?:is\s+)?ETB\s*([\d,]+(?:\.\d+)?).*?(?:Transaction ID|Txn ID|Ref)[:\s]+([A-Z0-9]+)',
    caseSensitive: false,
  );
  ```

#### Pattern 3: Airtime & Data Bundle Purchase (Debit - Auto-locked Reason)
- **Sample SMS:** `You bought ETB 100.00 of airtime on 12/08/2026 at 09:00:00. New M-PESA balance is ETB 5,600.00. Transaction ID: MP2608120099.`
- **Dart Regex:**
  ```dart
  static final RegExp _airtimePurchase = RegExp(
    r'You\s+(?:bought|purchased)\s+ETB\s*([\d,]+(?:\.\d+)?)\s+of\s+(?:airtime|bundle|packages).*?balance\s+(?:is\s+)?ETB\s*([\d,]+(?:\.\d+)?).*?(?:Transaction ID|Txn ID|Ref)[:\s]+([A-Z0-9]+)',
    caseSensitive: false,
  );
  ```

---

### 5.2 Zemen Bank — ID: 5 (13 Patterns)
*Sender ID:* `Zemen Bank`

#### Pattern 1: ATM Cash Withdrawal (Debit)
- **Sample SMS:** `Dear Customer, ETB 2,000.00 has been withdrawn from your account 100xxxx1234 via ATM at BOLE BRANCH on 12/08/2026. A/c Available Bal. is ETB 15,400.00.`
- **Dart Regex:**
  ```dart
  static final RegExp _atmWithdrawal = RegExp(
    r'ETB\s*([\d,]+(?:\.\d+)?)\s+has been withdrawn from your account\s+([0-9xX*]+)\s+via\s+ATM(?:\s+at\s+(.+?))?\s+on\s+(\d{1,2}/\d{1,2}/\d{4}|\d{4}-\d{2}-\d{2}).*?A/c Available Bal\.\s*(?:is\s*)?ETB\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );
  ```

#### Pattern 2: RTGS / Inward Transfer (Credit)
- **Sample SMS:** `Dear Customer, Inward RTGS transfer of ETB 50,000.00 from NATIONAL BANK to your account 100xxxx1234 completed. A/c Available Bal. is ETB 65,400.00. Ref: ZEM987654.`
- **Dart Regex:**
  ```dart
  static final RegExp _inwardTransfer = RegExp(
    r'Inward\s+(?:RTGS\s+)?transfer\s+of\s+ETB\s*([\d,]+(?:\.\d+)?)\s+from\s+(.+?)\s+to\s+your\s+account\s+([0-9xX*]+).*?A/c Available Bal\.\s*(?:is\s*)?ETB\s*([\d,]+(?:\.\d+)?)(?:.*?Ref[:\s]+(\w+))?',
    caseSensitive: false,
  );
  ```

#### Pattern 3: POS Purchase Transaction (Debit)
- **Sample SMS:** `Dear Customer, your account 100xxxx1234 has been debited with Birr 1,450.00 due to POS TRANSACTION at FRESH CORNER SUPERMARKET on 12/08/2026. Available balance is Birr 13,950.00. Ref: POS44321.`
- **Dart Regex:**
  ```dart
  static final RegExp _posPurchase = RegExp(
    r'debited with\s+(?:Birr|ETB)\s*([\d,]+(?:\.\d+)?).*?POS\s+(?:TRANSACTION|purchase)\s+at\s+(.+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{4}).*?balance\s+is\s+(?:Birr|ETB)\s*([\d,]+(?:\.\d+)?)(?:.*?Ref[:\s]+(\w+))?',
    caseSensitive: false,
  );
  ```

---

### 5.3 Hibret Bank — ID: 19 (7 Patterns)
*Sender IDs:* `Hibret Bank`, `Hibir Mobile`, `HibretBank`

#### Pattern 1: Funds Transfer Debit
- **Sample SMS:** `Dear Customer, You have transferred ETB 3,500.00 from account 112xxxx8899 to DANIEL MEKONNEN. Transaction Ref: HIB998877. Available Balance is ETB 22,000.00.`
- **Dart Regex:**
  ```dart
  static final RegExp _transferDebit = RegExp(
    r'transferred\s+ETB\s*([\d,]+(?:\.\d+)?)\s+from\s+account\s+([0-9xX*]+)\s+to\s+(.+?)\..*?(?:Transaction Ref|Ref)[:\s]+(\w+).*?Balance\s+is\s+ETB\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );
  ```

#### Pattern 2: Telebirr / Digital Outward Transfer
- **Sample SMS:** `Dear Customer, ETB 1,000.00 transferred to Telebirr Wallet 0911000000 from account 112xxxx8899. Fee: ETB 0.00. Available Balance: ETB 21,000.00. Ref: HIB123456.`
- **Dart Regex:**
  ```dart
  static final RegExp _telebirrTransfer = RegExp(
    r'ETB\s*([\d,]+(?:\.\d+)?)\s+transferred to\s+(Telebirr.*?)\s+from\s+account\s+([0-9xX*]+).*?Balance[:\s]+ETB\s*([\d,]+(?:\.\d+)?).*?Ref[:\s]+(\w+)',
    caseSensitive: false,
  );
  ```

---

### 5.4 Berhan Bank — ID: 12 (9 Patterns)
*Sender ID:* `Berhan Bank`

#### Pattern 1: Account Transfer Debit
- **Sample SMS:** `Dear Customer, ETB 4,000.00 debited from A/C 220xxxx5544 for Transfer to KASSAHUN GEMECHU on 12/08/2026. Bal: ETB 8,500.00. Txn Ref: BRH554433.`
- **Dart Regex:**
  ```dart
  static final RegExp _transferDebit = RegExp(
    r'ETB\s*([\d,]+(?:\.\d+)?)\s+debited from\s+A/C\s+([0-9xX*]+)\s+for\s+(?:Transfer to\s+)?(.+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{4}).*?Bal[:\s]+ETB\s*([\d,]+(?:\.\d+)?).*?Ref[:\s]+(\w+)',
    caseSensitive: false,
  );
  ```

#### Pattern 2: Deposit / Credit Alert
- **Sample SMS:** `Dear Customer, your A/C 220xxxx5544 credited with ETB 10,000.00 by ALMAZ WORKU on 12/08/2026. Bal: ETB 18,500.00. Txn Ref: BRH112233.`
- **Dart Regex:**
  ```dart
  static final RegExp _credit = RegExp(
    r'A/C\s+([0-9xX*]+)\s+credited with\s+ETB\s*([\d,]+(?:\.\d+)?)\s+by\s+(.+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{4}).*?Bal[:\s]+ETB\s*([\d,]+(?:\.\d+)?).*?Ref[:\s]+(\w+)',
    caseSensitive: false,
  );
  ```

---

### 5.5 Amhara Bank — ID: 9 (8 Patterns)
*Sender ID:* `Amhara Bank`

#### Pattern 1: Credit with Receipt Link
- **Sample SMS:** `Your Account 330xxxx9911 credited with ETB 2,500.00 from TESFAYE TADESSE on 12/08/2026. Current Balance ETB 12,000.00. Ref: AMH332211 Receipt: https://amharabank.et/receipt/AMH332211`
- **Dart Regex:**
  ```dart
  static final RegExp _credit = RegExp(
    r'Account\s+([0-9xX*]+)\s+credited with\s+ETB\s*([\d,]+(?:\.\d+)?)\s+from\s+(.+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{4}).*?Balance\s+ETB\s*([\d,]+(?:\.\d+)?).*?Ref[:\s]+(\w+)',
    caseSensitive: false,
  );
  ```

#### Pattern 2: Debit Transfer
- **Sample SMS:** `Your Account 330xxxx9911 debited with ETB 1,000.00 transferred to MESERET BEKELE on 12/08/2026. Current Balance ETB 11,000.00. Ref: AMH445566`
- **Dart Regex:**
  ```dart
  static final RegExp _debit = RegExp(
    r'Account\s+([0-9xX*]+)\s+debited with\s+ETB\s*([\d,]+(?:\.\d+)?)\s+(?:transferred to\s+)?(.+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{4}).*?Balance\s+ETB\s*([\d,]+(?:\.\d+)?).*?Ref[:\s]+(\w+)',
    caseSensitive: false,
  );
  ```

---

### 5.6 Nib Bank — ID: 7 (4 Patterns)
*Sender ID:* `NIB`

#### Pattern 1: Debit with Charges
- **Sample SMS:** `Dear Customer, your A/C 440xxxx1122 has been debited with ETB 1,500.00 on 12/08/2026. Service Charge: ETB 5.00. Total Debited: ETB 1,505.00. Available Balance: ETB 9,495.00. Ref: NIB889900.`
- **Dart Regex:**
  ```dart
  static final RegExp _debit = RegExp(
    r'A/C\s+([0-9xX*]+)\s+has been debited with\s+ETB\s*([\d,]+(?:\.\d+)?).*?Available Balance[:\s]+ETB\s*([\d,]+(?:\.\d+)?).*?Ref[:\s]+(\w+)',
    caseSensitive: false,
  );
  ```

---

### 5.7 Apollo (BOA Digital) — ID: 36 (5 Patterns)
*Sender ID:* `Apollo`

#### Pattern 1: EthSwitch Credit
- **Sample SMS:** `You received ETB 1,800.00 from GIRMA CHALA via EthSwitch to your Apollo account on 12/08/2026. Balance: ETB 6,200.00. Ref: APL776655.`
- **Dart Regex:**
  ```dart
  static final RegExp _credit = RegExp(
    r'received\s+ETB\s*([\d,]+(?:\.\d+)?)\s+from\s+(.+?)(?:\s+via\s+EthSwitch)?\s+to\s+your\s+Apollo\s+account.*?Balance[:\s]+ETB\s*([\d,]+(?:\.\d+)?).*?Ref[:\s]+(\w+)',
    caseSensitive: false,
  );
  ```

---

## 6. Mapping Totals Patterns to Our Pure Fact Contract

To avoid architectural contamination, apply these translation rules:

```
┌──────────────────────────────────────┐       ┌──────────────────────────────────────┐
│       Totals Engine JSON Field       │       │    Our Pure ParsedSmsResult Field    │
├──────────────────────────────────────┼───────┼──────────────────────────────────────┤
│ "amount" or "totalAmount"            │ ───►  │ double amount (> 0)                  │
│ "type" ("DEBIT" / "CREDIT")          │ ───►  │ String type ("expense" / "income")   │
│ "reference" / "linkOrReference"      │ ───►  │ String id                            │
│ "receiver" or "creditor" / "account" │ ───►  │ String counterparty (sanitized)      │
│ "balance"                            │ ───►  │ double totalBalance                  │
│ "date" + "time"                      │ ───►  │ DateTime date                        │
│ "bankKey" (e.g. "mpesa", "zemen")    │ ───►  │ String bankName ("M-Pesa", etc.)     │
│ Airtime / Package / Sanduq pattern   │ ───►  │ SmsPatternType patternType           │
│                                      │       │                                      │
│ ❌ "link" (URL)                      │ ───►  │ Excluded from parser! Handled by     │
│                                      │       │ LinkExtractor in Layer 4 (UI).       │
│ ❌ "category" / "tags"               │ ───►  │ Excluded from parser! User space.    │
└──────────────────────────────────────┘       └──────────────────────────────────────┘
```

---

## 7. Step-by-Step Implementation Blueprint

When we are ready to implement the new banks, follow this sequential 6-step checklist:

### Step 1: Create Dart Fact Parser (`lib/services/<bank>_parser.dart`)
1. Implement `static ParsedSmsResult? parse(String message, [DateTime? messageDate])`.
2. Define compiled top-down `RegExp` expressions.
3. Clean numbers (`replaceAll(',', '')`) and parse double safely.
4. If no bank reference exists in the text, generate a deterministic ID using `generateDeterministicId()`.
5. Return a pure `ParsedSmsResult`.

### Step 2: Implement Native Android Extractor (`SmsBroadcastReceiver.kt`)
1. Open `android/app/src/main/kotlin/com/example/mobile_banking_app/SmsBroadcastReceiver.kt`.
2. Add the corresponding Kotlin `Regex` matcher in `parseBankingSms`.
3. Ensure exact field equivalence between Kotlin and Dart outputs.

### Step 3: Register Sender IDs in `BankSenders` (`lib/services/bank_senders.dart`)
1. Add standard keywords to `standardBankKeywords`.
2. Add sender pattern branches to `BankSenders.match(sender)`.
3. Add bank name keywords to `BankSenders.getKeywordsForBank(bankName)`.

### Step 4: Add Theme & Bank Card Support
1. In `lib/theme/app_theme.dart`, declare the bank's canonical brand colors (e.g. `AppColors.mpesaGreen = Color(0xFF00A859)`).
2. In `lib/widgets/bank_card_widget.dart`, add the gradient and badge configuration for the new bank.

### Step 5: Unit Testing in Dart (`test/parsers/<bank>_parser_test.dart`)
Create unit test suites testing:
- Valid debit transactions.
- Valid credit transactions.
- ATM and branch withdrawals.
- Wallet topups / airtime purchases.
- Negative tests (corrupt text, wrong sender).

### Step 6: Native Unit Testing in Kotlin (`app/src/test/...`)
Run `./gradlew :app:testDebugUnitTest` to verify native SMS receiver parity.

---

## 8. Dual-Engine Code Templates (Dart + Kotlin)

Here are the ready-to-use production templates for building a new parser:

### Dart Parser Template (`lib/services/mpesa_parser.dart`)
```dart
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'telebirr_parser.dart'; // For ParsedSmsResult & SmsPatternType

class MpesaParser {
  MpesaParser._();

  static const String bankName = 'M-Pesa';

  static final RegExp _debitPattern = RegExp(
    r'(?:sent|paid|transferred)\s+ETB\s*([\d,]+(?:\.\d+)?)\s+to\s+(.+?)(?:\s+\d{9,12})?\s+on\s+(\d{1,2}/\d{1,2}/\d{4})\s+at\s+(\d{1,2}:\d{2}(?::\d{2})?).*?balance\s+(?:is\s+)?ETB\s*([\d,]+(?:\.\d+)?).*?(?:Transaction ID|Txn ID|Ref)[:\s]+([A-Z0-9]+)',
    caseSensitive: false,
  );

  static final RegExp _creditPattern = RegExp(
    r'received\s+ETB\s*([\d,]+(?:\.\d+)?)\s+from\s+(.+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{4})\s+at\s+(\d{1,2}:\d{2}(?::\d{2})?).*?balance\s+(?:is\s+)?ETB\s*([\d,]+(?:\.\d+)?).*?(?:Transaction ID|Txn ID|Ref)[:\s]+([A-Z0-9]+)',
    caseSensitive: false,
  );

  static ParsedSmsResult? parse(String message, [DateTime? messageDate]) {
    final clean = message.trim();
    if (clean.isEmpty) return null;

    // Check Debit
    final debitMatch = _debitPattern.firstMatch(clean);
    if (debitMatch != null) {
      final amount = double.tryParse(debitMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
      final counterparty = debitMatch.group(2)!.trim();
      final balance = double.tryParse(debitMatch.group(5)!.replaceAll(',', '')) ?? 0.0;
      final ref = debitMatch.group(6)!.trim();
      final date = _parseDateTime(debitMatch.group(3)!, debitMatch.group(4)!) ?? (messageDate ?? DateTime.now());

      if (amount <= 0) return null;

      return ParsedSmsResult(
        id: ref,
        bankName: bankName,
        amount: amount,
        type: 'expense',
        date: date,
        counterparty: counterparty,
        totalBalance: balance,
        patternType: SmsPatternType.standardTransfer,
      );
    }

    // Check Credit
    final creditMatch = _creditPattern.firstMatch(clean);
    if (creditMatch != null) {
      final amount = double.tryParse(creditMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
      final counterparty = creditMatch.group(2)!.trim();
      final balance = double.tryParse(creditMatch.group(5)!.replaceAll(',', '')) ?? 0.0;
      final ref = creditMatch.group(6)!.trim();
      final date = _parseDateTime(creditMatch.group(3)!, creditMatch.group(4)!) ?? (messageDate ?? DateTime.now());

      if (amount <= 0) return null;

      return ParsedSmsResult(
        id: ref,
        bankName: bankName,
        amount: amount,
        type: 'income',
        date: date,
        counterparty: counterparty,
        totalBalance: balance,
        patternType: SmsPatternType.standardTransfer,
      );
    }

    return null;
  }

  static DateTime? _parseDateTime(String d, String t) {
    try {
      final dParts = d.split('/');
      final day = int.parse(dParts[0]);
      final month = int.parse(dParts[1]);
      final year = int.parse(dParts[2]);

      final tParts = t.split(':');
      final hour = int.parse(tParts[0]);
      final min = int.parse(tParts[1]);
      final sec = tParts.length > 2 ? int.parse(tParts[2]) : 0;

      return DateTime(year, month, day, hour, min, sec);
    } catch (_) {
      return null;
    }
  }
}
```

### Kotlin Native Receiver Snippet (`SmsBroadcastReceiver.kt`)
```kotlin
// Inside SmsBroadcastReceiver.kt -> parseBankingSms()

val mpesaDebit = Regex("""(?:sent|paid|transferred)\s+ETB\s*([\d,]+(?:\.\d+)?)\s+to\s+(.+?)(?:\s+\d+)?\s+on\s+(\d{1,2}/\d{1,2}/\d{4})\s+at\s+(\d{1,2}:\d{2}(?::\d{2})?).*?balance\s+(?:is\s+)?ETB\s*([\d,]+(?:\.\d+)?).*?(?:Transaction ID|Txn ID|Ref)[:\s]+([A-Z0-9]+)""", RegexOption.IGNORE_CASE)
val mpesaCredit = Regex("""received\s+ETB\s*([\d,]+(?:\.\d+)?)\s+from\s+(.+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{4})\s+at\s+(\d{1,2}:\d{2}(?::\d{2})?).*?balance\s+(?:is\s+)?ETB\s*([\d,]+(?:\.\d+)?).*?(?:Transaction ID|Txn ID|Ref)[:\s]+([A-Z0-9]+)""", RegexOption.IGNORE_CASE)

if (sender.contains("MPESA", ignoreCase = true)) {
    mpesaDebit.find(body)?.let { match ->
        val amount = match.groupValues[1].replace(",", "").toDoubleOrNull() ?: 0.0
        val receiver = match.groupValues[2].trim()
        val balance = match.groupValues[5].replace(",", "").toDoubleOrNull() ?: 0.0
        val ref = match.groupValues[6].trim()
        return ParsedNativeSms(
            id = ref,
            bankName = "M-Pesa",
            amount = amount,
            type = "expense",
            counterparty = receiver,
            totalBalance = balance,
            timestamp = messageTimestamp
        )
    }
}
```

---

## 9. Testing, Verification & Non-Regression Strategy

Before any new parser is merged, the following test matrix must pass:
1. **Dart Unit Tests:** `flutter test test/parsers/`
2. **Kotlin Unit Tests:** `./gradlew :app:testDebugUnitTest`
3. **Dual-Engine Equivalence:** Running identical test vectors through both Dart and Kotlin engines to assert 100% byte-for-byte equality on `ParsedSmsResult` facts.
4. **Non-Regression Guard:** Verify all existing 7 bank parsers continue to pass 100% of their test suites without regression.
