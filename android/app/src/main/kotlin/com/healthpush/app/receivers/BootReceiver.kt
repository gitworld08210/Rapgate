package com.healthpush.app.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import com.healthpush.app.services.AppLockService

/**
 * Restarts AppLockService after a device reboot so blocking remains active
 * even if the user doesn't manually open the app.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        // Only start if user has configured blocked apps
        val prefs = context.getSharedPreferences("app_lock", Context.MODE_PRIVATE)
        val blocked = prefs.getStringSet("blocked_packages", emptySet()) ?: emptySet()
        if (blocked.isEmpty()) return

        val serviceIntent = Intent(context, AppLockService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
