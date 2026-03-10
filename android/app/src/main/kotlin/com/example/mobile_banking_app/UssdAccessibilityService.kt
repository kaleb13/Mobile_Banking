package com.example.mobile_banking_app

import android.accessibilityservice.AccessibilityService
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import android.graphics.Color
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.ScrollView
import android.graphics.drawable.GradientDrawable
import android.graphics.Typeface
import android.content.res.ColorStateList
import android.widget.ImageView

enum class UssdState {
    IDLE, DIALING, INTERACTING, FINISHING
}

class UssdAccessibilityService : AccessibilityService() {

    companion object {
        var instance: UssdAccessibilityService? = null
        var eventSink: EventChannel.EventSink? = null
        var pendingInputs: MutableList<String> = mutableListOf()
        var isAutomationRunning: Boolean = false
        var currentState: UssdState = UssdState.IDLE
        var lastScreenText: String = ""
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var overlayStatusTitle: TextView? = null
    private var overlayProgress: ProgressBar? = null
    private var chatLayout: LinearLayout? = null
    private var chatScrollView: ScrollView? = null
    private var appIconView: ImageView? = null
    private var successIconView: TextView? = null
    private var iconWrapperBg: GradientDrawable? = null
    private var overlayCancelBtn: android.widget.Button? = null

    fun showOverlay() {
        if (overlayView != null) return

        handler.post {
            try {
                windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
                val layoutParams = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or 
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or 
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                    PixelFormat.TRANSLUCENT
                )

                val dpToPx = { dp: Int -> (dp * resources.displayMetrics.density).toInt() }

                val root = FrameLayout(this)
                root.setBackgroundColor(Color.parseColor("#121212")) // App Background
                
                // Hide system navigation bar and status bar, and ignore keyboard resizing
                root.systemUiVisibility = (View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)

                val mainCol = LinearLayout(this)
                mainCol.orientation = LinearLayout.VERTICAL
                mainCol.layoutParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                )

                // TOP BAR (Top Right 'X')
                val topBar = LinearLayout(this)
                topBar.orientation = LinearLayout.HORIZONTAL
                topBar.gravity = Gravity.END // Align content to the right edge
                topBar.setPadding(dpToPx(16), dpToPx(40), dpToPx(16), dpToPx(16))
                
                val cancelIcon = ImageView(this)
                cancelIcon.setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
                cancelIcon.imageTintList = ColorStateList.valueOf(Color.WHITE)
                cancelIcon.setPadding(dpToPx(16), dpToPx(16), dpToPx(16), dpToPx(16))
                cancelIcon.setOnClickListener { cancelAutomation(false) }
                topBar.addView(cancelIcon)
                mainCol.addView(topBar)

                // ICON AREA (App Icon while processing, Green Checkmark on Success)
                val iconWrapper = FrameLayout(this)
                val iconParams = LinearLayout.LayoutParams(dpToPx(72), dpToPx(72))
                iconParams.gravity = Gravity.CENTER
                iconParams.topMargin = dpToPx(16)
                iconParams.bottomMargin = dpToPx(24)
                iconWrapper.layoutParams = iconParams
                
                iconWrapperBg = GradientDrawable()
                iconWrapperBg?.shape = GradientDrawable.OVAL
                iconWrapperBg?.setColor(Color.parseColor("#1A1A1A")) // Dark background initially
                iconWrapper.background = iconWrapperBg

                appIconView = ImageView(this)
                try {
                    val appIconDrawable = packageManager.getApplicationIcon("com.example.mobile_banking_app")
                    appIconView?.setImageDrawable(appIconDrawable)
                } catch (e: Exception) {
                    Log.e("UssdService", "Icon Error: ${e.message}")
                }
                
                val imgParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                ).apply {
                    val pad = dpToPx(12)
                    setMargins(pad, pad, pad, pad)
                }
                appIconView?.layoutParams = imgParams
                appIconView?.scaleType = ImageView.ScaleType.FIT_CENTER
                iconWrapper.addView(appIconView)

                successIconView = TextView(this)
                successIconView?.text = "✔" // Checkmark
                successIconView?.textSize = 36f
                successIconView?.setTextColor(Color.WHITE)
                successIconView?.layoutParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT
                ).apply { gravity = Gravity.CENTER }
                successIconView?.visibility = View.GONE
                iconWrapper.addView(successIconView)
                
                mainCol.addView(iconWrapper)

