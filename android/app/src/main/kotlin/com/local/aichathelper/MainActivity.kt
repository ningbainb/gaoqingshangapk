package com.local.aichathelper

import android.Manifest
import android.app.Activity
import android.content.ClipboardManager
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionConfig
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val methodChannelName = "ai_reply/floating"
    private val eventChannelName = "ai_reply/floating_events"
    private val projectionRequestCode = 4207
    private val notificationPermissionRequestCode = 4208
    private val nativeHandoffConsumedExtra = "ai_reply_native_handoff_consumed"
    private var eventSink: EventChannel.EventSink? = null
    private var pendingProjectionResult: MethodChannel.Result? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasOverlayPermission" -> result.success(Settings.canDrawOverlays(this))
                "hasNotificationPermission" -> result.success(hasNotificationPermission())
                "requestNotificationPermission" -> requestNotificationPermission(result)
                "openOverlaySettings" -> {
                    startActivitySafely(
                        Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")),
                        result,
                        "overlay_settings_failed",
                        "无法打开悬浮窗权限设置。"
                    )
                }
                "startFloatingWindow" -> {
                    startFloatingServiceSafely(
                        Intent(this, FloatingCaptureService::class.java),
                        result,
                        "floating_start_failed",
                        "无法启动悬浮窗服务。"
                    )
                }
                "stopFloatingWindow" -> {
                    stopFloatingServiceSafely(result)
                }
                "showReplyOverlay" -> {
                    showReplyOverlay(call.arguments, result)
                }
                "hideReplyOverlay" -> {
                    startFloatingServiceSafely(
                        Intent(this, FloatingCaptureService::class.java).apply {
                            action = FloatingCaptureService.ACTION_HIDE_REPLIES
                        },
                        result,
                        "floating_hide_failed",
                        "无法隐藏快捷回复面板。"
                    )
                }
                "collapseQuickPanel" -> {
                    collapseQuickPanelSafely(result)
                }
                "isAccessibilityEnabled" -> result.success(ScreenshotAccessibilityService.isEnabled(this))
                "isAccessibilityConnected" -> result.success(ScreenshotAccessibilityService.isConnected())
                "openAccessibilitySettings" -> {
                    startActivitySafely(
                        Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS),
                        result,
                        "accessibility_settings_failed",
                        "无法打开无障碍设置。"
                    )
                }
                "requestMediaProjectionScreenshot" -> requestProjection(result)
                "takeAccessibilityScreenshot" -> takeAccessibilityScreenshot(result)
                "readClipboardImage" -> readClipboardImage(result)
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                FloatingEvents.sink = events
                FloatingEvents.flushPending()
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                FloatingEvents.sink = null
            }
        })
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun onDestroy() {
        cancelPendingNativeResults("activity_destroyed", "截屏或权限请求已中断，请重试。")
        super.onDestroy()
    }

    private fun hasNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (hasNotificationPermission()) {
            result.success(true)
            return
        }
        if (pendingNotificationPermissionResult != null) {
            result.error("notification_permission_busy", "通知权限请求正在处理中。", null)
            return
        }
        pendingNotificationPermissionResult = result
        try {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                notificationPermissionRequestCode
            )
        } catch (error: Throwable) {
            pendingNotificationPermissionResult = null
            val message = error.message ?: "无法请求通知权限。"
            result.error("notification_permission_failed", message, null)
            FloatingEvents.error(message)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != notificationPermissionRequestCode) return
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        pendingNotificationPermissionResult?.success(granted)
        pendingNotificationPermissionResult = null
    }

    private fun cancelPendingNativeResults(code: String, message: String) {
        val hadPendingResult = pendingProjectionResult != null ||
            pendingNotificationPermissionResult != null
        pendingProjectionResult?.error(code, message, null)
        pendingProjectionResult = null
        pendingNotificationPermissionResult?.error(code, message, null)
        pendingNotificationPermissionResult = null
        ProjectionForegroundService.stop(this)
        if (hadPendingResult) FloatingEvents.error(message)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.getBooleanExtra(nativeHandoffConsumedExtra, false)) return
        if (intent.action == Intent.ACTION_VIEW) {
            val route = externalRoute(intent.data)
            if (!route.isNullOrBlank()) {
                markNativeHandoffConsumed(intent)
                FloatingEvents.route(route)
                return
            }
        }
        val sharedUris = sharedImageUris(intent)
        if (sharedUris.isNotEmpty()) {
            markNativeHandoffConsumed(intent)
            var lastImageError: Throwable? = null
            for (uri in sharedUris) {
                try {
                    FloatingEvents.screenshot(copyClipboardUri(uri), "share")
                    return
                } catch (error: Throwable) {
                    lastImageError = error
                }
            }
            val fallbackText = sharedText(intent)
            if (!fallbackText.isNullOrBlank()) {
                FloatingEvents.text(fallbackText.trim(), "share")
                return
            }
            FloatingEvents.error(lastImageError?.message ?: "无法读取分享的图片。")
            return
        }
        val sharedText = sharedText(intent)
        if (!sharedText.isNullOrBlank()) {
            markNativeHandoffConsumed(intent)
            val textSource = if (intent.action == Intent.ACTION_PROCESS_TEXT) "selected-text" else "share"
            FloatingEvents.text(sharedText.trim(), textSource)
            return
        }
    }

    private fun markNativeHandoffConsumed(intent: Intent) {
        intent.putExtra(nativeHandoffConsumedExtra, true)
        setIntent(intent)
    }

    private fun externalRoute(uri: Uri?): String? {
        if (uri == null || !uri.scheme.equals("aichathelper", ignoreCase = true)) return null
        if (!uri.isHierarchical) {
            return uri.schemeSpecificPart?.trim()?.trim('/')?.takeIf { it.isNotBlank() }
        }
        val host = uri.host?.trim('/')
        val path = uri.path?.trim('/')
        val pathRoute = listOfNotNull(host, path)
            .filter { it.isNotBlank() }
            .joinToString("/")
            .ifBlank { null }
        val queryRoute = externalRouteQuery(uri)
        if (!queryRoute.isNullOrBlank() &&
            (pathRoute.isNullOrBlank() || isExternalRouteWrapper(pathRoute))
        ) {
            return queryRoute
        }
        if (!queryRoute.isNullOrBlank() && !pathRoute.isNullOrBlank() &&
            isExternalRouteContainer(pathRoute)
        ) {
            return "$pathRoute/$queryRoute"
        }
        return pathRoute ?: queryRoute
    }

    private fun externalRouteQuery(uri: Uri): String? {
        if (!uri.isHierarchical) return null
        val aliases = setOf(
            "route",
            "path",
            "targetroute",
            "target",
            "screen",
            "page",
            "deeplink",
            "url",
            "uri",
            "link",
            "destination"
        )
        for (name in uri.queryParameterNames) {
            if (!aliases.contains(normalizedRouteKey(name))) continue
            val value = uri.getQueryParameter(name)?.trim()?.trim('/')
            if (!value.isNullOrBlank()) return value
        }
        return null
    }

    private fun isExternalRouteWrapper(route: String): Boolean =
        normalizedRouteKey(route.trim('/')) in setOf(
            "open",
            "route",
            "router",
            "navigate",
            "navigation",
            "go",
            "screen",
            "page",
            "target",
            "deeplink",
            "url",
            "uri",
            "link",
            "destination"
        )

    private fun isExternalRouteContainer(route: String): Boolean =
        normalizedRouteKey(route.trim('/')) in setOf(
            "settings"
        )

    private fun normalizedRouteKey(value: String): String =
        value.replace(Regex("[_\\-\\s]+"), "").lowercase()

    private fun sharedImageUris(intent: Intent): List<Uri> {
        val action = intent.action ?: return emptyList()
        val isImage = isImageMime(intent.type)
        if (action == Intent.ACTION_SEND) {
            val clipLooksImage = intent.clipData?.let { clipHasImageMime(it) } == true
            return usableImageUris(
                intent.streamUris() + intent.clipData.uriItems(),
                trustDeclaredImage = isImage || clipLooksImage
            )
        }
        if (action == Intent.ACTION_SEND_MULTIPLE) {
            val clipLooksImage = intent.clipData?.let { clipHasImageMime(it) } == true
            return usableImageUris(
                intent.streamUris() + intent.clipData.uriItems(),
                trustDeclaredImage = isImage || clipLooksImage
            )
        }
        if (action == Intent.ACTION_VIEW) {
            val clipLooksImage = intent.clipData?.let { clipHasImageMime(it) } == true
            return usableImageUris(
                listOfNotNull(intent.data) + intent.clipData.uriItems(),
                trustDeclaredImage = isImage || clipLooksImage
            )
        }
        return emptyList()
    }

    private fun isImageMime(mimeType: String?): Boolean =
        mimeType?.startsWith("image/") == true

    private fun isImageUri(uri: Uri?): Boolean {
        if (uri == null) return false
        val resolverType = runCatching { contentResolver.getType(uri) }.getOrNull()
        if (isImageMime(resolverType)) return true
        return isImageMime(imageMimeFromExtension(uri))
    }

    private fun imageMimeFromExtension(uri: Uri): String? {
        val candidates = listOfNotNull(
            MimeTypeMap.getFileExtensionFromUrl(uri.toString()),
            extensionFromPathSegment(uri.lastPathSegment),
            extensionFromPathSegment(uri.path)
        )
        for (extension in candidates
            .map { it.trim().lowercase() }
            .filter { it.isNotEmpty() }
            .distinct()
        ) {
            val mapped = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            if (!mapped.isNullOrBlank()) return mapped
        }
        return null
    }

    private fun extensionFromPathSegment(segment: String?): String? {
        val clean = segment
            ?.substringBefore('?')
            ?.substringBefore('#')
            ?.trim()
            ?: return null
        val dot = clean.lastIndexOf('.')
        if (dot < 0 || dot == clean.lastIndex) return null
        return clean.substring(dot + 1)
    }

    private fun sharedText(intent: Intent): String? {
        if (intent.action == Intent.ACTION_PROCESS_TEXT) {
            val processText = intent.processText()
            if (!processText.isNullOrBlank()) return processText
            return intent.extraText()
        }
        if (intent.action != Intent.ACTION_SEND &&
            intent.action != Intent.ACTION_SEND_MULTIPLE
        ) return null
        val mimeType = intent.type?.trim()?.lowercase()
        val looksTextShare = mimeType.isNullOrBlank() ||
            mimeType == "*/*" ||
            mimeType == "text/plain" ||
            mimeType.startsWith("text/")
        if (!looksTextShare) return null
        val extraText = intent.extraText()
        if (!extraText.isNullOrBlank()) return extraText
        val hasSharedUri = intent.hasSharedUri()
        if (hasSharedUri && (mimeType.isNullOrBlank() || mimeType == "*/*")) return null
        return intent.clipData.textItems(this)
            .joinToString("\n")
            .takeIf { it.isNotBlank() }
    }

    private fun Intent.processText(): String? = extraTextValue(Intent.EXTRA_PROCESS_TEXT)

    private fun Intent.extraText(): String? = extraTextValue(Intent.EXTRA_TEXT)

    @Suppress("DEPRECATION")
    private fun Intent.extraTextValue(key: String): String? {
        val rawText = extras?.get(key) ?: return null
        val textItems = when (rawText) {
            is CharSequence -> listOf(rawText.toString())
            is ArrayList<*> -> rawText.textItems()
            is Array<*> -> rawText.asIterable().textItems()
            is Iterable<*> -> rawText.textItems()
            else -> emptyList()
        }.mapNotNull { item -> item.trim().takeIf { it.isNotEmpty() } }
        return textItems.joinToString("\n").takeIf { it.isNotBlank() }
    }

    private fun Iterable<*>.textItems(): List<String> =
        mapNotNull { (it as? CharSequence)?.toString() }

    private fun android.content.ClipData?.textItems(context: Context): List<String> {
        val clip = this ?: return emptyList()
        val textItems = mutableListOf<String>()
        for (index in 0 until clip.itemCount) {
            val item = clip.getItemAt(index)
            if (item.uri != null || item.intent?.data != null) continue
            val text = item.coerceToText(context)?.toString()?.trim()
            if (!text.isNullOrEmpty()) textItems.add(text)
        }
        return textItems
    }

    private fun Intent.hasSharedUri(): Boolean {
        if (streamUris().isNotEmpty()) return true
        val clip = clipData ?: return false
        for (index in 0 until clip.itemCount) {
            val item = clip.getItemAt(index)
            if (item.uri != null || item.intent?.data != null) return true
        }
        return false
    }

    @Suppress("DEPRECATION")
    private fun Intent.streamUris(): List<Uri> {
        val rawStream = extras?.get(Intent.EXTRA_STREAM) ?: return emptyList()
        return when (rawStream) {
            is Uri -> listOf(rawStream)
            is ArrayList<*> -> rawStream.filterIsInstance<Uri>()
            is Array<*> -> rawStream.filterIsInstance<Uri>()
            is Iterable<*> -> rawStream.filterIsInstance<Uri>()
            else -> emptyList()
        }.distinct()
    }

    private fun android.content.ClipData?.uriItems(): List<Uri> {
        val clip = this ?: return emptyList()
        val uris = mutableListOf<Uri>()
        for (index in 0 until clip.itemCount) {
            val uri = clip.getItemAt(index).uri ?: clip.getItemAt(index).intent?.data
            if (uri != null) uris.add(uri)
        }
        return uris
    }

    private fun usableImageUris(uris: List<Uri>, trustDeclaredImage: Boolean): List<Uri> {
        val distinctUris = uris.distinct()
        if (distinctUris.isEmpty()) return emptyList()
        val imageUris = distinctUris.filter { isImageUri(it) }
        val fallbackUris = if (trustDeclaredImage) {
            distinctUris
        } else {
            distinctUris.filter { isUntypedFileUri(it) }
        }
        return imageUris + fallbackUris.filterNot { imageUris.contains(it) }
    }

    private fun isUntypedFileUri(uri: Uri): Boolean {
        val scheme = uri.scheme?.lowercase()
        if (scheme != ContentResolver.SCHEME_CONTENT && scheme != ContentResolver.SCHEME_FILE) {
            return false
        }
        val resolverType = runCatching { contentResolver.getType(uri) }.getOrNull()
        return resolverType.isNullOrBlank() || resolverType == "application/octet-stream"
    }

    private fun showReplyOverlay(arguments: Any?, result: MethodChannel.Result) {
        val map = arguments as? Map<*, *>
        val title = map?.get("title")?.toString() ?: "点击回复即可复制"
        val loading = map?.get("loading") as? Boolean ?: false
        val message = map?.get("message")?.toString()?.trim()?.takeIf { it.isNotEmpty() }
        val replies = (map?.get("replies") as? List<*>)
            ?.mapNotNull { it?.toString()?.trim() }
            ?.filter { it.isNotEmpty() }
            ?: emptyList()
        val returnPackage = map?.get("returnPackage")?.toString()?.trim()?.takeIf { it.isNotEmpty() }
        startFloatingServiceSafely(
            Intent(this, FloatingCaptureService::class.java).apply {
                action = FloatingCaptureService.ACTION_SHOW_REPLIES
                putExtra(FloatingCaptureService.EXTRA_TITLE, title)
                putExtra(FloatingCaptureService.EXTRA_LOADING, loading)
                putExtra(FloatingCaptureService.EXTRA_MESSAGE, message)
                putExtra(FloatingCaptureService.EXTRA_RETURN_PACKAGE, returnPackage)
                putStringArrayListExtra(
                    FloatingCaptureService.EXTRA_REPLIES,
                    ArrayList(replies)
                )
            },
            result,
            "floating_reply_failed",
            "无法显示快捷回复面板。"
        )
    }

    private fun startFloatingService(intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun startFloatingServiceSafely(
        intent: Intent,
        result: MethodChannel.Result,
        code: String,
        fallbackMessage: String
    ) {
        try {
            startFloatingService(intent)
            result.success(null)
        } catch (error: Throwable) {
            val message = error.message ?: fallbackMessage
            result.error(code, message, null)
            FloatingEvents.error(message)
        }
    }

    private fun stopFloatingServiceSafely(result: MethodChannel.Result) {
        try {
            stopService(Intent(this, FloatingCaptureService::class.java))
            result.success(null)
        } catch (error: Throwable) {
            val message = error.message ?: "无法关闭悬浮窗服务。"
            result.error("floating_stop_failed", message, null)
            FloatingEvents.error(message)
        }
    }

    private fun collapseQuickPanelSafely(result: MethodChannel.Result) {
        try {
            moveTaskToBack(true)
            result.success(null)
        } catch (error: Throwable) {
            val message = error.message ?: "无法回到聊天 App。"
            result.error("quick_panel_collapse_failed", message, null)
            FloatingEvents.error(message)
        }
    }

    private fun startActivitySafely(
        intent: Intent,
        result: MethodChannel.Result,
        code: String,
        fallbackMessage: String
    ) {
        try {
            startActivity(Intent(intent).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            result.success(null)
        } catch (error: Throwable) {
            val message = error.message ?: fallbackMessage
            result.error(code, message, null)
            FloatingEvents.error(message)
        }
    }

    private fun readClipboardImage(result: MethodChannel.Result) {
        try {
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val clip = clipboard.primaryClip
            if (clip == null || clip.itemCount == 0) {
                result.error("clipboard_empty", "剪贴板里没有图片。", null)
                return
            }
            val clipLooksImage = clipHasImageMime(clip)
            var lastImageError: Throwable? = null
            for (index in 0 until clip.itemCount) {
                val item = clip.getItemAt(index)
                val uri = item.uri ?: item.intent?.data
                if (uri != null && (clipLooksImage || isImageUri(uri) || isUntypedFileUri(uri))) {
                    try {
                        val path = copyClipboardUri(uri)
                        result.success(path)
                        return
                    } catch (error: Throwable) {
                        lastImageError = error
                    }
                }
            }
            if (lastImageError != null) {
                result.error("clipboard_failed", lastImageError.message ?: "读取剪贴板截图失败。", null)
                return
            }
            result.error("clipboard_no_image", "剪贴板里没有可读取的截图。", null)
        } catch (error: Throwable) {
            result.error("clipboard_failed", error.message ?: "读取剪贴板截图失败。", null)
        }
    }

    private fun clipHasImageMime(clip: android.content.ClipData): Boolean {
        val description = clip.description ?: return false
        for (index in 0 until description.mimeTypeCount) {
            if (isImageMime(description.getMimeType(index))) return true
        }
        return false
    }

    private fun copyClipboardUri(uri: Uri): String {
        val file = File.createTempFile("clipboard-image-", ".img", cacheDir)
        try {
            contentResolver.openInputStream(uri).use { input ->
                if (input == null) throw IllegalStateException("无法打开剪贴板图片。")
                FileOutputStream(file).use { output ->
                    input.copyTo(output)
                }
            }
            ensureCopiedImageFile(file)
        } catch (error: Throwable) {
            runCatching { if (file.exists()) file.delete() }
            throw error
        }
        return file.absolutePath
    }

    private fun ensureCopiedImageFile(file: File) {
        val options = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        BitmapFactory.decodeFile(file.absolutePath, options)
        if (options.outWidth <= 0 || options.outHeight <= 0) {
            throw IllegalStateException("剪贴板或分享内容不是可读取的图片。")
        }
    }

    private fun requestProjection(result: MethodChannel.Result) {
        if (pendingProjectionResult != null) {
            result.error("capture_busy", "已有截屏请求正在处理中，请稍后再试。", null)
            return
        }
        pendingProjectionResult = result
        try {
            val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                manager.createScreenCaptureIntent(MediaProjectionConfig.createConfigForDefaultDisplay())
            } else {
                manager.createScreenCaptureIntent()
            }
            startActivityForResult(intent, projectionRequestCode)
        } catch (error: Throwable) {
            pendingProjectionResult?.error(
                "capture_launch_failed",
                error.message ?: "无法打开系统截屏授权。",
                null
            )
            pendingProjectionResult = null
            FloatingEvents.error(error.message ?: "无法打开系统截屏授权。")
        }
    }

    @Deprecated("FlutterActivity still uses this callback for activity result interop.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != projectionRequestCode) return
        if (resultCode != Activity.RESULT_OK || data == null) {
            pendingProjectionResult?.error("cancelled", "用户取消了截屏授权。", null)
            pendingProjectionResult = null
            FloatingEvents.error("用户取消了截屏授权。")
            return
        }
        captureProjection(resultCode, data)
    }

    private fun captureProjection(resultCode: Int, data: Intent) {
        val metrics = resources.displayMetrics
        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val density = metrics.densityDpi
        var reader: ImageReader? = null
        var display: VirtualDisplay? = null
        var projectionCallback: MediaProjection.Callback? = null
        val projection = try {
            ProjectionForegroundService.start(this)
            val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            manager.getMediaProjection(resultCode, data)
        } catch (error: Throwable) {
            ProjectionForegroundService.stop(this)
            failProjection(error.message ?: "无法启动系统截屏授权，请重试。")
            return
        }
        if (projection == null) {
            ProjectionForegroundService.stop(this)
            failProjection("无法启动系统截屏授权，请重试。")
            return
        }
        try {
            projectionCallback = object : MediaProjection.Callback() {}
            projection.registerCallback(projectionCallback, Handler(Looper.getMainLooper()))
            reader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
            display = projection.createVirtualDisplay(
                "AIReplyCapture",
                width,
                height,
                density,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                reader.surface,
                null,
                null
            )
        } catch (error: Throwable) {
            display?.release()
            reader?.close()
            projectionCallback?.let { runCatching { projection.unregisterCallback(it) } }
            projection.stop()
            ProjectionForegroundService.stop(this)
            failProjection(error.message ?: "截屏初始化失败，请重试。")
            return
        }
        val captureReader = reader
        Handler(Looper.getMainLooper()).postDelayed({
            try {
                if (pendingProjectionResult == null) return@postDelayed
                val image = captureReader.acquireLatestImage()
                if (image == null) {
                    failProjection("没有截取到屏幕，请重试。")
                    return@postDelayed
                }
                var bitmap: Bitmap? = null
                var cropped: Bitmap? = null
                try {
                    val plane = image.planes[0]
                    val buffer = plane.buffer
                    val pixelStride = plane.pixelStride
                    val rowStride = plane.rowStride
                    val rowPadding = rowStride - pixelStride * width
                    bitmap = Bitmap.createBitmap(width + rowPadding / pixelStride, height, Bitmap.Config.ARGB_8888)
                    bitmap.copyPixelsFromBuffer(buffer)
                    cropped = Bitmap.createBitmap(bitmap, 0, 0, width, height)
                    val path = saveBitmap(cropped)
                    pendingProjectionResult?.success(path)
                    pendingProjectionResult = null
                    bringAppToFront()
                } finally {
                    image.close()
                    bitmap?.recycle()
                    cropped?.recycle()
                }
            } catch (error: Throwable) {
                failProjection(error.message ?: "截屏失败，请重试。")
            } finally {
                display?.release()
                captureReader.close()
                projectionCallback?.let { runCatching { projection.unregisterCallback(it) } }
                projection.stop()
                ProjectionForegroundService.stop(this)
            }
        }, 450)
    }

    private fun bringAppToFront() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
        }
        runCatching {
            startActivity(intent)
        }.onFailure { error ->
            FloatingEvents.error(error.message ?: "无法回到 AI Reply。")
        }
    }

    private fun failProjection(message: String) {
        pendingProjectionResult?.error("capture_failed", message, null)
        pendingProjectionResult = null
        FloatingEvents.error(message)
    }

    private fun takeAccessibilityScreenshot(result: MethodChannel.Result?) {
        ScreenshotAccessibilityService.capture(this) { path, error ->
            if (path != null) {
                result?.success(path)
                bringAppToFront()
            } else {
                result?.error("accessibility_failed", error ?: "无障碍截图失败。", null)
                FloatingEvents.error(error ?: "无障碍截图失败。")
            }
        }
    }

    private fun saveBitmap(bitmap: Bitmap): String {
        val file = File.createTempFile("floating-capture-", ".jpg", cacheDir)
        try {
            FileOutputStream(file).use { out ->
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)) {
                    throw IllegalStateException("无法保存截屏图片。")
                }
            }
        } catch (error: Throwable) {
            runCatching { if (file.exists()) file.delete() }
            throw error
        }
        return file.absolutePath
    }
}

