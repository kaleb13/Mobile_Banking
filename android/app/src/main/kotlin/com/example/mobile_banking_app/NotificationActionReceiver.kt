package com.example.mobile_banking_app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
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
        const val EXTRA_REASON_NAME = "extra_reason_name"

        private const val DB_NAME = "finance_v3.db"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val REASON_UPDATE_PENDING_KEY = "flutter.reason_update_pending"
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
                val reasonName = intent.getStringExtra(EXTRA_REASON_NAME) ?: return

                val updated = setTransactionReasonOnRealTransaction(context, txId, reasonName)
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
        } catch (_: Exception) {}
    }

    /**
     * Finds the real transaction in SQLite and sets its reason.
     *
     * Strategy:
     *   1. Look up reasonId from the reasons table
     *   2. Read the raw SMS body from notifications table (using SHA-256 txId)
     *   3. Search transactions table by rawMessage match (primary) or id match (fallback)
     *   4. If found: UPDATE reason on the real transaction
     *   5. If not found: UPDATE reason on the notifications row (Dart will attach it later)
     */
    private fun setTransactionReasonOnRealTransaction(context: Context, txId: String, reasonName: String): Boolean {
        return try {
            val dbPath = File(context.getDatabasePath(DB_NAME).path)
            if (!dbPath.exists()) return false

            val db = SQLiteDatabase.openDatabase(
                dbPath.path,
                null,
                SQLiteDatabase.OPEN_READWRITE
            )

            // 1. Look up reasonId from reasons table
            var reasonId: Int? = null
            val cursorReason = db.rawQuery("SELECT id FROM reasons WHERE LOWER(name) = LOWER(?) LIMIT 1", arrayOf(reasonName))
            if (cursorReason.moveToFirst()) {
                reasonId = cursorReason.getInt(0)
            }
            cursorReason.close()

            // 2. Read raw SMS body from notifications table for txId
            var notifBody: String? = null
            val cursorNotif = db.rawQuery("SELECT body FROM notifications WHERE id = ? LIMIT 1", arrayOf(txId))
            if (cursorNotif.moveToFirst()) {
                notifBody = cursorNotif.getString(0)
            }
            cursorNotif.close()

            // 3. Search transactions table — PRIORITIZE rawMessage matching
            var realTxFound = false

            // 3a. Primary: match by rawMessage (reliable — the SMS body is identical
            //     regardless of what ID the parser extracted)
            if (!notifBody.isNullOrBlank()) {
                val cursorByMsg = db.rawQuery(
                    "SELECT id FROM transactions WHERE rawMessage = ? LIMIT 1",
                    arrayOf(notifBody)
                )
                if (cursorByMsg.moveToFirst()) {
                    val realId = cursorByMsg.getString(0)
                    cursorByMsg.close()
                    db.execSQL(
                        "UPDATE transactions SET reason = ?, reasonId = ? WHERE id = ?",
                        arrayOf(reasonName, reasonId, realId)
                    )
                    realTxFound = true
                } else {
                    cursorByMsg.close()
                }
            }

            // 3b. Fallback: try direct id match (works for custom senders using SHA-256 IDs)
            if (!realTxFound) {
                val cursorById = db.rawQuery(
                    "SELECT id FROM transactions WHERE id = ? LIMIT 1",
                    arrayOf(txId)
                )
                if (cursorById.moveToFirst()) {
                    cursorById.close()
                    db.execSQL(
                        "UPDATE transactions SET reason = ?, reasonId = ? WHERE id = ?",
                        arrayOf(reasonName, reasonId, txId)
                    )
                    realTxFound = true
                } else {
                    cursorById.close()
                }
            }

            // 4. If transaction hasn't been parsed yet, store reason in notifications
            //    so Dart's processSmsRaw attaches it when the app loads
            if (!realTxFound) {
                db.execSQL(
                    "UPDATE notifications SET reason = ? WHERE id = ?",
                    arrayOf(reasonName, txId)
                )
            }

            db.close()
            true
        } catch (e: Exception) {
            false
        }
    }
}
