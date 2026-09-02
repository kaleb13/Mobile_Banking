# Bank Integration Master Specification & Architectural Checklist

This document is the mandatory rulebook and checklist for adding any banking institution (e.g. Telebirr, CBE, CBE Birr, Ahadu, BOA, Dashen, Awash, Zemen, Nib, Amhara, etc.) to Shibre. Whenever adding a new bank, **ALL 14 INTEGRATION POINTS** below MUST be implemented without omission.

---

## The 14-Point Bank Integration Checklist

```
[1]  Fact Parser (Dart)                  -> lib/services/<bank>_parser.dart
[2]  Native Background Receiver (Kotlin)  -> android/app/src/.../SmsBroadcastReceiver.kt
[3]  Sender Normalization & Registry      -> lib/services/bank_senders.dart
[4]  Isolate Batch Parser Loop            -> lib/services/sms_batch_parser.dart
[5]  Design System Palette & Colors       -> lib/theme/app_theme.dart
[6]  Standardized Bank Avatar Widget      -> lib/widgets/bank_avatar.dart
[7]  Standardized Bank Card Widget        -> lib/widgets/bank_card_widget.dart
[8]  Bank Detail Info Metadata Panel      -> lib/screens/dashboard/bank_detail/bank_metadata.dart
[9]  Transaction Detail Sheet Info Header -> lib/screens/dashboard/transaction_detail_screen.dart (_getBankInfo)
[10] Dashboard Recent Transactions Avatar -> lib/screens/dashboard/dashboard_screen.dart (_buildBankAvatarSmallWhite & _getBankIconSmall)
[11] All Transactions Screen Dark Avatar  -> lib/screens/dashboard/all_transactions_screen.dart (_buildDarkBankAvatar)
[12] Transaction Search Screen Avatar     -> lib/screens/dashboard/transaction_search_screen.dart (_buildBankAvatarSmallWhite)
[13] Analytics & Wallets Breakdown Filter -> lib/screens/dashboard/analysis_screen.dart (_normalizeBankName, _matchesBank, bankMap)
[14] Onboarding & Privacy Disclosures     -> lib/screens/intro/onboarding_screen.dart & privacy_policy_screen.dart
[15] Comprehensive Unit Test Suite       -> test/unit/<bank>_parser_test.dart & test/bank_senders_test.dart
```

---

## 1. Do's and Don'ts

### DO:
1. **Always use pure fact extraction** in the parser returning only the 8 permitted fields of `ParsedSmsResult`.
2. **Always extract the primary brand color directly from the official bank SVG logo** (`assets/images/<Bank>_Logo.svg`).
3. **Always create the card gradient** using a brighter tint at the start (`#...`) and the brand logo color at the end.
4. **Always create the transparent circular avatar background** using `AppColors.card<Bank>Dark.withValues(alpha: 0.12)` on light surfaces and `0.35` on dark surfaces.
5. **Always implement the dual-engine Kotlin extractor in `SmsBroadcastReceiver.kt`** with identical regex and facts.
6. **Always register `_getBankInfo()` in `transaction_detail_screen.dart`** so the bank header inside the transaction detail sheet shows the official logo, title, and "SMS received from <Bank>" subtitle.

### DON'T:
1. **NEVER** use borders, border strokes, or outlines (`Border.all`, `BorderSide`, stroked `OutlineInputBorder`).
2. **NEVER** use non-pill buttons (all buttons MUST be fully rounded pills `borderRadius: 100` / `StadiumBorder`).
3. **NEVER** allow a bank transaction to fall into the generic fallback (`Icon(Icons.account_balance)`) on any screen.
4. **NEVER** add UI getters, receipt URLs, or custom notes into the parser DTO (`ParsedSmsResult`).
5. **NEVER** modify other banks' parsers or SQLite schemas when adding a new bank.

---

## 2. Detailed Implementation Blueprint for Every Bank

### Point 1: Dart Fact Parser (`lib/services/<bank>_parser.dart`)
- Implement `<Bank>Parser.parse(String message, DateTime fallbackDate)` returning `ParsedSmsResult?`.
- Implement `<Bank>Parser.extractOwnerName(String message)`.
- Use deterministic SHA-256 fallback IDs formatted as `<BANK>-<HASH16>`.

### Point 2: Dual-Engine Kotlin Native Extractor (`SmsBroadcastReceiver.kt`)
- Add shortcodes and sender IDs to `BANK_SENDERS` map and `matchBankSender`.
- Add prefix to `computeFallbackId`.
- Add `<Bank>` case in `parseBankingSms` with `NativeParsedSms`.

### Point 3: Sender Registry (`lib/services/bank_senders.dart`)
- Add match keyword in `match(sender)`.
- Add keyword search list in `getKeywordsForBank(bankName)`.

### Point 4: Isolate Batch Parser (`lib/services/sms_batch_parser.dart`)
- Import `<bank>_parser.dart`.
- Add `<Bank>Parser.extractOwnerName` and `<Bank>Parser.parse` in `_parseInternal`.

