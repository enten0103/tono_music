package com.example.tono_music


import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.Toast
import android.os.Handler
import android.os.Looper
import androidx.appcompat.widget.AppCompatTextView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import kotlin.math.roundToInt
import androidx.core.net.toUri

/**
 * Android floating lyrics overlay implementation mirroring the Windows MethodChannel:
 * "com.enten0103.tono_music/window"
 */
object LyricsOverlayModule : MethodChannel.MethodCallHandler {
    private const val CHANNEL = "com.enten0103.tono_music/window"

    private var appContextRef: WeakReference<Context>? = null
    private var activityRef: WeakReference<Activity>? = null
    private var channel: MethodChannel? = null

    // Window and view state
    private var wm: WindowManager? = null
    private var params: WindowManager.LayoutParams? = null
    // Use weak references to avoid static View leaks
    private var containerRef: WeakReference<FrameLayout>? = null
    private var tvRef: WeakReference<StrokeTextView>? = null
    private var didToastOnce: Boolean = false

    // Style state
    private var text: String = ""
    private var fontFamily: String = "sans-serif"
    private var fontSizeSp: Int = 14
    private var fontWeight: Int = 400 // 100..900
    private var textColorRgb: Int = 0xFFFFFF
    private var textOpacity: Int = 255 // 0..255
    private var lines: Int = 1
    private var widthDp: Int = 600
    private var strokeWidthDp: Int = 0
    private var strokeColorRgb: Int = 0x000000
    private var align: String = "left" // left|center|right
    private var clickThrough: Boolean = false
    // Permission polling state
    @Volatile private var permPolling: Boolean = false
    private var permPollHandler: Handler? = null

    fun register(engine: FlutterEngine, activity: Activity) {
        appContextRef = WeakReference(activity.applicationContext)
        activityRef = WeakReference(activity)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler(this)
    }

