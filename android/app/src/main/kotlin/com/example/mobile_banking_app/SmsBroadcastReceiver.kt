package com.example.mobile_banking_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.provider.Telephony
import androidx.core.app.NotificationCompat
import java.io.File
import java.security.MessageDigest
import java.text.NumberFormat
import java.util.Collections
import java.util.LinkedHashMap
import java.util.Locale

/**
 * Clean Architecture Native BroadcastReceiver that listens for SMS_RECEIVED broadcasts.
 *
 * When an SMS arrives from a known bank sender:
 *   1. Verifies sender against the bank allowlist.
 *   2. Filters out OTP/PIN/security messages.
 *   3. Parses the message using strict bank fact extractors (mirroring Dart domain parsers).
 *   4. Drops non-transaction messages or invalid multi-part SMS segments (preventing ghost notifications).
 *   5. Debounces against recent transaction signatures to prevent duplicate multi-part notifications.
 *   6. Dispatches notifications based on the 3-mode button rule:
 *        - Locked Reason (Airtime, Package, Sanduq/Shamo, Loan): 0 action buttons.
 *        - Attached Unlocked Reason (via reason_links / SQLite): 2 action buttons [ OK ] and [ Change Reason ].
 *        - Uncategorized: 3 action buttons [ Quick 1 ], [ Quick 2 ], and [ Categorize ].
 *   7. Inserts a row into the notifications table in SQLite and notifies Flutter via EventChannel.
 */
class SmsBroadcastReceiver : BroadcastReceiver() {

    data class NativeParsedSms(
        val bankName: String,
        val amount: Double,
        val formattedAmount: String,
        val isDebit: Boolean,
        val counterparty: String,
        val directionHeader: String,
        val title: String,
        val isLocked: Boolean,
        val lockedReasonName: String?,
        val txReference: String?
    )

    companion object {
        const val CHANNEL_ID = "sms_auto_detect"
        const val CHANNEL_NAME = "SMS Auto-Detect"
        const val DB_NAME = "finance_v3.db"
        const val DEDUPE_WINDOW_MS = 15000L // 15 seconds debounce window

        const val EXTRA_NOTIFICATION_ID = "extra_notification_id"
        const val EXTRA_TX_ID = "extra_tx_id"
        const val EXTRA_SMS_BODY = "extra_sms_body"
        const val EXTRA_BANK_NAME = "extra_bank_name"
        const val EXTRA_AMOUNT = "extra_amount"
        const val EXTRA_DIRECTION = "extra_direction"

        // Sliding window cache for recently seen transaction signatures
        private val recentSignatures = Collections.synchronizedMap(
            object : LinkedHashMap<String, Long>(20, 0.75f, true) {
                override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Long>?): Boolean {
                    return size > 50
                }
            }
        )

        // Hardcoded bank sender allowlist
        private val BANK_SENDERS = mapOf(
            "TELEBIRR" to "Telebirr",
            "127" to "Telebirr",          // Telebirr short code
            "CBEBIRR" to "CBE Birr",
            "CBE BIRR" to "CBE Birr",
            "CBE" to "CBE",
            "AHADU" to "Ahadu Bank",
            "BOA" to "BOA",
            "ABYSSINIA" to "BOA",
            "DASHEN" to "Dashen Bank",
            "AMOLE" to "Dashen Bank",
        )

        fun matchBankSender(sender: String?): String? {
            if (sender.isNullOrBlank()) return null
            val s = sender.trim()

            // Reject personal phone numbers (but allow "127" short code)
            if (s != "127" && s.matches(Regex("^\\+?[0-9]{7,15}$"))) return null

            val upper = s.uppercase()
            for ((key, bankName) in BANK_SENDERS) {
                if (upper.contains(key)) return bankName
            }
            return null
        }

        fun isAmharicMessage(body: String): Boolean {
            return body.any { it in '\u1200'..'\u137F' }
        }

