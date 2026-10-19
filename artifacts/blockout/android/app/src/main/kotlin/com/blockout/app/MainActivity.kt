package com.blockout.app

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.blockout/app_blocker"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> result.success(getInstalledApps())
                    "getSavedSelection" ->
                        result.success(BlockSessionStore.selectedPackages(this).toList())
                    "saveSelection" -> {
                        val packages = call.argument<List<String>>("packageNames")
                        if (packages == null) {
                            result.error("INVALID_ARGUMENT", "App selection is missing.", null)
                        } else {
                            BlockSessionStore.saveSelection(this, packages.toSet())
                            result.success(null)
                        }
                    }
                    "isAccessibilityEnabled" ->
                        result.success(isBlockerServiceEnabled())
                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "getSession" -> result.success(getSession())
                    "startSession" -> startSession(call, result)
                    "stopSession" -> {
                        BlockSessionStore.stopSession(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolvedActivities = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                launcherIntent,
                PackageManager.ResolveInfoFlags.of(0L)
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(launcherIntent, 0)
        }

        return resolvedActivities
            .mapNotNull { info ->
                val appInfo = info.activityInfo?.applicationInfo ?: return@mapNotNull null
                val appPackageName = appInfo.packageName
                if (appPackageName == this.packageName) return@mapNotNull null
                val label = appInfo.loadLabel(packageManager).toString()
                mapOf("name" to label, "packageName" to appPackageName)
            }
            .distinctBy { it["packageName"] }
            .sortedBy { it["name"]?.lowercase() }
    }

    private fun isBlockerServiceEnabled(): Boolean {
        val expected = ComponentName(this, AppBlockAccessibilityService::class.java)
            .flattenToString()
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val serviceEnabled = enabledServices.split(':')
            .any { it.equals(expected, ignoreCase = true) }
        val accessibilityEnabled = Settings.Secure.getInt(
            contentResolver,
            Settings.Secure.ACCESSIBILITY_ENABLED,
            0
        ) == 1
        return serviceEnabled && accessibilityEnabled
    }

    private fun getSession(): Map<String, Any> {
        val endAt = BlockSessionStore.endsAtMillis(this)
        val packages = BlockSessionStore.activePackages(this)
        val active = endAt > System.currentTimeMillis() && packages.isNotEmpty()

        if (!active && (endAt != 0L || packages.isNotEmpty())) {
            BlockSessionStore.stopSession(this)
        }

        return mapOf(
            "active" to active,
            "endsAtMillis" to if (active) endAt else 0L,
            "packageNames" to if (active) packages.toList() else emptyList<String>()
        )
    }

    private fun startSession(
        call: MethodChannel.MethodCall,
        result: MethodChannel.Result
    ) {
        if (!isBlockerServiceEnabled()) {
            result.error(
                "ACCESSIBILITY_REQUIRED",
                "Enable BlockOut App Blocking in Android Accessibility settings.",
                null
            )
            return
        }

        val packages = call.argument<List<String>>("packageNames")?.toSet()
        val endsAt = call.argument<Number>("endsAtMillis")?.toLong()
        if (packages.isNullOrEmpty() || endsAt == null || endsAt <= System.currentTimeMillis()) {
            result.error("INVALID_ARGUMENT", "Choose apps and a future timer deadline.", null)
            return
        }

        BlockSessionStore.startSession(this, packages, endsAt)
        BlockSessionStore.saveSelection(this, packages)
        result.success(null)
    }
}
