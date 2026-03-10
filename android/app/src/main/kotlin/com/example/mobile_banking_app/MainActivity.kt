package com.example.mobile_banking_app

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.TelephonyManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityManager
import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import io.flutter.plugin.common.EventChannel
import android.net.Uri

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.shibre/ussd"
    private val EVENT_CHANNEL = "com.shibre/ussd_events"

    companion object {
        var instance: MainActivity? = null

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
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
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
            // Using fromParts is the safest way to handle special characters like * and # in phone URIs
            val ussdUri = Uri.fromParts("tel", code, null)
            
            // Start the dialer
            val callIntent = Intent(Intent.ACTION_CALL, ussdUri)
            startActivity(callIntent)
            
            // Give the system dialer 300ms to initialize the USSD session before we cover it
            Handler(Looper.getMainLooper()).postDelayed({
                bringToFront(this)
            }, 300)

            result.success("Automation Started")
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }
}
