package com.local.aichathelper

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class ProjectionForegroundService : Service() {
    companion object {
        private const val CHANNEL_ID = "ai_reply_projection"
        private const val NOTIFICATION_ID = 1402

        fun start(context: Context) {
            val intent = Intent(context, ProjectionForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, ProjectionForegroundService::class.java))
        }
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
        if (!enterForegroundSafely()) {
            stopSelf()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!enterForegroundSafely()) {
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun enterForegroundSafely(): Boolean =
        runCatching {
            enterForeground()
        }.onFailure { error ->
            FloatingEvents.error(error.message ?: "无法启动截屏前台服务。")
        }.isSuccess

    private fun enterForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification())
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "AI Reply 截屏",
            NotificationManager.IMPORTANCE_LOW
        )
        channel.description = "截取当前屏幕后自动关闭。"
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun notification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AI Reply 正在截屏")
            .setContentText("完成后会回到快回复页面。")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setOngoing(true)
            .build()
}
