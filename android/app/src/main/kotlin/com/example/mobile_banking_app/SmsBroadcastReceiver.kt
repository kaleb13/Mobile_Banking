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
        val txReference: String?,
        val totalBalance: Double = 0.0
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
            if (upper.contains("TELEBIRR") || s == "127") return "Telebirr"
            if (upper.contains("CBE") && upper.contains("BIRR")) return "CBE Birr"
            if (upper.contains("CBE")) return "CBE"
            if (upper.contains("AHADU")) return "Ahadu Bank"
            if (upper == "BOA" || upper.contains("ABYSSINIA") || upper.startsWith("BOA")) return "BOA"
            if (upper.contains("DASHEN") || upper.contains("AMOLE")) return "Dashen Bank"
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
            if ((lower.contains("one time") || lower.contains("onetime")) && lower.contains("password")) return true
            if (lower.contains("pin or password will be locked") || lower.contains("password will be locked") || lower.contains("pin will be locked")) return true
            if (lower.contains("mobile password is") || lower.contains("mobile banking password is")) return true
            if (lower.contains("security question") && lower.contains("pin")) return true
            if (lower.contains("temporary pin") || lower.contains("temporary password")) return true
            if (lower.contains("initial pin") || lower.contains("initial password")) return true
            if (lower.contains("your pin is") || lower.contains("your password is") || lower.contains("new pin is")) return true
            if (lower.contains("pin or password is wrong") || lower.contains("password is wrong") || lower.contains("pin is wrong")) return true

            if ((lower.contains("do not share") ||
                lower.contains("never share") ||
                lower.contains("do not disclose") ||
                lower.contains("keep it confidential") ||
                lower.contains("keep it secret")) &&
                (lower.contains("pin") ||
                 lower.contains("otp") ||
                 lower.contains("password") ||
                 lower.contains("code"))) {
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

        fun isIgnoredMessage(body: String): Boolean {
            if (body.isBlank()) return false
            val lower = body.lowercase()

            if (isSecurityOrAuthMessage(body)) return true

            // Loans & Credit notices & repayments
            if (lower.contains("outstanding credit") ||
                lower.contains("credit request with") ||
                lower.contains("credit limit") ||
                lower.contains("credit service") ||
                lower.contains("endekise service") ||
                lower.contains("ethiotel credit") ||
                lower.contains("telebirr mela") ||
                lower.contains("rmelaservice") ||
                lower.contains("loan balance") ||
                lower.contains("loan repayment") ||
                lower.contains("unpaid credit amount") ||
                lower.contains("repaid") ||
                lower.contains("penalty fee") ||
                lower.contains("facilitation fee")) {
                return true
            }

            // Inbound Airtime Gifts
            if (Regex("(?i)(?:received|you received)\\s+(?:etb\\s+)?[0-9.,]+\\s*(?:br\\.?\\s*)?airtime\\s+from").containsMatchIn(lower) ||
                (lower.contains("received") && lower.contains("airtime from"))) {
                return true
            }

            // Marketing, Lottery, Points, KYC, Gift Letters, Bonus Packages
            if (lower.contains("lottery ticket") ||
                lower.contains("lottery id") ||
                lower.contains("received 1 point") ||
                (lower.contains("received") && lower.contains("point")) ||
                lower.contains("gift package") ||
                (lower.contains("package:") && lower.contains("added to your service number")) ||
                lower.contains("lucky draw") ||
                lower.contains("spins on superapp") ||
                lower.contains("kyc upgrade") ||
                lower.contains("won 1 gb") ||
                lower.contains("thank you lucky draw") ||
                lower.contains("chance to draw") ||
                lower.contains("chance(s) to draw") ||
                lower.contains("gift letter") ||
                lower.contains("yegena chewata") ||
                lower.contains("adey flowers") ||
                lower.contains("enkutatesh gift") ||
                lower.contains("enkutatash gift")) {
                return true
            }

            // ATM Cash-Out & Deposit Voucher codes / Card ready notices / temporary invitations
            if (lower.contains("atm cash out") ||
                lower.contains("cash out voucher") ||
                lower.contains("voucher number is") ||
                lower.contains("deposit voucher code") ||
                lower.contains("voucher code is") ||
                lower.contains("secret word is") ||
                lower.contains("atm card is ready") ||
                lower.contains("collect your card") ||
                lower.contains("visa card number has been") ||
                lower.contains("my visa menu") ||
                lower.contains("invitation code is") ||
                lower.contains("you have invited")) {
                return true
            }

            // Payment Requests
            if (lower.contains("payment request of") ||
                lower.contains("is requesting money on") ||
                lower.contains("please review and approve or reject")) {
                return true
            }

            // Errors, Cancellations, Reversals
            if (lower.contains("is cancelled") ||
                lower.contains("has not been successful") ||
                lower.contains("was unsuccessful") ||
                lower.contains("fails to be sent") ||
                lower.contains("reversed to your account") ||
                lower.contains("processing failure response") ||
                lower.contains("insufficient balance for the requested transaction") ||
                lower.contains("is insufficient for the transaction") ||
                lower.contains("balance is insufficient to comp") ||
                lower.contains("wrong amount") ||
                lower.contains("account you try to transfer is not active") ||
                lower.contains("account you try to pay is not active") ||
                lower.contains("failed to authenticate the transaction") ||
                lower.contains("limit rule")) {
                return true
            }

            // Activation, Status & Profile Notices
            if (lower.contains("saving service") ||
                lower.contains("customer status has been change") ||
                lower.contains("account status has been changed") ||
                lower.contains("status has been changed from") ||
                lower.contains("changed to dormant") ||
                lower.contains("signature on your account") ||
                lower.contains("update your profile") ||
                lower.contains("registered for mobile banking") ||
                lower.contains("register yourself for") ||
                lower.contains("successfully registered and activated") ||
                lower.contains("account has been successfully activated") ||
                lower.contains("has been activated successfully") ||
                lower.contains("account is activated successfully") ||
                lower.contains("welcome! we are delighted") ||
                lower.contains("download cbe android application") ||
                lower.contains("start activation") ||
                lower.contains("new login to your mobile")) {
                return true
            }

            // Informational Balances
            if (lower.contains("customer incentive account balance is") ||
                lower.contains("pocketmoneyaccount balance is") ||
                lower.contains("e-money link bank balance is") ||
                lower.contains("customer e-money account balance is")) {
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

        private fun cleanCounterpartyName(raw: String): String {
            var cleaned = raw.trim()
            // Strip parenthesized phone numbers / identifiers e.g. "(2519****9104) 101813" or "(251912345678)"
            cleaned = cleaned.replace(Regex("\\s*\\(.*"), "").trim()
            // Strip trailing reference numbers / digits if any remain e.g. " 101813"
            cleaned = cleaned.replace(Regex("\\s+\\d{4,}\\b.*"), "").trim()
            return if (cleaned.isEmpty()) raw.trim() else cleaned
        }

        /**
         * Pure Fact Extraction Engine (Mirrors Dart Bank Parsers)
         */
        fun parseBankingSms(bankName: String, body: String): NativeParsedSms? {
            val singleLine = body.replace("\n", " ").replace("\r", " ")
            val lower = singleLine.lowercase()

            when (bankName) {
                "Telebirr" -> {
                    var telebirrTotalBal = 0.0
                    val balMatches = Regex("(?i)(?:(saving\\s+)?balance\\s+is\\s+ETB\\s*)([0-9,]+(?:\\.[0-9]+)?)").findAll(singleLine)
                    for (m in balMatches) {
                        val isSaving = m.groupValues[1].isNotBlank()
                        if (!isSaving) {
                            val raw = m.groupValues[2].replace(",", "")
                            val clean = if (raw.endsWith(".")) raw.substring(0, raw.length - 1) else raw
                            val v = clean.toDoubleOrNull() ?: 0.0
                            if (v > 0) {
                                telebirrTotalBal = v
                                break
                            }
                        }
                    }

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
                            directionHeader = if (isIncoming) "From: $phone" else (if (phone != "Airtime") "To: $phone" else "To: Airtime"),
                            title = if (isIncoming) "Income" else "Expense",
                            isLocked = true,
                            lockedReasonName = "Airtime",
                            txReference = ref,
                            totalBalance = telebirrTotalBal
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
                            directionHeader = if (phone != "Package") "To: $phone" else "To: Package",
                            title = "Expense",
                            isLocked = true,
                            lockedReasonName = "Package",
                            txReference = ref,
                            totalBalance = telebirrTotalBal
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
                            directionHeader = if (lower.contains("shamo")) "To: Shamo Account" else "To: Sanduq Savings",
                            title = "Expense",
                            isLocked = true,
                            lockedReasonName = "Internal Transfer",
                            txReference = ref,
                            totalBalance = telebirrTotalBal
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
                            directionHeader = "From: Telebirr Loan",
                            title = "Income",
                            isLocked = true,
                            lockedReasonName = "Loan",
                            txReference = ref,
                            totalBalance = telebirrTotalBal
                        )
                    }

                    // 5. Outgoing Transfer: "transferred ETB 100.00 to Abebe on..."
                    if (lower.contains("transferred")) {
                        val amount = parseAmount(Regex("(?i)transferred\\s+ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) return null

                        val toMatch = Regex("(?i)to\\s+(.*?)\\s+on\\s+\\d{2}/\\d{2}").find(singleLine)
                        val rawRecipient = toMatch?.groupValues?.get(1)?.trim() ?: ""
                        val accMatch = Regex("(?i)account\\s+(?:number\\s+)?([0-9A-Za-z]+)").find(rawRecipient)
                        val recipient = if (accMatch != null) accMatch.groupValues[1].trim() else cleanCounterpartyName(rawRecipient.ifEmpty { "Transfer" })
                        val refMatch = Regex("(?i)transaction\\s+number\\s+(?:is\\s+)?([A-Za-z0-9]+)").find(singleLine)
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "Telebirr",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = true,
                            counterparty = recipient,
                            directionHeader = "To: $recipient",
                            title = "Expense",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref,
                            totalBalance = telebirrTotalBal
                        )
                    }

                    // 6. Incoming Transfer: "received ETB 100.00 from Abebe on..."
                    if (lower.contains("received")) {
                        val amount = parseAmount(Regex("(?i)received\\s+ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) return null

                        val fromMatch = Regex("(?i)from\\s+(.*?)\\s+on\\s+\\d{2}/\\d{2}").find(singleLine)
                        val rawSender = fromMatch?.groupValues?.get(1)?.trim() ?: "Sender"
                        val senderName = cleanCounterpartyName(rawSender)
                        val refMatch = Regex("(?i)transaction\\s+number\\s+(?:is\\s+)?([A-Za-z0-9]+)").find(singleLine)
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "Telebirr",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = false,
                            counterparty = senderName,
                            directionHeader = "From: $senderName",
                            title = "Income",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref,
                            totalBalance = telebirrTotalBal
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
                            directionHeader = "To: Telebirr",
                            title = "Expense",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref,
                            totalBalance = telebirrTotalBal
                        )
                    }

                    // 8. Merchant / Betting Deposit: "deposited ETB 100.00 to 500004 - Betika Sport Betting on..."
                    if (lower.contains("deposited") && lower.contains("to")) {
                        val amount = parseAmount(Regex("(?i)deposited\\s+ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) return null

                        val toMatch = Regex("(?i)to\\s+(.*?)\\s+on\\s+\\d{2}/\\d{2}").find(singleLine)
                        val rawRecipient = toMatch?.groupValues?.get(1)?.trim() ?: ""
                        val dashSplit = rawRecipient.split(" - ")
                        val recipient = if (dashSplit.size >= 2 && dashSplit[0].trim().matches(Regex("^\\d+$"))) {
                            dashSplit.subList(1, dashSplit.size).joinToString(" - ").trim()
                        } else {
                            rawRecipient.ifEmpty { "Merchant Deposit" }
                        }
                        val refMatch = Regex("(?i)transaction\\s+number\\s+(?:is\\s+)?([A-Za-z0-9]+)").find(singleLine)
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "Telebirr",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = true,
                            counterparty = recipient,
                            directionHeader = "To: $recipient",
                            title = "Expense",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref,
                            totalBalance = telebirrTotalBal
                        )
                    }

                    // 9. Inbound Agent Cash Deposit & Direct Credit
                    if (lower.contains("credited with etb") || lower.contains("credited with")) {
                        val amount = parseAmount(Regex("(?i)credited\\s+with\\s+ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) return null

                        val agentMatch = Regex("(?i)via\\s+(?:telebirr\\s+agent|agent)\\s+([0-9A-Za-z]+)").find(singleLine)
                        val agentName = if (agentMatch != null) "telebirr agent ${agentMatch.groupValues[1]}" else "Telebirr Deposit"
                        val refMatch = Regex("(?i)transaction\\s+number\\s+(?:is\\s+)?([A-Za-z0-9]+)").find(singleLine)
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "Telebirr",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = false,
                            counterparty = agentName,
                            directionHeader = "From: $agentName",
                            title = "Income",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref,
                            totalBalance = telebirrTotalBal
                        )
                    }

                    // 10. Paid to merchant / digital service
                    if (lower.contains("paid")) {
                        val amount = parseAmount(Regex("(?i)paid\\s+ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) return null

                        val forMatch = Regex("(?i)(?:to|for)\\s+(.*?)\\s+(?:on\\s+\\d{2}/\\d{2}|for\\s+)").find(singleLine)
                            ?: Regex("(?i)(?:to|for)\\s+(.*?)\\s+on\\s+\\d{2}/\\d{2}").find(singleLine)
                        val rawDesc = forMatch?.groupValues?.get(1)?.trim() ?: "Merchant Payment"
                        val refMatch = Regex("(?i)transaction\\s+number\\s+(?:is\\s+)?([A-Za-z0-9]+)").find(singleLine)
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "Telebirr",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = true,
                            counterparty = rawDesc,
                            directionHeader = "To: $rawDesc",
                            title = "Expense",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref,
                            totalBalance = telebirrTotalBal
                        )
                    }
                }

                "CBE" -> {
                    val cbeBalMatch = Regex("(?i)[Cc]urrent\\s+[Bb]alance\\s+is\\s+ETB\\s*([0-9,]+\\.?\\d*)").find(singleLine)
                    val cbeTotalBal = if (cbeBalMatch != null) {
                        val raw = cbeBalMatch.groupValues[1].replace(",", "")
                        val clean = if (raw.endsWith(".")) raw.substring(0, raw.length - 1) else raw
                        clean.toDoubleOrNull() ?: 0.0
                    } else 0.0

                    if (lower.contains("credited")) {
                        var amount = parseAmount(Regex("(?i)credited\\s+with\\s+ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) {
                            amount = parseAmount(Regex("(?i)credited\\s+by\\s+.+?\\s+with\\s+ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        }
                        if (amount <= 0) return null

                        val fromMatch = Regex("(?i)from\\s+(.*?)(?:,\\s*on|\\s+on\\s+\\d{2}/\\d{2})").find(singleLine)
                        val byMatch = Regex("(?i)credited\\s+by\\s+(.*?)\\s+with\\s+ETB").find(singleLine)
                        val senderName = fromMatch?.groupValues?.get(1)?.trim()
                            ?: byMatch?.groupValues?.get(1)?.trim()
                            ?: "CBE Deposit"

                        var refMatch = Regex("(?i)ref\\s*(?:no\\.?)?\\s*([A-Za-z0-9]+)").find(singleLine)
                        if (refMatch == null) {
                            refMatch = Regex("(?i)(FT[0-9A-Z]+)").find(singleLine)
                        }
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "CBE",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = false,
                            counterparty = senderName,
                            directionHeader = "From: $senderName",
                            title = "Income",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref,
                            totalBalance = cbeTotalBal
                        )
                    }

                    if (lower.contains("transfer")) {
                        val amount = parseAmount(Regex("(?i)transferr?ed\\s+ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine).let {
                            if (it > 0) it else parseAmount(Regex("(?i)transfer\\s+of\\s+ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        }
                        if (amount > 0) {
                            val toMatch = Regex("(?i)to\\s+(.*?)(?:,\\s*on|\\s+on\\s+\\d{2}/\\d{2})").find(singleLine)
                            val recipient = toMatch?.groupValues?.get(1)?.trim() ?: run {
                                val toMatchParens = Regex("(?i)to\\s+account\\s+[\\d*]+\\s+\\(([^)]+)\\)").find(singleLine)
                                toMatchParens?.groupValues?.get(1)?.trim() ?: "CBE Transfer"
                            }
                            val refMatch = Regex("(?i)id=([A-Za-z0-9]+)").find(singleLine)
                                ?: Regex("(?i)ref\\s*(?:no\\.?)?\\s*([A-Za-z0-9]+)").find(singleLine)
                                ?: Regex("(FT[0-9A-Z]+)").find(singleLine)
                            val ref = refMatch?.groupValues?.get(1)?.trim()

                            return NativeParsedSms(
                                bankName = "CBE",
                                amount = amount,
                                formattedAmount = formatEtb(amount),
                                isDebit = true,
                                counterparty = recipient,
                                directionHeader = "To: $recipient",
                                title = "Expense",
                                isLocked = false,
                                lockedReasonName = null,
                                txReference = ref,
                                totalBalance = cbeTotalBal
                            )
                        }
                    }

                    if (lower.contains("debited") || lower.contains("withdrawn")) {
                        val amount = parseAmount(Regex("(?i)debited\\s+with\\s+ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) return null
                        val toMatch = Regex("(?i)to\\s+(.*?)(?:,\\s*on|\\s+on\\s+\\d{2}/\\d{2})").find(singleLine)
                        val recipient = toMatch?.groupValues?.get(1)?.trim() ?: "CBE Withdrawal"
                        val refMatch = Regex("(?i)id=([A-Za-z0-9]+)").find(singleLine)
                            ?: Regex("(?i)ref\\s*(?:no\\.?)?\\s*([A-Za-z0-9]+)").find(singleLine)
                            ?: Regex("(FT[0-9A-Z]+)").find(singleLine)
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        return NativeParsedSms(
                            bankName = "CBE",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = true,
                            counterparty = recipient,
                            directionHeader = "To: $recipient",
                            title = "Expense",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref,
                            totalBalance = cbeTotalBal
                        )
                    }
                }

                "BOA" -> {
                    val boaBalMatch = Regex("(?i)(?:Available\\s+Balance|Current\\s+Balance|Balance)\\s*(?:is|:)?\\s*(?:ETB|Birr|Br\\.?)?\\s*([0-9,.]+)").find(singleLine)
                    val boaTotalBal = if (boaBalMatch != null) {
                        val raw = boaBalMatch.groupValues[1].replace(",", "")
                        val clean = if (raw.endsWith(".")) raw.substring(0, raw.length - 1) else raw
                        clean.toDoubleOrNull() ?: 0.0
                    } else 0.0

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
                            title = "Income",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref,
                            totalBalance = boaTotalBal
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
                            directionHeader = "To: BOA",
                            title = "Expense",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref,
                            totalBalance = boaTotalBal
                        )
                    }
                }

                "Ahadu Bank" -> {
                    val ahaduBalMatch = Regex("(?i)(?:balance\\s+is\\s+(?:ETB\\s*)?|current\\s+balance\\s*(?:is|:)?\\s*(?:ETB\\s*)?|available\\s+balance\\s*(?:is|:)?\\s*(?:ETB\\s*)?|ቀሪ\\s+ሂሳብዎ\\s*(?:ETB|ብር)?\\s*)([0-9,.]+)").find(singleLine)
                    val ahaduTotalBal = if (ahaduBalMatch != null) {
                        val raw = ahaduBalMatch.groupValues[1].replace(",", "")
                        val clean = if (raw.endsWith(".")) raw.substring(0, raw.length - 1) else raw
                        clean.toDoubleOrNull() ?: 0.0
                    } else 0.0

                    if (lower.contains("credited") || lower.contains("received") || lower.contains("deposit")) {
                        val amount = parseAmount(Regex("(?i)ETB\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                        if (amount <= 0) return null
                        var refMatch = Regex("(?i)(?:reference\\s+number|ref(?:erence)?\\s*(?:no\\.?)?|ref\\.?)\\s*:?\\s*([A-Za-z0-9]+)").find(singleLine)
                        if (refMatch == null) {
                            refMatch = Regex("(?i)digitalreceipt\\?es=([A-Za-z0-9/\\-_]+)").find(singleLine)
                        }
                        val ref = refMatch?.groupValues?.get(1)?.trim()

                        var counterparty = "Ahadu Deposit"
                        val fromMatch = Regex("(?i)from\\s+(.*?)\\s+(?:with\\s+reference|with\\s+ref|on\\s+\\d{1,2}-|\\.)").find(singleLine)
                        if (fromMatch != null) {
                            var rawSender = fromMatch.groupValues[1].trim()
                            val ofMatch = Regex("(?i)^(?:Telebirr|CBE|BOA|Dashen|Bank|[A-Za-z]+)\\s+of\\s+(.+)$").find(rawSender)
                            if (ofMatch != null) {
                                rawSender = ofMatch.groupValues[1].trim()
                            }
                            if (rawSender.isNotEmpty()) counterparty = rawSender
                        }

                        return NativeParsedSms(
                            bankName = "Ahadu Bank",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = false,
                            counterparty = counterparty,
                            directionHeader = "From: $counterparty",
                            title = "Income",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref,
                            totalBalance = ahaduTotalBal
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

                        var counterparty = "Ahadu Transfer"
                        val toMatch = Regex("(?i)to\\s+(.*?)\\s+(?:with\\s+reference|with\\s+ref|on\\s+\\d{1,2}-|\\.)").find(singleLine)
                        if (toMatch != null) {
                            var rawRecipient = toMatch.groupValues[1].trim()
                            val ofMatch = Regex("(?i)^(?:Telebirr|CBE|BOA|Dashen|Bank|[A-Za-z]+)\\s+of\\s+(.+)$").find(rawRecipient)
                            if (ofMatch != null) {
                                rawRecipient = ofMatch.groupValues[1].trim()
                            }
                            if (rawRecipient.isNotEmpty()) counterparty = rawRecipient
                        }

                        return NativeParsedSms(
                            bankName = "Ahadu Bank",
                            amount = amount,
                            formattedAmount = formatEtb(amount),
                            isDebit = true,
                            counterparty = counterparty,
                            directionHeader = "To: $counterparty",
                            title = "Expense",
                            isLocked = false,
                            lockedReasonName = null,
                            txReference = ref,
                            totalBalance = ahaduTotalBal
                        )
                    }
                }

                "Dashen Bank" -> {
                    val dashenBalMatch = Regex("(?i)(?:balance\\s+is\\s+(?:ETB\\s*)?|a/c\\s+balance\\s+is\\s*(?:ETB)?\\s*|current\\s+balance\\s*is\\s*(?:ETB)?\\s*)([0-9,.]+)").find(singleLine)
                    val dashenTotalBal = if (dashenBalMatch != null) {
                        val raw = dashenBalMatch.groupValues[1].replace(",", "")
                        val clean = if (raw.endsWith(".")) raw.substring(0, raw.length - 1) else raw
                        clean.toDoubleOrNull() ?: 0.0
                    } else 0.0

                    var amount = parseAmount(Regex("(?i)(?:debited\\s+with|withdrawn|debit|paid|transferred)\\s+(?:ETB|Birr|USD)?\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                    if (amount <= 0) {
                        amount = parseAmount(Regex("(?i)(?:credited\\s+with|has\\s+deposited|deposited|received)\\s+(?:ETB|Birr|USD)?\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                    }
                    if (amount <= 0) {
                        amount = parseAmount(Regex("(?i)(?:ETB|Birr)\\s*([0-9,]+(?:\\.[0-9]+)?)"), singleLine)
                    }
                    if (amount <= 0) return null
                    val isDebit = lower.contains("debited") || lower.contains("transfer") || lower.contains("transferred") || lower.contains("paid") || lower.contains("withdrawn")

                    val refMatch = Regex("(?i)(?:transaction\\s*reference|ref\\s*no|reference|ref|txn\\s*id|txn\\s*no)[:\\s]*([A-Za-z0-9]+)").find(singleLine)
                    val ref = refMatch?.groupValues?.get(1)?.trim()

                    val toMatch = Regex("(?i)to\\s+([A-Za-z0-9\\s().+'’*:/\\\\#-]+?)(?:\\s+on\\s+\\d|\\s+at\\s+\\d|\\.\\s*|\\n|$)").find(singleLine)
                    val counterparty = if (isDebit) {
                        val raw = toMatch?.groupValues?.get(1)?.trim() ?: ""
                        if (raw.isNotEmpty() && !raw.startsWith("your account", ignoreCase = true) && !raw.startsWith("account", ignoreCase = true)) {
                            val cleanName = raw.replace(Regex("(?i)(?:'s|’s)?\\s+(?:tele\\s*birr\\s+|telebirr\\s+)?account(?:\\s+number)?(?:\\s*[:.\\s]*[0-9+*]+)?.*$"), "").trim()
                            if (cleanName.isNotEmpty()) cleanName else "Dashen Transfer"
                        } else "Dashen Transfer"
                    } else "Dashen Deposit"

                    return NativeParsedSms(
                        bankName = "Dashen Bank",
                        amount = amount,
                        formattedAmount = formatEtb(amount),
                        isDebit = isDebit,
                        counterparty = counterparty,
                        directionHeader = if (isDebit) "To: $counterparty" else "From: $counterparty",
                        title = if (isDebit) "Expense" else "Income",
                        isLocked = false,
                        lockedReasonName = null,
                        txReference = ref,
                        totalBalance = dashenTotalBal
                    )
                }

                "CBE Birr" -> {
                    val cbeBirrBalMatch = Regex("(?i)(?:current\\s+balance\\s+is\\s*(?:ETB|Br\\.?)?\\s*|balance\\s+is\\s*(?:ETB|Br\\.?)?\\s*)([0-9,]+(?:\\.[0-9]+)?)").find(singleLine)
                    val cbeBirrTotalBal = if (cbeBirrBalMatch != null) {
                        val raw = cbeBirrBalMatch.groupValues[1].replace(",", "")
                        val clean = if (raw.endsWith(".")) raw.substring(0, raw.length - 1) else raw
                        clean.toDoubleOrNull() ?: 0.0
                    } else 0.0

                    val amount = parseAmount(Regex("(?i)([0-9,]+(?:\\.[0-9]+)?)\\s*Br\\.?"), singleLine)
                    if (amount <= 0) return null
                    val isDebit = lower.contains("paid") || lower.contains("transferred") || lower.contains("debited")
                    val refMatch = Regex("(?i)(?:txn\\s*id|transaction\\s*id(?:\\s*is)?|ref(?:erence)?(?:\\s*id)?|eqn)\\s*[:.]?\\s*([A-Za-z0-9]+)").find(singleLine)
                    val ref = refMatch?.groupValues?.get(1)?.trim()

                    val fromMatch = Regex("(?i)from\\s+(.*?)(?:\\s+on\\s+|\\s*,|\\s*\\.)").find(singleLine)
                    val rawSender = fromMatch?.groupValues?.get(1)?.trim() ?: ""
                    val dashSplit = rawSender.split(" - ")
                    val senderOrRecip = if (dashSplit.size >= 2 && dashSplit[0].trim().matches(Regex("^\\d+$"))) {
                        dashSplit.subList(1, dashSplit.size).joinToString(" - ").trim()
                    } else if (rawSender.isNotEmpty()) {
                        rawSender
                    } else {
                        if (isDebit) "CBE Birr Payment" else "CBE Birr Deposit"
                    }

                    return NativeParsedSms(
                        bankName = "CBE Birr",
                        amount = amount,
                        formattedAmount = formatEtb(amount),
                        isDebit = isDebit,
                        counterparty = senderOrRecip,
                        directionHeader = if (isDebit) "To: $senderOrRecip" else "From: $senderOrRecip",
                        title = if (isDebit) "Expense" else "Income",
                        isLocked = false,
                        lockedReasonName = null,
                        txReference = ref,
                        totalBalance = cbeBirrTotalBal
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
        if (isIgnoredMessage(body)) return

        val txId = generateId(sender, timestampMs, body)

        // 1. Parse into structured banking facts. Drop non-transaction messages or broken SMS parts!
        val parsed = parseBankingSms(bankName, body)
        if (parsed == null) {
            // Unrecognized or unparsed banking SMS: save to notifications table for manual user setup
            insertNotificationIntoDb(context, txId, bankName, body, timestampMs)
            return
        }

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

        // Extract SIM slot & account identifier
        val subId = intent.getIntExtra(android.telephony.SubscriptionManager.EXTRA_SUBSCRIPTION_INDEX, 
            intent.getIntExtra("subscription",
            intent.getIntExtra("subscription_id",
            intent.getIntExtra("sub_id", -1))))

        val explicitSlot = intent.getIntExtra("android.telephony.extra.SLOT_INDEX",
            intent.getIntExtra("slot",
            intent.getIntExtra("slot_id",
            intent.getIntExtra("sim_slot",
            intent.getIntExtra("simSlot",
            intent.getIntExtra("phone",
            intent.getIntExtra("phone_id", -1)))))))

        val subManager = try {
            context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? android.telephony.SubscriptionManager
        } catch (_: Throwable) { null }

        val simSlot = when {
            subId >= 0 -> {
                val directSlot = try { subManager?.getActiveSubscriptionInfo(subId)?.simSlotIndex } catch (_: Throwable) { null }
                if (directSlot != null) {
                    directSlot
                } else {
                    val allSubs = try { subManager?.activeSubscriptionInfoList } catch (_: Throwable) { null }
                    val matchedInfo = allSubs?.firstOrNull { it.subscriptionId == subId }
                    matchedInfo?.simSlotIndex ?: if (explicitSlot in 0..1) explicitSlot else (if (subId in 0..1) subId else 0)
                }
            }
            explicitSlot in 0..1 -> explicitSlot
            else -> 0
        }

        var accountIdentifier: String? = null
        val acctMatch = Regex("(?i)(?:account\\s*(?:no\\.?)?\\s*|acc(?:ount)?\\s*)([0-9*]{4,20})").find(body)
        if (acctMatch != null) {
            val rawAcct = acctMatch.groupValues[1]
            if (rawAcct.length >= 4) {
                accountIdentifier = rawAcct.takeLast(4)
            }
        }

        // 3. Resolve attached reason: check internal transfer counterpart first, then locked patterns, then reason_links
        var counterpartId: String? = null
        var internalTransferResolved: ResolvedReason? = null
        if (!parsed.txReference.isNullOrBlank() && parsed.txReference.length >= 4) {
            val oppositeType = if (parsed.isDebit) "income" else "expense"
            try {
                val dbPath = File(context.getDatabasePath(DB_NAME).path)
                if (dbPath.exists()) {
                    val db = SQLiteDatabase.openDatabase(dbPath.path, null, SQLiteDatabase.OPEN_READWRITE)
                    val cursorMatch = db.rawQuery(
                        "SELECT id FROM transactions WHERE (bankReference = ? OR id LIKE ?) AND amount = ? AND type = ? LIMIT 1",
                        arrayOf(parsed.txReference, "${parsed.txReference}_%", parsed.amount.toString(), oppositeType)
                    )
                    if (cursorMatch.moveToFirst()) {
                        counterpartId = cursorMatch.getString(0)
                    }
                    cursorMatch.close()
                    db.close()

                    if (counterpartId != null) {
                        internalTransferResolved = resolveReasonFromDb(context, "Internal Transfer", parsed.counterparty, body)
                    }
                }
            } catch (_: Exception) {}
        }

        val resolvedReason = internalTransferResolved ?: resolveReasonFromDb(
            context,
            if (parsed.isLocked) parsed.lockedReasonName else null,
            parsed.counterparty,
            body
        )

        // 4. Save directly into transactions table in SQLite (never into notifications for parsed SMS)
        insertTransactionIntoDb(context, txId, parsed, body, timestampMs, resolvedReason, simSlot, accountIdentifier, counterpartId)

        // 5. Show Android status bar notification (0 action buttons for locked reasons and Internal Transfers)
        showNotification(context, txId, parsed, resolvedReason?.name, body)

        try {
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                MainActivity.smsEventSink?.success("newTransaction")
            }
        } catch (_: Exception) {}
    }

    data class ResolvedReason(
        val name: String,
        val id: Int?,
        val categoryId: Int?,
        val subcategoryId: Int?
    )

    private fun resolveReasonFromDb(
        context: Context,
        reasonNameOrNull: String?,
        counterparty: String,
        body: String
    ): ResolvedReason? {
        return try {
            val dbPath = File(context.getDatabasePath(DB_NAME).path)
            if (!dbPath.exists()) {
                return if (!reasonNameOrNull.isNullOrBlank()) {
                    ResolvedReason(name = reasonNameOrNull, id = null, categoryId = null, subcategoryId = null)
                } else null
            }

            val db = SQLiteDatabase.openDatabase(
                dbPath.path,
                null,
                SQLiteDatabase.OPEN_READONLY
            )

            var targetReasonName = reasonNameOrNull

            // If reasonName not pre-provided (e.g. not a locked pattern), search reason_links
            if (targetReasonName.isNullOrBlank()) {
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
                            targetReasonName = rName
                            break
                        }
                    }
                }
                cursor.close()
            }

            if (targetReasonName.isNullOrBlank()) {
                db.close()
                return null
            }

            // Look up hierarchy from reasons table
            var reasonId: Int? = null
            var categoryId: Int? = null
            var subcategoryId: Int? = null
            var finalName = targetReasonName

            val cursorReason = db.rawQuery(
                "SELECT id, name, parentId FROM reasons WHERE LOWER(name) = LOWER(?) LIMIT 1",
                arrayOf(targetReasonName)
            )
            if (cursorReason.moveToFirst()) {
                reasonId = cursorReason.getInt(0)
                finalName = cursorReason.getString(1) ?: targetReasonName
                val parentId = if (cursorReason.isNull(2)) null else cursorReason.getInt(2)
                if (parentId != null) {
                    categoryId = parentId
                    subcategoryId = reasonId
                } else {
                    categoryId = reasonId
                    subcategoryId = null
                }
            }
            cursorReason.close()
            db.close()

            ResolvedReason(
                name = finalName,
                id = reasonId,
                categoryId = categoryId,
                subcategoryId = subcategoryId
            )
        } catch (_: Exception) {
            if (!reasonNameOrNull.isNullOrBlank()) {
                ResolvedReason(name = reasonNameOrNull, id = null, categoryId = null, subcategoryId = null)
            } else null
        }
    }

    private fun insertTransactionIntoDb(
        context: Context,
        txId: String,
        parsed: NativeParsedSms,
        body: String,
        timestampMs: Long,
        resolvedReason: ResolvedReason?,
        simSlot: Int = 0,
        accountIdentifier: String? = null,
        counterpartId: String? = null
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

            val rawId = parsed.txReference ?: txId
            val txType = if (parsed.isDebit) "expense" else "income"
            val idToUse = if (rawId.contains("_slot")) rawId else "${rawId}_slot${simSlot}_$txType"

            var effectiveTotalBalance = parsed.totalBalance
            if (effectiveTotalBalance <= 0.0) {
                try {
                    val cursorBal = db.rawQuery(
                        "SELECT totalBalance FROM transactions WHERE name = ? AND simSlot = ? AND totalBalance > 0 ORDER BY date DESC, rowid DESC LIMIT 1",
                        arrayOf(parsed.bankName, simSlot.toString())
                    )
                    if (cursorBal.moveToFirst()) {
                        val prevBal = cursorBal.getDouble(0)
                        if (prevBal > 0.0) {
                            effectiveTotalBalance = if (parsed.isDebit) (prevBal - parsed.amount).coerceAtLeast(0.0) else (prevBal + parsed.amount)
                        }
                    }
                    cursorBal.close()
                } catch (_: Exception) {}
            }

            val sql = """
                INSERT OR IGNORE INTO transactions (
                    id, name, amount, type, date, sender, category, rawMessage,
                    isAutoDetected, totalBalance, reason, reasonId, categoryId,
                    subcategoryId, customReasonText, note, linkedTransactionId,
                    bankReference, isBookmarked, simSlot, accountIdentifier
                ) VALUES (?, ?, ?, ?, ?, ?, 'Auto', ?, 1, ?, ?, ?, ?, ?, NULL, NULL, ?, ?, 0, ?, ?)
            """.trimIndent()

            val statement = db.compileStatement(sql)
            statement.bindString(1, idToUse)
            statement.bindString(2, parsed.bankName)
            statement.bindDouble(3, parsed.amount)
            statement.bindString(4, txType)
            statement.bindString(5, dateIso)
            statement.bindString(6, parsed.counterparty)
            statement.bindString(7, body)
            statement.bindDouble(8, effectiveTotalBalance)

            if (resolvedReason?.name != null) {
                statement.bindString(9, resolvedReason.name)
            } else {
                statement.bindNull(9)
            }

            if (resolvedReason?.id != null) {
                statement.bindLong(10, resolvedReason.id.toLong())
            } else {
                statement.bindNull(10)
            }

            if (resolvedReason?.categoryId != null) {
                statement.bindLong(11, resolvedReason.categoryId.toLong())
            } else {
                statement.bindNull(11)
            }

            if (resolvedReason?.subcategoryId != null) {
                statement.bindLong(12, resolvedReason.subcategoryId.toLong())
            } else {
                statement.bindNull(12)
            }

            if (counterpartId != null) {
                statement.bindString(13, counterpartId)
            } else {
                statement.bindNull(13)
            }

            if (parsed.txReference != null) {
                statement.bindString(14, parsed.txReference)
            } else {
                statement.bindNull(14)
            }

            statement.bindLong(15, simSlot.toLong())
            if (accountIdentifier != null) {
                statement.bindString(16, accountIdentifier)
            } else {
                statement.bindNull(16)
            }

            statement.executeInsert()
            statement.close()

            // If a counterpart transaction was matched, link and update it as Internal Transfer
            if (counterpartId != null) {
                val itId = resolvedReason?.id
                if (itId != null) {
                    db.execSQL(
                        "UPDATE transactions SET reason = 'Internal Transfer', reasonId = ?, linkedTransactionId = ? WHERE id = ?",
                        arrayOf(itId, idToUse, counterpartId)
                    )
                } else {
                    db.execSQL(
                        "UPDATE transactions SET reason = 'Internal Transfer', linkedTransactionId = ? WHERE id = ?",
                        arrayOf(idToUse, counterpartId)
                    )
                }
            }

            db.close()
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun insertNotificationIntoDb(
        context: Context,
        id: String,
        bankName: String,
        body: String,
        timestampMs: Long
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
                VALUES (?, ?, ?, ?, 0, NULL)
            """.trimIndent()

            db.execSQL(sql, arrayOf(id, bankName, body, dateIso))
            db.close()
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun showNotification(
        context: Context,
        txId: String,
        parsed: NativeParsedSms,
        attachedReason: String?,
        body: String
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

        val isInternalTransfer = attachedReason?.equals("Internal Transfer", ignoreCase = true) == true
        val isReasonLocked = parsed.isLocked || isInternalTransfer
        val realTxId = parsed.txReference ?: txId

        val openIntent = if (isReasonLocked) {
            // Locked reason: Launch main app directly (no quick categorization dialog)
            Intent(context, MainActivity::class.java).apply {
                this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EXTRA_TX_ID, realTxId)
                putExtra(EXTRA_NOTIFICATION_ID, notifId)
                putExtra(EXTRA_SMS_BODY, body)
            }
        } else {
            // Unlocked: Launch transparent quick-edit dialog
            Intent(context, TransactionQuickEditActivity::class.java).apply {
                this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EXTRA_TX_ID, realTxId)
                putExtra(EXTRA_NOTIFICATION_ID, notifId)
                putExtra(EXTRA_SMS_BODY, body)
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

        if (isReasonLocked) {
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
                putExtra(EXTRA_TX_ID, realTxId)
                putExtra(EXTRA_SMS_BODY, body)
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
                putExtra(EXTRA_TX_ID, realTxId)
                putExtra(EXTRA_SMS_BODY, body)
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
