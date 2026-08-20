package com.healthpush.app.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

/**
 * Detects when the foreground app changes. If the new app is in the blocked
 * list AND the unlock window has expired, it signals AppLockService to show
 * the overlay.
 *
 * The user must manually enable this in Settings → Accessibility.
 */
class AppLockAccessibilityService : AccessibilityService() {

    override fun onServiceConnected() {
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            notificationTimeout = 100
        }
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return

        // Ignore our own app and system UI
        if (packageName == this.packageName) return
        if (packageName == "com.android.systemui") return

        // Check if this app is blocked and we're currently locked
        if (shouldBlock(packageName)) {
            showLockOverlay(packageName)
        }
    }

    override fun onInterrupt() {}

    private fun shouldBlock(packageName: String): Boolean {
        // Check unlock status
        if (AppLockService.isUnlocked) {
            val now = System.currentTimeMillis()
            if (AppLockService.unlockUntilMs > now) return false
            // Unlock expired
            AppLockService.isUnlocked = false
        }

        // Check if the app is in the blocked list but not the allowlist
        if (AppLockService.allowlistPackages.contains(packageName)) return false
        return AppLockService.blockedPackages.contains(packageName)
    }

    private fun showLockOverlay(blockedPackage: String) {
        val intent = Intent(this, AppLockService::class.java).apply {
            action = AppLockService.ACTION_SHOW_OVERLAY
            putExtra("blocked_package", blockedPackage)
        }
        startService(intent)

        // Notify Flutter via event channel
        AppLockService.eventSink?.success(
            mapOf(
                "event" to "app_blocked",
                "package" to blockedPackage
            )
        )
    }
}
