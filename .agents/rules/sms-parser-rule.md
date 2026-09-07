---
trigger: always_on
---

# SMS Parsing, Architectural Integrity & Layer Separation Rules

## 1. Pure Fact Parsing Contract (`ParsedSmsResult` Only)
- **Fact-Only Extraction**: SMS Parsers (`TelebirrParser`, `CbeParser`, `BoaParser`, `AhaduParser`, `DashenParser`, `CbeBirrParser`) MUST ONLY extract objective facts into the pure `ParsedSmsResult` DTO.
- **The 8 Allowed Fields**:
  1. `id`: String (Unique bank transaction reference code)
  2. `bankName`: String (e.g., "Ahadu Bank", "Telebirr", "CBE")
  3. `amount`: double (Monetary value > 0)
  4. `type`: String ("income" or "expense")
  5. `date`: DateTime (Transaction timestamp)
  6. `counterparty`: String (Sender, receiver, or account number)
  7. `totalBalance`: double (Post-transaction balance reported in SMS)
  8. `patternType`: SmsPatternType (`standardTransfer`, `telebirrAirtime`, `telebirrPackage`, `telebirrSanduq`)
- **Prohibited Parser Outputs**: Parsers MUST NEVER extract, output, or store derived UI getters (e.g. Receipt URLs, button configurations) or categorization logic. Receipt URLs belong exclusively to computed getters on `AppTransaction` (`LinkExtractor`), not the parser.

## 2. Strict Layer Separation
When working on the application, strictly enforce the 4-layer boundary:
1. **Layer 1: Fact Parsers (`lib/services/*_parser.dart`)**: Extract only the 8 objective facts above. Zero database, UI, or reason logic.
2. **Layer 2: Domain Enrichment (`AppTransaction.fromParsedResult`)**: Transforms facts into domain models. Attaches system lock flags (`isReasonLocked`) for Airtime, Package, Sanduq, and Loans.
3. **Layer 3: SQLite Storage & Idempotency (`DatabaseService`)**: Persists pure transaction rows. User-space fields (`note`, `customReasonText`) are preserved and never overwritten by parsers.
4. **Layer 4: Presentation & UI (`lib/screens/`, `lib/widgets/`)**:
   - URL links are extracted on-the-fly via `LinkExtractor.extractUrls(rawMessage)` only when displaying the UI.
   - Reason linking buttons and chevrons MUST NEVER render on locked transactions.

## 3. Untouchable User Space
- **`note` and `customReasonText`**: These fields are strictly reserved for manual user entry.
- Parsers, auto-detection routines, and isolate batch processors are strictly forbidden from populating or overriding these fields.

## 4. Dual-Engine Consistency (Dart & Kotlin Native)
- Whenever a banking pattern, regex, or logic change is made to a Dart parser, the corresponding native Android extractor in `SmsBroadcastReceiver.kt` (`parseBankingSms`) MUST be updated in lockstep.
- **Verification Requirement**: Both `flutter test` (Dart unit/integration tests) and `./gradlew :app:testDebugUnitTest` (Kotlin unit tests) must pass with 100% success before any task is considered complete.

## 5. Architectural Non-Regression Guardrails
- Modifying one bank's parser must never alter the parser table, database schema, or behavior of the other 5 banks.
- When the user asks "Can the app read this message?", output ONLY the exact `ParsedSmsResult` facts. Do not invent extra fields or mix in downstream UI/reason actions unless explicitly instructed.

## 6. System-Wide Domain Vocabulary Contract (AI & Human Alignment)
To prevent semantic confusion and misinterpretation across the codebase:
- **Bank / Provider Identity (`tx.bankName` / `AppSender.bankName`)**: The financial institution (e.g. Telebirr, CBE, Bunna Bank). NEVER use `tx.counterparty` or `tx.sender` to determine bank identity.
- **Counterparty (`tx.counterparty` / `AppReasonLink.counterpartyName`)**: The human, merchant, or phone number on the other side of the transaction (e.g., Abebe Bikila, Ethio Telecom).
- **Wallet Container (`AppSender`)**: Represents a bank account or wallet container in the Wallets screen and DB. `sender.bankName` provides a clean alias for `sender.senderName`.
- **Reason vs Category (`AppReason`)**:
  - `AppReason` with `parentId == null && !isSpecial` is a top-level **Category** (Food, Transport, Salary).
  - `AppReason` with `parentId != null` is a **Subcategory** (Groceries, Fuel).
  - `AppReason` with `isSpecial == true` represents **Flow Mechanics** (Internal Transfer, Cash Withdrawal/Deposit, Loan, Pass-Through).
  - On `AppTransaction`, `tx.sourceTag` (with `category` as backward-compat alias) indicates transaction intake origin (`'Auto'` for SMS, `'Manual'` for user entry). The true user category is `tx.resolvedCategory` or resolved via `tx.categoryId`.
- **Cash Transaction Types (`CashTransaction.isIncome` / `isExpense`)**:
  - `CashTransaction` uses `'income'` for inflow and `'expense'` for outflow (with transparent backward-compat decoding of legacy `'addition'`). ALWAYS use `.isIncome` or `.isExpense` helpers.
- **Auto-Link Direction (`AppReasonLink.isIncome` / `isExpense`)**:
  - `linkType == 'sender'` means **Income** (counterparty was payer).
  - `linkType == 'receiver'` means **Expense** (counterparty was recipient).
  - ALWAYS use `.isIncome` or `.isExpense` getters on `AppReasonLink`.
- **Loan Tracking (`LoanRecord.monitoredBanks` vs `LoanRepaymentRequest.counterpartyFound`)**:
  - In `LoanRecord`, `monitoredBanks` (with `trackedSenderName` backward-compat alias) stores monitored **Bank Channels** (e.g. `"Telebirr, CBE"`).
  - In `LoanRepaymentRequest`, `counterpartyFound` (with `senderFound` backward-compat alias) stores the **Counterparty / Borrower** name parsed from SMS.
