package com.minepacu.craftpresence.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.ui.graphics.Color
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

private val DarkColorScheme = darkColorScheme(
    primary = PresenceBlueDark,
    onPrimary = Color(0xFF111A60),
    primaryContainer = Color(0xFF27318F),
    onPrimaryContainer = Color(0xFFE1E4FF),
    secondary = PresenceMintDark,
    onSecondary = Color(0xFF00382A),
    secondaryContainer = Color(0xFF00513F),
    onSecondaryContainer = Color(0xFF8CFBDD),
    tertiary = PresenceAmberDark,
    onTertiary = Color(0xFF332300),
    tertiaryContainer = Color(0xFF5A4200),
    onTertiaryContainer = Color(0xFFFFDEA0),
    background = PresenceDarkBackground,
    onBackground = Color(0xFFE1E4DE),
    surface = PresenceDarkBackground,
    onSurface = Color(0xFFE1E4DE),
    surfaceContainer = PresenceDarkSurface,
    surfaceVariant = PresenceDarkSurfaceVariant,
    onSurfaceVariant = PresenceDarkOnSurfaceVariant,
)

private val LightColorScheme = lightColorScheme(
    primary = PresenceBlue,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFE0E3FF),
    onPrimaryContainer = Color(0xFF141B5F),
    secondary = PresenceMint,
    onSecondary = Color.White,
    secondaryContainer = Color(0xFF9BF7D9),
    onSecondaryContainer = Color(0xFF002119),
    tertiary = PresenceAmber,
    onTertiary = Color.White,
    tertiaryContainer = Color(0xFFFFDEA0),
    onTertiaryContainer = Color(0xFF302100),
    background = PresenceBackground,
    onBackground = Color(0xFF1B1F1A),
    surface = PresenceBackground,
    onSurface = Color(0xFF1B1F1A),
    surfaceContainer = PresenceSurface,
    surfaceVariant = PresenceSurfaceVariant,
    onSurfaceVariant = PresenceOnSurfaceVariant,
)

@Composable
fun CraftPresenceTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }

        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
