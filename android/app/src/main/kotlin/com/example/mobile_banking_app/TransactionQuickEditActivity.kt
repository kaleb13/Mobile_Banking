package com.example.mobile_banking_app

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Transparent floating Activity for quick transaction categorization.
 *
 * Launched from notification actions ("Open" / "Categorize") instead of
 * opening the full MainActivity. Hosts a lightweight Flutter engine that
 * renders a compact glassmorphism card with transaction info and reason
 * selector chips.
 *
 * The Activity has a transparent theme (QuickEditTheme) so it floats
 * over whatever app the user is currently using.
 *
 * Intent extras:
 *   - extra_tx_id: SHA-256 notification key
 *   - extra_sms_body: raw SMS text
 *   - extra_bank_name: resolved bank name (e.g. "CBE", "Telebirr")
 *   - extra_amount: formatted amount string (e.g. "ETB 1,500.00")
 *   - extra_direction: direction header (e.g. "From: CBE")
 */
class TransactionQuickEditActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL_NAME = "com.shibre/quick_edit"
        private const val DB_NAME = "finance_v3.db"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val REASON_UPDATE_PENDING_KEY = "flutter.reason_update_pending"
        private const val TAG = "QuickEditActivity"

        const val EXTRA_NOTIFICATION_ID = "extra_notification_id"
        const val EXTRA_TX_ID = "extra_tx_id"
        const val EXTRA_SMS_BODY = "extra_sms_body"
        const val EXTRA_BANK_NAME = "extra_bank_name"
        const val EXTRA_AMOUNT = "extra_amount"
        const val EXTRA_DIRECTION = "extra_direction"
    }

    override fun getDartEntrypointFunctionName(): String = "quickEditMain"

    // CRITICAL: Tell Flutter's rendering surface to be transparent.
    // Without this, Flutter draws an opaque background even if the
    // Android theme is translucent.
    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val notifId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, -1)
        val txId = intent.getStringExtra(EXTRA_TX_ID) ?: ""
        val smsBody = intent.getStringExtra(EXTRA_SMS_BODY) ?: ""
        val bankName = intent.getStringExtra(EXTRA_BANK_NAME) ?: ""
        val amount = intent.getStringExtra(EXTRA_AMOUNT) ?: ""
        val direction = intent.getStringExtra(EXTRA_DIRECTION) ?: ""

        // Load reasons from SQLite to pass to Flutter
        val reasons = loadReasonsFromDb()

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME
        )

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getTransactionData" -> {
                    val currentTx = loadCurrentTransaction(txId, smsBody)
                    val resolvedTxId = (currentTx["id"] as? String)?.takeIf { it.isNotBlank() } ?: txId
                    val resolvedBank = (currentTx["name"] as? String)?.takeIf { it.isNotBlank() } ?: bankName
                    val resolvedAmount = (currentTx["amount"] as? String)?.takeIf { it.isNotBlank() } ?: amount
                    val resolvedType = (currentTx["type"] as? String)?.takeIf { it.isNotBlank() }
                        ?: if (direction.contains("From", true)) "income" else "expense"
                    val resolvedSender = (currentTx["sender"] as? String) ?: ""
                    val resolvedDate = (currentTx["date"] as? String) ?: ""
                    val rawAmount = (currentTx["rawAmount"] as? Double) ?: 0.0

                    val data = mapOf(
                        "txId" to resolvedTxId,
                        "smsBody" to smsBody,
                        "bankName" to resolvedBank,
                        "amount" to resolvedAmount,
                        "rawAmount" to rawAmount,
                        "type" to resolvedType,
                        "direction" to direction,
                        "sender" to resolvedSender,
                        "date" to resolvedDate,
                        "reasons" to reasons,
                    )
                    result.success(data)
                }

                "getTransferCandidates" -> {
                    val candidates = getTransferCandidates(txId, smsBody)
                    result.success(candidates)
                }

                "linkInternalTransfer" -> {
                    val targetTxId = call.argument<String>("targetTxId") ?: ""
                    if (targetTxId.isNotBlank()) {
                        val linked = linkInternalTransfer(txId, smsBody, targetTxId)
                        if (linked) {
                            setReasonUpdatePending()
                            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                            if (notifId != -1) notificationManager?.cancel(notifId)
                            if (txId.isNotBlank()) notificationManager?.cancel(txId.hashCode())
                            if (targetTxId.isNotBlank()) notificationManager?.cancel(targetTxId.hashCode())
                            try {
                                MainActivity.smsEventSink?.success("reasonUpdated")
                            } catch (_: Exception) {}
                        }
                        result.success(linked)
                    } else {
                        result.error("INVALID", "Target transaction ID is blank", null)
                    }
                    finish()
                }

                "saveLoan" -> {
                    val loanType = call.argument<String>("loanType") ?: "lent"
                    val personName = call.argument<String>("personName") ?: ""
                    val trackedSenderName = call.argument<String>("trackedSenderName") ?: bankName
                    val principalAmount = call.argument<Double>("amount") ?: 0.0
                    val loanDate = call.argument<String>("loanDate") ?: ""
                    val dueDate = call.argument<String>("dueDate") ?: ""
                    val note = call.argument<String>("note")

                    val saved = saveLoanRecord(
                        txId, smsBody, loanType, personName, trackedSenderName,
                        principalAmount, loanDate, dueDate, note
                    )
                    if (saved) {
                        setReasonUpdatePending()
                        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                        if (notifId != -1) notificationManager?.cancel(notifId)
                        if (txId.isNotBlank()) notificationManager?.cancel(txId.hashCode())
                        try {
                            MainActivity.smsEventSink?.success("reasonUpdated")
                        } catch (_: Exception) {}
                    }
                    result.success(saved)
                    finish()
                }

                "saveReasonWithRule" -> {
                    val reasonName = call.argument<String>("reasonName") ?: ""
                    val reasonId = call.argument<Int>("reasonId")
                    val contactName = call.argument<String>("contactName") ?: ""
                    if (reasonName.isNotBlank()) {
                        val saved = saveReasonWithRule(txId, smsBody, reasonName, reasonId, contactName)
                        if (saved) {
                            setReasonUpdatePending()
                            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                            if (notifId != -1) notificationManager?.cancel(notifId)
                            if (txId.isNotBlank()) notificationManager?.cancel(txId.hashCode())
                            try {
                                MainActivity.smsEventSink?.success("reasonUpdated")
                            } catch (_: Exception) {}
                        }
                        result.success(saved)
                    } else {
                        result.error("INVALID", "Reason name is blank", null)
                    }
                    finish()
                }

                "saveReason" -> {
                    val reasonName = call.argument<String>("reasonName") ?: ""
                    val reasonId = call.argument<Int>("reasonId")
                    if (reasonName.isNotBlank()) {
                        val saved = saveReasonToTransaction(txId, smsBody, reasonName, reasonId)
                        if (saved) {
                            setReasonUpdatePending()
                            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                            if (notifId != -1) notificationManager?.cancel(notifId)
                            if (txId.isNotBlank()) notificationManager?.cancel(txId.hashCode())
                            try {
                                MainActivity.smsEventSink?.success("reasonUpdated")
                            } catch (_: Exception) {}
                        }
                        result.success(saved)
                    } else {
                        result.error("INVALID", "Reason name is blank", null)
                    }
                    finish()
                }

                "dismiss" -> {
                    result.success(true)
                    finish()
                }

                "openApp" -> {
                    val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        if (txId.isNotBlank()) {
                            putExtra("extra_tx_id", txId)
                        }
                    }
                    if (launchIntent != null) {
                        startActivity(launchIntent)
                    }
                    result.success(true)
                    finish()
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Load all reasons from the reasons table as a list of maps.
     */
    private fun loadReasonsFromDb(): List<Map<String, Any?>> {
        return try {
            val dbPath = File(getDatabasePath(DB_NAME).path)
            if (!dbPath.exists()) return emptyList()

            val db = SQLiteDatabase.openDatabase(
                dbPath.path, null, SQLiteDatabase.OPEN_READONLY
            )

            val reasons = mutableListOf<Map<String, Any?>>()
            val cursor = db.rawQuery("SELECT id, name, isSystem, parentId, isSpecial FROM reasons ORDER BY name", null)
            while (cursor.moveToNext()) {
                val parentIdVal = if (cursor.isNull(3)) null else cursor.getInt(3)
                reasons.add(
                    mapOf(
                        "id" to cursor.getInt(0),
                        "name" to cursor.getString(1),
                        "isSystem" to (cursor.getInt(2) == 1),
                        "parentId" to parentIdVal,
                        "isSpecial" to (cursor.getInt(4) == 1),
                    )
                )
            }
            cursor.close()
            db.close()
            reasons
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load reasons", e)
            emptyList()
        }
    }

    /**
     * Save the selected reason to the transaction in SQLite.
     * Uses the same rawMessage-matching strategy as NotificationActionReceiver.
     */
    private fun saveReasonToTransaction(
        txId: String,
        smsBody: String,
        reasonName: String,
        reasonId: Int?
    ): Boolean {
        return try {
            val dbPath = File(getDatabasePath(DB_NAME).path)
            if (!dbPath.exists()) return false

            val db = SQLiteDatabase.openDatabase(
                dbPath.path, null, SQLiteDatabase.OPEN_READWRITE
            )

            // Resolve reasonId, categoryId, subcategoryId from DB
            var resolvedReasonId = reasonId
            var categoryId: Int? = null
            var subcategoryId: Int? = null

            val cursorReason = if (resolvedReasonId != null) {
                db.rawQuery("SELECT id, name, parentId FROM reasons WHERE id = ? LIMIT 1", arrayOf(resolvedReasonId.toString()))
            } else {
                db.rawQuery("SELECT id, name, parentId FROM reasons WHERE LOWER(name) = LOWER(?) LIMIT 1", arrayOf(reasonName))
            }
            if (cursorReason.moveToFirst()) {
                resolvedReasonId = cursorReason.getInt(0)
                val parentId = if (cursorReason.isNull(2)) null else cursorReason.getInt(2)
                if (parentId != null) {
                    categoryId = parentId
                    subcategoryId = resolvedReasonId
                } else {
                    categoryId = resolvedReasonId
                    subcategoryId = null
                }
            }
            cursorReason.close()

            val values = ContentValues().apply {
                put("reason", reasonName)
                if (resolvedReasonId != null) {
                    put("reasonId", resolvedReasonId)
                } else {
                    putNull("reasonId")
                }
                if (categoryId != null) {
                    put("categoryId", categoryId)
                }
                if (subcategoryId != null) {
                    put("subcategoryId", subcategoryId)
                }
            }

            var found = false

            // Strategy 1: Match by rawMessage (primary — bridges SHA-256 vs bank-ref ID gap)
            if (smsBody.isNotBlank()) {
                val normalizedBody = smsBody.replace(Regex("\\s+"), " ").trim()
                val cursor = db.rawQuery("SELECT id, rawMessage FROM transactions", null)
                while (cursor.moveToNext()) {
                    val realId = cursor.getString(0)
                    val txRaw = cursor.getString(1) ?: ""
                    if (txRaw.replace(Regex("\\s+"), " ").trim() == normalizedBody) {
                        db.update("transactions", values, "id = ?", arrayOf(realId))
                        found = true
                        break
                    }
                }
                cursor.close()
            }

            // Strategy 2: Direct ID or bankReference fallback
            if (!found) {
                val cursor = db.rawQuery(
                    "SELECT id FROM transactions WHERE id = ? OR bankReference = ? LIMIT 1",
                    arrayOf(txId, txId)
                )
                if (cursor.moveToFirst()) {
                    val targetId = cursor.getString(0)
                    cursor.close()
                    db.update("transactions", values, "id = ?", arrayOf(targetId))
                    found = true
                } else {
                    cursor.close()
                }
            }

            // Also update the notifications table (both by direct ID and by matching body)
            try {
                val colCheck = db.rawQuery(
                    "SELECT COUNT(*) FROM pragma_table_info('notifications') WHERE name='reason'",
                    null
                )
                val hasReasonCol = colCheck.moveToFirst() && colCheck.getInt(0) > 0
                colCheck.close()

                if (hasReasonCol) {
                    if (txId.isNotBlank()) {
                        db.execSQL(
                            "UPDATE notifications SET reason = ? WHERE id = ?",
                            arrayOf(reasonName, txId)
                        )
                    }
                    if (smsBody.isNotBlank()) {
                        val normalizedBody = smsBody.replace(Regex("\\s+"), " ").trim()
                        val cursorNotifs = db.rawQuery("SELECT id, body FROM notifications", null)
                        while (cursorNotifs.moveToNext()) {
                            val nId = cursorNotifs.getString(0)
                            val nBody = cursorNotifs.getString(1) ?: ""
                            if (nBody.replace(Regex("\\s+"), " ").trim() == normalizedBody) {
                                db.execSQL(
                                    "UPDATE notifications SET reason = ? WHERE id = ?",
                                    arrayOf(reasonName, nId)
                                )
                                break
                            }
                        }
                        cursorNotifs.close()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update notification reason", e)
            }

            db.close()
            true
        } catch (e: Exception) {
            Log.e(TAG, "saveReasonToTransaction failed", e)
            false
        }
    }

    private fun loadCurrentTransaction(txId: String, smsBody: String): Map<String, Any?> {
        return try {
            val dbPath = File(getDatabasePath(DB_NAME).path)
            if (!dbPath.exists()) return emptyMap()

            val db = SQLiteDatabase.openDatabase(dbPath.path, null, SQLiteDatabase.OPEN_READONLY)
            var result: Map<String, Any?> = emptyMap()

            if (smsBody.isNotBlank()) {
                val normalizedBody = smsBody.replace(Regex("\\s+"), " ").trim()
                val cursor = db.rawQuery("SELECT id, name, amount, type, date, sender, category, rawMessage FROM transactions", null)
                while (cursor.moveToNext()) {
                    val txRaw = cursor.getString(7) ?: ""
                    if (txRaw.replace(Regex("\\s+"), " ").trim() == normalizedBody) {
                        result = mapOf(
                            "id" to cursor.getString(0),
                            "name" to cursor.getString(1),
                            "rawAmount" to cursor.getDouble(2),
                            "amount" to "ETB " + String.format(java.util.Locale.US, "%,.2f", cursor.getDouble(2)),
                            "type" to cursor.getString(3),
                            "date" to cursor.getString(4),
                            "sender" to cursor.getString(5),
                            "category" to cursor.getString(6),
                            "rawMessage" to txRaw
                        )
                        break
                    }
                }
                cursor.close()
            }

            if (result.isEmpty() && txId.isNotBlank()) {
                val cursor = db.rawQuery(
                    "SELECT id, name, amount, type, date, sender, category, rawMessage FROM transactions WHERE id = ? OR bankReference = ? LIMIT 1",
                    arrayOf(txId, txId)
                )
                if (cursor.moveToFirst()) {
                    result = mapOf(
                        "id" to cursor.getString(0),
                        "name" to cursor.getString(1),
                        "rawAmount" to cursor.getDouble(2),
                        "amount" to "ETB " + String.format(java.util.Locale.US, "%,.2f", cursor.getDouble(2)),
                        "type" to cursor.getString(3),
                        "date" to cursor.getString(4),
                        "sender" to cursor.getString(5),
                        "category" to cursor.getString(6),
                        "rawMessage" to (cursor.getString(7) ?: "")
                    )
                }
                cursor.close()
            }

            db.close()
            result
        } catch (e: Exception) {
            Log.e(TAG, "loadCurrentTransaction failed", e)
            emptyMap()
        }
    }

    private fun getTransferCandidates(sourceTxId: String, smsBody: String): List<Map<String, Any?>> {
        return try {
            val dbPath = File(getDatabasePath(DB_NAME).path)
            if (!dbPath.exists()) return emptyList()

            val db = SQLiteDatabase.openDatabase(dbPath.path, null, SQLiteDatabase.OPEN_READONLY)
            val currentTx = loadCurrentTransaction(sourceTxId, smsBody)
            val currentRealId = (currentTx["id"] as? String) ?: sourceTxId
            val currentType = (currentTx["type"] as? String) ?: "expense"
            val currentRawAmount = (currentTx["rawAmount"] as? Double) ?: 0.0
            val targetType = if (currentType.equals("income", ignoreCase = true)) "expense" else "income"

            val candidates = mutableListOf<Map<String, Any?>>()
            val cursor = if (currentRawAmount > 0.0) {
                db.rawQuery(
                    "SELECT id, name, amount, type, date, sender, rawMessage FROM transactions WHERE (linkedTransactionId IS NULL OR linkedTransactionId = '') AND id != ? AND LOWER(type) = LOWER(?) AND ABS(amount - ?) < 0.01 ORDER BY date DESC LIMIT 25",
                    arrayOf(currentRealId, targetType, currentRawAmount.toString())
                )
            } else {
                db.rawQuery(
                    "SELECT id, name, amount, type, date, sender, rawMessage FROM transactions WHERE (linkedTransactionId IS NULL OR linkedTransactionId = '') AND id != ? AND LOWER(type) = LOWER(?) ORDER BY date DESC LIMIT 25",
                    arrayOf(currentRealId, targetType)
                )
            }
            while (cursor.moveToNext()) {
                candidates.add(
                    mapOf(
                        "id" to cursor.getString(0),
                        "name" to cursor.getString(1),
                        "amount" to cursor.getDouble(2),
                        "type" to cursor.getString(3),
                        "date" to cursor.getString(4),
                        "sender" to cursor.getString(5),
                        "rawMessage" to (cursor.getString(6) ?: "")
                    )
                )
            }
            cursor.close()
            db.close()
            candidates
        } catch (e: Exception) {
            Log.e(TAG, "getTransferCandidates failed", e)
            emptyList()
        }
    }

    private fun linkInternalTransfer(sourceTxId: String, smsBody: String, targetTxId: String): Boolean {
        return try {
            val dbPath = File(getDatabasePath(DB_NAME).path)
            if (!dbPath.exists()) return false

            val db = SQLiteDatabase.openDatabase(dbPath.path, null, SQLiteDatabase.OPEN_READWRITE)
            val currentTx = loadCurrentTransaction(sourceTxId, smsBody)
            val sourceRealId = (currentTx["id"] as? String) ?: sourceTxId

            // Resolve internal transfer reasonId
            var internalReasonId: Int? = null
            val cursorReason = db.rawQuery("SELECT id FROM reasons WHERE LOWER(name) LIKE '%internal%' OR LOWER(name) = 'transfer' LIMIT 1", null)
            if (cursorReason.moveToFirst()) {
                internalReasonId = cursorReason.getInt(0)
            }
            cursorReason.close()

            // Update source transaction
            val sourceValues = ContentValues().apply {
                put("linkedTransactionId", targetTxId)
                put("reason", "Internal Transfer")
                if (internalReasonId != null) put("reasonId", internalReasonId)
            }
            db.update("transactions", sourceValues, "id = ?", arrayOf(sourceRealId))

            // Update target transaction
            val targetValues = ContentValues().apply {
                put("linkedTransactionId", sourceRealId)
                put("reason", "Internal Transfer")
                if (internalReasonId != null) put("reasonId", internalReasonId)
            }
            db.update("transactions", targetValues, "id = ?", arrayOf(targetTxId))

            // Clean counterpart notifications & cancel Android notification banners
            try {
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                notificationManager?.cancel(targetTxId.hashCode())
                notificationManager?.cancel(sourceRealId.hashCode())

                val cursorNotif = db.rawQuery(
                    "SELECT id, body FROM notifications WHERE transactionId = ? OR id = ? OR transactionId = ?",
                    arrayOf(targetTxId, targetTxId, sourceRealId)
                )
                while (cursorNotif.moveToNext()) {
                    val nId = cursorNotif.getString(0)
                    notificationManager?.cancel(nId.hashCode())
                }
                cursorNotif.close()

                db.execSQL("UPDATE notifications SET isRead = 1, reason = 'Internal Transfer' WHERE transactionId = ? OR id = ? OR transactionId = ?", arrayOf(targetTxId, targetTxId, sourceRealId))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to cancel counterpart notifications", e)
            }

            db.close()
            true
        } catch (e: Exception) {
            Log.e(TAG, "linkInternalTransfer failed", e)
            false
        }
    }

    private fun saveLoanRecord(
        sourceTxId: String,
        smsBody: String,
        loanType: String,
        personName: String,
        trackedSenderName: String,
        principalAmount: Double,
        loanDate: String,
        dueDate: String,
        note: String?
    ): Boolean {
        return try {
            val dbPath = File(getDatabasePath(DB_NAME).path)
            if (!dbPath.exists()) return false

            val db = SQLiteDatabase.openDatabase(dbPath.path, null, SQLiteDatabase.OPEN_READWRITE)
            val currentTx = loadCurrentTransaction(sourceTxId, smsBody)
            val sourceRealId = (currentTx["id"] as? String) ?: sourceTxId

            val loanValues = ContentValues().apply {
                put("loanType", loanType)
                put("personName", personName)
                put("trackedSenderName", trackedSenderName)
                put("principalAmount", principalAmount)
                put("paidAmount", 0.0)
                put("loanDate", loanDate.ifBlank { java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US).format(java.util.Date()) })
                put("dueDate", dueDate.ifBlank { java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US).format(java.util.Date(System.currentTimeMillis() + 30L * 24 * 3600 * 1000)) })
                put("linkedTransactionId", sourceRealId)
                put("status", "active")
                if (!note.isNullOrBlank()) put("note", note)
            }
            val loanId = db.insert("loan_records", null, loanValues)

            // Resolve loan reasonId
            var loanReasonId: Int? = null
            val cursorReason = db.rawQuery("SELECT id FROM reasons WHERE LOWER(name) = 'loan' LIMIT 1", null)
            if (cursorReason.moveToFirst()) loanReasonId = cursorReason.getInt(0)
            cursorReason.close()

            val txValues = ContentValues().apply {
                put("reason", "Loan")
                if (loanReasonId != null) put("reasonId", loanReasonId)
            }
            db.update("transactions", txValues, "id = ?", arrayOf(sourceRealId))

            db.close()
            loanId > 0
        } catch (e: Exception) {
            Log.e(TAG, "saveLoanRecord failed", e)
            false
        }
    }

    private fun saveReasonWithRule(
        txId: String,
        smsBody: String,
        reasonName: String,
        reasonId: Int?,
        contactName: String
    ): Boolean {
        val saved = saveReasonToTransaction(txId, smsBody, reasonName, reasonId)
        if (saved && contactName.isNotBlank()) {
            try {
                val dbPath = File(getDatabasePath(DB_NAME).path)
                if (dbPath.exists()) {
                    val db = SQLiteDatabase.openDatabase(dbPath.path, null, SQLiteDatabase.OPEN_READWRITE)
                    var rId = reasonId
                    if (rId == null) {
                        val cursor = db.rawQuery("SELECT id FROM reasons WHERE LOWER(name) = LOWER(?) LIMIT 1", arrayOf(reasonName))
                        if (cursor.moveToFirst()) rId = cursor.getInt(0)
                        cursor.close()
                    }
                    if (rId != null) {
                        val ruleValues = ContentValues().apply {
                            put("reasonId", rId)
                            put("linkedName", contactName.trim())
                            put("linkType", "counterparty")
                        }
                        db.insertWithOnConflict("reason_links", null, ruleValues, SQLiteDatabase.CONFLICT_REPLACE)
                    }
                    db.close()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save reason_links rule", e)
            }
        }
        return saved
    }

    private fun setReasonUpdatePending() {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(REASON_UPDATE_PENDING_KEY, true).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set reason_update_pending", e)
        }
    }
}
