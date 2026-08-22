package com.example.mobile_banking_app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.io.File

/**
 * Handles background click actions from Android system notification buttons.
 *
 * Supported Actions:
 *   - ACTION_DISMISS: Dismisses/cancels the notification banner.
 *   - ACTION_SET_REASON: Attaches the selected reason (e.g., "Food" or "Goods")
 *     directly to the real parsed transaction in SQLite, cancels the notification,
 *     and triggers a UI refresh in Flutter via EventChannel.
 *
 * Transaction matching strategy (Bug Fix):
 *   The SHA-256 txId from SmsBroadcastReceiver does NOT match the bank-extracted
 *   transaction ID used by Dart parsers (e.g. "FT24832901..."). So we:
 *     1. Look up the raw SMS body from the notifications table using txId
 *     2. Match against transactions.rawMessage (reliable, parser-agnostic)
 *     3. Fall back to direct id match only as a last resort
 *   If no transaction exists yet, store the reason in the notifications row
 *   so Dart attaches it when the transaction is eventually parsed.
 */
class NotificationActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_DISMISS = "com.example.mobile_banking_app.ACTION_DISMISS"
        const val ACTION_SET_REASON = "com.example.mobile_banking_app.ACTION_SET_REASON"

        const val EXTRA_NOTIFICATION_ID = "extra_notification_id"
        const val EXTRA_TX_ID = "extra_tx_id"
        const val EXTRA_SMS_BODY = "extra_sms_body"
        const val EXTRA_REASON_NAME = "extra_reason_name"

        private const val DB_NAME = "finance_v3.db"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val REASON_UPDATE_PENDING_KEY = "flutter.reason_update_pending"
        private const val TAG = "NotifActionReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val notifId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, -1)

        // Always dismiss the notification banner when an action button is clicked
        if (notifId != -1) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(notifId)
        }

        when (action) {
            ACTION_DISMISS -> {
                // Banner dismissed
            }
            ACTION_SET_REASON -> {
                val txId = intent.getStringExtra(EXTRA_TX_ID) ?: return
                val smsBody = intent.getStringExtra(EXTRA_SMS_BODY)
                val reasonName = intent.getStringExtra(EXTRA_REASON_NAME) ?: return

                val updated = setTransactionReasonOnRealTransaction(context, txId, smsBody, reasonName)
                if (updated) {
                    // Set a dirty flag so Flutter's _reconcileOnResume() knows to
                    // force-reload even when row counts haven't changed.
                    setReasonUpdatePending(context)

                    try {
                        MainActivity.smsEventSink?.success("reasonUpdated")
                    } catch (_: Exception) {}
                }
            }
        }
    }

    /**
     * Sets a SharedPreferences flag that Flutter reads on app resume.
     * This ensures the UI reloads transactions even when only a reason
     * column was updated (no row count change).
     */
    private fun setReasonUpdatePending(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(REASON_UPDATE_PENDING_KEY, true).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set reason_update_pending flag", e)
        }
    }

    /**
     * Finds the real transaction in SQLite and sets its reason.
     *
     * Strategy:
     *   1. Look up reasonId from the reasons table
     *   2. Use intentSmsBody if provided, fallback to notifications table lookup (using SHA-256 txId)
     *   3. Search transactions table by rawMessage match (primary) or id match (fallback)
     *   4. If found: UPDATE reason on the real transaction using ContentValues
     *   5. ALWAYS update notifications table row as well if it still exists
     */
    private fun setTransactionReasonOnRealTransaction(
        context: Context,
        txId: String,
        intentSmsBody: String?,
        reasonName: String
    ): Boolean {
        return try {
            val dbPath = File(context.getDatabasePath(DB_NAME).path)
            if (!dbPath.exists()) return false

            val db = SQLiteDatabase.openDatabase(
                dbPath.path,
                null,
                SQLiteDatabase.OPEN_READWRITE
            )

            // 1. Look up reasonId, categoryId, subcategoryId from reasons table
            var reasonId: Int? = null
            var categoryId: Int? = null
            var subcategoryId: Int? = null

            val cursorReason = db.rawQuery(
                "SELECT id, name, parentId FROM reasons WHERE LOWER(name) = LOWER(?) LIMIT 1",
                arrayOf(reasonName)
            )
            if (cursorReason.moveToFirst()) {
                reasonId = cursorReason.getInt(0)
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

            // 2. Read raw SMS body: prefer intentSmsBody, fallback to notifications table query
            var notifBody: String? = intentSmsBody
            if (notifBody.isNullOrBlank()) {
                val cursorNotif = db.rawQuery("SELECT body FROM notifications WHERE id = ? LIMIT 1", arrayOf(txId))
                if (cursorNotif.moveToFirst()) {
                    notifBody = cursorNotif.getString(0)
                }
                cursorNotif.close()
            }

            // 3. Search transactions table — PRIORITIZE rawMessage matching
            var realTxFound = false

            val values = android.content.ContentValues().apply {
                put("reason", reasonName)
                if (reasonId != null) {
                    put("reasonId", reasonId)
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

            // 3a. Primary: match by rawMessage (normalized whitespace to bridge \r\n vs \n differences)
            if (!notifBody.isNullOrBlank()) {
                val normalizedNotifBody = notifBody.replace(Regex("\\s+"), " ").trim()
                val cursorTx = db.rawQuery("SELECT id, rawMessage FROM transactions", null)
                while (cursorTx.moveToNext()) {
                    val realId = cursorTx.getString(0)
                    val txRawMsg = cursorTx.getString(1) ?: ""
                    val normalizedTxMsg = txRawMsg.replace(Regex("\\s+"), " ").trim()
                    if (normalizedTxMsg == normalizedNotifBody) {
                        db.update("transactions", values, "id = ?", arrayOf(realId))
                        realTxFound = true
                        break
                    }
                }
                cursorTx.close()
            }

            // 3b. Fallback: try direct id or bankReference match
            if (!realTxFound) {
                val cursorById = db.rawQuery(
                    "SELECT id FROM transactions WHERE id = ? OR bankReference = ? LIMIT 1",
                    arrayOf(txId, txId)
                )
                if (cursorById.moveToFirst()) {
                    val targetId = cursorById.getString(0)
                    cursorById.close()
                    db.update("transactions", values, "id = ?", arrayOf(targetId))
                    realTxFound = true
                } else {
                    cursorById.close()
                }
            }

            // 4. ALWAYS store reason in notifications row (by ID and normalized body)
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
                    if (!notifBody.isNullOrBlank()) {
                        val normalizedNotifBody = notifBody.replace(Regex("\\s+"), " ").trim()
                        val cursorNotifs = db.rawQuery("SELECT id, body FROM notifications", null)
                        while (cursorNotifs.moveToNext()) {
                            val nId = cursorNotifs.getString(0)
                            val nBody = cursorNotifs.getString(1) ?: ""
                            if (nBody.replace(Regex("\\s+"), " ").trim() == normalizedNotifBody) {
                                db.execSQL(
                                    "UPDATE notifications SET reason = ? WHERE id = ?",
                                    arrayOf(reasonName, nId)
                                )
                                break
                            }
                        }
                        cursorNotifs.close()
                    }
                } else {
                    Log.w(TAG, "notifications.reason column missing — skipping reason update for notif $txId")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update notification reason for $txId", e)
            }

            db.close()
            true
        } catch (e: Exception) {
            Log.e(TAG, "setTransactionReasonOnRealTransaction failed for txId=$txId", e)
            false
        }
    }
}