                // CHAT BUBBLES IN SEPARATE CONTAINER
                val chatWrapper = LinearLayout(this)
                chatWrapper.orientation = LinearLayout.VERTICAL
                val wrapParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f
                )
                wrapParams.setMargins(dpToPx(24), 0, dpToPx(24), dpToPx(24))
                chatWrapper.layoutParams = wrapParams
                
                val chatBg = GradientDrawable()
                chatBg.setColor(Color.parseColor("#1A1A1A")) // Distinct dark card
                chatBg.cornerRadius = dpToPx(16).toFloat()
                chatWrapper.background = chatBg
                chatWrapper.setPadding(0, dpToPx(16), 0, dpToPx(16))

                chatScrollView = ScrollView(this)
                chatScrollView?.layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.MATCH_PARENT
                )

                chatLayout = LinearLayout(this)
                chatLayout?.orientation = LinearLayout.VERTICAL
                chatLayout?.setPadding(dpToPx(16), 0, dpToPx(16), 0)
                chatScrollView?.addView(chatLayout)
                chatWrapper.addView(chatScrollView)
                
                mainCol.addView(chatWrapper)

                // FOOTER (Slimmer)
                val footer = LinearLayout(this)
                footer.orientation = LinearLayout.VERTICAL
                
                val footerBg = GradientDrawable()
                footerBg.setColor(Color.parseColor("#121212")) // Blends with background or dark slightly
                footer.background = footerBg
                footer.setPadding(dpToPx(24), dpToPx(16), dpToPx(24), dpToPx(32))

                overlayStatusTitle = TextView(this)
                overlayStatusTitle?.text = "Processing..."
                overlayStatusTitle?.setTextColor(Color.WHITE)
                overlayStatusTitle?.textSize = 18f
                overlayStatusTitle?.gravity = Gravity.CENTER
                overlayStatusTitle?.setTypeface(null, Typeface.BOLD)
                val titleParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
                )
                titleParams.bottomMargin = dpToPx(24)
                footer.addView(overlayStatusTitle, titleParams)

                // Solid thick progress bar line
                overlayProgress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal)
                overlayProgress?.isIndeterminate = true
                overlayProgress?.progressTintList = ColorStateList.valueOf(Color.parseColor("#38A169"))
                val progParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dpToPx(4))
                progParams.bottomMargin = dpToPx(32)
                overlayProgress?.layoutParams = progParams
                footer.addView(overlayProgress)

                val cancelBtn = android.widget.Button(this)
                cancelBtn.text = "Close"
                cancelBtn.setTextColor(Color.parseColor("#38A169"))
                cancelBtn.textSize = 14f
                cancelBtn.setTypeface(null, Typeface.BOLD)
                cancelBtn.setBackgroundColor(Color.TRANSPARENT)
                cancelBtn.isAllCaps = false
                val btnParams = LinearLayout.LayoutParams(
                    dpToPx(120), dpToPx(48)
                ).apply { gravity = Gravity.CENTER }
                cancelBtn.layoutParams = btnParams
                
                val border = GradientDrawable()
                border.setStroke(dpToPx(1), Color.parseColor("#1AFFFFFF"))
                border.cornerRadius = dpToPx(24).toFloat()
                cancelBtn.background = border
                cancelBtn.setOnClickListener { cancelAutomation(overlayCancelBtn?.text?.toString() == "Retry") }
                
                overlayCancelBtn = cancelBtn
                footer.addView(cancelBtn)

                mainCol.addView(footer)
                root.addView(mainCol)

                overlayView = root
                windowManager?.addView(overlayView, layoutParams)

                addBubbleToChat("Starting automation...", true)
            } catch (e: Exception) {
                Log.e("UssdService", "Overlay Error: ${e.message}")
            }
        }
    }

    private fun cancelAutomation(isRetry: Boolean = false) {
        if (overlayView == null) return // Already closed
        isAutomationRunning = false
        
        handler.post {
            updateStatusTitle(if (isRetry) "Retrying..." else "Closing...")
            
            if (currentState != UssdState.FINISHING) {
                overlayProgress?.progressTintList = ColorStateList.valueOf(Color.parseColor("#E53E3E")) // Red color
                addBubbleToChat(if (isRetry) "User requested retry." else "User cancelled operation.", false)
            }

            handler.postDelayed({
                if (currentState != UssdState.FINISHING) {
                    // Aggressively attempt to close USSD dialer dialogs if they are blocking
                    try {
                        val rootNode = rootInActiveWindow
                        if (rootNode != null) {
                            val cBtn = findNodeByText(rootNode, "Cancel") ?: findNodeByText(rootNode, "Dismiss") ?: findNodeByText(rootNode, "OK")
                            cBtn?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                        }
                    } catch(e: Exception) {}

                    hideOverlay()
                    performGlobalAction(GLOBAL_ACTION_BACK)
                    
                    handler.postDelayed({
                        performGlobalAction(GLOBAL_ACTION_BACK) // Double back to force phone dialer to close
                        val msg = if (isRetry) "Retry requested" else "Automation cancelled by user"
                        eventSink?.success(mapOf("type" to "error", "content" to msg))
                        MainActivity.bringToFront(this@UssdAccessibilityService)
                        currentState = UssdState.IDLE
                    }, 100)
                } else {
                    // Fast graceful exit for success state without breaking Flutter UI
                    hideOverlay()
                    MainActivity.bringToFront(this@UssdAccessibilityService)
                    currentState = UssdState.IDLE
                }
            }, 500)
        }
    }

    fun addBubbleToChat(text: String, isBank: Boolean) {
        if (chatLayout == null) return
        handler.post {
            val dpToPx = { dp: Int -> (dp * resources.displayMetrics.density).toInt() }
            
            val bubble = TextView(this)
            bubble.text = text
            bubble.textSize = 14f
            bubble.setTypeface(null, Typeface.BOLD)
            
            val bg = GradientDrawable()
            if (isBank) {
                bubble.setTextColor(Color.BLACK)
                bg.setColor(Color.parseColor("#F0B90B"))
                bg.cornerRadii = floatArrayOf(
                    dpToPx(16).toFloat(), dpToPx(16).toFloat(),
                    dpToPx(16).toFloat(), dpToPx(16).toFloat(),
                    dpToPx(16).toFloat(), dpToPx(16).toFloat(),
                    0f, 0f // bottom left flat
                )
            } else {
                bubble.setTextColor(Color.WHITE)
                bg.setColor(Color.parseColor("#0DFFFFFF")) // 5% white
                bg.cornerRadii = floatArrayOf(
                    dpToPx(16).toFloat(), dpToPx(16).toFloat(),
                    dpToPx(16).toFloat(), dpToPx(16).toFloat(),
                    0f, 0f, // bottom right flat
                    dpToPx(16).toFloat(), dpToPx(16).toFloat()
                )
            }
            bubble.background = bg
            bubble.setPadding(dpToPx(16), dpToPx(12), dpToPx(16), dpToPx(12))

            val wrapperParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT
            )
            wrapperParams.gravity = if (isBank) Gravity.START else Gravity.END
            wrapperParams.bottomMargin = dpToPx(16)
            
            bubble.layoutParams = wrapperParams
            chatLayout?.addView(bubble)

            // auto scroll
            chatScrollView?.post {
                chatScrollView?.fullScroll(View.FOCUS_DOWN)
            }
        }
    }

    fun hideOverlay() {
        handler.post {
            try {
                if (overlayView != null) {
                    windowManager?.removeView(overlayView)
                    overlayView = null
                    chatLayout = null
                    chatScrollView = null
                    overlayStatusTitle = null
                    overlayProgress = null
                    appIconView = null
                    successIconView = null
                    iconWrapperBg = null
                    overlayCancelBtn = null
                }
            } catch (e: Exception) {
                Log.e("UssdService", "Hide Overlay Error: ${e.message}")
            }
        }
    }

    private fun updateStatusTitle(title: String) {
        handler.post {
            overlayStatusTitle?.text = title
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var processingRunnable: Runnable? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d("UssdService", "Accessibility Service Connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (!isAutomationRunning) return

        val packageName = event.packageName?.toString() ?: ""
        if (packageName == this.packageName) return

        // DEBOUNCE: Cancel any pending processing and restart the timer
        processingRunnable?.let { handler.removeCallbacks(it) }
        
        processingRunnable = Runnable {
            processDialog()
        }
        
        handler.postDelayed(processingRunnable!!, 250)
    }

    private fun processDialog() {
        if (!isAutomationRunning) return

        try {
            val rootNode = rootInActiveWindow ?: return
            
            val nodeText = findNodeByClassName(rootNode, "android.widget.TextView")
            val inputField = findNodeByClassName(rootNode, "android.widget.EditText")
            val sendButton = findNodeByText(rootNode, "Send") ?: findNodeByText(rootNode, "OK") ?: findNodeByText(rootNode, "Submit")

            if (nodeText != null) {
                val text = nodeText.text?.toString() ?: ""
                if (text.trim().isEmpty() || text == lastScreenText) return
                lastScreenText = text

                Log.d("UssdService", "Processing Debounced Dialog: $text")
                addBubbleToChat(text, isBank = true)
                eventSink?.success(mapOf("type" to "screen", "content" to text))

                // Error / Delay Detection -> Change Bottom Button to 'Retry'
                val tLower = text.lowercase()
                if (tLower.contains("delay") || tLower.contains("error") || tLower.contains("failed") || tLower.contains("invalid") || tLower.contains("sorry")) {
                    handler.post {
                        updateStatusTitle("Error Occurred")
                        overlayCancelBtn?.text = "Retry"
                        overlayCancelBtn?.setTextColor(Color.parseColor("#E53E3E")) // Red warning text
                        overlayProgress?.isIndeterminate = false
                        overlayProgress?.progress = 100
                        overlayProgress?.progressTintList = ColorStateList.valueOf(Color.parseColor("#E53E3E"))
                    }
                }

                when (currentState) {
                    UssdState.IDLE, UssdState.DIALING -> {
                        currentState = UssdState.INTERACTING
                        processInput(inputField, sendButton)
                    }
                    UssdState.INTERACTING -> {
                        if (pendingInputs.isEmpty() && (text.contains("Balance", true) || (text.contains("Welcome", true) && !text.contains("Enter", true)))) {
                            currentState = UssdState.FINISHING
                            finishAutomation(rootNode, text)
                        } else {
                            processInput(inputField, sendButton)
                        }
                    }
                    UssdState.FINISHING -> {
                        isAutomationRunning = false
                        currentState = UssdState.IDLE
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("UssdService", "Process Error: ${e.message}")
        }
    }

    private fun processInput(inputField: AccessibilityNodeInfo?, sendButton: AccessibilityNodeInfo?) {
        if (pendingInputs.isNotEmpty() && inputField != null && sendButton != null) {
            val nextInput = pendingInputs.removeAt(0)
            Log.d("UssdService", "State Machine Typing: $nextInput")
            addBubbleToChat(if (nextInput.length > 3) "••••" else nextInput, isBank = false)
            eventSink?.success(mapOf("type" to "input", "content" to nextInput))

            val arguments = Bundle()
            arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, nextInput)
            inputField.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
            sendButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }
    }

    private fun finishAutomation(rootNode: AccessibilityNodeInfo, finalText: String) {
        UssdAccessibilityService.lastScreenText = ""
        updateStatusTitle("Success")
        
        // Make the progress bar a solid 'complete' line instead of indeterminate spinning
        // Swap App Icon for Green Checkmark
        handler.post {
            overlayProgress?.isIndeterminate = false
            overlayProgress?.progress = 100
            
            appIconView?.visibility = View.GONE
            successIconView?.visibility = View.VISIBLE
            iconWrapperBg?.setColor(Color.parseColor("#38A169")) // Turn background green
        }
        
        eventSink?.success(mapOf("type" to "finish", "content" to finalText))
        
        // Attempt to close the dialog gracefully
        val closeButton = findNodeByText(rootNode, "OK") 
                       ?: findNodeByText(rootNode, "Dismiss") 
                       ?: findNodeByText(rootNode, "Cancel")
        
        if (closeButton != null) {
            closeButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        } else {
            performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
        }

        // Clean up and bring Flutter back into view
        hideOverlay()
        MainActivity.bringToFront(this)
    }

    private fun findNodeByClassName(root: AccessibilityNodeInfo, className: String): AccessibilityNodeInfo? {
        val deque = ArrayDeque<AccessibilityNodeInfo>()
        deque.add(root)
        while (deque.isNotEmpty()) {
            val node = deque.removeFirst()
            if (node.className?.toString() == className) return node
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { deque.add(it) }
            }
        }
        return null
    }

    private fun findNodeByText(root: AccessibilityNodeInfo, text: String): AccessibilityNodeInfo? {
        val deque = ArrayDeque<AccessibilityNodeInfo>()
        deque.add(root)
        while (deque.isNotEmpty()) {
            val node = deque.removeFirst()
            if (node.text?.toString()?.contains(text, ignoreCase = true) == true) return node
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { deque.add(it) }
            }
        }
        return null
    }

    override fun onInterrupt() {
        instance = null
        isAutomationRunning = false
        currentState = UssdState.IDLE
        hideOverlay()
    }
}
