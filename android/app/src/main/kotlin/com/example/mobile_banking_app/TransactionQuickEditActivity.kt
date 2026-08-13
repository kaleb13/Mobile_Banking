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
                    val data = mapOf(
                        "txId" to txId,
                        "smsBody" to smsBody,
                        "bankName" to bankName,
                        "amount" to amount,
                        "direction" to direction,
                        "reasons" to reasons,
                    )
                    result.success(data)
                }

                "saveReason" -> {
                    val reasonName = call.argument<String>("reasonName") ?: ""
                    val reasonId = call.argument<Int>("reasonId")
                    if (reasonName.isNotBlank()) {
                        val saved = saveReasonToTransaction(txId, smsBody, reasonName, reasonId)
                        if (saved) {
                            setReasonUpdatePending()
                            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                            if (txId.isNotBlank()) {
                                notificationManager?.cancel(txId.hashCode())
                            }
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

            // Resolve reasonId from DB if not provided
            var resolvedReasonId = reasonId
            if (resolvedReasonId == null) {
                val cursorReason = db.rawQuery(
                    "SELECT id FROM reasons WHERE LOWER(name) = LOWER(?) LIMIT 1",
                    arrayOf(reasonName)
                )
                if (cursorReason.moveToFirst()) {
                    resolvedReasonId = cursorReason.getInt(0)
                }
                cursorReason.close()
            }

            val values = ContentValues().apply {
                put("reason", reasonName)
                if (resolvedReasonId != null) {
                    put("reasonId", resolvedReasonId)
                } else {
                    putNull("reasonId")
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

            // Strategy 2: Direct ID fallback
            if (!found) {
                val cursor = db.rawQuery(
                    "SELECT id FROM transactions WHERE id = ? LIMIT 1",
                    arrayOf(txId)
                )
                if (cursor.moveToFirst()) {
                    db.update("transactions", values, "id = ?", arrayOf(txId))
                    found = true
                }
                cursor.close()
            }

            // Also update the notifications table
            try {
                val colCheck = db.rawQuery(
                    "SELECT COUNT(*) FROM pragma_table_info('notifications') WHERE name='reason'",
                    null
                )
                val hasReasonCol = colCheck.moveToFirst() && colCheck.getInt(0) > 0
                colCheck.close()

                if (hasReasonCol) {
                    db.execSQL(
                        "UPDATE notifications SET reason = ? WHERE id = ?",
                        arrayOf(reasonName, txId)
                    )
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

    private fun setReasonUpdatePending() {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(REASON_UPDATE_PENDING_KEY, true).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set reason_update_pending", e)
        }
    }
}
