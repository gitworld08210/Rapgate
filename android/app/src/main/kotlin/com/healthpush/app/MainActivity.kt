package com.healthpush.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.app.AppOpsManager
import android.content.pm.PackageManager
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import com.healthpush.app.services.AppLockService

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.healthpush.app/applock"
    private val EVENT_CHANNEL = "com.healthpush.app/applock_events"

    /// Enumerating installed apps is slow (a PackageManager IPC per app to
    /// resolve its label). Doing it on the platform thread froze the UI and
    /// risked an ANR, so it runs here and posts the result back.
    private val backgroundExecutor: ExecutorService =
        Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    /// The launchable-app set barely changes while the app is open, so the
    /// first query is reused for subsequent opens of the picker.
    private var cachedApps: List<Map<String, String>>? = null

    override fun onDestroy() {
        backgroundExecutor.shutdown()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityServiceEnabled" -> {
                    result.success(isAccessibilityEnabled())
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "hasOverlayPermission" -> {
                    result.success(hasOverlayPermission())
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(null)
                }
                "hasUsageStatsPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "requestUsageStatsPermission" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                "isBatteryOptimizationDisabled" -> {
                    result.success(isBatteryOptimizationDisabled())
                }
                "requestDisableBatteryOptimization" -> {
                    requestDisableBatteryOptimization()
                    result.success(null)
                }
                "updateBlockedApps" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    updateBlockedApps(packages)
                    result.success(null)
                }
                "updateAllowlist" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    updateAllowlist(packages)
                    result.success(null)
                }
                "setUnlockStatus" -> {
                    val isUnlocked = call.argument<Boolean>("isUnlocked") ?: false
                    val unlockUntilMs = call.argument<Long>("unlockUntilMs")
                    setUnlockStatus(isUnlocked, unlockUntilMs)
                    result.success(null)
                }
                "getInstalledApps" -> {
                    // Never block the platform thread on this.
                    val cached = cachedApps
                    if (cached != null) {
                        result.success(cached)
                    } else {
                        backgroundExecutor.execute {
                            val apps = try {
                                queryLaunchableApps()
                            } catch (e: Exception) {
                                emptyList()
                            }
                            mainHandler.post {
                                cachedApps = apps
                                // The engine may have been detached while we
                                // were working; guard against a late reply.
                                if (!isDestroyed) result.success(apps)
                            }
                        }
                    }
                }
                "startAppLockService" -> {
                    startAppLockService()
                    result.success(null)
                }
                "stopAppLockService" -> {
                    stopAppLockService()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    AppLockService.eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    AppLockService.eventSink = null
                }
            }
        )
    }

    // ==================== Permission checks ====================

    private fun isAccessibilityEnabled(): Boolean {
        val serviceName = "${packageName}/${packageName}.services.AppLockAccessibilityService"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabledServices.contains(serviceName)
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else true
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun isBatteryOptimizationDisabled(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            return pm.isIgnoringBatteryOptimizations(packageName)
        }
        return true
    }

    private fun requestDisableBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        }
    }

    // ==================== App lock management ====================

    private fun updateBlockedApps(packages: List<String>) {
        val prefs = getSharedPreferences("app_lock", Context.MODE_PRIVATE)
        prefs.edit().putStringSet("blocked_packages", packages.toSet()).apply()
        AppLockService.blockedPackages = packages.toHashSet()
    }

    private fun updateAllowlist(packages: List<String>) {
        val prefs = getSharedPreferences("app_lock", Context.MODE_PRIVATE)
        prefs.edit().putStringSet("allowlist_packages", packages.toSet()).apply()
        AppLockService.allowlistPackages = packages.toHashSet()
    }

    private fun setUnlockStatus(isUnlocked: Boolean, unlockUntilMs: Long?) {
        val prefs = getSharedPreferences("app_lock", Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean("is_unlocked", isUnlocked)
            .putLong("unlock_until_ms", unlockUntilMs ?: 0L)
            .apply()
        AppLockService.isUnlocked = isUnlocked
        AppLockService.unlockUntilMs = unlockUntilMs ?: 0L
    }

    /**
     * Returns the apps the user can actually launch, for the block-list picker.
     *
     * Runs on [backgroundExecutor] — must NOT be called from the main thread.
     *
     * This queries launcher activities rather than every installed package.
     * That is both faster (typically ~100 results instead of 300+) and more
     * correct: the previous `getInstalledApplications` + `FLAG_SYSTEM` filter
     * included packages with no UI to open, while wrongly excluding
     * pre-installed apps the user genuinely wants to block — Chrome and
     * YouTube ship as system apps on most devices, so they never appeared.
     */
    private fun queryLaunchableApps(): List<Map<String, String>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)

        val resolved = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(0L)
            )
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(intent, 0)
        }

        return resolved
            .asSequence()
            .mapNotNull { info ->
                val pkg = info.activityInfo?.packageName ?: return@mapNotNull null
                // Don't offer to block ourselves — that would make the unlock
                // flow unreachable.
                if (pkg == packageName) return@mapNotNull null
                mapOf(
                    "packageName" to pkg,
                    "appName" to (info.loadLabel(pm)?.toString() ?: pkg)
                )
            }
            .distinctBy { it["packageName"] }
            .sortedBy { it["appName"]?.lowercase() }
            .toList()
    }

    private fun startAppLockService() {
        val intent = Intent(this, AppLockService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopAppLockService() {
        stopService(Intent(this, AppLockService::class.java))
    }
}