    private fun ctx(): Context? = appContextRef?.get()
    private fun act(): Activity? = activityRef?.get()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "createLyricsWindow" -> {
                result.success(createOrUpdateOverlay())
            }
            "showLyricsWindow" -> {
                if (containerRef?.get() == null) createOrUpdateOverlay()
                showOverlay()
                result.success(true)
            }
            "hideLyricsWindow" -> {
                hideOverlay()
                result.success(true)
            }
            "destroyLyricsWindow" -> {
                destroyOverlay()
                result.success(true)
            }
            "setLyricsText" -> {
                text = (call.argument<String>("text") ?: "")
                tvRef?.get()?.text = text
                result.success(true)
            }
            "setLyricsFontFamily" -> {
                fontFamily = call.arguments as? String ?: fontFamily
                applyTypeface()
                result.success(true)
            }
            "setLyricsFontSize" -> {
                val v = argInt(call, "fontSize")
                if (v != null) {
                    fontSizeSp = v.coerceAtLeast(8)
                    tvRef?.get()?.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, fontSizeSp.toFloat())
                    requestRelayout()
                    result.success(true); return
                }
                result.error("bad_args", "Expected fontSize", null)
            }
            "setLyricsFontWeight" -> {
                val w = parseWeight(call)
                if (w != null) {
                    fontWeight = w
                    applyTypeface()
                    result.success(true); return
                }
                result.error("bad_args", "Expected weight", null)
            }
            "setLyricsTextColor" -> {
                val rgb = parseRgb(call, "textColor")
                if (rgb != null) {
                    textColorRgb = rgb and 0xFFFFFF
                    applyTextColor()
                    result.success(true); return
                }
                result.error("bad_args", "Expected textColor", null)
            }
            "setLyricsTextOpacity" -> {
                val a = argInt(call, "alpha")
                if (a != null) {
                    textOpacity = a.coerceIn(0, 255)
                    applyTextColor()
                    result.success(true); return
                }
                result.error("bad_args", "Expected alpha", null)
            }
            "setLyricsStroke" -> {
                val w = argInt(call, "width")
                val c = parseRgb(call, "color")
                if (w != null && c != null) {
                    strokeWidthDp = w.coerceIn(0, 20)
                    strokeColorRgb = c and 0xFFFFFF
                    applyStroke()
                    result.success(true); return
                }
                result.error("bad_args", "Expected {width,color}", null)
            }
            "setLyricsTextAlign" -> {
                val a = (call.argument<String>("align") ?: "").lowercase()
                if (a in listOf("left","center","right")) {
                    align = a
                    applyAlign()
                    result.success(true); return
                }
                result.error("bad_args", "Expected align", null)
            }
            "setOverlayWidth" -> {
                val w = argInt(call, "width")
                if (w != null) {
                    widthDp = w.coerceAtLeast(200)
                    requestRelayout()
                    result.success(true); return
                }
                result.error("bad_args", "Expected width", null)
            }
            "setOverlayLines" -> {
                val l = argInt(call, "lines")
                if (l != null) {
                    lines = l.coerceIn(1, 10)
                    tvRef?.get()?.isSingleLine = (lines <= 1)
                    tvRef?.get()?.maxLines = lines
                    tvRef?.get()?.ellipsize = android.text.TextUtils.TruncateAt.END
                    requestRelayout()
                    result.success(true); return
                }
                result.error("bad_args", "Expected lines", null)
            }
            "setOverlayClickThrough" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                setClickThrough(enabled)
                result.success(enabled)
            }
            // Windows-specific APIs that are no-op on Android
            "setOverlayOpacity", "setLyricsPosition" -> {
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun createOrUpdateOverlay(): Boolean {
        val context = ctx() ?: return false
        if (!ensurePermission()) return false
        if (wm == null) wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        containerRef?.get()?.let { return true }

        val container = DragFrameLayout(context).apply {
            setBackgroundColor(Color.TRANSPARENT)
        }
        val tv = StrokeTextView(context).apply {
            text = this@LyricsOverlayModule.text
            setPadding(dp(8), dp(4), dp(8), dp(4))
            isClickable = false
            isFocusable = false
            // Ensure multiline wrapping is enabled when lines > 1
            isSingleLine = false
            setHorizontallyScrolling(false)
        }
        container.addView(tv, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT))
        containerRef = WeakReference(container)
        tvRef = WeakReference(tv)

        params = WindowManager.LayoutParams().apply {
            width = dp(widthDp)
            height = WindowManager.LayoutParams.WRAP_CONTENT
            gravity = Gravity.TOP or Gravity.START
            x = 100; y = 100
            format = PixelFormat.TRANSLUCENT
            flags = (WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                    or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                    or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
        }

        applyTypeface()
    tvRef?.get()?.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, fontSizeSp.toFloat())
    tvRef?.get()?.isSingleLine = (lines <= 1)
    tvRef?.get()?.maxLines = lines
    tvRef?.get()?.ellipsize = android.text.TextUtils.TruncateAt.END
        applyTextColor()
        applyStroke()
        applyAlign()

        try {
            wm?.addView(container, params)
        } catch (e: Exception) {
            // 例如 BadTokenException：权限或窗口类型异常
            try { Toast.makeText(context, "添加悬浮窗失败: ${e.message}", Toast.LENGTH_LONG).show() } catch (_: Exception) {}
            destroyOverlay()
            return false
        }
        // 初次创建后根据锁定状态设置背景
        applyOverlayBackground()
        // 一次性提示：帮助用户确认已成功创建悬浮窗
        if (!didToastOnce) {
            try { Toast.makeText(context, "歌词浮窗已开启", Toast.LENGTH_SHORT).show() } catch (_: Exception) {}
            didToastOnce = true
        }
        setClickThrough(clickThrough)
        enableDragIfNeeded()
        return true
    }

    private fun showOverlay() {
        if (containerRef?.get() == null) {
            if (!createOrUpdateOverlay()) return
        } else {
            containerRef?.get()?.visibility = View.VISIBLE
            if (!didToastOnce) {
                val c = ctx()
                try { Toast.makeText(c, "歌词浮窗已显示", Toast.LENGTH_SHORT).show() } catch (_: Exception) {}
                didToastOnce = true
            }
        }
    }

    private fun hideOverlay() {
        containerRef?.get()?.visibility = View.GONE
    }

    private fun destroyOverlay() {
        try {
            val w = wm; val v = containerRef?.get()
            if (w != null && v != null) w.removeViewImmediate(v)
        } catch (_: Exception) {}
        containerRef = null
        tvRef = null
        params = null
        didToastOnce = false
    }

    private fun setClickThrough(enable: Boolean) {
        clickThrough = enable
        val p = params ?: return
        var f = p.flags
        f = if (enable) {
            (f or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE)
        } else {
            (f and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv())
        }
        p.flags = f
        params = p
        containerRef?.get()?.let { wm?.updateViewLayout(it, p) }
        applyOverlayBackground()
        enableDragIfNeeded()
    }

    // Background: unlocked -> semi-transparent black; locked -> fully transparent
    private fun applyOverlayBackground() {
        val v = containerRef?.get() ?: return
        if (clickThrough) {
            v.background = null
            v.setBackgroundColor(Color.TRANSPARENT)
            return
        }
        val bg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(8).toFloat()
            setColor(Color.argb(32, 0, 0, 0))
        }
        v.background = bg
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun enableDragIfNeeded() {
        val view = containerRef?.get() ?: return
        if (clickThrough) {
            view.setOnTouchListener(null)
            return
        }
        var lastX = 0f; var lastY = 0f
        var startX = 0f; var startY = 0f
        var moved = false
        val touchSlop = ViewConfiguration.get(view.context).scaledTouchSlop
        view.setOnTouchListener { _, ev ->
            val p = params ?: return@setOnTouchListener false
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    lastX = ev.rawX; lastY = ev.rawY
                    startX = ev.rawX; startY = ev.rawY
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dxFloat = ev.rawX - lastX; val dyFloat = ev.rawY - lastY
                    val totalDx = ev.rawX - startX; val totalDy = ev.rawY - startY
                    if (!moved) {
                        if (kotlin.math.abs(totalDx) >= touchSlop || kotlin.math.abs(totalDy) >= touchSlop) moved = true
                    }
                    val dx = dxFloat.roundToInt(); val dy = dyFloat.roundToInt()
                    lastX = ev.rawX; lastY = ev.rawY
                    if (moved) {
                        p.x += dx; p.y += dy
                        containerRef?.get()?.let { wm?.updateViewLayout(it, p) }
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    // If it was a click (no move beyond slop), perform click for accessibility
                    if (!moved) {
                        view.performClick()
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    moved = false
                    true
                }
                else -> false
            }
        }
    }

    private fun requestRelayout() {
        val p = params ?: return
        p.width = dp(widthDp)
        containerRef?.get()?.let { wm?.updateViewLayout(it, p) }
    }

    private fun applyTypeface() {
        val t = try { Typeface.create(fontFamily, Typeface.NORMAL) } catch (_: Exception) { Typeface.SANS_SERIF }
        val tf = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            Typeface.create(t, fontWeight.coerceIn(100, 900), false)
        } else {
            // Approximate: use bold for >=700
            Typeface.create(t, if (fontWeight >= 700) Typeface.BOLD else Typeface.NORMAL)
        }
        tvRef?.get()?.typeface = tf
    }

    private fun applyTextColor() {
        val a = textOpacity.coerceIn(0, 255)
        val r = (textColorRgb shr 16) and 0xFF
        val g = (textColorRgb shr 8) and 0xFF
        val b = textColorRgb and 0xFF
        val argb = Color.argb(a, r, g, b)
        tvRef?.get()?.setTextColor(argb)
    }

    private fun applyStroke() {
        tvRef?.get()?.setStroke(strokeWidthDp, strokeColorRgb)
    }

    private fun applyAlign() {
        val horizontal = when (align) {
            "center" -> Gravity.CENTER_HORIZONTAL
            "right" -> Gravity.END
            else -> Gravity.START
        }
        val vertical = if (lines <= 1) Gravity.CENTER_VERTICAL else Gravity.TOP
        tvRef?.get()?.gravity = horizontal or vertical
    }

    private fun dp(dp: Int): Int {
        val c = ctx() ?: return dp
        val density = c.resources.displayMetrics.density
        return (dp * density + 0.5f).toInt()
    }

    private fun ensurePermission(): Boolean {
        val c = ctx() ?: return false
        return if (Settings.canDrawOverlays(c)) true else {
                // Try several routes to grant overlay permission; caller can retry create later.
                val a = act()
                if (a != null) {
                    // 1) App-specific overlay settings
                    val intents = arrayListOf(
                        Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, ("package:" + c.packageName).toUri()).addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK
                        ),
                        // 2) Generic overlay settings list (user selects app)
                        Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        // 3) App details page（从应用信息进入“悬浮窗/其他权限”）
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            ("package:" + c.packageName).toUri()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    var started = false
                    for (intent in intents) {
                        try {
                            a.startActivity(intent)
                            started = true
                            break
                        } catch (_: Exception) { }
                    }
                    // 4) MIUI 兼容路径（可能变更，尽力尝试）
                    if (!started) {
                        val miuiIntents = arrayListOf(
                            Intent("miui.intent.action.APP_PERM_EDITOR").setClassName(
                                "com.miui.securitycenter",
                                "com.miui.permcenter.permissions.PermissionsEditorActivity"
                            ).putExtra("extra_pkgname", c.packageName).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                            Intent("miui.intent.action.APP_PERM_EDITOR").setClassName(
                                "com.miui.securitycenter",
                                "com.miui.permcenter.permissions.AppPermissionsEditorActivity"
                            ).putExtra("extra_pkgname", c.packageName).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        for (i in miuiIntents) {
                            try { a.startActivity(i); started = true; break } catch (_: Exception) {}
                        }
                    }
                    if (started) startOverlayPermissionPoll()
                }
                false
            }

    }

    private fun startOverlayPermissionPoll() {
        if (permPolling) return
        val c = ctx() ?: return
        permPolling = true
        val handler = permPollHandler ?: Handler(Looper.getMainLooper()).also { permPollHandler = it }
        var attempts = 0
        val task = object : Runnable {
            override fun run() {
                val context = ctx()
                if (context == null) {
                    permPolling = false
                    return
                }
                val granted = Settings.canDrawOverlays(context)
                if (granted) {
                    permPolling = false
                    try {
                        createOrUpdateOverlay()
                        showOverlay()
                        try { Toast.makeText(context, "已授权悬浮窗，已自动开启", Toast.LENGTH_SHORT).show() } catch (_: Exception) {}
                    } catch (_: Exception) {}
                    return
                }
                attempts++
                if (attempts < 12) {
                    handler.postDelayed(this, 1000)
                } else {
                    permPolling = false
                }
            }
        }
        handler.postDelayed(task, 1000)
    }

    private fun argInt(call: MethodCall, key: String): Int? {
        val any = call.argument<Any?>(key) ?: return null
        return when (any) {
            is Int -> any
            is Long -> any.toInt()
            is Double -> any.roundToInt()
            is String -> any.toIntOrNull()
            else -> null
        }
    }

    private fun parseRgb(call: MethodCall, key: String): Int? {
        val any = call.argument<Any?>(key) ?: return null
        return when (any) {
            is Int -> any and 0xFFFFFF
            is Long -> (any.toInt() and 0xFFFFFF)
            is Double -> any.toInt() and 0xFFFFFF
            is String -> {
                var s = any.trim()
                if (s.startsWith("#")) s = s.substring(1)
                if (s.startsWith("0x", true)) s = s.substring(2)
                s.toIntOrNull(16)
            }
            else -> null
        }
    }

    private fun parseWeight(call: MethodCall): Int? {
        val any = call.argument<Any?>("weight") ?: return null
        var w: Int? = when (any) {
            is Int -> any
            is Long -> any.toInt()
            is Double -> any.roundToInt()
            is String -> any.toIntOrNull()
            else -> null
        }
        if (w == null) {
            val name = (any as? String)?.lowercase() ?: return null
            w = when (name) {
                "thin","hairline","极细","超细" -> 100
                "extralight","ultralight","纤细" -> 200
                "light","细" -> 300
                "regular","normal","常规","正常" -> 400
                "medium","中","中等" -> 500
                "semibold","demibold","半粗","中粗" -> 600
                "bold","粗","加粗" -> 700
                "extrabold","ultrabold","特粗","超粗" -> 800
                "black","heavy","黑","重","黑体" -> 900
                else -> null
            }
        }
        if (w != null) {
            w = w.coerceIn(100, 900)
        }
        return w
    }
}