object FloatingEvents {
    private const val maxPendingEvents = 20
    var sink: EventChannel.EventSink? = null
    private val pending = mutableListOf<Map<String, String>>()

    fun screenshot(path: String, source: String? = null) {
        val cleanPath = cleanEventField(path) ?: return
        val event = mutableMapOf("path" to cleanPath)
        cleanEventField(source)?.let { event["source"] = it }
        emit(event)
    }

    fun error(message: String) {
        val cleanMessage = cleanEventField(message) ?: return
        emit(mapOf("error" to cleanMessage))
    }

    fun route(route: String) {
        val cleanRoute = cleanEventField(route) ?: return
        emit(mapOf("route" to cleanRoute))
    }

    fun text(text: String, source: String? = null) {
        val cleanText = cleanEventField(text) ?: return
        val event = mutableMapOf("text" to cleanText)
        cleanEventField(source)?.let { event["source"] = it }
        emit(event)
    }

    fun copiedReply(text: String) {
        val cleanText = cleanEventField(text) ?: return
        emit(mapOf("copiedReply" to cleanText))
    }

    fun hasActiveSink(): Boolean = sink != null

    fun flushPending() {
        Handler(Looper.getMainLooper()).post {
            val currentSink = sink ?: return@post
            val events = pending.toList()
            pending.clear()
            events.forEach { currentSink.success(it) }
        }
    }

    private fun emit(event: Map<String, String>) {
        Handler(Looper.getMainLooper()).post {
            val currentSink = sink
            if (currentSink == null) {
                if (pending.size >= maxPendingEvents) pending.removeAt(0)
                pending.add(event)
            } else {
                currentSink.success(event)
            }
        }
    }

    private fun cleanEventField(value: String?): String? =
        value?.trim()?.takeIf { it.isNotEmpty() }
}
