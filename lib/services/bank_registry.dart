import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/bank_definition.dart';

/// Central registry managing all dynamic bank definitions, branding, and rules.
///
/// Implements the 3-tier cascade:
/// 1. Local verified OTA manifest in internal documents storage
/// 2. Bundled assets manifest (`assets/banks_manifest.json`)
/// 3. In-memory hardcoded fallbacks
class BankRegistry {
  BankRegistry._();
  static final BankRegistry instance = BankRegistry._();

  static const String manifestFileName = 'banks_manifest.json';
  static const String bundledAssetPath = 'assets/banks_manifest.json';

  int _schemaVersion = 1;
  int _rulesVersion = 0;
  List<BankDefinition> _banks = [];
  final Map<String, BankDefinition> _banksById = {};
  final Map<String, BankDefinition> _banksByName = {};
  bool _initialized = false;

  int get schemaVersion => _schemaVersion;
  int get rulesVersion => _rulesVersion;
  List<BankDefinition> get allBanks => List.unmodifiable(_banks);
  bool get isInitialized => _initialized;

  /// Initializes the registry from disk or bundled asset.
  Future<void> init() async {
    if (_initialized) return;

    // 1. Try reading from internal app documents storage (OTA update)
    bool loadedOta = false;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final otaFile = File('${appDir.path}/$manifestFileName');
      if (await otaFile.exists()) {
        final content = await otaFile.readAsString();
        loadedOta = loadFromJsonString(content);
      }
    } catch (_) {
      loadedOta = false;
    }

    // 2. If no OTA, load bundled asset
    if (!loadedOta) {
      try {
        final bundledContent = await rootBundle.loadString(bundledAssetPath);
        loadFromJsonString(bundledContent);
      } catch (_) {
        // Asset not yet bundled in running APK
      }
    }

    // 3. Guaranteed in-memory fallback if neither OTA nor asset could be loaded
    if (_banks.isEmpty) {
      loadFromJsonString(_defaultFallbackJson);
    }