private class StrokeTextView(context: Context) : AppCompatTextView(context) {
    private var strokeWidthPx: Float = 0f
    private var strokeColor: Int = Color.BLACK

    fun setStroke(widthDp: Int, colorRgb: Int) {
        val density = resources.displayMetrics.density
        strokeWidthPx = (widthDp * density).coerceAtLeast(0f)
        val r = (colorRgb shr 16) and 0xFF
        val g = (colorRgb shr 8) and 0xFF
        val b = colorRgb and 0xFF
        strokeColor = Color.rgb(r, g, b)
        invalidate()
    }

    override fun onDraw(canvas: android.graphics.Canvas) {
        if (strokeWidthPx > 0f) {
            val tp = paint
            val oldColor = currentTextColor
            val oldStyle = tp.style
            val oldWidth = tp.strokeWidth
            val oldJoin = tp.strokeJoin
            val oldMiter = tp.strokeMiter

            tp.style = Paint.Style.STROKE
            tp.strokeWidth = strokeWidthPx
            tp.strokeJoin = Paint.Join.ROUND
            tp.strokeMiter = 10f
            setTextColor(strokeColor)
            super.onDraw(canvas)

            tp.style = oldStyle
            tp.strokeWidth = oldWidth
            tp.strokeJoin = oldJoin
            tp.strokeMiter = oldMiter
            setTextColor(oldColor)
        }
        super.onDraw(canvas)
    }
}

// Container with a proper performClick implementation for accessibility
private class DragFrameLayout(context: Context) : FrameLayout(context) {
    override fun performClick(): Boolean {
        super.performClick()
        return true
    }
}
