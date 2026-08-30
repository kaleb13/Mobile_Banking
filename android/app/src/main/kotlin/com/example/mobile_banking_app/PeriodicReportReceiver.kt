package com.example.mobile_banking_app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.text.DecimalFormat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Handles offline background scheduling and delivery of periodic summary reports:
 * 1. Daily Spending Summary (Evening digest @ 8:00 PM)
 * 2. Weekly Financial Report (End-of-week breakdown @ Sunday 8:00 PM)
 * 3. Monthly Spending Analysis (Monthly breakdown @ 1st of month 9:00 AM)
 *
 * Runs 100% offline with zero network dependency, querying the local SQLite database.
 */
class PeriodicReportReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "PeriodicReportReceiver"

        const val ACTION_DAILY_REPORT = "com.example.mobile_banking_app.ACTION_DAILY_REPORT"
        const val ACTION_WEEKLY_REPORT = "com.example.mobile_banking_app.ACTION_WEEKLY_REPORT"
        const val ACTION_MONTHLY_REPORT = "com.example.mobile_banking_app.ACTION_MONTHLY_REPORT"
        const val ACTION_TEST_REPORT = "com.example.mobile_banking_app.ACTION_TEST_REPORT"

        const val EXTRA_REPORT_TYPE = "extra_report_type"

        const val CHANNEL_ID = "periodic_reports_channel"
        const val CHANNEL_NAME = "Financial Reports & Summaries"

        const val NOTIF_ID_DAILY = 2001
        const val NOTIF_ID_WEEKLY = 2002
        const val NOTIF_ID_MONTHLY = 2003
        const val NOTIF_ID_TEST = 2000

        private const val DB_NAME = "finance_v3.db"
        private const val PREFS_NAME = "FlutterSharedPreferences"

        private val moneyFormatter = DecimalFormat("#,##0.00")
        private val isoDateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
        private val dayOnlyFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)

        /**
         * Schedules all enabled periodic alarms.
         */
        fun scheduleAll(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val isPushEnabled = prefs.getBoolean("flutter.is_push_notifications_enabled", false)

            if (!isPushEnabled) {
                cancelAll(context)
                return
            }

            val isDailyEnabled = prefs.getBoolean("flutter.report_daily_enabled", true)
            val isWeeklyEnabled = prefs.getBoolean("flutter.report_weekly_enabled", true)
            val isMonthlyEnabled = prefs.getBoolean("flutter.report_monthly_enabled", true)

            if (isDailyEnabled) scheduleDaily(context) else cancelAlarm(context, ACTION_DAILY_REPORT, NOTIF_ID_DAILY)
            if (isWeeklyEnabled) scheduleWeekly(context) else cancelAlarm(context, ACTION_WEEKLY_REPORT, NOTIF_ID_WEEKLY)
            if (isMonthlyEnabled) scheduleMonthly(context) else cancelAlarm(context, ACTION_MONTHLY_REPORT, NOTIF_ID_MONTHLY)
        }

        /**
         * Cancels all scheduled periodic alarms.
         */
        fun cancelAll(context: Context) {
            cancelAlarm(context, ACTION_DAILY_REPORT, NOTIF_ID_DAILY)
            cancelAlarm(context, ACTION_WEEKLY_REPORT, NOTIF_ID_WEEKLY)
            cancelAlarm(context, ACTION_MONTHLY_REPORT, NOTIF_ID_MONTHLY)
        }

        private fun cancelAlarm(context: Context, action: String, requestCode: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, PeriodicReportReceiver::class.java).apply { this.action = action }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        }

        /**
         * Schedules Daily Report at 8:00 PM (20:00) every day.
         */
        fun scheduleDaily(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, PeriodicReportReceiver::class.java).apply {
                action = ACTION_DAILY_REPORT
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                NOTIF_ID_DAILY,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val calendar = Calendar.getInstance().apply {
                timeInMillis = System.currentTimeMillis()
                set(Calendar.HOUR_OF_DAY, 20)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                // If 8:00 PM has already passed today, schedule for tomorrow
                if (timeInMillis <= System.currentTimeMillis()) {
                    add(Calendar.DAY_OF_YEAR, 1)
                }
            }

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                } else {
                    alarmManager.set(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                }
                Log.d(TAG, "Daily report scheduled for: ${calendar.time}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule daily report", e)
            }
        }

        /**
         * Schedules Weekly Report for every Sunday at 8:00 PM (20:00).
         */
        fun scheduleWeekly(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, PeriodicReportReceiver::class.java).apply {
                action = ACTION_WEEKLY_REPORT
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                NOTIF_ID_WEEKLY,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val calendar = Calendar.getInstance().apply {
                timeInMillis = System.currentTimeMillis()
                set(Calendar.DAY_OF_WEEK, Calendar.SUNDAY)
                set(Calendar.HOUR_OF_DAY, 20)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                // If this Sunday 8:00 PM has already passed, schedule for next Sunday
                if (timeInMillis <= System.currentTimeMillis()) {
                    add(Calendar.WEEK_OF_YEAR, 1)
                }
            }

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                } else {
                    alarmManager.set(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                }
                Log.d(TAG, "Weekly report scheduled for: ${calendar.time}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule weekly report", e)
            }
        }

        /**
         * Schedules Monthly Report for the 1st of every month at 9:00 AM.
         */
        fun scheduleMonthly(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, PeriodicReportReceiver::class.java).apply {
                action = ACTION_MONTHLY_REPORT
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                NOTIF_ID_MONTHLY,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val calendar = Calendar.getInstance().apply {
                timeInMillis = System.currentTimeMillis()
                set(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 9)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                // If 1st of current month has passed, schedule for 1st of next month
                if (timeInMillis <= System.currentTimeMillis()) {
                    add(Calendar.MONTH, 1)
                }
            }

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                } else {
                    alarmManager.set(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                }
                Log.d(TAG, "Monthly report scheduled for: ${calendar.time}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule monthly report", e)
            }
        }

        /**
         * Generates and fires a test report immediately with optional live balance passed from Flutter.
         */
        fun fireTestReport(
            context: Context,
            reportType: String,
            explicitBalance: Double? = null,
            explicitCurrency: String? = null
        ) {
            val receiver = PeriodicReportReceiver()
            when (reportType.lowercase().trim()) {
                "weekly" -> receiver.handleWeeklyReport(context, isTest = true, explicitBalance = explicitBalance, explicitCurrency = explicitCurrency)
                "monthly" -> receiver.handleMonthlyReport(context, isTest = true, explicitBalance = explicitBalance, explicitCurrency = explicitCurrency)
                else -> receiver.handleDailyReport(context, isTest = true, explicitBalance = explicitBalance, explicitCurrency = explicitCurrency)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.d(TAG, "PeriodicReportReceiver triggered with action: $action")

        if (action == Intent.ACTION_BOOT_COMPLETED || action == "android.intent.action.QUICKBOOT_POWERON") {
            Log.d(TAG, "Device reboot completed — rescheduling periodic alarms")
            scheduleAll(context)
            return
        }

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isPushEnabled = prefs.getBoolean("flutter.is_push_notifications_enabled", false)

        when (action) {
            ACTION_DAILY_REPORT -> {
                if (isPushEnabled && prefs.getBoolean("flutter.report_daily_enabled", true)) {
                    handleDailyReport(context, isTest = false)
                }
                // Reschedule for next day
                scheduleDaily(context)
            }
            ACTION_WEEKLY_REPORT -> {
                if (isPushEnabled && prefs.getBoolean("flutter.report_weekly_enabled", true)) {
                    handleWeeklyReport(context, isTest = false)
                }
                // Reschedule for next week
                scheduleWeekly(context)
            }
            ACTION_MONTHLY_REPORT -> {
                if (isPushEnabled && prefs.getBoolean("flutter.report_monthly_enabled", true)) {
                    handleMonthlyReport(context, isTest = false)
                }
                // Reschedule for next month
                scheduleMonthly(context)
            }
            ACTION_TEST_REPORT -> {
                val type = intent.getStringExtra(EXTRA_REPORT_TYPE) ?: "daily"
                fireTestReport(context, type)
            }
        }
    }

    private fun calculateTotalBalance(db: SQLiteDatabase): Double {
        var total = 0.0
        val seenAccounts = HashSet<String>()
        val pausedSenders = HashSet<String>()

        // 1. Read paused senders from SQLite senders table
        try {
            val cursorSenders = db.rawQuery("SELECT senderName, isPaused FROM senders", null)
            while (cursorSenders.moveToNext()) {
                val sName = cursorSenders.getString(0) ?: ""
                val isPaused = cursorSenders.getInt(1)
                if (isPaused == 1) {
                    pausedSenders.add(sName.trim().lowercase())
                }
            }
            cursorSenders.close()
        } catch (_: Exception) {}

        try {
            // 2. Query latest positive balance for each bank sender/name and SIM slot
            val cursor = db.rawQuery(
                "SELECT name, sender, COALESCE(simSlot, 0) as slot, totalBalance FROM transactions WHERE totalBalance > 0 ORDER BY date DESC, id DESC",
                null
            )
            while (cursor.moveToNext()) {
                val name = cursor.getString(0) ?: ""
                val sender = cursor.getString(1) ?: ""
                val slot = cursor.getInt(2)
                val bankKey = if (name.isNotBlank()) name.trim().lowercase() else sender.trim().lowercase()
                val key = "$bankKey-$slot"

                if (pausedSenders.contains(bankKey) || pausedSenders.contains(sender.trim().lowercase())) {
                    continue
                }

                if (!seenAccounts.contains(key)) {
                    seenAccounts.add(key)
                    val bal = cursor.getDouble(3)
                    if (bal > 0) {
                        total += bal
                    }
                }
            }
            cursor.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error calculating bank balances", e)
        }

        try {
            // 3. Add cash balance if cash_transactions table exists and not paused
            if (!pausedSenders.contains("cash wallet")) {
                val cursorCash = db.rawQuery(
                    "SELECT SUM(CASE WHEN type = 'addition' THEN amount WHEN type = 'expense' THEN -amount ELSE 0 END) FROM cash_transactions",
                    null
                )
                if (cursorCash.moveToFirst()) {
                    val cashBal = cursorCash.getDouble(0)
                    if (cashBal > 0) {
                        total += cashBal
                    }
                }
                cursorCash.close()
            }
        } catch (_: Exception) {}

        return total
    }

    private fun handleDailyReport(
        context: Context,
        isTest: Boolean,
        explicitBalance: Double? = null,
        explicitCurrency: String? = null
    ) {
        try {
            val db = openDatabase(context) ?: return
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val currency = explicitCurrency ?: prefs.getString("flutter.selected_currency_code", "ETB") ?: "ETB"

            val todayStr = dayOnlyFormat.format(Date())
            val startIso = "${todayStr}T00:00:00"
            val endIso = "${todayStr}T23:59:59"

            var totalSpent = 0.0
            var totalIncome = 0.0

            // 1. Query today's expenses (excluding internal transfer, bounce, cash, loan)
            val cursorExp = db.rawQuery(
                "SELECT SUM(amount) FROM transactions WHERE type = 'expense' AND date >= ? AND date <= ? " +
                "AND (linkedTransactionId IS NULL OR linkedTransactionId = '') " +
                "AND (reason IS NULL OR LOWER(TRIM(reason)) NOT IN ('bounce', 'internal transfer', 'cash', 'transfer')) " +
                "AND (customReasonText IS NULL OR LOWER(TRIM(customReasonText)) NOT IN ('bounce', 'internal transfer', 'cash', 'transfer'))",
                arrayOf(startIso, endIso)
            )
            if (cursorExp.moveToFirst()) {
                totalSpent = cursorExp.getDouble(0)
            }
            cursorExp.close()

            // 2. Query today's income (excluding internal transfer, bounce, cash, loan)
            val cursorInc = db.rawQuery(
                "SELECT SUM(amount) FROM transactions WHERE type = 'income' AND date >= ? AND date <= ? " +
                "AND (linkedTransactionId IS NULL OR linkedTransactionId = '') " +
                "AND (reason IS NULL OR LOWER(TRIM(reason)) NOT IN ('bounce', 'internal transfer', 'cash', 'transfer')) " +
                "AND (customReasonText IS NULL OR LOWER(TRIM(customReasonText)) NOT IN ('bounce', 'internal transfer', 'cash', 'transfer'))",
                arrayOf(startIso, endIso)
            )
            if (cursorInc.moveToFirst()) {
                totalIncome = cursorInc.getDouble(0)
            }
            cursorInc.close()

            // 3. Query true total balance across all bank accounts & wallets
            val currentBalance = explicitBalance ?: calculateTotalBalance(db)
            db.close()

            val prefix = if (isTest) "[Test] " else ""
            val formattedBal = moneyFormatter.format(currentBalance)
            val title: String
            val body: String

            if (totalSpent > 0) {
                val formattedSpent = moneyFormatter.format(totalSpent)
                title = "${prefix}Spent $formattedSpent $currency today"
                body = if (totalIncome > 0) {
                    val formattedInc = moneyFormatter.format(totalIncome)
                    "+$formattedInc $currency income · Total Balance: $formattedBal $currency"
                } else {
                    "Total Balance: $formattedBal $currency"
                }
            } else if (totalIncome > 0) {
                val formattedInc = moneyFormatter.format(totalIncome)
                title = "${prefix}+$formattedInc $currency income today"
                body = "Total Balance: $formattedBal $currency"
            } else {
                title = "${prefix}No expense today"
                body = "Total Balance: $formattedBal $currency"
            }

            val notifId = if (isTest) NOTIF_ID_TEST else NOTIF_ID_DAILY
            showReportNotification(context, notifId, title, body)
        } catch (e: Exception) {
            Log.e(TAG, "Error generating daily report", e)
        }
    }

    private fun handleWeeklyReport(
        context: Context,
        isTest: Boolean,
        explicitBalance: Double? = null,
        explicitCurrency: String? = null
    ) {
        try {
            val db = openDatabase(context) ?: return
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val currency = explicitCurrency ?: prefs.getString("flutter.selected_currency_code", "ETB") ?: "ETB"

            val cal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, -7)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
            }
            val startIso = isoDateFormat.format(cal.time)

            var totalSpent = 0.0
            var totalIncome = 0.0

            // 1. Query past 7 days expenses (excluding internal transfer, bounce, cash, loan)
            val cursorExp = db.rawQuery(
                "SELECT SUM(amount) FROM transactions WHERE type = 'expense' AND date >= ? " +
                "AND (linkedTransactionId IS NULL OR linkedTransactionId = '') " +
                "AND (reason IS NULL OR LOWER(TRIM(reason)) NOT IN ('bounce', 'internal transfer', 'cash', 'transfer')) " +
                "AND (customReasonText IS NULL OR LOWER(TRIM(customReasonText)) NOT IN ('bounce', 'internal transfer', 'cash', 'transfer'))",
                arrayOf(startIso)
            )
            if (cursorExp.moveToFirst()) {
                totalSpent = cursorExp.getDouble(0)
            }
            cursorExp.close()

            // 2. Query past 7 days income (excluding internal transfer, bounce, cash, loan)
            val cursorInc = db.rawQuery(
                "SELECT SUM(amount) FROM transactions WHERE type = 'income' AND date >= ? " +
                "AND (linkedTransactionId IS NULL OR linkedTransactionId = '') " +
                "AND (reason IS NULL OR LOWER(TRIM(reason)) NOT IN ('bounce', 'internal transfer', 'cash', 'transfer')) " +
                "AND (customReasonText IS NULL OR LOWER(TRIM(customReasonText)) NOT IN ('bounce', 'internal transfer', 'cash', 'transfer'))",
                arrayOf(startIso)
            )
            if (cursorInc.moveToFirst()) {
                totalIncome = cursorInc.getDouble(0)
            }
            cursorInc.close()

            // 3. Query top expense category (strictly excluding internal transfer, bounce, cash)
            var topReason: String? = null
            val cursorReason = db.rawQuery(
                "SELECT COALESCE(NULLIF(TRIM(customReasonText), ''), TRIM(reason)) as cat, SUM(amount) as total " +
                "FROM transactions " +
                "WHERE type = 'expense' AND date >= ? " +
                "AND (linkedTransactionId IS NULL OR linkedTransactionId = '') " +
                "AND (reason IS NULL OR LOWER(TRIM(reason)) NOT IN ('bounce', 'internal transfer', 'cash', 'transfer')) " +
                "AND (customReasonText IS NULL OR LOWER(TRIM(customReasonText)) NOT IN ('bounce', 'internal transfer', 'cash', 'transfer')) " +
                "AND (COALESCE(NULLIF(TRIM(customReasonText), ''), TRIM(reason)) IS NOT NULL AND COALESCE(NULLIF(TRIM(customReasonText), ''), TRIM(reason)) != '') " +
                "GROUP BY cat ORDER BY total DESC LIMIT 1",
                arrayOf(startIso)
            )
            if (cursorReason.moveToFirst()) {
                topReason = cursorReason.getString(0)
            }
            cursorReason.close()

            // 4. Query true total balance
            val currentBalance = explicitBalance ?: calculateTotalBalance(db)
            db.close()

            val prefix = if (isTest) "[Test] " else ""
            val formattedBal = moneyFormatter.format(currentBalance)
            val title: String
            val body: String

            if (totalSpent > 0) {
                val formattedSpent = moneyFormatter.format(totalSpent)
                title = "${prefix}Past 7 days: Spent $formattedSpent $currency"
                body = if (topReason != null) {
                    "Top category: $topReason · Total Balance: $formattedBal $currency"
                } else if (totalIncome > 0) {
                    val formattedInc = moneyFormatter.format(totalIncome)
                    "+$formattedInc $currency income · Total Balance: $formattedBal $currency"
                } else {
                    "Total Balance: $formattedBal $currency"
                }
            } else if (totalIncome > 0) {
                val formattedInc = moneyFormatter.format(totalIncome)
                title = "${prefix}Past 7 days: +$formattedInc $currency income"
                body = "Total Balance: $formattedBal $currency"
            } else {
                title = "${prefix}No activity this week"
                body = "Total Balance: $formattedBal $currency"
            }

            val notifId = if (isTest) NOTIF_ID_TEST else NOTIF_ID_WEEKLY
            showReportNotification(context, notifId, title, body)
        } catch (e: Exception) {
            Log.e(TAG, "Error generating weekly report", e)
        }
    }

    private fun handleMonthlyReport(
        context: Context,
        isTest: Boolean,
        explicitBalance: Double? = null,
        explicitCurrency: String? = null
    ) {
        try {
            val db = openDatabase(context) ?: return
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val currency = explicitCurrency ?: prefs.getString("flutter.selected_currency_code", "ETB") ?: "ETB"

            val cal = Calendar.getInstance().apply {
                if (isTest) {
                    set(Calendar.DAY_OF_MONTH, 1)
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                } else {
                    add(Calendar.MONTH, -1)
                    set(Calendar.DAY_OF_MONTH, 1)
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                }
            }
            val startIso = isoDateFormat.format(cal.time)

            var totalSpent = 0.0
            var totalIncome = 0.0

            // 1. Query month's expenses (excluding internal transfer, bounce, cash, loan)
            val cursorExp = db.rawQuery(
                "SELECT SUM(amount) FROM transactions WHERE type = 'expense' AND date >= ? " +
                "AND (linkedTransactionId IS NULL OR linkedTransactionId = '') " +
                "AND (reason IS NULL OR LOWER(TRIM(reason)) NOT IN ('bounce', 'internal transfer', 'cash', 'transfer')) " +
                "AND (customReasonText IS NULL OR LOWER(TRIM(customReasonText)) NOT IN ('bounce', 'internal transfer', 'cash', 'transfer'))",
                arrayOf(startIso)
            )
            if (cursorExp.moveToFirst()) {
                totalSpent = cursorExp.getDouble(0)
            }
            cursorExp.close()

            // 2. Query month's income (excluding internal transfer, bounce, cash, loan)
            val cursorInc = db.rawQuery(
                "SELECT SUM(amount) FROM transactions WHERE type = 'income' AND date >= ? " +
                "AND (linkedTransactionId IS NULL OR linkedTransactionId = '') " +
                "AND (reason IS NULL OR LOWER(TRIM(reason)) NOT IN ('bounce', 'internal transfer', 'cash', 'transfer')) " +
                "AND (customReasonText IS NULL OR LOWER(TRIM(customReasonText)) NOT IN ('bounce', 'internal transfer', 'cash', 'transfer'))",
                arrayOf(startIso)
            )
            if (cursorInc.moveToFirst()) {
                totalIncome = cursorInc.getDouble(0)
            }
            cursorInc.close()

            // 3. Query top expense category (strictly excluding internal transfer, bounce, cash)
            var topReason: String? = null
            val cursorReason = db.rawQuery(
                "SELECT COALESCE(NULLIF(TRIM(customReasonText), ''), TRIM(reason)) as cat, SUM(amount) as total " +
                "FROM transactions " +
                "WHERE type = 'expense' AND date >= ? " +
                "AND (linkedTransactionId IS NULL OR linkedTransactionId = '') " +
                "AND (reason IS NULL OR LOWER(TRIM(reason)) NOT IN ('bounce', 'internal transfer', 'cash', 'transfer')) " +
                "AND (customReasonText IS NULL OR LOWER(TRIM(customReasonText)) NOT IN ('bounce', 'internal transfer', 'cash', 'transfer')) " +
                "AND (COALESCE(NULLIF(TRIM(customReasonText), ''), TRIM(reason)) IS NOT NULL AND COALESCE(NULLIF(TRIM(customReasonText), ''), TRIM(reason)) != '') " +
                "GROUP BY cat ORDER BY total DESC LIMIT 1",
                arrayOf(startIso)
            )
            if (cursorReason.moveToFirst()) {
                topReason = cursorReason.getString(0)
            }
            cursorReason.close()

            // 4. Query true total balance
            val currentBalance = explicitBalance ?: calculateTotalBalance(db)
            db.close()

            val prefix = if (isTest) "[Test] " else ""
            val formattedBal = moneyFormatter.format(currentBalance)
            val title: String
            val body: String

            if (totalSpent > 0) {
                val formattedSpent = moneyFormatter.format(totalSpent)
                title = "${prefix}This month: Spent $formattedSpent $currency"
                body = if (topReason != null) {
                    "Top category: $topReason · Total Balance: $formattedBal $currency"
                } else if (totalIncome > 0) {
                    val formattedInc = moneyFormatter.format(totalIncome)
                    "+$formattedInc $currency income · Total Balance: $formattedBal $currency"
                } else {
                    "Total Balance: $formattedBal $currency"
                }
            } else if (totalIncome > 0) {
                val formattedInc = moneyFormatter.format(totalIncome)
                title = "${prefix}This month: +$formattedInc $currency income"
                body = "Total Balance: $formattedBal $currency"
            } else {
                title = "${prefix}No activity this month"
                body = "Total Balance: $formattedBal $currency"
            }

            val notifId = if (isTest) NOTIF_ID_TEST else NOTIF_ID_MONTHLY
            showReportNotification(context, notifId, title, body)
        } catch (e: Exception) {
            Log.e(TAG, "Error generating monthly report", e)
        }
    }

    private fun showReportNotification(context: Context, notifId: Int, title: String, body: String) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Daily, weekly, and monthly financial summaries and spending reports"
                enableLights(true)
                lightColor = android.graphics.Color.parseColor("#F0B90B")
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Tap action: open app
        val contentIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            notifId,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setColor(android.graphics.Color.parseColor("#F0B90B"))

        notificationManager.notify(notifId, builder.build())
        Log.d(TAG, "Dispatched notification #$notifId: $title")
    }

    private fun openDatabase(context: Context): SQLiteDatabase? {
        return try {
            val dbPath = File(context.getDatabasePath(DB_NAME).path)
            if (!dbPath.exists()) return null
            SQLiteDatabase.openDatabase(
                dbPath.path,
                null,
                SQLiteDatabase.OPEN_READONLY
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open $DB_NAME", e)
            null
        }
    }
}