    _initialized = true;
  }

  /// Parses and loads bank definitions from raw JSON string.
  ///
  /// Returns true if parsing was successful and at least one bank was loaded.
  bool loadFromJsonString(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final schemaVer = decoded['schemaVersion'] as int? ?? 1;
      // Reject unknown newer schema versions to protect older apps
      if (schemaVer > 1) {
        return false;
      }

      final rulesVer = decoded['rulesVersion'] as int? ?? 0;
      final bankList = decoded['banks'] as List<dynamic>? ?? [];

      final List<BankDefinition> parsedBanks = [];
      for (final item in bankList) {
        if (item is Map<String, dynamic>) {
          parsedBanks.add(BankDefinition.fromJson(item));
        }
      }

      if (parsedBanks.isEmpty) return false;

      _schemaVersion = schemaVer;
      _rulesVersion = rulesVer;
      _banks = parsedBanks;
      _banksById.clear();
      _banksByName.clear();

      for (final bank in _banks) {
        _banksById[bank.id.toLowerCase()] = bank;
        _banksByName[bank.bankName.toUpperCase()] = bank;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Finds a bank by its unique ID (e.g. 'cbe', 'telebirr').
  BankDefinition? getBankById(String id) {
    return _banksById[id.toLowerCase()];
  }

  /// Finds a bank by its display/canonical bank name (e.g. 'CBE', 'Telebirr').
  BankDefinition? getBankByName(String bankName) {
    return _banksByName[bankName.toUpperCase()];
  }

  /// Associates an incoming SMS sender (phone, shortcode, or alphanumeric ID) with a Bank.
  BankDefinition? matchBankBySender(String sender) {
    final sTrim = sender.trim();
    if (sTrim.isEmpty) return null;

    // 1. Exact canonical name match
    final exact = getBankByName(sTrim);
    if (exact != null) return exact;

    // 2. Numeric shortcode match across all banks
    for (final bank in _banks) {
      if (bank.senderIdentifiers.numericShortCode != null &&
          bank.senderIdentifiers.numericShortCode == sTrim) {
        return bank;
      }
    }

    // 3. Exact sender match across all banks (case-insensitive)
    final sUpper = sTrim.toUpperCase();
    for (final bank in _banks) {
      if (bank.senderIdentifiers.exactSenders.contains(sUpper)) {
        return bank;
      }
    }

    // 4. Keyword match by specificity (longest keyword match first)
    // E.g. "cbe birr" (length 8) matches before "cbe" (length 3)
    final sLower = sTrim.toLowerCase();
    BankDefinition? bestMatch;
    int longestKwLen = 0;

    for (final bank in _banks) {
      for (final kw in bank.senderIdentifiers.keywords) {
        if (sLower.contains(kw) && kw.length > longestKwLen) {
          longestKwLen = kw.length;
          bestMatch = bank;
        }
      }
    }

    return bestMatch;
  }

  /// Retrieves dynamic branding for a bank, or null if not registered.
  BankBranding? getBranding(String bankName) {
    final bank = getBankByName(bankName);
    return bank?.branding;
  }

  /// Retrieves the dynamic subtitle for a bank.
  String? getSubtitle(String bankName) {
    final bank = getBankByName(bankName);
    return bank?.subtitle.isNotEmpty == true ? bank?.subtitle : null;
  }

  /// Retrieves the dynamic gradient colors for a bank, or null if not registered.
  List<Color>? getGradient(String bankName) {
    final branding = getBranding(bankName);
    if (branding == null || branding.gradientColorsHex.isEmpty) return null;
    return branding.toColorList();
  }

  /// Returns whether a bank card uses dark text theme.
  bool? isDarkTextTheme(String bankName) {
    final branding = getBranding(bankName);
    return branding?.isDarkTextTheme;
  }

  /// Returns all search keywords defined across all banks for SMS querying.
  List<String> get allBankKeywords {
    final Set<String> keywords = {};
    for (final bank in _banks) {
      keywords.addAll(bank.senderIdentifiers.keywords);
    }
    return keywords.toList();
  }

  static const String _defaultFallbackJson = r'''
{
  "schemaVersion": 1,
  "rulesVersion": 2026091701,
  "minSupportedAppVersion": "1.0.0",
  "banks": [
    {
      "id": "telebirr",
      "bankName": "Telebirr",
      "officialTitle": "Ethio Telecom",
      "subtitle": "Ethio Telecom , E- money",
      "accountType": "wallet",
      "senderIdentifiers": {
        "canonical": "Telebirr",
        "keywords": ["telebirr", "127"],
        "exactSenders": ["TELEBIRR", "127"],
        "numericShortCode": "127"
      },
      "branding": {
        "gradientColors": ["#0BA751", "#88BF47"],
        "isDarkTextTheme": false,
        "iconAssetFallback": "assets/images/Telebirr_Logo.svg"
      },
      "parsing": {"patterns": []}
    },
    {
      "id": "cbe",
      "bankName": "CBE",
      "officialTitle": "Commercial Bank of Ethiopia",
      "subtitle": "Commercial Bank of Ethiopia",
      "accountType": "bank",
      "senderIdentifiers": {
        "canonical": "CBE",
        "keywords": ["cbe", "commercial bank"],
        "exactSenders": ["CBE"]
      },
      "branding": {
        "gradientColors": ["#3D1B0F", "#6E482F"],
        "isDarkTextTheme": false,
        "iconAssetFallback": "assets/images/CBE.svg"
      },
      "parsing": {"patterns": []}
    },
    {
      "id": "cbebirr",
      "bankName": "CBE Birr",
      "officialTitle": "CBE Birr Mobile Wallet",
      "subtitle": "CBE Birr Mobile Wallet",
      "accountType": "wallet",
      "senderIdentifiers": {
        "canonical": "CBE Birr",
        "keywords": ["cbebirr", "cbe birr"],
        "exactSenders": ["CBEBIRR", "CBE BIRR"]
      },
      "branding": {
        "gradientColors": ["#5E1268", "#9C27B0"],
        "isDarkTextTheme": false,
        "iconAssetFallback": "assets/images/CBE.svg"
      },
      "parsing": {"patterns": []}
    },
    {
      "id": "ahadu",
      "bankName": "Ahadu Bank",
      "officialTitle": "Ahadu Bank S.C.",
      "subtitle": "Ahadu Bank S.C.",
      "accountType": "bank",
      "senderIdentifiers": {
        "canonical": "Ahadu Bank",
        "keywords": ["ahadu"],
        "exactSenders": ["AHADU", "AHADUBANK"]
      },
      "branding": {
        "gradientColors": ["#6B031F", "#C71545"],
        "isDarkTextTheme": false,
        "iconAssetFallback": "assets/images/AhaduBank_Logo.svg"
      },
      "parsing": {"patterns": []}
    },
    {
      "id": "boa",
      "bankName": "BOA",
      "officialTitle": "Bank of Abyssinia",
      "subtitle": "Bank of Abyssinia S.C.",
      "accountType": "bank",
      "senderIdentifiers": {
        "canonical": "BOA",
        "keywords": ["boa", "abyssinia"],
        "exactSenders": ["BOA", "ABYSSINIA"]
      },
      "branding": {
        "gradientColors": ["#C68000", "#FFB800"],
        "isDarkTextTheme": false,
        "iconAssetFallback": "assets/images/Bank_of_Abyssinia_Logo.svg"
      },
      "parsing": {"patterns": []}
    },
    {
      "id": "dashen",
      "bankName": "Dashen Bank",
      "officialTitle": "Dashen Bank S.C.",
      "subtitle": "Dashen Bank S.C.",
      "accountType": "bank",
      "senderIdentifiers": {
        "canonical": "Dashen Bank",
        "keywords": ["dashen", "amole"],
        "exactSenders": ["DASHEN", "AMOLE"]
      },
      "branding": {
        "gradientColors": ["#2563EB", "#162068"],
        "isDarkTextTheme": false,
        "iconAssetFallback": "assets/images/Dashen_Bank_Logo.svg"
      },
      "parsing": {"patterns": []}
    },
    {
      "id": "awash",
      "bankName": "Awash Bank",
      "officialTitle": "Awash Bank S.C.",
      "subtitle": "Awash Bank S.C.",
      "accountType": "bank",
      "senderIdentifiers": {
        "canonical": "Awash Bank",
        "keywords": ["awash", "awashbirr"],
        "exactSenders": ["AWASH", "AWASH BANK", "AWASHBIRR"]
      },
      "branding": {
        "gradientColors": ["#1E1B9A", "#010066"],
        "isDarkTextTheme": false,
        "iconAssetFallback": "assets/images/Awash_Bank_Logo.svg"
      },
      "parsing": {"patterns": []}
    },
    {
      "id": "zemen",
      "bankName": "Zemen Bank",
      "officialTitle": "Zemen Bank S.C.",
      "subtitle": "Zemen Bank S.C.",
      "accountType": "bank",
      "senderIdentifiers": {
        "canonical": "Zemen Bank",
        "keywords": ["zemen"],
        "exactSenders": ["ZEMEN", "ZEMEN BANK"]
      },
      "branding": {
        "gradientColors": ["#F43F5E", "#D12048"],
        "isDarkTextTheme": false,
        "iconAssetFallback": "assets/images/ZemenBank_Logo.svg"
      },
      "parsing": {"patterns": []}
    },
    {
      "id": "nib",
      "bankName": "Nib Bank",
      "officialTitle": "Nib International Bank S.C.",
      "subtitle": "Nib International Bank S.C.",
      "accountType": "bank",
      "senderIdentifiers": {
        "canonical": "Nib Bank",
        "keywords": ["nib"],
        "exactSenders": ["NIB", "NIB BANK", "NIBBANK"]
      },
      "branding": {
        "gradientColors": ["#B86B35", "#8B4D20"],
        "isDarkTextTheme": false,
        "iconAssetFallback": "assets/images/NIB_Bank_Logo.svg"
      },
      "parsing": {"patterns": []}
    },
    {
      "id": "bunna",
      "bankName": "Bunna Bank",
      "officialTitle": "Bunna Bank S.C.",
      "subtitle": "Bunna Bank S.C.",
      "accountType": "bank",
      "senderIdentifiers": {
        "canonical": "Bunna Bank",
        "keywords": ["bunna", "buna"],
        "exactSenders": ["BUNNA", "BUNNA BANK", "BUNA", "BUNA BANK"]
      },
      "branding": {
        "gradientColors": ["#852A2A", "#551919"],
        "isDarkTextTheme": false,
        "iconAssetFallback": "assets/images/Buna_Bank_Logo.svg"
      },
      "parsing": {"patterns": []}
    }
  ]
}
''';
}
