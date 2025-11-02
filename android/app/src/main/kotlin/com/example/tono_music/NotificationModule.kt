package com.example.tono_music

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import android.os.SystemClock
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import androidx.core.net.toUri
import androidx.core.graphics.toColorInt
import androidx.core.graphics.createBitmap

object NotificationModule : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private const val METHOD_CHANNEL = "tono_music/notification"
    private const val EVENT_CHANNEL = "tono_music/notification_events"
    private const val CHANNEL_ID = "music_channel_native"
    private const val CHANNEL_NAME = "音乐播放器通知(原生)"
    private const val NOTIFICATION_ID = 1

    // Hold a weak reference to Application Context to avoid static leaks.
    private var appContextRef: WeakReference<Context>? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    @Volatile private var eventSink: EventChannel.EventSink? = null

    // Avoid general bitmap caching per request; keep only last used cover to mitigate flicker
    @Volatile private var lastCoverUrl: String? = null // last requested URL
    @Volatile private var lastCoverBitmap: Bitmap? = null
    @Volatile private var lastCoverBitmapUrl: String? = null // URL that current cached bitmap corresponds to
    @Volatile private var lastNotifyUptimeMs: Long = 0L

    fun register(flutterEngine: FlutterEngine, ctx: Context) {
        appContextRef = WeakReference(ctx.applicationContext)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel?.setMethodCallHandler(this)
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        eventChannel?.setStreamHandler(this)
        ensureChannel()
    }

    private fun contextOrNull(): Context? = appContextRef?.get()

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> {
                ensureChannel()
                result.success(true)
            }
            "isAllowed" -> {
                val ctx = contextOrNull() ?: return result.error("no_context", "Context is null", null)
                // Consider both channel toggle and runtime POST_NOTIFICATIONS on Android 13+
                val allowed = hasNotificationPermission(ctx)
                result.success(allowed)
            }
            "requestPermission" -> {
                val ctx = contextOrNull() ?: return result.error("no_context", "Context is null", null)
                try {
                    val intent = Intent().apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            action = android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS
                            putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, ctx.packageName)
                        } else {
                            action = android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                            data = ("package:" + ctx.packageName).toUri()
                        }
                    }
                    ctx.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("permission_request_failed", e.message, null)
                }
            }
            "update" -> {
                val title = call.argument<String>("title") ?: ""
                val text = call.argument<String>("text") ?: ""
                val playing = call.argument<Boolean>("playing") ?: false
                val cover = call.argument<String>("cover") ?: ""
                showOrUpdate(title, text, playing, cover)
                result.success(true)
            }
            "dismiss" -> {
                dismiss()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ctx = contextOrNull() ?: return
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                val ch = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH)
                ch.description = "用于音乐播放控制的通知栏(原生)"
                ch.enableLights(false)
                ch.enableVibration(false)
                ch.setSound(null, null)
                nm.createNotificationChannel(ch)
            }
        }
    }

    private fun pendingAction(action: String): PendingIntent {
        val ctx = contextOrNull() ?: throw IllegalStateException("Context null")
        val intent = Intent(ctx, NotificationActionReceiver::class.java).apply {
            this.action = action
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or (PendingIntent.FLAG_IMMUTABLE)
        return PendingIntent.getBroadcast(ctx, action.hashCode(), intent, flags)
    }

    private fun buildNotification(title: String, text: String, playing: Boolean, coverBitmap: Bitmap? = null): Notification {
        val ctx = contextOrNull() ?: throw IllegalStateException("Context null")
    val (titleColor, textColor) = resolveNotificationTextColors(ctx)
        val launchPi = launchAppPendingIntent()
        val builder = NotificationCompat.Builder(ctx, CHANNEL_ID)
            // Keep status bar small icon in sync with play state
            .setSmallIcon(if (playing) R.drawable.pause_24px else R.drawable.play_arrow_24px)
            .setColor("#2196F3".toColorInt())
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            // Tapping notification opens the app
            .setContentIntent(launchPi)

        // Collapsed custom view (no outlined buttons)
        val collapsed = RemoteViews(ctx.packageName, R.layout.notification_media_collapsed).apply {
            setTextViewText(R.id.tvTitle, title)
            setTextViewText(R.id.tvText, text)
            // adapt text colors for light/dark
            setTextColor(R.id.tvTitle, titleColor)
            setTextColor(R.id.tvText, textColor)
            // Force container & text paddings each update (some ROMs drop XML paddings on reapply)
            val p4 = dp(ctx, 4)
            val p6 = dp(ctx, 6)
            val p1 = dp(ctx, 1)
            setViewPadding(R.id.textContainer, p4, 0, p6, 0)
            setViewPadding(R.id.tvTitle, 0, p1, 0, p1)
            setViewPadding(R.id.tvText, 0, p1, 0, p1)
            setImageViewResource(
                R.id.btnPlayPause,
                if (playing) R.drawable.pause_24px else R.drawable.play_arrow_24px
            )
            // tint action icons to match theme
            setInt(R.id.btnPrev, "setColorFilter", titleColor)
            setInt(R.id.btnPlayPause, "setColorFilter", titleColor)
            setInt(R.id.btnNext, "setColorFilter", titleColor)
            setOnClickPendingIntent(R.id.btnPrev, pendingAction("prev"))
            setOnClickPendingIntent(R.id.btnPlayPause, pendingAction(if (playing) "pause" else "play"))
            setOnClickPendingIntent(R.id.btnNext, pendingAction("next"))
            // Tap on text area opens app
            setOnClickPendingIntent(R.id.textContainer, launchPi)
            setOnClickPendingIntent(R.id.tvTitle, launchPi)
            setOnClickPendingIntent(R.id.tvText, launchPi)
        }

        // Expanded custom view (same controls, more space)
        val expanded = RemoteViews(ctx.packageName, R.layout.notification_media_expanded).apply {
            setTextViewText(R.id.tvTitle, title)
            setTextViewText(R.id.tvText, text)
            // adapt text colors for light/dark
            setTextColor(R.id.tvTitle, titleColor)
            setTextColor(R.id.tvText, textColor)
            setImageViewResource(
                R.id.btnPlayPause,
                if (playing) R.drawable.pause_24px else R.drawable.play_arrow_24px
            )
            // tint action icons to match theme
            setInt(R.id.btnPrev, "setColorFilter", titleColor)
            setInt(R.id.btnPlayPause, "setColorFilter", titleColor)
            setInt(R.id.btnNext, "setColorFilter", titleColor)
            setInt(R.id.btnToggleOverlay, "setColorFilter", titleColor)
            setOnClickPendingIntent(R.id.btnPrev, pendingAction("prev"))
            setOnClickPendingIntent(R.id.btnPlayPause, pendingAction(if (playing) "pause" else "play"))
            setOnClickPendingIntent(R.id.btnNext, pendingAction("next"))
            setOnClickPendingIntent(R.id.btnToggleOverlay, pendingAction("toggle_overlay"))
            // Set cover: show provided bitmap, else placeholder
            if (coverBitmap != null) {
                setImageViewBitmap(R.id.ivCover, coverBitmap)
            } else {
                setImageViewResource(R.id.ivCover, R.mipmap.ic_launcher)
            }
            // Tap on text area opens app
            setOnClickPendingIntent(R.id.textContainer, launchPi)
            setOnClickPendingIntent(R.id.tvTitle, launchPi)
            setOnClickPendingIntent(R.id.tvText, launchPi)
        }

        builder.setCustomContentView(collapsed)
        builder.setCustomBigContentView(expanded)
        builder.setStyle(NotificationCompat.DecoratedCustomViewStyle())

        return builder.build()
    }

    private fun launchAppPendingIntent(): PendingIntent {
        val ctx = contextOrNull() ?: throw IllegalStateException("Context null")
        val pm = ctx.packageManager
        val launch = pm.getLaunchIntentForPackage(ctx.packageName)
            ?: Intent(ctx, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(ctx, 0, launch, flags)
    }

    private fun dp(ctx: Context, dp: Int): Int {
        val density = ctx.resources.displayMetrics.density
        return (dp * density + 0.5f).toInt()
    }

    private fun resolveNotificationTextColors(ctx: Context): Pair<Int, Int> {
        // Heuristic: follow system night mode. For light mode use Material guideline opacities for black text,
        // for dark mode use white equivalents.
        val night = (ctx.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES
        return if (night) {
            // Title: 100% white, Subtitle: 70% white
            Pair(0xFFFFFFFF.toInt(), 0xB3FFFFFF.toInt())
        } else {
            // Title: 87% black, Subtitle: 60% black
            Pair(0xDE000000.toInt(), 0x99000000.toInt())
        }
    }

    private fun showOrUpdate(title: String, text: String, playing: Boolean, coverUrl: String) {
        val ctx = contextOrNull() ?: return
        val nm = NotificationManagerCompat.from(ctx)
        // On Android 13+ POST_NOTIFICATIONS can be denied; check explicitly.
        if (!hasNotificationPermission(ctx)) return
        try {
            val now = SystemClock.uptimeMillis()
            val requestedUrl = coverUrl.trim()
            // Show previous bitmap while fetching the new one to avoid flicker
            val displayBitmap: Bitmap? = lastCoverBitmap
            nm.notify(NOTIFICATION_ID, buildNotification(title, text, playing, displayBitmap))
            lastNotifyUptimeMs = now
            // Remember the latest requested URL
            lastCoverUrl = requestedUrl
        } catch (se: SecurityException) {
            // Permission might have been revoked between check & notify.
            // Gracefully ignore to satisfy lint and avoid crashes.
        }

        // Load cover asynchronously and update (rounded corners), while keeping previous bitmap visible
        val needFetch = coverUrl.isNotBlank() && (coverUrl.trim() != (lastCoverBitmapUrl ?: ""))
        if (needFetch) {
            Thread {
                val req = coverUrl.trim()
                val bmpRaw = fetchBitmap(req)
                val radius = dp(ctx, 6).toFloat()
                val bmp = bmpRaw?.let { roundedBitmap(it, radius) }
                if (bmp != null) {
                    try {
                        // Only update if this request is still the latest
                        if (req == lastCoverUrl) {
                            lastCoverBitmap = bmp
                            lastCoverBitmapUrl = req
                            if (hasNotificationPermission(ctx)) {
                                nm.notify(NOTIFICATION_ID, buildNotification(title, text, playing, bmp))
                            }
                        }
                    } catch (_: SecurityException) {
                        // Handle explicit SecurityException as per lint guidance
                    } catch (_: Exception) { }
                }
            }.start()
        }
    }

    private fun fetchBitmap(url: String): Bitmap? {
        return try {
            val conn = java.net.URL(url).openConnection() as java.net.HttpURLConnection
            conn.connectTimeout = 4000
            conn.readTimeout = 6000
            conn.instanceFollowRedirects = true
            conn.requestMethod = "GET"
            conn.doInput = true
            conn.connect()
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else null
            stream?.use { BitmapFactory.decodeStream(it) }
        } catch (_: Exception) {
            null
        }
    }

    private fun roundedBitmap(src: Bitmap, radius: Float): Bitmap {
        val output = createBitmap(src.width, src.height)
        val canvas = Canvas(output)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val rect = RectF(0f, 0f, src.width.toFloat(), src.height.toFloat())
        canvas.drawRoundRect(rect, radius, radius, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(src, 0f, 0f, paint)
        return output
    }

    private fun dismiss() {
        val ctx = contextOrNull() ?: return
        val nm = NotificationManagerCompat.from(ctx)
        try {
            nm.cancel(NOTIFICATION_ID)
        } catch (_: SecurityException) {
        }
    }

    // Expose a safe public dismiss for app lifecycle teardown
    fun dismissPublic() {
        try { dismiss() } catch (_: Exception) {}
    }

    fun sendActionEvent(action: String) {
        eventSink?.success(action)
    }

    private fun hasNotificationPermission(ctx: Context): Boolean {
        // Fast path
        if (!NotificationManagerCompat.from(ctx).areNotificationsEnabled()) return false
        // Android 13+ runtime permission
        return if (Build.VERSION.SDK_INT >= 33) {
            ContextCompat.checkSelfPermission(
                ctx,
                android.Manifest.permission.POST_NOTIFICATIONS
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else true
    }
}