### Point 5: Color Palette (`lib/theme/app_theme.dart`)
```dart
static const Color card<Bank>Dark     = Color(0xFF...); // Base brand color from SVG logo
static const Color card<Bank>Light    = Color(0xFF...); // Luminous gradient highlight
static const Color card<Bank>DarkIcon = Color(0xFF...); // Deep icon tone
```

### Point 6: Bank Avatar Widget (`lib/widgets/bank_avatar.dart`)
```dart
} else if (nameUp.contains('<BANK>')) {
  img = SvgPicture.asset(
    'assets/images/<Bank>_Logo.svg',
    width: iconSize * 1.15,
    height: iconSize * 1.15,
    fit: BoxFit.contain,
    colorFilter: isLight ? null : const ColorFilter.mode(Colors.white, BlendMode.srcIn),
  );
  bgColor = isLight
      ? AppColors.card<Bank>Dark.withValues(alpha: 0.12)
      : AppColors.card<Bank>Dark.withValues(alpha: 0.35);
}
```

### Point 7: Bank Card Widget (`lib/widgets/bank_card_widget.dart`)
- In `buildBankIcon`: Return SVG with white filter on gradient and brand color on light surface.
- In `subtitle`: Return official full legal name e.g. `'<Bank> Bank S.C.'`.
- In `getCardGradient`: Return `[AppColors.card<Bank>Light, AppColors.card<Bank>Dark]`.

### Point 8: Bank Metadata Panel (`lib/screens/dashboard/bank_detail/bank_metadata.dart`)
```dart
} else if (nameUp.contains('<BANK>')) {
  return BankInfoData(
    bankName: name,
    displayName: '<Bank> Bank',
    title: '<Bank> Bank S.C.',
    subtitle: '<Bank> Bank S.C.',
    badgeLabel: 'COMMERCIAL BANK · SMS PARSED',
    badgeIcon: Icons.account_balance_rounded,
    description: 'Automated transaction ledger tracking and real-time balance reconciliation for <Bank> Bank SMS notifications.',
    behindGradient: unifiedGradient,
    isDarkTextTheme: isDark,
  );
}
```

### Point 9: Transaction Detail Screen Info Header (`lib/screens/dashboard/transaction_detail_screen.dart`)
```dart
} else if (combined.contains('<BANK>')) {
  bg = AppColors.card<Bank>Dark.withValues(alpha: 0.15);
  iconWidget = SvgPicture.asset(
    'assets/images/<Bank>_Logo.svg',
    width: 24,
    height: 24,
    fit: BoxFit.contain,
  );
  bankName = '<Bank> Bank S.C.';
  shortName = '<Bank>';
}
```

### Point 10: Dashboard Recent Transactions Avatar (`lib/screens/dashboard/dashboard_screen.dart`)
- `_buildBankAvatarSmallWhite`:
  ```dart
  } else if (nameUp.contains('<BANK>')) {
    img = SvgPicture.asset('assets/images/<Bank>_Logo.svg', width: 24, height: 24, fit: BoxFit.contain);
    bgColor = AppColors.card<Bank>Dark.withValues(alpha: 0.12);
  }
  ```
- `_getBankIconSmall`:
  ```dart
  } else if (nameUp.contains('<BANK>')) {
    return SvgPicture.asset('assets/images/<Bank>_Logo.svg', width: size, height: size, fit: BoxFit.contain, colorFilter: overrideColor != null ? ColorFilter.mode(overrideColor, BlendMode.srcIn) : null);
  }
  ```

### Point 11: All Transactions Screen Avatar (`lib/screens/dashboard/all_transactions_screen.dart`)
- `_buildDarkBankAvatar`:
  ```dart
  } else if (nameUp.contains('<BANK>')) {
    assetPath = 'assets/images/<Bank>_Logo.svg';
    isSvg = true;
  }
  ```

### Point 12: Transaction Search Screen Avatar (`lib/screens/dashboard/transaction_search_screen.dart`)
- `_buildBankAvatarSmallWhite`:
  ```dart
  } else if (nameUp.contains('<BANK>')) {
    img = SvgPicture.asset('assets/images/<Bank>_Logo.svg', width: 24, height: 24, fit: BoxFit.contain);
    bgColor = AppColors.card<Bank>Dark.withValues(alpha: 0.12);
  }
  ```

### Point 13: Analytics & Breakdown (`lib/screens/dashboard/analysis_screen.dart`)
- In `_normalizeBankName`: Return `'<Bank>'`.
- In `_matchesBank`: Handle `bUp.contains('<BANK>')`.
- In `bankMap`: Add `'<Bank>': (inVal: 0.0, outVal: 0.0)`.

### Point 14: Onboarding & Privacy Disclosures
- In `lib/screens/intro/onboarding_screen.dart`: Add to `supportedBanks` list and terms.
- In `lib/screens/dashboard/privacy_policy_screen.dart`: Add to supported banks paragraph.

### Point 15: Automated Unit Tests
- Create `test/unit/<bank>_parser_test.dart` testing each pattern and the XML backup dataset.
- Update `test/bank_senders_test.dart`.
- Run `flutter test` to verify 100% pass rate.
