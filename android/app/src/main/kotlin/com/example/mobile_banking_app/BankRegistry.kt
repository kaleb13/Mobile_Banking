package com.example.mobile_banking_app

import android.content.Context
import org.json.JSONObject
import java.io.File

data class NativePatternRule(
    val patternId: String,
    val name: String,
    val type: String, // "income" or "expense"
    val patternType: String,
    val triggerKeywords: List<String>,
    val regex: String,
    val amountGroup: Int,
    val counterpartyGroup: Int,
    val counterpartyDefault: String?,
    val balanceGroup: Int?,
    val idGroup: Int?
)

data class NativeSenderIdentifier(
    val canonical: String,
    val keywords: List<String>,
    val exactSenders: List<String>,
    val numericShortCode: String?
) {
    fun matches(sender: String): Boolean {
        val sTrim = sender.trim()
        if (sTrim.isEmpty()) return false
        if (numericShortCode != null && sTrim == numericShortCode) return true
        val sUpper = sTrim.uppercase()
        if (exactSenders.any { it.equals(sUpper, ignoreCase = true) }) return true
        val sLower = sTrim.lowercase()
        return keywords.any { sLower.contains(it) }
    }
}

data class NativeBankDefinition(
    val id: String,
    val bankName: String,
    val officialTitle: String,
    val subtitle: String,
    val senderIdentifiers: NativeSenderIdentifier,
    val securityFilterRegex: String?,
    val ignoreFilterRegex: String?,
    val patterns: List<NativePatternRule>
)

object BankRegistry {
    private const val MANIFEST_FILENAME = "banks_manifest.json"
    private var schemaVersion = 1
    private var rulesVersion = 0
    private val banks = mutableListOf<NativeBankDefinition>()
    private val banksByName = mutableMapOf<String, NativeBankDefinition>()
    private val banksById = mutableMapOf<String, NativeBankDefinition>()
    private var initialized = false

    fun init(context: Context? = null) {
        if (initialized && banks.isNotEmpty()) return
        if (context == null) return

        try {
            // 1. Check OTA manifest in filesDir or app_flutter
            val otaFile = File(context.filesDir, MANIFEST_FILENAME)
            val appDocFile = File(context.filesDir, "app_flutter/$MANIFEST_FILENAME")
            val targetFile = if (otaFile.exists()) otaFile else if (appDocFile.exists()) appDocFile else null

            var jsonContent: String? = null
            if (targetFile != null && targetFile.exists()) {
                jsonContent = targetFile.readText()
            }

            // 2. Fallback to bundled asset
            if (jsonContent.isNullOrBlank()) {
                try {
                    context.assets.open("flutter_assets/assets/$MANIFEST_FILENAME").use { inputStream ->
                        jsonContent = inputStream.bufferedReader().use { it.readText() }
                    }
                } catch (_: Exception) {
                    try {
                        context.assets.open("assets/$MANIFEST_FILENAME").use { inputStream ->
                            jsonContent = inputStream.bufferedReader().use { it.readText() }
                        }
                    } catch (_: Exception) {}
                }
            }

            if (!jsonContent.isNullOrBlank()) {
                loadFromJson(jsonContent!!)
            }

            // 3. In-memory static fallback (guarantees registry is NEVER empty even before rebuild)
            if (banks.isEmpty()) {
                loadFromJson(DEFAULT_FALLBACK_JSON)
            }
            initialized = true
        } catch (_: Exception) {}
    }

