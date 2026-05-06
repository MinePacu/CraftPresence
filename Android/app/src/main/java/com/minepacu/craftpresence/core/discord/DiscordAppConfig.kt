package com.minepacu.craftpresence.core.discord

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

/** Reads and validates Discord SDK configuration bundled with the Android app. */
object DiscordAppConfig {
    private const val META_APPLICATION_ID = "com.minepacu.craftpresence.DISCORD_APPLICATION_ID"

    /** Returns the Discord application ID from Android manifest metadata, if configured. */
    fun applicationId(context: Context): String? {
        val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.getApplicationInfo(
                context.packageName,
                PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
        }
        return appInfo.metaData?.getString(META_APPLICATION_ID)
            ?.takeIf { it.isNotBlank() }
    }

    /** Returns a validation error when the application ID cannot be used by the Discord SDK. */
    fun validationError(applicationId: String?): DiscordSdkError.InvalidApplicationId? {
        val normalizedId = applicationId?.trim().orEmpty()
        return when {
            normalizedId.isEmpty() -> DiscordSdkError.InvalidApplicationId("APPLICATION_ID is missing.")
            normalizedId == "YOUR_APPLICATION_ID" -> {
                DiscordSdkError.InvalidApplicationId("APPLICATION_ID still uses the placeholder value.")
            }
            normalizedId == "000000000000000000" -> {
                DiscordSdkError.InvalidApplicationId("APPLICATION_ID still uses the placeholder value.")
            }
            normalizedId.any { !it.isDigit() } -> {
                DiscordSdkError.InvalidApplicationId("APPLICATION_ID must contain only numeric characters.")
            }
            else -> null
        }
    }
}