        fun isSecurityOrAuthMessage(body: String): Boolean {
            val lower = body.lowercase()

            if (lower.contains("one-time password")) return true
            if (lower.contains("one time password")) return true
            if (lower.contains("otp code")) return true
            if (lower.contains("otp is")) return true
            if (lower.contains("your otp")) return true
            if (lower.contains("otp:")) return true
            if (lower.contains("passcode")) return true
            if (lower.contains("secret code")) return true
            if (lower.contains("login code")) return true
            if (lower.contains("activation code")) return true
            if (lower.contains("confirmation code")) return true

            if (lower.contains("pin or password is incorrect")) return true
            if (lower.contains("incorrect pin")) return true
            if (lower.contains("incorrect password")) return true
            if (lower.contains("invalid pin")) return true
            if (lower.contains("invalid password")) return true
            if (lower.contains("wrong pin")) return true
            if (lower.contains("wrong password")) return true
            if (lower.contains("pin is incorrect")) return true
            if (lower.contains("password is incorrect")) return true
            if (lower.contains("pin locked") || lower.contains("password locked")) return true
            if (lower.contains("account has been locked") || lower.contains("account locked")) return true

            if (lower.contains("pin reset")) return true
            if (lower.contains("password reset")) return true
            if (lower.contains("reset your pin")) return true
            if (lower.contains("reset your password")) return true
            if (lower.contains("change your pin")) return true
            if (lower.contains("change your password")) return true
            if (lower.contains("pin changed") || lower.contains("password changed")) return true
            if (lower.contains("temporary pin") || lower.contains("temporary password")) return true
            if (lower.contains("initial pin") || lower.contains("initial password")) return true
            if (lower.contains("your pin is") || lower.contains("your password is")) return true

            if ((lower.contains("do not share") || lower.contains("never share") ||
                 lower.contains("do not disclose") || lower.contains("keep it confidential")) &&
                (lower.contains("pin") || lower.contains("otp") || lower.contains("password") || lower.contains("code"))) {
                return true
            }

            if (lower.contains("auth code")) return true
            if (lower.contains("verification code") &&
                Regex("\\d{4,8}").containsMatchIn(lower)) return true
            if ((lower.contains("access code") || lower.contains("security code")) &&
                (lower.contains("use") || lower.contains("enter") || lower.contains("otp") || lower.contains("code"))) {
                return true
            }

            if (lower.contains("የይለፍ ቃል") ||
                lower.contains("የይለፍ ቃልዎ") ||
                lower.contains("ሚስጥር ቁጥር") ||
                lower.contains("ሚስጥራዊ ቁጥር") ||
                lower.contains("የይለፍ ቁጥር") ||
                lower.contains("የማረጋገጫ ኮድ") ||
                lower.contains("የማረጋገጫ ቁጥር") ||
                (lower.contains("ኮድ") && (lower.contains("አይስጡ") || lower.contains("አያጋሩ")))) {
                return true
            }

            return false
        }

        fun generateId(sender: String, timestampMs: Long, body: String): String {
            val input = "$sender|$timestampMs|$body"
            val digest = MessageDigest.getInstance("SHA-256")
            val hashBytes = digest.digest(input.toByteArray(Charsets.UTF_8))
            return hashBytes.joinToString("") { "%02x".format(it) }
        }

        private fun formatEtb(amount: Double): String {
            val formatter = NumberFormat.getNumberInstance(Locale.US).apply {
                minimumFractionDigits = 2
                maximumFractionDigits = 2
            }
            return "ETB ${formatter.format(amount)}"
        }

        private fun parseAmount(regex: Regex, text: String): Double {
            val match = regex.find(text) ?: return 0.0
            val raw = match.groupValues[1].replace(",", "").trim()
            val clean = if (raw.endsWith(".")) raw.substring(0, raw.length - 1) else raw
            return clean.toDoubleOrNull() ?: 0.0
        }

