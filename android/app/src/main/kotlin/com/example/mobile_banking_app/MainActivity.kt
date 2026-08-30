package com.example.mobile_banking_app

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityManager
import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import android.provider.Telephony
import android.telephony.SubscriptionManager
import android.text.TextUtils
import io.flutter.plugin.common.EventChannel
import android.net.Uri

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.shibre/ussd"
    private val EVENT_CHANNEL = "com.shibre/ussd_events"
    private val SMS_EVENT_CHANNEL = "com.shibre/sms_events"
    private val DEEP_LINK_CHANNEL = "com.shibre/deep_link"

    private var pendingTxId: String? = null
    private var deepLinkMethodChannel: MethodChannel? = null

    companion object {
        var instance: MainActivity? = null
        var smsEventSink: EventChannel.EventSink? = null

        fun bringToFront(context: Context) {
            val intent = Intent(context, MainActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            context.startActivity(intent)
        }
    }

    override fun onCreate(saved: android.os.Bundle?) {
        super.onCreate(saved)
        instance = this
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val txId = intent?.getStringExtra("open_tx_id")
        if (!txId.isNullOrEmpty()) {
            pendingTxId = txId
            deepLinkMethodChannel?.invokeMethod("openTransactionDetail", txId)
        }
    }

    override fun onDestroy() {
        instance = null
        deepLinkMethodChannel = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        deepLinkMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEP_LINK_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialTxId" -> {
                        result.success(pendingTxId)
                        pendingTxId = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.shibre/quick_edit").setMethodCallHandler { call, result ->
            when (call.method) {
                "cancelPhoneNotification" -> {
                    val notifIdStr = call.argument<String>("id") ?: ""
                    if (notifIdStr.isNotBlank()) {
                        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                        notificationManager?.cancel(notifIdStr.hashCode())
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.shibre/reports").setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleReports" -> {
                    PeriodicReportReceiver.scheduleAll(this)
                    result.success(true)
                }
                "cancelReports" -> {
                    PeriodicReportReceiver.cancelAll(this)
                    result.success(true)
                }
                "sendTestReport" -> {
                    val reportType = call.argument<String>("type") ?: "daily"
                    val explicitBalance = call.argument<Double>("totalBalance")
                    val explicitCurrency = call.argument<String>("currency")
                    PeriodicReportReceiver.fireTestReport(this, reportType, explicitBalance, explicitCurrency)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.shibre/sms_scanner").setMethodCallHandler { call, result ->
            when (call.method) {
                "getSimCards" -> {
                    val subManager = try {
                        getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                    } catch (_: Throwable) { null }
                    val sims = ArrayList<Map<String, Any>>()
                    try {
                        subManager?.activeSubscriptionInfoList?.forEach { info ->
                            val sim = HashMap<String, Any>()
                            sim["subscriptionId"] = info.subscriptionId
                            sim["simSlot"] = info.simSlotIndex
                            sim["displayName"] = info.displayName?.toString() ?: "SIM ${info.simSlotIndex + 1}"
                            sim["carrierName"] = info.carrierName?.toString() ?: ""
                            sims.add(sim)
                        }
                    } catch (_: Throwable) {}
                    result.success(sims)
                }
                "openSmsInNativeApp" -> {
                    val sender = call.argument<String>("sender") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    val dateMs = call.argument<Long>("date")
                    
                    var opened = false

                    // 1. Try to locate the exact thread_id from Android's Telephony database
                    try {
                        var threadId: Long? = null
                        val selection = when {
                            dateMs != null && dateMs > 0 -> "${Telephony.Sms.DATE} BETWEEN ? AND ?"
                            body.isNotBlank() -> "${Telephony.Sms.BODY} LIKE ?"
                            else -> null
                        }
                        val selectionArgs = when {
                            dateMs != null && dateMs > 0 -> arrayOf((dateMs - 5000).toString(), (dateMs + 5000).toString())
                            body.isNotBlank() -> arrayOf("%${body.take(30)}%")
                            else -> null
                        }

                        contentResolver.query(
                            Uri.parse("content://sms"),
                            arrayOf("thread_id", "_id", "address"),
                            selection,
                            selectionArgs,
                            "date DESC LIMIT 1"
                        )?.use { cursor ->
                            if (cursor.moveToFirst()) {
                                val tIdx = cursor.getColumnIndex("thread_id")
                                if (tIdx >= 0) {
                                    val t = cursor.getLong(tIdx)
                                    if (t > 0) threadId = t
                                }
                            }
                        }

                        if (threadId != null && threadId > 0) {
                            val threadUri = Uri.parse("content://mms-sms/conversations/$threadId")
                            val intent = Intent(Intent.ACTION_VIEW, threadUri).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            opened = true
                        }
                    } catch (_: Throwable) {}

                    // 2. Fallback to sender address / shortcode thread (e.g. 6061, 127, Telebirr)
                    if (!opened) {
                        try {
                            val resolvedAddress = when {
                                sender.matches(Regex("^[0-9+]+$")) -> sender
                                sender.contains("CBE", ignoreCase = true) -> "6061"
                                sender.contains("TELEBIRR", ignoreCase = true) -> "127"
                                sender.contains("AHADU", ignoreCase = true) -> "Ahadu"
                                sender.contains("DASHEN", ignoreCase = true) -> "Dashen"
                                sender.contains("ABYSSINIA", ignoreCase = true) || sender.contains("BOA", ignoreCase = true) -> "BOA"
                                else -> sender
                            }
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                data = Uri.parse("smsto:${Uri.encode(resolvedAddress)}")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            opened = true
                        } catch (_: Throwable) {}
                    }

                    // 3. Fallback to opening default messaging app main screen
                    if (!opened) {
                        try {
                            val genericIntent = Intent(Intent.ACTION_MAIN).apply {
                                addCategory(Intent.CATEGORY_APP_MESSAGING)
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(genericIntent)
                            opened = true
                        } catch (_: Throwable) {}
                    }

                    result.success(opened)
                }
                "getBankSmsFast" -> {
                    val sinceTimestamp = call.argument<Long>("since")
                    val rawSenders = call.argument<List<String>>("senders") 
                        ?: call.argument<List<String>>("customSenders") 
                        ?: listOf()
                    val targetSenders = rawSenders.filter { it.isNotBlank() }.map { it.trim().lowercase() }.toSet()

                    Thread {
                        try {
                            // ── 1. High-Performance Query with Date Push-Down across ALL SIMs ──
                            val selection = if (sinceTimestamp != null && sinceTimestamp > 0) "${Telephony.Sms.DATE} >= ?" else null
                            val selectionArgs = if (sinceTimestamp != null && sinceTimestamp > 0) arrayOf(sinceTimestamp.toString()) else null

                            // Use the base content://sms URI first to get all messages across all SIM cards
                            val smsUri = Uri.parse("content://sms")
                            var cursor = try {
                                contentResolver.query(
                                    smsUri,
                                    null,
                                    selection,
                                    selectionArgs,
                                    "date ASC"
                                )
                            } catch (_: Exception) {
                                null
                            }

                            // Fallback to Inbox URI if root URI is restricted
                            if (cursor == null) {
                                cursor = try {
                                    contentResolver.query(
                                        Telephony.Sms.Inbox.CONTENT_URI,
                                        null,
                                        selection,
                                        selectionArgs,
                                        "${Telephony.Sms.DATE} ASC"
                                    )
                                } catch (_: Exception) {
                                    null
                                }
                            }

                            // ── 2. Build authoritative subscriptionId -> simSlot map (Google Messages / AOSP standard) ──
                            val subManager = try {
                                getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                            } catch (_: Throwable) { null }

                            val subIdToSlotMap = HashMap<Int, Int>()
                            try {
                                subManager?.activeSubscriptionInfoList?.forEach { info ->
                                    subIdToSlotMap[info.subscriptionId] = info.simSlotIndex
                                }
                            } catch (_: Throwable) {}

                            val messages = ArrayList<Map<String, Any>>(cursor?.count ?: 0)
                            cursor?.use {
                                val addrIdx = it.getColumnIndex(Telephony.Sms.ADDRESS)
                                val bodyIdx = it.getColumnIndex(Telephony.Sms.BODY)
                                val dateIdx = it.getColumnIndex(Telephony.Sms.DATE)
                                
                                val subIdIdx = try { it.getColumnIndex(Telephony.Sms.SUBSCRIPTION_ID) } catch (_: Throwable) { -1 }.let { idx ->
                                    if (idx >= 0) idx else try { it.getColumnIndex("sub_id") } catch (_: Throwable) { -1 }
                                }.let { idx ->
                                    if (idx >= 0) idx else try { it.getColumnIndex("subscription_id") } catch (_: Throwable) { -1 }
                                }.let { idx ->
                                    if (idx >= 0) idx else try { it.getColumnIndex("subscription") } catch (_: Throwable) { -1 }
                                }

                                val phoneIdIdx = try { it.getColumnIndex("phone_id") } catch (_: Throwable) { -1 }.let { idx ->
                                    if (idx >= 0) idx else try { it.getColumnIndex("phone") } catch (_: Throwable) { -1 }
                                }
                                val simSlotIdx = try { it.getColumnIndex("sim_slot") } catch (_: Throwable) { -1 }.let { idx ->
                                    if (idx >= 0) idx else try { it.getColumnIndex("slot_id") } catch (_: Throwable) { -1 }
                                }.let { idx ->
                                    if (idx >= 0) idx else try { it.getColumnIndex("slot") } catch (_: Throwable) { -1 }
                                }.let { idx ->
                                    if (idx >= 0) idx else try { it.getColumnIndex("sim_index") } catch (_: Throwable) { -1 }
                                }
                                val simIdIdx = try { it.getColumnIndex("sim_id") } catch (_: Throwable) { -1 }.let { idx ->
                                    if (idx >= 0) idx else try { it.getColumnIndex("simId") } catch (_: Throwable) { -1 }
                                }.let { idx ->
                                    if (idx >= 0) idx else try { it.getColumnIndex("sim_num") } catch (_: Throwable) { -1 }
                                }

                                android.util.Log.d("ShibreSIM", "Query columns: subIdIdx=$subIdIdx phoneIdIdx=$phoneIdIdx simSlotIdx=$simSlotIdx simIdIdx=$simIdIdx activeSubs=$subIdToSlotMap")

                                while (it.moveToNext()) {
                                    val addr = if (addrIdx >= 0) it.getString(addrIdx) else null
                                    val body = if (bodyIdx >= 0) it.getString(bodyIdx) else null
                                    val date = if (dateIdx >= 0) it.getLong(dateIdx) else null
                                    val subIdVal = if (subIdIdx >= 0) try { it.getInt(subIdIdx) } catch (_: Throwable) { -1 } else -1
                                    val phoneIdVal = if (phoneIdIdx >= 0) try { it.getInt(phoneIdIdx) } catch (_: Throwable) { -1 } else -1
                                    val simSlotVal = if (simSlotIdx >= 0) try { it.getInt(simSlotIdx) } catch (_: Throwable) { -1 } else -1
                                    val simIdVal = if (simIdIdx >= 0) try { it.getInt(simIdIdx) } catch (_: Throwable) { -1 } else -1

                                    // Determine physical SIM slot (0 = SIM 1, 1 = SIM 2):
                                    // 1. Authoritative lookup from SubscriptionManager via sub_id (AOSP standard)
                                    // 2. Hardware phone_id (0 = SIM 1, 1 = SIM 2 on Qualcomm/Samsung RIL)
                                    // 3. Hardware sim_slot (0 = SIM 1, 1 = SIM 2)
                                    // 4. Hardware sim_id (MediaTek / older Samsung)
                                    // 5. Direct subId if 0 or 1
                                    val simSlot = when {
                                        subIdVal >= 0 && subIdToSlotMap.containsKey(subIdVal) -> subIdToSlotMap[subIdVal] ?: 0
                                        phoneIdVal in 0..1 -> phoneIdVal
                                        simSlotVal in 0..1 -> simSlotVal
                                        simSlotVal in 1..2 -> simSlotVal - 1
                                        simIdVal in 0..1 -> simIdVal
                                        subIdVal in 0..1 -> subIdVal
                                        else -> 0
                                    }

                                    if (!addr.isNullOrEmpty() && !body.isNullOrEmpty() && date != null) {
                                        val lowerAddr = addr.trim().lowercase()
                                        val isBank = targetSenders.isEmpty() ||
                                                targetSenders.contains(lowerAddr) ||
                                                targetSenders.any { k -> lowerAddr.contains(k) }
                                        if (isBank) {
                                            android.util.Log.d("ShibreSIM", "BANK_MSG: sender=$addr subId=$subIdVal simSlotCol=$simSlotVal -> resolvedSlot=$simSlot text=${body.replace('\n', ' ').take(50)}")
                                            val item = HashMap<String, Any>(5)
                                            item["sender"] = addr
                                            item["body"] = body
                                            item["date"] = date
                                            item["simSlot"] = simSlot

                                            // Extract account suffix if present in SMS text
                                            val acctMatch = Regex("(?i)(?:account\\s*(?:no\\.?)?\\s*|acc(?:ount)?\\s*)([0-9*]{4,20})").find(body)
                                            if (acctMatch != null) {
                                                val rawAcct = acctMatch.groupValues[1]
                                                if (rawAcct.length >= 4) {
                                                    item["accountIdentifier"] = rawAcct.takeLast(4)
                                                }
                                            }

                                            messages.add(item)
                                        }
                                    }
                                }
                            }

                            Handler(Looper.getMainLooper()).post {
                                result.success(messages)
                            }
                        } catch (e: Exception) {
                            Handler(Looper.getMainLooper()).post {
                                result.error("QUERY_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendUssd" -> {
                    val code = call.argument<String>("code")
                    val inputs = call.argument<List<String>>("inputs") ?: listOf()
                    
                    if (!isAccessibilityServiceEnabled(this, UssdAccessibilityService::class.java)) {
                        result.error("ACCESSIBILITY_DISABLED", "Please enable Shibre USSD Automation in Accessibility settings", null)
                        return@setMethodCallHandler
                    }

                    if (code != null) {
                        UssdAccessibilityService.pendingInputs = inputs.toMutableList()
                        UssdAccessibilityService.isAutomationRunning = true
                        UssdAccessibilityService.lastScreenText = "" 
                        UssdAccessibilityService.instance?.showOverlay()
                        sendUssdRequest(code, result)
                    } else {
                        result.error("INVALID_CODE", "USSD code is null", null)
                    }
                }
                "checkAccessibility" -> {
                    result.success(isAccessibilityServiceEnabled(this, UssdAccessibilityService::class.java))
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    UssdAccessibilityService.eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    UssdAccessibilityService.eventSink = null
                }
            }
        )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    smsEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    smsEventSink = null
                }
            }
        )

        // If pendingTxId was set before Flutter Engine finished setup, dispatch it now
        if (pendingTxId != null) {
            Handler(Looper.getMainLooper()).postDelayed({
                pendingTxId?.let { txId ->
                    deepLinkMethodChannel?.invokeMethod("openTransactionDetail", txId)
                }
            }, 500)
        }
    }

    private fun isAccessibilityServiceEnabled(context: Context, service: Class<out AccessibilityService>): Boolean {
        val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_GENERIC)
        val expectedComponentName = ComponentName(context, service)
        
        if (enabledServices != null) {
            for (enabledService in enabledServices) {
                val enabledComponentName = ComponentName(
                    enabledService.resolveInfo.serviceInfo.packageName,
                    enabledService.resolveInfo.serviceInfo.name
                )
                if (enabledComponentName == expectedComponentName) return true
            }
        }
        return false
    }

    private fun sendUssdRequest(code: String, result: MethodChannel.Result) {
        try {
            val ussdUri = Uri.fromParts("tel", code, null)
            val callIntent = Intent(Intent.ACTION_CALL, ussdUri)
            startActivity(callIntent)
            
            Handler(Looper.getMainLooper()).postDelayed({
                bringToFront(this)
            }, 300)

            result.success("Automation Started")
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }
}