    fun loadFromJson(jsonString: String): Boolean {
        try {
            val root = JSONObject(jsonString)
            val sVer = root.optInt("schemaVersion", 1)
            if (sVer > 1) return false

            val rVer = root.optInt("rulesVersion", 0)
            val banksArray = root.optJSONArray("banks") ?: return false

            val parsedBanks = mutableListOf<NativeBankDefinition>()
            for (i in 0 until banksArray.length()) {
                val bObj = banksArray.getJSONObject(i)
                val id = bObj.optString("id", "")
                val bankName = bObj.optString("bankName", "")
                val officialTitle = bObj.optString("officialTitle", bankName)
                val subtitle = bObj.optString("subtitle", "")

                val sObj = bObj.optJSONObject("senderIdentifiers")
                val canonical = sObj?.optString("canonical", bankName) ?: bankName
                val keywords = mutableListOf<String>()
                val kArray = sObj?.optJSONArray("keywords")
                if (kArray != null) {
                    for (k in 0 until kArray.length()) {
                        keywords.add(kArray.getString(k).lowercase())
                    }
                }
                val exactSenders = mutableListOf<String>()
                val eArray = sObj?.optJSONArray("exactSenders")
                if (eArray != null) {
                    for (e in 0 until eArray.length()) {
                        exactSenders.add(eArray.getString(e).uppercase())
                    }
                }
                val numericShortCode = if (sObj?.has("numericShortCode") == true && !sObj.isNull("numericShortCode")) {
                    sObj.getString("numericShortCode")
                } else null

                val senderId = NativeSenderIdentifier(canonical, keywords, exactSenders, numericShortCode)

                val pObj = bObj.optJSONObject("parsing")
                val secFilter = if (pObj?.has("securityFilterRegex") == true && !pObj.isNull("securityFilterRegex")) {
                    pObj.getString("securityFilterRegex")
                } else null
                val ignFilter = if (pObj?.has("ignoreFilterRegex") == true && !pObj.isNull("ignoreFilterRegex")) {
                    pObj.getString("ignoreFilterRegex")
                } else null

                val patternsList = mutableListOf<NativePatternRule>()
                val patArray = pObj?.optJSONArray("patterns")
                if (patArray != null) {
                    for (p in 0 until patArray.length()) {
                        val patObj = patArray.getJSONObject(p)
                        val triggerKws = mutableListOf<String>()
                        val tArray = patObj.optJSONArray("triggerKeywords")
                        if (tArray != null) {
                            for (t in 0 until tArray.length()) {
                                triggerKws.add(tArray.getString(t).lowercase())
                            }
                        }

                        patternsList.add(
                            NativePatternRule(
                                patternId = patObj.optString("patternId", ""),
                                name = patObj.optString("name", ""),
                                type = patObj.optString("type", "expense"),
                                patternType = patObj.optString("patternType", "standardTransfer"),
                                triggerKeywords = triggerKws,
                                regex = patObj.optString("regex", ""),
                                amountGroup = patObj.optInt("amountGroup", 1),
                                counterpartyGroup = patObj.optInt("counterpartyGroup", 2),
                                counterpartyDefault = if (patObj.has("counterpartyDefault") && !patObj.isNull("counterpartyDefault")) patObj.getString("counterpartyDefault") else null,
                                balanceGroup = if (patObj.has("balanceGroup") && !patObj.isNull("balanceGroup")) patObj.getInt("balanceGroup") else null,
                                idGroup = if (patObj.has("idGroup") && !patObj.isNull("idGroup")) patObj.getInt("idGroup") else null
                            )
                        )
                    }
                }

                parsedBanks.add(
                    NativeBankDefinition(
                        id = id,
                        bankName = bankName,
                        officialTitle = officialTitle,
                        subtitle = subtitle,
                        senderIdentifiers = senderId,
                        securityFilterRegex = secFilter,
                        ignoreFilterRegex = ignFilter,
                        patterns = patternsList
                    )
                )
            }

            if (parsedBanks.isNotEmpty()) {
                schemaVersion = sVer
                rulesVersion = rVer
                banks.clear()
                banks.addAll(parsedBanks)
                banksByName.clear()
                banksById.clear()
                for (b in banks) {
                    banksByName[b.bankName.uppercase()] = b
                    banksById[b.id.lowercase()] = b
                }
                return true
            }
        } catch (_: Exception) {}
        return false
    }

    fun matchBank(sender: String?): NativeBankDefinition? {
        if (sender.isNullOrBlank()) return null
        val sTrim = sender.trim()

        // 1. Exact canonical name match
        val exact = banksByName[sTrim.uppercase()]
        if (exact != null) return exact

        // 2. Numeric shortcode match across all banks
        for (b in banks) {
            if (b.senderIdentifiers.numericShortCode != null && b.senderIdentifiers.numericShortCode == sTrim) {
                return b
            }
        }

        // 3. Exact sender match across all banks (case-insensitive)
        val sUpper = sTrim.uppercase()
        for (b in banks) {
            if (b.senderIdentifiers.exactSenders.any { it.equals(sUpper, ignoreCase = true) }) {
                return b
            }
        }

        // 4. Keywords by specificity (longest keyword match first)
        val sLower = sTrim.lowercase()
        var bestMatch: NativeBankDefinition? = null
        var longestKwLen = 0
        for (b in banks) {
            for (kw in b.senderIdentifiers.keywords) {
                if (sLower.contains(kw) && kw.length > longestKwLen) {
                    longestKwLen = kw.length
                    bestMatch = b
                }
            }
        }
        return bestMatch
    }

