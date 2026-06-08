package com.local.aichathelper

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executor

class ScreenshotAccessibilityService : AccessibilityService() {
    companion object {
        private var instance: ScreenshotAccessibilityService? = null

        fun isConnected(): Boolean = instance != null

        fun isEnabled(context: Context): Boolean {
            if (isConnected()) return true
            val resolver = context.contentResolver
            val accessibilityEnabled = Settings.Secure.getInt(
                resolver,
                Settings.Secure.ACCESSIBILITY_ENABLED,
                0
            ) == 1
            if (!accessibilityEnabled) return false
            val enabledServices = Settings.Secure.getString(
                resolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            val expected = ComponentName(
                context,
                ScreenshotAccessibilityService::class.java
            )
            val splitter = TextUtils.SimpleStringSplitter(':')
            splitter.setString(enabledServices)
            while (splitter.hasNext()) {
                val enabled = ComponentName.unflattenFromString(splitter.next())
                if (enabled == expected) return true
            }
            return false
        }

        fun capture(context: Context, callback: (String?, String?) -> Unit) {
            val service = instance
            if (service == null) {
                val message = if (isEnabled(context)) {
                    "AI Reply 无障碍服务已开启但还在连接，请稍后再试。"
                } else {
                    "请先在系统设置中开启 AI Reply 无障碍服务。"
                }
                callback(null, message)
                return
            }
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                callback(null, "当前系统版本不支持无障碍截图。")
                return
            }
            val executor = Executor { command -> Handler(Looper.getMainLooper()).post(command) }
            try {
                service.takeScreenshot(Display.DEFAULT_DISPLAY, executor, object : AccessibilityService.TakeScreenshotCallback {
                    override fun onSuccess(screenshot: ScreenshotResult) {
                        var bitmap: Bitmap? = null
                        var software: Bitmap? = null
                        var file: File? = null
                        try {
                            bitmap = Bitmap.wrapHardwareBuffer(screenshot.hardwareBuffer, screenshot.colorSpace)
                            if (bitmap == null) {
                                callback(null, "无障碍截图为空。")
                                return
                            }
                            software = bitmap.copy(Bitmap.Config.ARGB_8888, false)
                            file = File.createTempFile("accessibility-capture-", ".jpg", context.cacheDir)
                            FileOutputStream(file).use { out ->
                                if (!software.compress(Bitmap.CompressFormat.JPEG, 92, out)) {
                                    throw IllegalStateException("无法保存无障碍截图。")
                                }
                            }
                            callback(file.absolutePath, null)
                        } catch (error: Throwable) {
                            runCatching { file?.takeIf { it.exists() }?.delete() }
                            callback(null, error.message ?: "无障碍截图失败。")
                        } finally {
                            software?.recycle()
                            bitmap?.recycle()
                            screenshot.hardwareBuffer.close()
                        }
                    }

                    override fun onFailure(errorCode: Int) {
                        callback(null, "无障碍截图失败，错误码：$errorCode")
                    }
                })
            } catch (error: Throwable) {
                callback(null, error.message ?: "无障碍截图失败。")
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        super.onDestroy()
    }

    override fun onUnbind(intent: Intent?): Boolean {
        if (instance === this) instance = null
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}
}
