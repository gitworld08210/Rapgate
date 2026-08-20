package com.healthpush.app.services

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.*
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.EventChannel
import com.healthpush.app.MainActivity

/**
 * Foreground service that manages the lock overlay.
 *
 * When the AccessibilityService detects a blocked app in the foreground and
 * the unlock window has expired, it starts this service with ACTION_SHOW_OVERLAY.
 * The overlay is a full-screen window that covers the blocked app and directs
 * the user to complete push-ups.
 */
class AppLockService : Service() {

    companion object {
        const val ACTION_SHOW_OVERLAY = "com.healthpush.ACTION_SHOW_OVERLAY"
        const val CHANNEL_ID = "app_lock_service"
        const val NOTIFICATION_ID = 1001

        // Shared state between AccessibilityService and this service.
        // These are also synced from Flutter via the platform channel.
        @Volatile var blockedPackages: HashSet<String> = hashSetOf()
        @Volatile var allowlistPackages: HashSet<String> = hashSetOf()
        @Volatile var isUnlocked: Boolean = false
        @Volatile var unlockUntilMs: Long = 0L

        var eventSink: EventChannel.EventSink? = null
    }

    private var overlayView: View? = null
    private var windowManager: WindowManager? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        loadStateFromPrefs()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW_OVERLAY -> {
                val blockedPackage = intent.getStringExtra("blocked_package") ?: ""
                showOverlay(blockedPackage)
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        removeOverlay()
        super.onDestroy()
    }

    // ==================== Overlay ====================

    private fun showOverlay(blockedPackage: String) {
        if (overlayView != null) return // already showing

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_SYSTEM_ALERT,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#F0111111")) // near-opaque dark
            setPadding(64, 64, 64, 64)
        }

        val lockIcon = TextView(this).apply {
            text = "🔒"
            textSize = 64f
            gravity = Gravity.CENTER
        }
        layout.addView(lockIcon)

        val title = TextView(this).apply {
            text = "App Locked"
            textSize = 28f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, 32, 0, 16)
        }
        layout.addView(title)

        val subtitle = TextView(this).apply {
            text = "Complete your push-ups to unlock this app for 24 hours."
            textSize = 15f
            setTextColor(Color.parseColor("#AAAAAA"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 48)
        }
        layout.addView(subtitle)

        val doButton = Button(this).apply {
            text = "Do Push-ups Now"
            textSize = 16f
            setTextColor(Color.BLACK)
            setBackgroundColor(Color.parseColor("#B5E048")) // lime
            setPadding(48, 24, 48, 24)
            setOnClickListener {
                removeOverlay()
                openApp()
            }
        }
        layout.addView(doButton)

        val goHomeButton = Button(this).apply {
            text = "Go to Home Screen"
            textSize = 14f
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.TRANSPARENT)
            setPadding(48, 32, 48, 24)
            setOnClickListener {
                removeOverlay()
                goHome()
            }
        }
        layout.addView(goHomeButton)

        overlayView = layout

        try {
            windowManager?.addView(layout, params)
        } catch (e: Exception) {
            overlayView = null
        }
    }

    private fun removeOverlay() {
        overlayView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
            overlayView = null
        }
    }

    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("navigate_to", "pushup_session")
        }
        startActivity(intent)
    }

    private fun goHome() {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    // ==================== Notification ====================

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Lock Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the app lock running in the background"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("HealthPush")
            .setContentText("App lock is active")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    // ==================== Prefs ====================

    private fun loadStateFromPrefs() {
        val prefs = getSharedPreferences("app_lock", Context.MODE_PRIVATE)
        blockedPackages = HashSet(prefs.getStringSet("blocked_packages", emptySet()) ?: emptySet())
        allowlistPackages = HashSet(prefs.getStringSet("allowlist_packages", emptySet()) ?: emptySet())
        isUnlocked = prefs.getBoolean("is_unlocked", false)
        unlockUntilMs = prefs.getLong("unlock_until_ms", 0L)
    }
}