        /**
         * Pure Fact Extraction Engine (Mirrors Dart Bank Parsers)
         */
        fun parseBankingSms(bankName: String, body: String): NativeParsedSms? {
            val singleLine = body.replace("\n", " ").replace("\r", " ")
            val lower = singleLine.lowercase()

            when (bankName) {
                "Telebirr" -> {
                    // 1. Airtime pattern: outgoing recharge OR incoming airtime topup
                    if (lower.contains("airtime") || ((lower.contains("recharged") || lower.contains("bought") || lower.contains("recharge")) && (lower.contains("airtime") || lower.contains("ethio telecom")))) {
                        var amount = parseAmount(Regex("(?i)(?:recharged|bought|received)\\s+(?:(?:ETB|Br\\.?|Birr)\\s*)?([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) {
                            amount = parseAmount(Regex("(?i)ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        }
                        if (amount <= 0) return null

                        val isIncoming = lower.contains("received")
                        val phoneMatch = if (isIncoming) {
                            Regex("(?i)from\\s+(\\+?(?:251|0)?[97]\\d{8})").find(singleLine)
                        } else {
                            Regex("(?i)(?:airtime\\s+for|for)\\s+(\\+?(?:251|0)?[97]\\d{8})").find(singleLine)
                        }
                        val phone = phoneMatch?.groupValues?.get(1)?.trim() ?: "Airtime"
                        val refMatch = Regex("(?i)transaction\\s+number\\s+(?:is\\s+)?([A-Za-z0-9]+)").find(singleLine)
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "Telebirr",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = !isIncoming,
                            counterparty = phone,
                            directionHeader = if (isIncoming) "From: $phone" else (if (phone != "Airtime") "To: $phone" else "Debit (Telebirr)"),
                            title = "Banking SMS from Telebirr",
                            isLocked = true,
                            lockedReasonName = "Airtime",
                            txReference = ref
                        )
                    }

                    // 2. Package pattern: "paid ETB 50.00 for package subscription to 972665987 on..."
                    if (lower.contains("package") && (lower.contains("paid") || lower.contains("bought") || lower.contains("package subscription") || lower.contains("monthly voice"))) {
                        var amount = parseAmount(Regex("(?i)(?:paid|bought)\\s+(?:(?:ETB|Br\\.?|Birr)\\s*)?([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) {
                            amount = parseAmount(Regex("(?i)ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        }
                        if (amount <= 0) return null

                        val phoneMatch = Regex("(?i)(?:made\\s+for|to|for)\\s+(\\+?(?:251|0)?[97]\\d{8})").find(singleLine)
                        val phone = phoneMatch?.groupValues?.get(1)?.trim() ?: "Package"
                        val refMatch = Regex("(?i)transaction\\s+number\\s+(?:is\\s+)?([A-Za-z0-9]+)").find(singleLine)
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "Telebirr",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = true,
                            counterparty = phone,
                            directionHeader = if (phone != "Package") "To: $phone" else "Debit (Telebirr)",
                            title = "Banking SMS from Telebirr",
                            isLocked = true,
                            lockedReasonName = "Package",
                            txReference = ref
                        )
                    }

                    // 3. Sanduq / Shamo / Internal savings
                    if (lower.contains("sanduq") || lower.contains("shamo") || (lower.contains("saving") && lower.contains("balance")) || (lower.contains("reserved") && lower.contains("account"))) {
                        var amount = parseAmount(Regex("(?i)(?:reserved|transferred)?\\s*ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) {
                            amount = parseAmount(Regex("(?i)ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        }
                        val refMatch = Regex("(?i)transaction\\s+number\\s+(?:is\\s+)?([A-Za-z0-9]+)").find(singleLine)
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "Telebirr",
                            amount = if (amount > 0) amount else 0.0,
                            formattedAmount = if (amount > 0) formatEtb(amount) else "Internal Transfer",
                            isDebit = true,
                            counterparty = if (lower.contains("shamo")) "Shamo Account" else "Sanduq Savings",
                            directionHeader = "Debit (Telebirr)",
                            title = "Banking SMS from Telebirr",
                            isLocked = true,
                            lockedReasonName = "Internal Transfer",
                            txReference = ref
                        )
                    }

                    // 4. Loan / Credit Request
                    if (lower.contains("credit request") || lower.contains("contract number") || lower.contains("credit loan") || lower.contains("loan disbursement")) {
                        val amount = parseAmount(Regex("(?i)ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        val refMatch = Regex("(?i)transaction\\s+number\\s+(?:is\\s+)?([A-Za-z0-9]+)").find(singleLine)
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "Telebirr",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = false,
                            counterparty = "Telebirr Loan",
                            directionHeader = "Credit (Telebirr)",
                            title = "Banking SMS from Telebirr",
                            isLocked = true,
                            lockedReasonName = "Loan",
                            txReference = ref
                        )
                    }

                    // 5. Outgoing Transfer: "transferred ETB 100.00 to Abebe on..."
                    if (lower.contains("transferred")) {
                        val amount = parseAmount(Regex("(?i)transferred\\s+ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) return null

                        val toMatch = Regex("(?i)to\\s+(.*?)\\s+on\\s+\\d{2}/\\d{2}").find(singleLine)
                        val rawRecipient = toMatch?.groupValues?.get(1)?.trim() ?: ""
                        val accMatch = Regex("(?i)account\\s+(?:number\\s+)?([0-9A-Za-z]+)").find(rawRecipient)
                        val recipient = accMatch?.groupValues?.get(1)?.trim() ?: rawRecipient.ifEmpty { "Transfer" }
                        val refMatch = Regex("(?i)transaction\\s+number\\s+(?:is\\s+)?([A-Za-z0-9]+)").find(singleLine)
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "Telebirr",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = true,
                            counterparty = recipient,
                            directionHeader = "To: $recipient",
                            title = if (recipient != "Transfer") "Transaction with $recipient" else "Banking SMS from Telebirr",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref
                        )
                    }

                    // 6. Incoming Transfer: "received ETB 100.00 from Abebe on..."
                    if (lower.contains("received")) {
                        val amount = parseAmount(Regex("(?i)received\\s+ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) return null

                        val fromMatch = Regex("(?i)from\\s+(.*?)\\s+on\\s+\\d{2}/\\d{2}").find(singleLine)
                        val senderName = fromMatch?.groupValues?.get(1)?.trim() ?: "Sender"
                        val refMatch = Regex("(?i)transaction\\s+number\\s+(?:is\\s+)?([A-Za-z0-9]+)").find(singleLine)
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "Telebirr",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = false,
                            counterparty = senderName,
                            directionHeader = "From: $senderName",
                            title = if (senderName != "Sender") "Transaction with $senderName" else "Banking SMS from Telebirr",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref
                        )
                    }

                    // 7. General Debit
                    if (lower.contains("debited")) {
                        val amount = parseAmount(Regex("(?i)debited\\s+with\\s+ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) return null
                        val refMatch = Regex("(?i)transaction\\s+number\\s+(?:is\\s+)?([A-Za-z0-9]+)").find(singleLine)
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "Telebirr",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = true,
                            counterparty = "Telebirr Debit",
                            directionHeader = "Debit (Telebirr)",
                            title = "Banking SMS from Telebirr",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref
                        )
                    }
                }

                "CBE" -> {
                    if (lower.contains("credited")) {
                        val amount = parseAmount(Regex("(?i)credited\\s+with\\s+ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) return null
                        val fromMatch = Regex("(?i)from\\s+(.*?)(?:,\\s*on|\\s+on\\s+\\d{2}/\\d{2})").find(singleLine)
                        val senderName = fromMatch?.groupValues?.get(1)?.trim() ?: "CBE Deposit"
                        val refMatch = Regex("(?i)ref\\s*(?:no\\.?)?\\s*([A-Za-z0-9]+)").find(singleLine)
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "CBE",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = false,
                            counterparty = senderName,
                            directionHeader = "From: $senderName",
                            title = if (senderName != "CBE Deposit") "Transaction with $senderName" else "Banking SMS from CBE",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref
                        )
                    }

                    if (lower.contains("debited") || lower.contains("transfer") || lower.contains("withdrawn")) {
                        val amount = parseAmount(Regex("(?i)(?:debited\\s+with|transfer\\s+of)\\s+ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) return null
                        val toMatch = Regex("(?i)to\\s+(.*?)(?:,\\s*on|\\s+on\\s+\\d{2}/\\d{2})").find(singleLine)
                        val recipient = toMatch?.groupValues?.get(1)?.trim() ?: "CBE Withdrawal"
                        val refMatch = Regex("(?i)ref\\s*(?:no\\.?)?\\s*([A-Za-z0-9]+)").find(singleLine)
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "CBE",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = true,
                            counterparty = recipient,
                            directionHeader = "To: $recipient",
                            title = if (recipient != "CBE Withdrawal") "Transaction with $recipient" else "Banking SMS from CBE",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref
                        )
                    }
                }

                "BOA" -> {
                    if (lower.contains("credited")) {
                        val amount = parseAmount(Regex("(?i)credited\\s+with\\s+ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) return null
                        val byMatch = Regex("(?i)by\\s+(.*?)(?:\\s*\\.|\\s*available)").find(singleLine)
                        val senderName = byMatch?.groupValues?.get(1)?.trim() ?: "BOA Deposit"
                        val refMatch = Regex("(?i)trx=([A-Za-z0-9]+)").find(singleLine)
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "BOA",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = false,
                            counterparty = senderName,
                            directionHeader = "From: $senderName",
                            title = if (senderName != "BOA Deposit") "Transaction with $senderName" else "Banking SMS from BOA",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref
                        )
                    }

                    if (lower.contains("debited") || lower.contains("paid")) {
                        val amount = parseAmount(Regex("(?i)debited\\s+with\\s+ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) return null
                        val refMatch = Regex("(?i)trx=([A-Za-z0-9]+)").find(singleLine)
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "BOA",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = true,
                            counterparty = "BOA Transfer",
                            directionHeader = "Debit (BOA)",
                            title = "Banking SMS from BOA",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref
                        )
                    }
                }

                "Ahadu Bank" -> {
                    if (lower.contains("credited") || lower.contains("received") || lower.contains("deposit")) {
                        val amount = parseAmount(Regex("(?i)ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) return null
                        var refMatch = Regex("(?i)(?:reference\\s+number|ref(?:erence)?\\s*(?:no\\.?)?|ref\\.?)\\s*:?\\s*([A-Za-z0-9]+)").find(singleLine)
                        if (refMatch == null) {
                            refMatch = Regex("(?i)digitalreceipt\\?es=([A-Za-z0-9/\\-_]+)").find(singleLine)
                        }
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "Ahadu Bank",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = false,
                            counterparty = "Ahadu Deposit",
                            directionHeader = "From: Ahadu Deposit",
                            title = "Banking SMS from Ahadu Bank",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref
                        )
                    }

                    if (lower.contains("debited") || lower.contains("debit") || lower.contains("transfer") || lower.contains("withdrawn") || lower.contains("paid")) {
                        val amount = parseAmount(Regex("(?i)ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) return null
                        var refMatch = Regex("(?i)(?:reference\\s+number|ref(?:erence)?\\s*(?:no\\.?)?|ref\\.?)\\s*:?\\s*([A-Za-z0-9]+)").find(singleLine)
                        if (refMatch == null) {
                            refMatch = Regex("(?i)digitalreceipt\\?es=([A-Za-z0-9/\\-_]+)").find(singleLine)
                        }
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "Ahadu Bank",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = true,
                            counterparty = "Ahadu Transfer",
                            directionHeader = "Debit (Ahadu Bank)",
                            title = "Banking SMS from Ahadu Bank",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref
                        )
                    }
                }

                "Dashen Bank" -> {
                    val amount = parseAmount(Regex("(?i)ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                    if (amount <= 0) return null
                    val isDebit = lower.contains("debited") || lower.contains("transfer") || lower.contains("paid")

                    return NativeParsedSms(
                        bankName = "Dashen Bank",
                        amount = amount,
                        formattedAmount = formatEtb(amount),
                        isDebit = isDebit,
                        counterparty = if (isDebit) "Dashen Transfer" else "Dashen Deposit",
                        directionHeader = if (isDebit) "Debit (Dashen Bank)" else "Credit (Dashen Bank)",
                        title = "Banking SMS from Dashen Bank",
                        isLocked = false,
                        lockedReasonName = null,
                        txReference = null
                    )
                }

                "CBE Birr" -> {
                    val amount = parseAmount(Regex("(?i)([0-9,]+(?:\\.[0-9]+)?)\\s*Br\\.?"), singleLine)
                    if (amount <= 0) return null
                    val isDebit = lower.contains("paid") || lower.contains("transferred") || lower.contains("debited")
                    val refMatch = Regex("(?i)txn\\s+id\\s+([A-Za-z0-9]+)").find(singleLine)
                    val ref = refMatch?.groupValues?.get(1)?.trim()

                    return NativeParsedSms(
                        bankName = "CBE Birr",
                        amount = amount,
                        formattedAmount = formatEtb(amount),
                        isDebit = isDebit,
                        counterparty = if (isDebit) "CBE Birr Payment" else "CBE Birr Deposit",
                        directionHeader = if (isDebit) "Debit (CBE Birr)" else "Credit (CBE Birr)",
                        title = "Banking SMS from CBE Birr",
                        isLocked = false,
                        lockedReasonName = null,
                        txReference = ref
                    )
                }
            }

            return null
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) return

        val sender = messages[0].displayOriginatingAddress ?: return
        val body = messages.joinToString("") { it.displayMessageBody ?: "" }
        val timestampMs = messages[0].timestampMillis

        if (body.isBlank()) return

        val bankName = matchBankSender(sender) ?: return
        if (isAmharicMessage(body)) return
        if (isSecurityOrAuthMessage(body)) return

        // 1. Parse into structured banking facts. Drop non-transaction messages or broken SMS parts!
        val parsed = parseBankingSms(bankName, body) ?: return

        // 2. Sliding window debounce (15 seconds) to prevent duplicate notifications from multi-part PDUs
        val dedupeKey = "${parsed.bankName}|${parsed.isDebit}|${parsed.formattedAmount}|${parsed.txReference ?: parsed.counterparty}"
        val now = System.currentTimeMillis()
        synchronized(recentSignatures) {
            val lastSeen = recentSignatures[dedupeKey]
            if (lastSeen != null && (now - lastSeen) < DEDUPE_WINDOW_MS) {
                return // Drop duplicate notification
            }
            recentSignatures[dedupeKey] = now
        }

        val txId = generateId(sender, timestampMs, body)

        // 3. Resolve attached reason: locked patterns first, otherwise check reason_links in SQLite
        val attachedReason = if (parsed.isLocked) {
            parsed.lockedReasonName
        } else {
            checkAttachedReasonInDb(context, parsed.counterparty, body)
        }

        // 4. Save notification to SQLite for Dart hydration
        insertIntoDb(context, txId, bankName, body, timestampMs, attachedReason)

        // 5. Show Android status bar notification
        showNotification(context, txId, parsed, attachedReason)

        try {
            MainActivity.smsEventSink?.success("newTransaction")
        } catch (_: Exception) {}
    }

    private fun insertIntoDb(
        context: Context,
        id: String,
        bankName: String,
        body: String,
        timestampMs: Long,
        reason: String?
    ): Boolean {
        return try {
            val dbPath = File(context.getDatabasePath(DB_NAME).path)
            if (!dbPath.exists()) return false

            val db = SQLiteDatabase.openDatabase(
                dbPath.path,
                null,
                SQLiteDatabase.OPEN_READWRITE
            )

            val dateIso = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", java.util.Locale.US)
                .format(java.util.Date(timestampMs))

            val sql = """
                INSERT OR IGNORE INTO notifications (id, sender, body, date, isRead, reason)
                VALUES (?, ?, ?, ?, 0, ?)
            """.trimIndent()

            db.execSQL(sql, arrayOf(id, bankName, body, dateIso, reason))
            db.close()
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun checkAttachedReasonInDb(context: Context, counterparty: String, body: String): String? {
        return try {
            val dbPath = File(context.getDatabasePath(DB_NAME).path)
            if (!dbPath.exists()) return null

            val db = SQLiteDatabase.openDatabase(
                dbPath.path,
                null,
                SQLiteDatabase.OPEN_READONLY
            )

            var matchedReason: String? = null
            val lowerCounterparty = counterparty.lowercase().trim()
            val lowerBody = body.lowercase().trim()

            val cursor = db.rawQuery("""
                SELECT r.name, rl.linkedName
                FROM reason_links rl
                JOIN reasons r ON rl.reasonId = r.id
            """.trimIndent(), null)

            while (cursor.moveToNext()) {
                val rName = cursor.getString(0)
                val linkedName = cursor.getString(1)?.lowercase()?.trim() ?: ""
                if (linkedName.isNotBlank()) {
                    if (lowerCounterparty.contains(linkedName) || lowerBody.contains(linkedName)) {
                        matchedReason = rName
                        break
                    }
                }
            }
            cursor.close()
            db.close()
            matchedReason
        } catch (_: Exception) {
            null
        }
    }

    private fun showNotification(
        context: Context,
        txId: String,
        parsed: NativeParsedSms,
        attachedReason: String?
    ) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for auto-detected banking SMS"
            }
            notificationManager.createNotificationChannel(channel)
        }

        val notifId = txId.hashCode()

        val reasonLine = when {
            parsed.isLocked -> "${parsed.lockedReasonName} (Locked)"
            !attachedReason.isNullOrBlank() -> attachedReason
            else -> "Uncategorized"
        }

        val directionLine = parsed.directionHeader
        val amountLine = parsed.formattedAmount
        val title = parsed.title
        val bigText = "$directionLine\nAmount: $amountLine\nReason: $reasonLine"

        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val openIntent = if (parsed.isLocked) {
            // Locked reason: Launch main app directly (no quick categorization dialog)
            Intent(context, MainActivity::class.java).apply {
                this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EXTRA_TX_ID, txId)
                putExtra(EXTRA_NOTIFICATION_ID, notifId)
            }
        } else {
            // Unlocked: Launch transparent quick-edit dialog
            Intent(context, TransactionQuickEditActivity::class.java).apply {
                this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EXTRA_TX_ID, txId)
                putExtra(EXTRA_NOTIFICATION_ID, notifId)
                putExtra(EXTRA_SMS_BODY, "")
                putExtra(EXTRA_BANK_NAME, parsed.bankName)
                putExtra(EXTRA_AMOUNT, amountLine)
                putExtra(EXTRA_DIRECTION, directionLine)
            }
        }
        val openPendingIntent = PendingIntent.getActivity(context, notifId, openIntent, pendingFlags)

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText("$directionLine | $amountLine | Reason: $reasonLine")
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(openPendingIntent)
            .setAutoCancel(true)

        if (parsed.isLocked) {
            // Mode 1: Locked Reason -> 0 ACTION BUTTONS (Plain informative notification banner)
        } else if (!attachedReason.isNullOrBlank()) {
            // Mode 2: Attached Unlocked Reason -> 2 Action Buttons [ OK ] and [ Change Reason ]
            val okIntent = Intent(context, NotificationActionReceiver::class.java).apply {
                action = NotificationActionReceiver.ACTION_DISMISS
                putExtra(EXTRA_NOTIFICATION_ID, notifId)
            }
            val okPendingIntent = PendingIntent.getBroadcast(
                context,
                notifId * 10 + 1,
                okIntent,
                pendingFlags
            )

            builder.addAction(0, "OK", okPendingIntent)
            builder.addAction(0, "Change Reason", openPendingIntent)
        } else {
            // Mode 3: Uncategorized -> 3 Action Buttons [ Button 1 ], [ Button 2 ], and [ Categorize ]
            val (button1Name, button2Name) = getQuickButtonNames(context)

            val button1Intent = Intent(context, NotificationActionReceiver::class.java).apply {
                action = NotificationActionReceiver.ACTION_SET_REASON
                putExtra(EXTRA_NOTIFICATION_ID, notifId)
                putExtra(EXTRA_TX_ID, txId)
                putExtra(NotificationActionReceiver.EXTRA_REASON_NAME, button1Name)
            }
            val button1PendingIntent = PendingIntent.getBroadcast(
                context,
                notifId * 10 + 2,
                button1Intent,
                pendingFlags
            )

            val button2Intent = Intent(context, NotificationActionReceiver::class.java).apply {
                action = NotificationActionReceiver.ACTION_SET_REASON
                putExtra(EXTRA_NOTIFICATION_ID, notifId)
                putExtra(EXTRA_TX_ID, txId)
                putExtra(NotificationActionReceiver.EXTRA_REASON_NAME, button2Name)
            }
            val button2PendingIntent = PendingIntent.getBroadcast(
                context,
                notifId * 10 + 3,
                button2Intent,
                pendingFlags
            )

            builder.addAction(0, button1Name, button1PendingIntent)
            builder.addAction(0, button2Name, button2PendingIntent)
            builder.addAction(0, "Categorize", openPendingIntent)
        }

        notificationManager.notify(notifId, builder.build())
    }

    private fun getQuickButtonNames(context: Context): Pair<String, String> {
        return try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val btn1 = prefs.getString("flutter.notif_quick_button_1", "Food")?.takeIf { it.isNotBlank() } ?: "Food"
            val btn2 = prefs.getString("flutter.notif_quick_button_2", "Goods")?.takeIf { it.isNotBlank() } ?: "Goods"
            Pair(btn1, btn2)
        } catch (_: Exception) {
            Pair("Food", "Goods")
        }
    }
}
