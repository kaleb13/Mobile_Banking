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
import java.util.Locale

/**
 * Native BroadcastReceiver that listens for SMS_RECEIVED broadcasts.
 *
 * When an SMS arrives from a known bank sender, this receiver:
 *   1. Checks the sender against a hardcoded allowlist (CBE, Telebirr, etc.)
 *   2. Filters out OTP/PIN/security messages
 *   3. Generates a SHA-256 idempotency key from sender|timestamp|body
 *   4. Inserts a row into the app's SQLite database (INSERT OR IGNORE)
 *   5. Shows a rich 3-line Android notification banner with dynamic action buttons:
 *        - Attached Reason: [ OK ] and [ Change Reason ]
 *        - Uncategorized: [ Food ], [ Utilities ], and [ Open ]
 *   6. Pushes an event to Flutter via static EventSink (if Flutter engine is alive)
 */
class SmsBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val CHANNEL_ID = "sms_auto_detect"
        private const val CHANNEL_NAME = "SMS Auto-Detect"
        private const val DB_NAME = "finance_v3.db"

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

        /**
         * Matches a sender address against the hardcoded bank allowlist.
         */
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

        /**
         * Returns true if the text contains Amharic Ethiopic characters.
         */
        fun isAmharicMessage(body: String): Boolean {
            return body.any { it in '\u1200'..'\u137F' }
        }

        /**
         * Returns true if the text contains at least one English banking keyword.
         */
        fun isEnglishBankingMessage(body: String): Boolean {
            val lower = body.lowercase()
            val keywords = listOf(
                "received", "sent", "send", "transferred", "transfer", "paid", "pay",
                "payment", "credited", "credit", "debited", "debit", "deposited",
                "deposit", "withdrawn", "withdrawal", "withdraw", "balance", "account",
                "available", "remaining", "amount", "total", "birr", "etb", "usd",
                "loan", "repay", "due", "transaction", "txn", "ref no", "reference",
                "purchase", "charged", "fee", "bank", "wallet", "mobile money",
                "telebirr", "cbe", "ahadu", "boa", "dashen"
            )
            return keywords.any { lower.contains(it) }
        }

        /**
         * Returns true if the message is a security/auth/OTP message.
         */
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

            // ── Amharic PIN / Password / Security / OTP patterns ─────────────
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

        /**
         * Generates a SHA-256 fingerprint from sender, timestamp, and body.
         */
        fun generateId(sender: String, timestampMs: Long, body: String): String {
            val input = "$sender|$timestampMs|$body"
            val digest = MessageDigest.getInstance("SHA-256")
            val hashBytes = digest.digest(input.toByteArray(Charsets.UTF_8))
            return hashBytes.joinToString("") { "%02x".format(it) }
        }

        /**
         * Extracts transaction amount from SMS text.
         */
        fun extractAmount(body: String): String {
            val regex = Regex("(?i)(?:ETB|Birr|Br\\.?|USD)\\s*([0-9,]+(?:\\.[0-9]{1,2})?)")
            val match = regex.find(body)
            if (match != null) {
                val rawAmountStr = match.groupValues[1].replace(",", "")
                val doubleVal = rawAmountStr.toDoubleOrNull()
                if (doubleVal != null) {
                    val formatter = NumberFormat.getNumberInstance(Locale.US).apply {
                        minimumFractionDigits = 2
                        maximumFractionDigits = 2
                    }
                    return "ETB ${formatter.format(doubleVal)}"
                }
            }

            // Fallback: simple numeric extraction
            val numRegex = Regex("([0-9]{1,6}(?:\\.[0-9]{1,2})?)")
            val numMatch = numRegex.find(body)
            if (numMatch != null) {
                val rawAmountStr = numMatch.groupValues[1].replace(",", "")
                val doubleVal = rawAmountStr.toDoubleOrNull()
                if (doubleVal != null) {
                    val formatter = NumberFormat.getNumberInstance(Locale.US).apply {
                        minimumFractionDigits = 2
                        maximumFractionDigits = 2
                    }
                    return "ETB ${formatter.format(doubleVal)}"
                }
            }
            return "ETB 0.00"
        }

        /**
         * Extracts person name or counterparty from SMS text.
         */
        fun extractPersonName(body: String): String? {
            // "to Kaleb Kebede" or "from Kaleb Kebede"
            val toFromRegex = Regex("(?i)(?:to|from)\\s+([A-Za-z]+(?:\\s+[A-Za-z]+)?)")
            val match = toFromRegex.find(body)
            if (match != null) {
                val name = match.groupValues[1].trim()
                // Ignore known bank names
                val upper = name.uppercase()
                if (!upper.contains("BANK") && !upper.contains("TELEBIRR") && !upper.contains("CBE")) {
                    return name
                }
            }
            return null
        }

        /**
         * Returns a direction header string like "To: John" or "From: John".
         */
        fun getDirectionHeader(bankName: String, body: String): String {
            val person = extractPersonName(body)
            if (!person.isNullOrBlank()) {
                val lower = body.lowercase()
                val isDebit = lower.contains("debit") || lower.contains("transferred") ||
                        lower.contains("paid") || lower.contains("spent") ||
                        lower.contains("transfer to") || lower.contains("payment to")
                return if (isDebit) "To: $person" else "From: $person"
            }
            val lower = body.lowercase()
            val isDebit = lower.contains("debit") || lower.contains("transferred") ||
                    lower.contains("paid") || lower.contains("spent") ||
                    lower.contains("transfer to") || lower.contains("payment to")
            return if (isDebit) "Debit ($bankName)" else "Credit ($bankName)"
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
        if (!isEnglishBankingMessage(body)) return

        val txId = generateId(sender, timestampMs, body)
        val attachedReason = checkAttachedReasonInDb(context, sender, body)

        // Show Android system status bar notification with interactive action buttons
        showNotification(context, txId, bankName, body, attachedReason)

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
        sender: String
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
                INSERT OR IGNORE INTO notifications (id, sender, body, date, isRead)
                VALUES (?, ?, ?, ?, 0)
            """.trimIndent()

            db.execSQL(sql, arrayOf(id, bankName, body, dateIso))
            db.close()
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Checks SQLite database to see if the message or counterparty has a linked reason.
     * Only returns a valid reason name from the `reasons` / `reason_links` tables.
     * System bank names (e.g. "CBE", "Telebirr") are NEVER returned as attached reasons.
     */
    private fun checkAttachedReasonInDb(context: Context, sender: String, body: String): String? {
        return try {
            val dbPath = File(context.getDatabasePath(DB_NAME).path)
            if (!dbPath.exists()) return null

            val db = SQLiteDatabase.openDatabase(
                dbPath.path,
                null,
                SQLiteDatabase.OPEN_READONLY
            )

            var reason: String? = null

            // 1. Check Telebirr credit/loan auto-reasons
            val lower = body.lowercase()
            if (lower.contains("credit loan") || lower.contains("loan disbursement") || lower.contains("credit request") || lower.contains("contract number") || lower.contains("outstanding credit amount")) {
                reason = "Loan"
            }

            // 2. Check internal transfers (Sanduq / self transfer)
            if (reason == null && (lower.contains("sanduq") || lower.contains("internal transfer"))) {
                reason = "Internal Transfer"
            }

            // 3. Check reason_links table joined with reasons table
            if (reason == null) {
                try {
                    val cursor = db.rawQuery("""
                        SELECT r.name, rl.linkedName
                        FROM reason_links rl
                        JOIN reasons r ON rl.reasonId = r.id
                    """.trimIndent(), null)

                    while (cursor.moveToNext()) {
                        val rName = cursor.getString(0)
                        val linkedName = cursor.getString(1) ?: ""
                        if (linkedName.isNotBlank() && lower.contains(linkedName.lowercase())) {
                            reason = rName
                            break
                        }
                    }
                    cursor.close()
                } catch (_: Exception) {
                    // Table reason_links or reasons might not exist yet on fresh install
                }
            }

            db.close()
            reason
        } catch (e: Exception) {
            null
        }
    }

    private fun isLockedReason(reason: String?, body: String): Boolean {
        val rLower = reason?.lowercase()?.trim() ?: ""
        val bLower = body.lowercase().trim()
        return rLower == "loan" ||
               rLower == "internal transfer" ||
               rLower == "bounce" ||
               rLower == "saving" ||
               rLower == "savings" ||
               bLower.contains("credit loan") ||
               bLower.contains("loan disbursement") ||
               bLower.contains("credit request") ||
               bLower.contains("contract number") ||
               bLower.contains("outstanding credit amount") ||
               bLower.contains("sanduq") ||
               bLower.contains("saving account") ||
               bLower.contains("saving balance")
    }

    private fun extractPersonName(body: String): String? {
        val pattern = java.util.regex.Pattern.compile("(?:from|to|by)\\s+([A-Za-z]+(?:\\s+[A-Za-z]+){0,4})", java.util.regex.Pattern.CASE_INSENSITIVE)
        val matcher = pattern.matcher(body)
        if (matcher.find()) {
            val rawName = matcher.group(1)?.trim() ?: return null
            val nonPersonKeywords = setOf("cbe", "telebirr", "ahadu", "bank", "account", "mobile", "service", "ethiopia", "atm")
            if (!nonPersonKeywords.contains(rawName.lowercase(java.util.Locale.US))) {
                return limitPersonNameWords(rawName)
            }
        }
        return null
    }

    private fun limitPersonNameWords(name: String): String {
        val words = name.trim().split("\\s+".toRegex()).filter { it.isNotEmpty() }
        return when {
            words.isEmpty() -> name
            words.size == 1 -> words[0]
            else -> "${words[0]} ${words[1]}" // Max 2 words! (1 shows 1, 3 shows 2)
        }
    }

    private fun showNotification(
        context: Context,
        txId: String,
        bankName: String,
        body: String,
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

        val isLocked = isLockedReason(attachedReason, body)
        val resolvedReason = if (isLocked && attachedReason.isNullOrBlank()) {
            if (body.lowercase().contains("sanduq") || body.lowercase().contains("internal transfer")) "Internal Transfer" else "Loan"
        } else {
            attachedReason
        }

        val directionLine = getDirectionHeader(bankName, body)
        val amountLine = extractAmount(body)
        val reasonLine = if (!resolvedReason.isNullOrBlank()) {
            if (isLocked) "$resolvedReason (Locked)" else resolvedReason
        } else {
            "Uncategorized"
        }

        val personName = extractPersonName(body)
        val title = if (!personName.isNullOrBlank()) {
            "Transaction with $personName"
        } else {
            "Banking SMS from $bankName"
        }

        val bigText = "$directionLine\nAmount: $amountLine\nReason: $reasonLine"

        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val openIntent = if (isLocked) {
            // Locked reason: Launch main app directly (no quick-edit categorization dialog)
            Intent(context, MainActivity::class.java).apply {
                this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
        } else {
            // Unlocked: Launch the transparent quick-edit dialog
            Intent(context, TransactionQuickEditActivity::class.java).apply {
                this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(TransactionQuickEditActivity.EXTRA_TX_ID, txId)
                putExtra(TransactionQuickEditActivity.EXTRA_SMS_BODY, body)
                putExtra(TransactionQuickEditActivity.EXTRA_BANK_NAME, bankName)
                putExtra(TransactionQuickEditActivity.EXTRA_AMOUNT, amountLine)
                putExtra(TransactionQuickEditActivity.EXTRA_DIRECTION, directionLine)
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

        if (isLocked) {
            // Locked Reason Case: NO action buttons. Plain informative notification. Tapping opens the main app.
        } else if (!attachedReason.isNullOrBlank()) {
            // Attached Unlocked Reason Case: 2 Action Buttons [ OK ] and [ Change Reason ]
            val okIntent = Intent(context, NotificationActionReceiver::class.java).apply {
                action = NotificationActionReceiver.ACTION_DISMISS
                putExtra(NotificationActionReceiver.EXTRA_NOTIFICATION_ID, notifId)
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
            // Uncategorized Case: 3 Action Buttons [ Food ], [ Goods ], and [ Categorize ]
            val foodIntent = Intent(context, NotificationActionReceiver::class.java).apply {
                action = NotificationActionReceiver.ACTION_SET_REASON
                putExtra(NotificationActionReceiver.EXTRA_NOTIFICATION_ID, notifId)
                putExtra(NotificationActionReceiver.EXTRA_TX_ID, txId)
                putExtra(NotificationActionReceiver.EXTRA_SMS_BODY, body)
                putExtra(NotificationActionReceiver.EXTRA_REASON_NAME, "Food")
            }
            val foodPendingIntent = PendingIntent.getBroadcast(
                context,
                notifId * 10 + 2,
                foodIntent,
                pendingFlags
            )

            val goodsIntent = Intent(context, NotificationActionReceiver::class.java).apply {
                action = NotificationActionReceiver.ACTION_SET_REASON
                putExtra(NotificationActionReceiver.EXTRA_NOTIFICATION_ID, notifId)
                putExtra(NotificationActionReceiver.EXTRA_TX_ID, txId)
                putExtra(NotificationActionReceiver.EXTRA_SMS_BODY, body)
                putExtra(NotificationActionReceiver.EXTRA_REASON_NAME, "Goods")
            }
            val goodsPendingIntent = PendingIntent.getBroadcast(
                context,
                notifId * 10 + 3,
                goodsIntent,
                pendingFlags
            )

            builder.addAction(0, "Food", foodPendingIntent)
            builder.addAction(0, "Goods", goodsPendingIntent)
            builder.addAction(0, "Categorize", openPendingIntent)
        }

        notificationManager.notify(notifId, builder.build())
    }
}