    fun getBank(bankName: String): NativeBankDefinition? {
        return banksByName[bankName.uppercase()]
    }

    private const val DEFAULT_FALLBACK_JSON = """
{
  "schemaVersion": 1,
  "rulesVersion": 2026091601,
  "minSupportedAppVersion": "1.0.0",
  "banks": [
    {
      "id": "telebirr",
      "bankName": "Telebirr",
      "officialTitle": "Ethio Telecom",
      "subtitle": "Ethio Telecom , E- money",
      "senderIdentifiers": {
        "canonical": "Telebirr",
        "keywords": ["telebirr", "127"],
        "exactSenders": ["TELEBIRR", "127"],
        "numericShortCode": "127"
      },
      "parsing": {"patterns": []}
    },
    {
      "id": "cbe",
      "bankName": "CBE",
      "officialTitle": "Commercial Bank of Ethiopia",
      "subtitle": "Commercial Bank of Ethiopia",
      "senderIdentifiers": {
        "canonical": "CBE",
        "keywords": ["cbe", "commercial bank"],
        "exactSenders": ["CBE"]
      },
      "parsing": {"patterns": []}
    },
    {
      "id": "cbebirr",
      "bankName": "CBE Birr",
      "officialTitle": "CBE Birr Mobile Wallet",
      "subtitle": "CBE Birr Mobile Wallet",
      "senderIdentifiers": {
        "canonical": "CBE Birr",
        "keywords": ["cbebirr", "cbe birr"],
        "exactSenders": ["CBEBIRR", "CBE BIRR"]
      },
      "parsing": {"patterns": []}
    },
    {
      "id": "ahadu",
      "bankName": "Ahadu Bank",
      "officialTitle": "Ahadu Bank S.C.",
      "subtitle": "Ahadu Bank S.C.",
      "senderIdentifiers": {
        "canonical": "Ahadu Bank",
        "keywords": ["ahadu"],
        "exactSenders": ["AHADU", "AHADUBANK"]
      },
      "parsing": {"patterns": []}
    },
    {
      "id": "boa",
      "bankName": "BOA",
      "officialTitle": "Bank of Abyssinia",
      "subtitle": "Bank of Abyssinia S.C.",
      "senderIdentifiers": {
        "canonical": "BOA",
        "keywords": ["boa", "abyssinia"],
        "exactSenders": ["BOA", "ABYSSINIA"]
      },
      "parsing": {"patterns": []}
    },
    {
      "id": "dashen",
      "bankName": "Dashen Bank",
      "officialTitle": "Dashen Bank S.C.",
      "subtitle": "Dashen Bank S.C.",
      "senderIdentifiers": {
        "canonical": "Dashen Bank",
        "keywords": ["dashen", "amole"],
        "exactSenders": ["DASHEN", "AMOLE"]
      },
      "parsing": {"patterns": []}
    },
    {
      "id": "awash",
      "bankName": "Awash Bank",
      "officialTitle": "Awash Bank S.C.",
      "subtitle": "Awash Bank S.C.",
      "senderIdentifiers": {
        "canonical": "Awash Bank",
        "keywords": ["awash", "awashbirr"],
        "exactSenders": ["AWASH", "AWASH BANK", "AWASHBIRR"]
      },
      "parsing": {"patterns": []}
    },
    {
      "id": "zemen",
      "bankName": "Zemen Bank",
      "officialTitle": "Zemen Bank S.C.",
      "subtitle": "Zemen Bank S.C.",
      "senderIdentifiers": {
        "canonical": "Zemen Bank",
        "keywords": ["zemen"],
        "exactSenders": ["ZEMEN", "ZEMEN BANK"]
      },
      "parsing": {"patterns": []}
    },
    {
      "id": "nib",
      "bankName": "Nib Bank",
      "officialTitle": "Nib International Bank S.C.",
      "subtitle": "Nib International Bank S.C.",
      "senderIdentifiers": {
        "canonical": "Nib Bank",
        "keywords": ["nib"],
        "exactSenders": ["NIB", "NIB BANK", "NIBBANK"]
      },
      "parsing": {"patterns": []}
    },
    {
      "id": "bunna",
      "bankName": "Bunna Bank",
      "officialTitle": "Bunna Bank S.C.",
      "subtitle": "Bunna Bank S.C.",
      "senderIdentifiers": {
        "canonical": "Bunna Bank",
        "keywords": ["bunna", "buna"],
        "exactSenders": ["BUNNA", "BUNNA BANK", "BUNA", "BUNA BANK"]
      },
      "parsing": {"patterns": []}
    }
  ]
}
"""
}
