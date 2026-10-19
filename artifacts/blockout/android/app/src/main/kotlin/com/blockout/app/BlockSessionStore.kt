package com.blockout.app

import android.content.Context

internal object BlockSessionStore {
    private const val PREFERENCES = "blockout_preferences"
    private const val SELECTED_PACKAGES = "selected_packages"
    private const val ACTIVE_PACKAGES = "active_packages"
    private const val ENDS_AT_MILLIS = "ends_at_millis"

    private fun preferences(context: Context) =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    fun selectedPackages(context: Context): Set<String> =
        preferences(context).getStringSet(SELECTED_PACKAGES, emptySet())
            ?.toSet()
            ?: emptySet()

    fun saveSelection(context: Context, packages: Set<String>) {
        preferences(context).edit()
            .putStringSet(SELECTED_PACKAGES, packages.toSet())
            .apply()
    }

    fun activePackages(context: Context): Set<String> =
        preferences(context).getStringSet(ACTIVE_PACKAGES, emptySet())
            ?.toSet()
            ?: emptySet()

    fun endsAtMillis(context: Context): Long =
        preferences(context).getLong(ENDS_AT_MILLIS, 0L)

    fun startSession(context: Context, packages: Set<String>, endsAt: Long) {
        preferences(context).edit()
            .putStringSet(ACTIVE_PACKAGES, packages.toSet())
            .putLong(ENDS_AT_MILLIS, endsAt)
            .apply()
    }

    fun stopSession(context: Context) {
        preferences(context).edit()
            .remove(ACTIVE_PACKAGES)
            .remove(ENDS_AT_MILLIS)
            .apply()
    }
}
