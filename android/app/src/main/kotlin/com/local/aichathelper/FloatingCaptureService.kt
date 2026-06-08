package com.local.aichathelper

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.StateListDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.core.app.NotificationCompat
import kotlin.math.abs

class FloatingCaptureService : Service() {
    companion object {
        const val ACTION_SHOW_REPLIES = "com.local.aichathelper.SHOW_REPLIES"
        const val ACTION_HIDE_REPLIES = "com.local.aichathelper.HIDE_REPLIES"
        const val EXTRA_TITLE = "title"
        const val EXTRA_LOADING = "loading"
        const val EXTRA_MESSAGE = "message"
        const val EXTRA_REPLIES = "replies"
        const val EXTRA_RETURN_PACKAGE = "returnPackage"
        private const val CHANNEL_ID = "ai_reply_floating"
        private const val NOTIFICATION_ID = 1401
        private const val PREFS_NAME = "ai_reply_floating_prefs"
        private const val PREF_FLOATING_X = "floating_x"
        private const val PREF_FLOATING_Y = "floating_y"
    }

    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var replyView: View? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        if (!enterForegroundSafely()) {
            stopSelf()
            return
        }
    }

    private fun enterForegroundSafely(): Boolean =
        runCatching {
            enterForeground()
        }.onFailure { error ->
            FloatingEvents.error(error.message ?: "无法启动悬浮窗前台服务。")
        }.isSuccess

    private fun enterForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification())
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW_REPLIES -> showReplyPanel(
                intent.getStringExtra(EXTRA_TITLE) ?: "点击回复即可复制",
                intent.getBooleanExtra(EXTRA_LOADING, false),
                intent.getStringArrayListExtra(EXTRA_REPLIES) ?: arrayListOf(),
                intent.getStringExtra(EXTRA_RETURN_PACKAGE),
                intent.getStringExtra(EXTRA_MESSAGE)?.takeIf { it.isNotBlank() }
            )
            ACTION_HIDE_REPLIES -> hideReplyPanel()
            else -> showFloatingButton()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        floatingView?.let { removeViewSafely(it) }
        replyView?.let { removeViewSafely(it) }
        floatingView = null
        replyView = null
        super.onDestroy()
    }

    private fun showFloatingButton() {
        if (!Settings.canDrawOverlays(this)) {
            FloatingEvents.error("请先开启悬浮窗权限。")
            stopSelf()
            return
        }
        if (floatingView != null) return
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val button = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(7), dp(6), dp(7), dp(6))
            background = statefulGradientBackground(
                intArrayOf(0xFF0F766E.toInt(), 0xFF38BDF8.toInt()),
                intArrayOf(0xFF115E59.toInt(), 0xFF22D3EE.toInt()),
                dp(22).toFloat(),
                0x99CCFBF1.toInt(),
                dp(1)
            )
            elevation = 18f
            contentDescription = "AI Reply 悬浮截图"
            setOnClickListener { view ->
                performLightHaptic(view)
                captureCurrentScreen("floating")
            }
        }
        button.addView(TextView(this).apply {
            text = "AI"
            textSize = 18f
            gravity = Gravity.CENTER
            includeFontPadding = false
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(0xFFFFFFFF.toInt())
        })
        button.addView(TextView(this).apply {
            text = "回复"
            textSize = 10f
            gravity = Gravity.CENTER
            includeFontPadding = false
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(0xEFFFFFFF.toInt())
        })
        val params = WindowManager.LayoutParams(
            dp(64),
            dp(64),
            overlayWindowType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = dp(16)
            y = dp(140)
        }
        restoreFloatingButtonPosition(params)
        var startX = 0
        var startY = 0
        var touchX = 0f
        var touchY = 0f
        var moved = false
        val touchSlop = ViewConfiguration.get(this).scaledTouchSlop
        button.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x
                    startY = params.y
                    touchX = event.rawX
                    touchY = event.rawY
                    moved = false
                    view.alpha = 0.94f
                    view.scaleX = 0.96f
                    view.scaleY = 0.96f
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.rawX - touchX
                    val deltaY = event.rawY - touchY
                    if (abs(deltaX) > touchSlop || abs(deltaY) > touchSlop) {
                        moved = true
                    }
                    if (!moved) return@setOnTouchListener true
                    view.alpha = 0.86f
                    params.x = startX - deltaX.toInt()
                    params.y = startY + deltaY.toInt()
                    clampFloatingButtonPosition(params)
                    runCatching {
                        windowManager?.updateViewLayout(view, params)
                    }.onFailure { error ->
                        FloatingEvents.error(error.message ?: "无法移动悬浮窗。")
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    view.alpha = 1f
                    view.scaleX = 1f
                    view.scaleY = 1f
                    if (moved) {
                        saveFloatingButtonPosition(params)
                    } else {
                        view.performClick()
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    moved = false
                    view.alpha = 1f
                    view.scaleX = 1f
                    view.scaleY = 1f
                    true
                }
                else -> true
            }
        }
        runCatching {
            windowManager?.addView(button, params)
        }.onSuccess {
            floatingView = button
        }.onFailure { error ->
            floatingView = null
            FloatingEvents.error(error.message ?: "无法显示悬浮窗。")
            stopSelf()
        }
    }

    private fun showReplyPanel(
        title: String,
        loading: Boolean,
        replies: List<String>,
        returnPackage: String?,
        message: String? = null
    ) {
        if (!Settings.canDrawOverlays(this)) {
            FloatingEvents.error("请先开启悬浮窗权限。")
            stopSelf()
            return
        }
        val manager = windowManager
            ?: (getSystemService(Context.WINDOW_SERVICE) as WindowManager).also {
                windowManager = it
            }
        hideReplyPanel(stopIfEmpty = false)
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(16), dp(18), dp(16))
            background = roundedBackground(
                0xF20A1424.toInt(),
                dp(22).toFloat(),
                0x6645E6D1,
                dp(1)
            )
            elevation = 24f
        }
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        header.addView(TextView(this).apply {
            text = "AI"
            textSize = 13f
            gravity = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(0xFF082F49.toInt())
            background = roundedBackground(0xFFB8F7E8.toInt(), dp(14).toFloat())
        }, LinearLayout.LayoutParams(dp(38), dp(28)))
        header.addView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(10), 0, dp(8), 0)
            addView(TextView(this@FloatingCaptureService).apply {
                text = title
                textSize = 17f
                includeFontPadding = false
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(0xFFFFFFFF.toInt())
            })
            addView(TextView(this@FloatingCaptureService).apply {
                text = when {
                    loading -> "正在理解聊天截图"
                    replies.isEmpty() -> "当前没有可复制回复"
                    else -> "${replies.size.coerceAtMost(5)} 条建议，点击即复制"
                }
                textSize = 12f
                includeFontPadding = false
                setTextColor(0xBFFFFFFF.toInt())
                setPadding(0, dp(4), 0, 0)
            })
        }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        header.addView(TextView(this).apply {
            text = "关闭"
            textSize = 12f
            gravity = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(0xFFE0F2FE.toInt())
            background = statefulRoundedBackground(
                0x1FFFFFFF,
                0x33FFFFFF,
                dp(14).toFloat(),
                0x33FFFFFF,
                dp(1)
            )
            setOnClickListener { hideReplyPanel() }
        }, LinearLayout.LayoutParams(dp(54), dp(30)))
        panel.addView(header)
        panel.addView(statusChip(loading, replies.isNotEmpty()), LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = dp(14)
            bottomMargin = dp(10)
        })
        if (loading || replies.isEmpty()) {
            panel.addView(TextView(this).apply {
                text = message ?: if (loading) "请稍等，完成后会自动更新。" else "暂时没有可复制的回复。"
                textSize = 15f
                setTextColor(0xFFE0F2FE.toInt())
                setLineSpacing(0f, 1.08f)
                background = roundedBackground(0x14FFFFFF, dp(16).toFloat(), 0x22FFFFFF, dp(1))
                setPadding(dp(14), dp(12), dp(14), dp(12))
            })
        } else {
            replies.take(5).forEachIndexed { index, reply ->
                panel.addView(TextView(this).apply {
                    text = reply
                    textSize = 15f
                    typeface = if (index == 0) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
                    setTextColor(0xFF082F49.toInt())
                    setLineSpacing(0f, 1.08f)
                    background = statefulRoundedBackground(
                        if (index == 0) 0xFFE0FFF7.toInt() else 0xFFF8FAFC.toInt(),
                        if (index == 0) 0xFFB8F7E8.toInt() else 0xFFE2E8F0.toInt(),
                        dp(16).toFloat(),
                        if (index == 0) 0xFF5EEAD4.toInt() else 0xFFD6E2EA.toInt(),
                        dp(1)
                    )
                    setPadding(dp(14), dp(12), dp(14), dp(12))
                    setOnClickListener { view ->
                        if (copyReplySafely(reply)) {
                            performLightHaptic(view)
                            FloatingEvents.copiedReply(reply)
                            showCopiedToast()
                            hideReplyPanel()
                            openReturnPackage(returnPackage)
                        }
                    }
                }, LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    if (index > 0) topMargin = dp(8)
                })
            }
        }
        if (!loading && replies.isNotEmpty()) {
            panel.addView(TextView(this).apply {
                text = if (returnPackage.isNullOrBlank()) {
                    "复制后可回到聊天 App 粘贴"
                } else {
                    "复制后会自动回到聊天 App"
                }
                textSize = 12f
                gravity = Gravity.CENTER
                setTextColor(0x99FFFFFF.toInt())
                setPadding(0, dp(12), 0, 0)
            })
        }

        val container = MaxHeightScrollView(
            this,
            (resources.displayMetrics.heightPixels * 0.62f).toInt()
        ).apply {
            isVerticalScrollBarEnabled = true
            overScrollMode = View.OVER_SCROLL_IF_CONTENT_SCROLLS
            addView(panel)
        }
        val params = WindowManager.LayoutParams(
            (resources.displayMetrics.widthPixels * 0.86f).toInt().coerceAtMost(dp(420)),
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayWindowType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = dp(132)
        }
        runCatching {
            manager.addView(container, params)
        }.onSuccess {
            replyView = container
        }.onFailure { error ->
            replyView = null
            FloatingEvents.error(error.message ?: "无法显示快捷回复面板。")
            stopIfNoVisibleWindows()
        }
    }

    private fun hideReplyPanel(stopIfEmpty: Boolean = true) {
        replyView?.let { view ->
            removeViewSafely(view)
        }
        replyView = null
        if (stopIfEmpty) stopIfNoVisibleWindows()
    }

    private fun stopIfNoVisibleWindows() {
        if (floatingView == null && replyView == null) {
            stopSelf()
        }
    }

    private fun removeViewSafely(view: View) {
        runCatching {
            windowManager?.removeView(view)
        }.onFailure { error ->
            FloatingEvents.error(error.message ?: "无法移除悬浮窗视图。")
        }
    }

    private fun copyReply(reply: String) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("AI Reply", reply))
    }

    private fun copyReplySafely(reply: String): Boolean =
        runCatching {
            copyReply(reply)
        }.onFailure { error ->
            FloatingEvents.error(error.message ?: "无法复制回复到剪贴板。")
        }.isSuccess

    private fun showCopiedToast() {
        runCatching {
            Toast.makeText(this, "已复制到剪贴板", Toast.LENGTH_SHORT).show()
        }
    }

    private fun performLightHaptic(view: View) {
        runCatching {
            view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
        }
    }

    private fun openReturnPackage(returnPackage: String?) {
        val targetPackage = returnPackage?.trim()?.takeIf { it.isNotEmpty() } ?: return
        val launchIntent = packageManager.getLaunchIntentForPackage(targetPackage)
        if (launchIntent == null) {
            FloatingEvents.error("无法回到聊天 App：未找到 $targetPackage。")
            return
        }
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { startActivity(launchIntent) }
            .onFailure { error ->
                FloatingEvents.error(error.message ?: "无法回到聊天 App。")
            }
    }

    private fun statusChip(loading: Boolean, hasReplies: Boolean): TextView =
        TextView(this).apply {
            text = when {
                loading -> "AI 分析中"
                hasReplies -> "已生成"
                else -> "提示"
            }
            textSize = 12f
            gravity = Gravity.CENTER
            includeFontPadding = false
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(if (hasReplies) 0xFF042F2E.toInt() else 0xFFE0F2FE.toInt())
            background = roundedBackground(
                if (hasReplies) 0xFFA7F3D0.toInt() else 0x1F38BDF8,
                dp(14).toFloat(),
                if (hasReplies) 0x665EEAD4 else 0x5538BDF8,
                dp(1)
            )
            setPadding(dp(10), dp(6), dp(10), dp(6))
        }

    private fun statefulGradientBackground(
        normalColors: IntArray,
        pressedColors: IntArray,
        radius: Float,
        strokeColor: Int,
        strokeWidth: Int
    ): StateListDrawable =
        StateListDrawable().apply {
            addState(
                intArrayOf(android.R.attr.state_pressed),
                gradientBackground(pressedColors, radius, strokeColor, strokeWidth)
            )
            addState(
                intArrayOf(),
                gradientBackground(normalColors, radius, strokeColor, strokeWidth)
            )
        }

    private fun statefulRoundedBackground(
        normalColor: Int,
        pressedColor: Int,
        radius: Float,
        strokeColor: Int,
        strokeWidth: Int
    ): StateListDrawable =
        StateListDrawable().apply {
            addState(
                intArrayOf(android.R.attr.state_pressed),
                roundedBackground(pressedColor, radius, strokeColor, strokeWidth)
            )
            addState(
                intArrayOf(),
                roundedBackground(normalColor, radius, strokeColor, strokeWidth)
            )
        }

    private fun gradientBackground(
        colors: IntArray,
        radius: Float,
        strokeColor: Int,
        strokeWidth: Int
    ): GradientDrawable =
        GradientDrawable(GradientDrawable.Orientation.TL_BR, colors).apply {
            cornerRadius = radius
            setStroke(strokeWidth, strokeColor)
        }

    private fun roundedBackground(
        color: Int,
        radius: Float,
        strokeColor: Int = 0x00000000,
        strokeWidth: Int = 0
    ): GradientDrawable =
        GradientDrawable().apply {
            cornerRadius = radius
            setColor(color)
            if (strokeWidth > 0) setStroke(strokeWidth, strokeColor)
        }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density + 0.5f).toInt()

    private fun clampFloatingButtonPosition(params: WindowManager.LayoutParams) {
        val metrics = resources.displayMetrics
        val maxX = (metrics.widthPixels - params.width).coerceAtLeast(0)
        val maxY = (metrics.heightPixels - params.height).coerceAtLeast(0)
        params.x = params.x.coerceIn(0, maxX)
        params.y = params.y.coerceIn(0, maxY)
    }

    private fun restoreFloatingButtonPosition(params: WindowManager.LayoutParams) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        params.x = prefs.getInt(PREF_FLOATING_X, params.x)
        params.y = prefs.getInt(PREF_FLOATING_Y, params.y)
        clampFloatingButtonPosition(params)
    }

    private fun saveFloatingButtonPosition(params: WindowManager.LayoutParams) {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putInt(PREF_FLOATING_X, params.x)
            .putInt(PREF_FLOATING_Y, params.y)
            .apply()
    }

    private class MaxHeightScrollView(
        context: Context,
        private val maxHeight: Int
    ) : ScrollView(context) {
        override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
            val cappedHeightSpec = View.MeasureSpec.makeMeasureSpec(
                maxHeight,
                View.MeasureSpec.AT_MOST
            )
            super.onMeasure(widthMeasureSpec, cappedHeightSpec)
        }
    }

    private fun overlayWindowType(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            legacyPhoneWindowType()
        }

    @Suppress("DEPRECATION")
    private fun legacyPhoneWindowType(): Int =
        WindowManager.LayoutParams.TYPE_PHONE

    private fun captureCurrentScreen(source: String = "floating") {
        if (!ScreenshotAccessibilityService.isEnabled(this)) {
            showReplyPanel(
                "需要开启无障碍增强",
                false,
                emptyList(),
                null,
                "为避免跳回 App，悬浮窗截图需要使用无障碍增强。请回到 AI Reply 的悬浮窗截图页开启后再试。"
            )
            return
        }
        showReplyPanel("AI Reply 正在分析", true, emptyList(), null)
        ScreenshotAccessibilityService.capture(this) { path, error ->
            if (path != null) {
                FloatingEvents.screenshot(path, source)
                openAppIfNeededForCapture(source)
            } else {
                val message = error ?: "无障碍截图失败，请重试。"
                showReplyPanel("截图失败", false, emptyList(), null, message)
                FloatingEvents.error(message)
            }
        }
    }

    private fun openAppIfNeededForCapture(source: String) {
        if (source == "floating" || FloatingEvents.hasActiveSink()) return
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
        }
        runCatching { startActivity(intent) }
            .onFailure { error ->
                FloatingEvents.error(error.message ?: "无法打开 AI Reply 处理读屏回复。")
            }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(CHANNEL_ID, "AI Reply 悬浮窗", NotificationManager.IMPORTANCE_LOW)
        channel.description = "点击悬浮窗后才截图，用于生成聊天回复。"
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun notification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AI Reply 悬浮窗已开启")
            .setContentText("点击悬浮窗后才会截图。")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
