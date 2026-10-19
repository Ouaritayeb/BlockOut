package com.blockout.app

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

class AppBlockAccessibilityService : AccessibilityService() {
    private var lastBlockedPackage: String? = null
    private var lastBlockScreenAt = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val foregroundPackage = event.packageName?.toString() ?: return

        if (foregroundPackage == packageName) {
            lastBlockedPackage = null
            return
        }

        val endAt = BlockSessionStore.endsAtMillis(this)
        val blockedPackages = BlockSessionStore.activePackages(this)
        if (endAt <= System.currentTimeMillis()) {
            if (endAt != 0L || blockedPackages.isNotEmpty()) {
                BlockSessionStore.stopSession(this)
            }
            lastBlockedPackage = null
            return
        }

        if (foregroundPackage !in blockedPackages) {
            lastBlockedPackage = null
            return
        }

        val now = System.currentTimeMillis()
        if (lastBlockedPackage == foregroundPackage && now - lastBlockScreenAt < 1500L) {
            return
        }

        val label = try {
            val appInfo = packageManager.getApplicationInfo(foregroundPackage, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (_: Exception) {
            foregroundPackage
        }

        val blockIntent = Intent(this, BlockedActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(BlockedActivity.EXTRA_APP_LABEL, label)
            putExtra(BlockedActivity.EXTRA_ENDS_AT, endAt)
        }
        startActivity(blockIntent)
        lastBlockedPackage = foregroundPackage
        lastBlockScreenAt = now
    }

    override fun onInterrupt() = Unit
}
