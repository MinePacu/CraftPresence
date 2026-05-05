package com.minepacu.craftpresence

import android.Manifest
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.SystemBarStyle
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.lifecycle.lifecycleScope
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Apps
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.runtime.CompositionLocalProvider
import com.discord.socialsdk.DiscordSocialSdkInit
import com.minepacu.craftpresence.core.config.AppLanguage
import com.minepacu.craftpresence.core.config.AppSettings
import com.minepacu.craftpresence.core.config.ConfigUtility
import com.minepacu.craftpresence.core.config.ProgramPresenceSettings
import com.minepacu.craftpresence.core.discord.DiscordActivity
import com.minepacu.craftpresence.core.discord.DiscordAppConfig
import com.minepacu.craftpresence.core.discord.DiscordAuthorizationStatus
import com.minepacu.craftpresence.core.discord.DiscordDashboardStatus
import com.minepacu.craftpresence.core.discord.DiscordSdkManager
import com.minepacu.craftpresence.core.media.MusicPlatform
import com.minepacu.craftpresence.core.notifications.ForegroundAppNotificationController
import com.minepacu.craftpresence.core.permissions.PermissionService
import com.minepacu.craftpresence.core.presence.AppleMusicPresenceManager
import com.minepacu.craftpresence.core.presence.ProgramPresenceManager
import com.minepacu.craftpresence.core.programs.ProgramDetector
import com.minepacu.craftpresence.ui.localization.LocalizedText
import com.minepacu.craftpresence.ui.localization.LocalizedTextProvider
import com.minepacu.craftpresence.ui.localization.rememberLocalizedText
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        DiscordSocialSdkInit.setEngineActivity(this)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.auto(
                lightScrim = android.graphics.Color.TRANSPARENT,
                darkScrim = android.graphics.Color.TRANSPARENT,
            ),
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
        }
        @Suppress("DEPRECATION")
        window.statusBarColor = android.graphics.Color.TRANSPARENT
        setContent {
            MaterialTheme {
                CraftPresenceApp()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        DiscordSocialSdkInit.setEngineActivity(this)
        lifecycleScope.launch {
            ConfigUtility.getInstance(this@MainActivity).refreshSettings()
        }
    }
}

private enum class AppTab(val icon: ImageVector) {
    OVERVIEW(Icons.Filled.Home),
    DISCORD(Icons.Filled.SportsEsports),
    PROGRAMS(Icons.Filled.Apps),
    PRESENCE(Icons.Filled.Edit),
    MUSIC(Icons.Filled.MusicNote),
    PERMISSIONS(Icons.Filled.Security),
    SETTINGS(Icons.Filled.Settings),
}

private data class InstalledAppInfo(
    val label: String,
    val packageName: String,
    val isSystemApp: Boolean,
)

@Composable
private fun CraftPresenceApp() {
    val context = LocalContext.current
    val config = remember { ConfigUtility.getInstance(context) }
    val discord = remember { DiscordSdkManager.getInstance(context) }
    val programPresence = remember { ProgramPresenceManager.getInstance(context) }
    val musicPresence = remember { AppleMusicPresenceManager.getInstance(context) }
    val detector = remember { ProgramDetector.getInstance(context) }
    val foregroundAppNotification = remember { ForegroundAppNotificationController.getInstance(context) }
    val permissions = remember { PermissionService(context) }

    val settings by config.settings.collectAsState()
    val discordState by discord.state.collectAsState()
    val programState by programPresence.state.collectAsState()
    val musicState by musicPresence.state.collectAsState()
    val foreground by detector.updates.collectAsState()

    var selectedTab by remember { mutableStateOf(AppTab.OVERVIEW) }
    var showDiscordOnboarding by remember { mutableStateOf(false) }
    var automaticDiscordMessage by remember { mutableStateOf("") }
    var showInstalledAppPicker by remember { mutableStateOf(false) }
    var installedAppSearch by remember { mutableStateOf("") }
    var installedApps by remember { mutableStateOf(emptyList<InstalledAppInfo>()) }
    var installedAppsLoading by remember { mutableStateOf(false) }
    var showSystemApps by remember { mutableStateOf(true) }
    val foregroundDisplayEnabled = settings.showForegroundAppIndicator
    val foregroundNotificationEnabled = settings.showForegroundAppNotification
    val text = rememberLocalizedText(settings.preferredLanguage)
    val scope = rememberCoroutineScope()
    val statusBarTopPadding = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val filteredInstalledApps = remember(installedApps, installedAppSearch, showSystemApps) {
        val query = installedAppSearch.trim()
        val visibleApps = if (showSystemApps) {
            installedApps
        } else {
            installedApps.filterNot { it.isSystemApp }
        }
        if (query.isBlank()) {
            visibleApps
        } else {
            visibleApps.filter {
                it.label.contains(query, ignoreCase = true) ||
                    it.packageName.contains(query, ignoreCase = true)
            }
        }
    }

    LaunchedEffect(settings.hasCompletedDiscordOnboarding, text) {
        if (!settings.hasCompletedDiscordOnboarding) {
            showDiscordOnboarding = true
            return@LaunchedEffect
        }

        showDiscordOnboarding = false
        runCatching {
            discord.configure(
                autoAuthorize = true,
                allowInteractiveAuthorization = false,
            )
        }.onSuccess {
            automaticDiscordMessage = ""
        }.onFailure {
            automaticDiscordMessage = it.message ?: text.discordAutoConnectFailed
        }
    }

    LaunchedEffect(foregroundDisplayEnabled, foregroundNotificationEnabled, programState.isEnabled) {
        if (foregroundDisplayEnabled || foregroundNotificationEnabled || programState.isEnabled) {
            detector.start()
        } else {
            detector.stop()
        }
    }

    LaunchedEffect(
        settings.programPresenceEnabled,
        settings.packageNames,
        settings.hasCompletedDiscordOnboarding,
    ) {
        val shouldRunProgramPresence = settings.programPresenceEnabled &&
            settings.packageNames.isNotEmpty() &&
            settings.hasCompletedDiscordOnboarding
        if (shouldRunProgramPresence) {
            programPresence.startMonitoring()
        } else if (programState.isEnabled) {
            programPresence.stopMonitoring()
        }
    }

    LaunchedEffect(foregroundNotificationEnabled) {
        if (foregroundNotificationEnabled) {
            foregroundAppNotification.start()
        } else {
            foregroundAppNotification.stop()
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            foregroundAppNotification.stop()
        }
    }

    CompositionLocalProvider(LocalizedTextProvider provides text) {
        Scaffold(
            containerColor = MaterialTheme.colorScheme.background,
            contentWindowInsets = WindowInsets(0.dp),
            bottomBar = {
                NavigationBar {
                    AppTab.entries.forEach { tab ->
                        val title = tabTitle(tab, text)
                        NavigationBarItem(
                            selected = selectedTab == tab,
                            onClick = { selectedTab = tab },
                            icon = {
                                Icon(
                                    imageVector = tab.icon,
                                    contentDescription = title,
                                )
                            },
                            label = { Text(title) },
                        )
                    }
                }
            },
        ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(
                start = 18.dp,
                top = statusBarTopPadding + 18.dp,
                end = 18.dp,
                bottom = 18.dp,
            ),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item {
                Header(
                    title = "CraftPresence",
                    subtitle = text.headerSubtitle,
                )
            }
            if (automaticDiscordMessage.isNotBlank()) {
                item {
                    WarningCard(title = text.discordAutoConnect, message = automaticDiscordMessage)
                }
            }
            if (foregroundDisplayEnabled) {
                item {
                    ForegroundAppBanner(
                        appName = foreground.appName.orEmpty(),
                        packageName = foreground.packageName.orEmpty(),
                        isTracked = foreground.packageName in settings.packageNames,
                    )
                }
            }

            when (selectedTab) {
                AppTab.OVERVIEW -> {
                    item {
                        OverviewScreen(
                            settings = settings,
                            discordStatus = discordState.dashboardStatus,
                            discordUser = discordState.currentUser?.username,
                            programEnabled = programState.isEnabled,
                            musicEnabled = musicState.isEnabled,
                            foregroundDisplayEnabled = foregroundDisplayEnabled,
                            foregroundApp = if (foregroundDisplayEnabled) foreground.appName.orEmpty() else "",
                            foregroundPackage = if (foregroundDisplayEnabled) foreground.packageName.orEmpty() else "",
                            foregroundTracked = foregroundDisplayEnabled && foreground.packageName in settings.packageNames,
                            musicTrack = musicState.currentTrack,
                            musicArtist = musicState.currentArtist,
                            lastError = discordState.lastErrorMessage,
                        )
                    }
                }

                AppTab.DISCORD -> {
                    item {
                        DiscordScreen(
                            context = context,
                            manager = discord,
                            settings = settings,
                            config = config,
                            status = discordState.dashboardStatus,
                            authorization = discordState.authorizationStatus,
                            username = discordState.currentUser?.username,
                            userId = discordState.currentUser?.id,
                            lastError = discordState.lastErrorMessage,
                        )
                    }
                }

                AppTab.PROGRAMS -> {
                    if (showInstalledAppPicker) {
                        item {
                            InstalledAppPickerHeader(
                                searchQuery = installedAppSearch,
                                onSearchQueryChange = { installedAppSearch = it },
                                showSystemApps = showSystemApps,
                                onShowSystemAppsChange = { showSystemApps = it },
                                onBack = { showInstalledAppPicker = false },
                            )
                        }
                        if (installedAppsLoading) {
                            item {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(vertical = 28.dp),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    CircularProgressIndicator()
                                }
                            }
                        } else if (filteredInstalledApps.isEmpty()) {
                            item {
                                Text(
                                    text.noAppsFound,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 20.dp),
                                )
                            }
                        }
                        items(filteredInstalledApps, key = { it.packageName }) { app ->
                            InstalledAppRow(
                                app = app,
                                isRegistered = app.packageName in settings.packageNames,
                                onSelect = {
                                    scope.launch {
                                        config.addPackageName(app.packageName, app.label)
                                        showInstalledAppPicker = false
                                        installedAppSearch = ""
                                    }
                                },
                            )
                        }
                    } else {
                        item {
                            ProgramPresenceControls(
                                stateEnabled = programState.isEnabled,
                                status = programState.discordStatus,
                                lastError = programState.lastErrorMessage,
                                activeAppName = programState.activeAppName,
                                activePackageName = programState.activePackageName,
                                onStart = {
                                    scope.launch {
                                        config.setSettings(settings.copy(programPresenceEnabled = true))
                                        programPresence.startMonitoring()
                                    }
                                },
                                onStop = {
                                    scope.launch {
                                        config.setSettings(settings.copy(programPresenceEnabled = false))
                                        programPresence.stopMonitoring()
                                    }
                                },
                            )
                        }
                        item {
                            AddProgramCard(
                                settings = settings,
                                foregroundDisplayEnabled = foregroundDisplayEnabled,
                                foregroundPackage = if (foregroundDisplayEnabled) foreground.packageName.orEmpty() else "",
                                foregroundApp = if (foregroundDisplayEnabled) foreground.appName.orEmpty() else "",
                                config = config,
                                onChooseInstalledApp = {
                                    showInstalledAppPicker = true
                                    if (installedApps.isEmpty() && !installedAppsLoading) {
                                        installedAppsLoading = true
                                        scope.launch {
                                            installedApps = runCatching {
                                                withContext(Dispatchers.IO) {
                                                    installedApplications(context.applicationContext)
                                                }
                                            }.getOrDefault(emptyList())
                                            installedAppsLoading = false
                                        }
                                    }
                                },
                            )
                        }
                        items(settings.packageNames, key = { it }) { packageName ->
                            val displayName = settings.appDisplayNames[packageName]
                                ?: remember(packageName) { appLabel(context, packageName) }
                            ProgramRow(
                                packageName = packageName,
                                displayName = displayName,
                                settings = settings.programSettings[packageName] ?: ProgramPresenceSettings(),
                                savedDisplayName = settings.appDisplayNames[packageName].orEmpty(),
                                config = config,
                            )
                        }
                    }
                }

                AppTab.PRESENCE -> {
                    item {
                        PresenceScreen(
                            settings = settings,
                            currentPackageName = foreground.packageName.orEmpty(),
                            currentAppName = foreground.appName.orEmpty(),
                            config = config,
                        )
                    }
                }

                AppTab.MUSIC -> {
                    item {
                        MusicScreen(
                            enabledPlatforms = musicState.enabledPlatforms,
                            activePlatform = musicState.activePlatform,
                            status = musicState.discordStatus,
                            track = musicState.currentTrack,
                            artist = musicState.currentArtist,
                            album = musicState.currentAlbum,
                            isPlaying = musicState.isPlaying,
                            artworkUrl = musicState.albumArtworkUrl,
                            onStartAll = { musicPresence.startMonitoring() },
                            onStopAll = { musicPresence.stopMonitoring() },
                            onStartPlatform = { musicPresence.startMonitoring(it) },
                            onStopPlatform = { musicPresence.stopMonitoring(it) },
                        )
                    }
                }

                AppTab.PERMISSIONS -> {
                    item {
                        PermissionsScreen(permissions = permissions)
                    }
                }

                AppTab.SETTINGS -> {
                    item {
                        SettingsScreen(settings = settings, config = config)
                    }
                }
            }
        }
    }

        if (showDiscordOnboarding) {
            DiscordOnboardingDialog(
                context = context,
                manager = discord,
                config = config,
                settings = settings,
                status = discordState.dashboardStatus,
                lastError = discordState.lastErrorMessage,
                onDismiss = { showDiscordOnboarding = false },
            )
        }
    }
}

@Composable
private fun Header(title: String, subtitle: String) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun ForegroundAppBanner(appName: String, packageName: String, isTracked: Boolean) {
    val text = LocalizedTextProvider.current
    InfoCard(text.foregroundAppTitle) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(appName.ifBlank { text.noDetectedApp }, fontWeight = FontWeight.SemiBold)
                Text(
                    packageName.ifBlank { text.usageAccessMayBeRequired },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.MiddleEllipsis,
                )
            }
            StatusChip(
                text = if (isTracked) text.tracked else text.untracked,
                tint = if (isTracked) Color(0xFF2E7D32) else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun DiscordOnboardingDialog(
    context: Context,
    manager: DiscordSdkManager,
    config: ConfigUtility,
    settings: AppSettings,
    status: DiscordDashboardStatus,
    lastError: String?,
    onDismiss: () -> Unit,
) {
    val text = LocalizedTextProvider.current
    val scope = rememberCoroutineScope()
    var actionMessage by remember { mutableStateOf("") }
    val applicationId = remember { DiscordAppConfig.applicationId(context).orEmpty() }
    val validationMessage = remember(applicationId) {
        DiscordAppConfig.validationError(applicationId)?.message
    }

    AlertDialog(
        onDismissRequest = {},
        title = { Text(text.discordConnect) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(text.discordOnboardingBody)
                KeyValueRow(text.status, dashboardStatusText(status, text))
                KeyValueRow("Application ID", maskApplicationId(applicationId).ifBlank { text.notConfiguredValue })
                if (validationMessage != null) {
                    Text(validationMessage, color = MaterialTheme.colorScheme.error)
                }
                if (!lastError.isNullOrBlank()) {
                    Text(lastError, color = MaterialTheme.colorScheme.error)
                }
                if (actionMessage.isNotBlank()) {
                    Text(actionMessage, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    scope.launch {
                        actionMessage = text.discordAuthStart
                        runCatching {
                            manager.configure(autoAuthorize = false)
                            manager.authorizeIfNeeded()
                        }.onSuccess {
                            config.setSettings(settings.copy(hasCompletedDiscordOnboarding = true))
                            actionMessage = text.discordAccountConnected
                            onDismiss()
                        }.onFailure {
                            actionMessage = it.message ?: text.discordConnectFailed
                        }
                    }
                },
                enabled = status != DiscordDashboardStatus.AUTHORIZING &&
                    status != DiscordDashboardStatus.CONNECTING &&
                    validationMessage == null,
            ) {
                Text(text.connectAccount)
            }
        },
        dismissButton = {
            TextButton(
                onClick = {
                    scope.launch {
                        config.setSettings(settings.copy(hasCompletedDiscordOnboarding = true))
                        onDismiss()
                    }
                },
            ) {
                Text(text.later)
            }
        },
    )
}

@Composable
private fun OverviewScreen(
    settings: AppSettings,
    discordStatus: DiscordDashboardStatus,
    discordUser: String?,
    programEnabled: Boolean,
    musicEnabled: Boolean,
    foregroundDisplayEnabled: Boolean,
    foregroundApp: String,
    foregroundPackage: String,
    foregroundTracked: Boolean,
    musicTrack: String,
    musicArtist: String,
    lastError: String?,
) {
    val text = LocalizedTextProvider.current
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            MetricCard(
                title = "Discord",
                value = dashboardStatusText(discordStatus, text),
                detail = discordUser ?: text.noConnectedAccount,
                tint = statusColor(discordStatus),
                modifier = Modifier.weight(1f),
            )
            MetricCard(
                title = text.registeredApps,
                value = text.countItems(settings.packageNames.size),
                detail = if (programEnabled) text.appDetectionRunning else text.appDetectionStopped,
                tint = if (programEnabled) Color(0xFF2E7D32) else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f),
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            MetricCard(
                title = text.currentApp,
                value = if (foregroundDisplayEnabled) foregroundApp.ifBlank { text.unknown } else text.displayOff,
                detail = if (foregroundDisplayEnabled) foregroundPackage.ifBlank { text.noUsageInfo } else text.canEnableInSettings,
                tint = if (foregroundTracked) Color(0xFF2E7D32) else MaterialTheme.colorScheme.primary,
                modifier = Modifier.weight(1f),
            )
            MetricCard(
                title = text.music,
                value = if (musicEnabled) text.active else text.standby,
                detail = if (musicTrack.isBlank()) text.noPlaybackInfo else "$musicTrack - $musicArtist",
                tint = if (musicEnabled) Color(0xFF00796B) else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f),
            )
        }

        InfoCard(text.currentDetectionInfo) {
            KeyValueRow(text.display, if (foregroundDisplayEnabled) text.on else text.off)
            KeyValueRow(text.appName, if (foregroundDisplayEnabled) foregroundApp.ifBlank { text.unknown } else text.hidden)
            KeyValueRow(text.packageName, if (foregroundDisplayEnabled) foregroundPackage.ifBlank { text.unknown } else text.hidden)
            KeyValueRow(text.registrationStatus, if (!foregroundDisplayEnabled) text.hidden else if (foregroundTracked) text.tracked else text.untracked)
            KeyValueRow(text.discordStatus, dashboardStatusText(discordStatus, text))
        }

        if (!lastError.isNullOrBlank()) {
            WarningCard(title = text.lastError, message = lastError)
        }
    }
}

@Composable
private fun DiscordScreen(
    context: Context,
    manager: DiscordSdkManager,
    settings: AppSettings,
    config: ConfigUtility,
    status: DiscordDashboardStatus,
    authorization: DiscordAuthorizationStatus,
    username: String?,
    userId: String?,
    lastError: String?,
) {
    val text = LocalizedTextProvider.current
    val scope = rememberCoroutineScope()
    var message by remember { mutableStateOf("") }
    val applicationId = remember { DiscordAppConfig.applicationId(context).orEmpty() }
    val validationMessage = remember(applicationId) {
        DiscordAppConfig.validationError(applicationId)?.message
    }

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        InfoCard(text.discordConnect) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column {
                    Text(text.status, fontWeight = FontWeight.SemiBold)
                    Text(dashboardStatusText(status, text), color = statusColor(status))
                }
                StatusChip(dashboardStatusText(status, text), statusColor(status))
            }
            HorizontalDivider(modifier = Modifier.padding(vertical = 10.dp))
            KeyValueRow("Application ID", maskApplicationId(applicationId).ifBlank { text.notConfiguredValue })
            KeyValueRow(text.authorization, authorizationText(authorization, text))
            KeyValueRow(text.account, username ?: text.none)
            if (userId != null) KeyValueRow(text.userId, userId)
        }

        InfoCard(text.actions) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(
                    onClick = {
                        scope.launch {
                            message = text.discordAuthStart
                            runCatching {
                                manager.configure(autoAuthorize = false)
                                manager.authorizeIfNeeded()
                            }.onSuccess {
                                config.setSettings(settings.copy(hasCompletedDiscordOnboarding = true))
                                message = text.discordAccountConnected
                            }.onFailure {
                                message = it.message ?: text.discordConnectFailed
                            }
                        }
                    },
                    enabled = status != DiscordDashboardStatus.AUTHORIZING && status != DiscordDashboardStatus.CONNECTING,
                ) {
                    Text(if (status == DiscordDashboardStatus.READY) text.reconnect else text.connect)
                }
                OutlinedButton(
                    onClick = {
                        scope.launch {
                            runCatching { manager.fetchCurrentUser() }
                                .onSuccess { message = text.accountRefreshSuccess }
                                .onFailure { message = it.message ?: text.accountRefreshFailed }
                        }
                    },
                    enabled = authorization == DiscordAuthorizationStatus.AUTHORIZED,
                ) {
                    Text(text.refreshAccount)
                }
                OutlinedButton(
                    onClick = {
                        scope.launch {
                            manager.logout()
                            message = text.discordDisconnected
                        }
                    },
                    enabled = authorization == DiscordAuthorizationStatus.AUTHORIZED,
                ) {
                    Text(text.disconnect)
                }
            }
        }

        InfoCard(text.requirements) {
            Text(text.discordRequirementInstalled)
            Text(text.discordRequirementApplicationId)
            Text(text.discordRequirementRichPresence)
        }

        if (validationMessage != null) WarningCard(text.applicationIdNeedsCheck, validationMessage)
        if (!lastError.isNullOrBlank()) WarningCard(text.lastError, lastError)
        if (message.isNotBlank()) AssistChip(onClick = { message = "" }, label = { Text(message) })
    }
}

@Composable
private fun ProgramPresenceControls(
    stateEnabled: Boolean,
    status: String,
    lastError: String?,
    activeAppName: String,
    activePackageName: String,
    onStart: () -> Unit,
    onStop: () -> Unit,
) {
    val text = LocalizedTextProvider.current
    InfoCard(text.appRichPresence) {
        KeyValueRow(text.operation, if (stateEnabled) text.running else text.stopped)
        KeyValueRow(text.status, presenceStatusText(status, text))
        KeyValueRow(text.currentApp, activeAppName.ifBlank { text.notDetected })
        KeyValueRow(text.packageName, activePackageName.ifBlank { text.notDetected })
        if (!lastError.isNullOrBlank()) {
            Text(lastError, color = MaterialTheme.colorScheme.error)
        }
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = onStart, enabled = !stateEnabled) { Text(text.startDetection) }
            OutlinedButton(onClick = onStop, enabled = stateEnabled) { Text(text.stop) }
        }
    }
}

@Composable
private fun AddProgramCard(
    settings: AppSettings,
    foregroundDisplayEnabled: Boolean,
    foregroundPackage: String,
    foregroundApp: String,
    config: ConfigUtility,
    onChooseInstalledApp: () -> Unit,
) {
    val text = LocalizedTextProvider.current
    val scope = rememberCoroutineScope()
    var packageName by remember { mutableStateOf("") }
    var displayName by remember { mutableStateOf("") }

    InfoCard(text.appToRegister) {
        Text(text.appRegistrationDescription)
        Spacer(Modifier.height(10.dp))
        OutlinedTextField(
            value = packageName,
            onValueChange = { packageName = it },
            label = { Text(text.packageName) },
            placeholder = { Text("com.example.app") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(10.dp))
        OutlinedTextField(
            value = displayName,
            onValueChange = { displayName = it },
            label = { Text(text.displayName) },
            placeholder = { Text(text.displayNameExample) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(10.dp))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(
                onClick = onChooseInstalledApp,
            ) {
                Text(text.chooseInstalledApp)
            }
            OutlinedButton(
                onClick = {
                    scope.launch {
                        config.addPackageName(packageName, displayName)
                        packageName = ""
                        displayName = ""
                    }
                },
                enabled = packageName.isNotBlank(),
            ) {
                Text(text.addManually)
            }
            OutlinedButton(
                onClick = { scope.launch { config.addPackageName(foregroundPackage, foregroundApp) } },
                enabled = foregroundDisplayEnabled && foregroundPackage.isNotBlank() && foregroundPackage !in settings.packageNames,
            ) {
                Text(text.addCurrentApp)
            }
            OutlinedButton(
                onClick = { scope.launch { config.addPackageName("com.apple.android.music", "Apple Music") } },
                enabled = "com.apple.android.music" !in settings.packageNames,
            ) {
                Text(text.addAppleMusic)
            }
        }
        if (!foregroundDisplayEnabled) {
            Text(
                text.enableForegroundHint,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 8.dp),
            )
        } else if (foregroundPackage.isNotBlank()) {
            Text(
                text.currentDetectedValue(foregroundApp.ifBlank { foregroundPackage }),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    }
}

@Composable
private fun InstalledAppPickerHeader(
    searchQuery: String,
    onSearchQueryChange: (String) -> Unit,
    showSystemApps: Boolean,
    onShowSystemAppsChange: (Boolean) -> Unit,
    onBack: () -> Unit,
) {
    val text = LocalizedTextProvider.current
    InfoCard(text.installedApps) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = text.cancel)
                Spacer(Modifier.width(6.dp))
                Text(text.cancel)
            }
        }
        Spacer(Modifier.height(10.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text.showSystemApps, fontWeight = FontWeight.SemiBold)
            Switch(
                checked = showSystemApps,
                onCheckedChange = onShowSystemAppsChange,
            )
        }
        Spacer(Modifier.height(10.dp))
        OutlinedTextField(
            value = searchQuery,
            onValueChange = onSearchQueryChange,
            label = { Text(text.searchApps) },
            singleLine = true,
            leadingIcon = {
                Icon(Icons.Filled.Search, contentDescription = null)
            },
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun InstalledAppRow(
    app: InstalledAppInfo,
    isRegistered: Boolean,
    onSelect: () -> Unit,
) {
    val text = LocalizedTextProvider.current
    ElevatedCard(shape = RoundedCornerShape(8.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Surface(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape),
                color = MaterialTheme.colorScheme.primaryContainer,
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(app.label.take(1).uppercase(), fontWeight = FontWeight.Bold)
                }
            }
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        app.label,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                    if (app.isSystemApp) {
                        StatusChip(text.systemApp, MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
                Text(
                    app.packageName,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.MiddleEllipsis,
                )
            }
            Button(onClick = onSelect, enabled = !isRegistered) {
                Text(if (isRegistered) text.alreadyRegistered else text.selectApp)
            }
        }
    }
}

@Composable
private fun ProgramRow(
    packageName: String,
    displayName: String,
    settings: ProgramPresenceSettings,
    savedDisplayName: String,
    config: ConfigUtility,
) {
    val text = LocalizedTextProvider.current
    val scope = rememberCoroutineScope()
    var showEditor by remember { mutableStateOf(false) }

    ElevatedCard(shape = RoundedCornerShape(8.dp)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Surface(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape),
                    color = MaterialTheme.colorScheme.primaryContainer,
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Text(displayName.take(1).uppercase(), fontWeight = FontWeight.Bold)
                    }
                }
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(displayName, fontWeight = FontWeight.SemiBold)
                    Text(
                        packageName,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.MiddleEllipsis,
                    )
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = { showEditor = true }) { Text(text.presenceSettings) }
                OutlinedButton(onClick = { scope.launch { config.removePackageName(packageName) } }) {
                    Text(text.delete)
                }
            }
        }
    }

    if (showEditor) {
        ProgramSettingsDialog(
            title = displayName,
            packageName = packageName,
            initialDisplayName = savedDisplayName.ifBlank { displayName },
            initialSettings = settings,
            onDismiss = { showEditor = false },
            onSave = { nextDisplayName, next ->
                scope.launch {
                    config.setAppDisplayName(packageName, nextDisplayName)
                    config.setProgramSettings(packageName, next)
                    showEditor = false
                }
            },
        )
    }
}

@Composable
private fun ProgramSettingsDialog(
    title: String,
    packageName: String,
    initialDisplayName: String,
    initialSettings: ProgramPresenceSettings,
    onDismiss: () -> Unit,
    onSave: (String, ProgramPresenceSettings) -> Unit,
) {
    val text = LocalizedTextProvider.current
    var draft by remember(initialSettings) { mutableStateOf(initialSettings) }
    var displayName by remember(initialDisplayName) { mutableStateOf(initialDisplayName) }
    val scroll = rememberScrollState()

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Column {
                Text(title)
                Text(packageName, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(scroll),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                PresenceTextField(text.displayName, text.displayNameExample, displayName) { displayName = it }
                Text(text.activityType, fontWeight = FontWeight.SemiBold)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    DiscordActivity.ActivityType.entries.forEach { type ->
                        FilterChip(
                            selected = draft.activityType == type,
                            onClick = { draft = draft.copy(activityType = type) },
                            label = { Text(activityTypeText(type, text)) },
                        )
                    }
                }
                PresenceTextField(text.detailText, text.defaultDetailText, draft.detailText) { draft = draft.copy(detailText = it) }
                PresenceTextField(text.stateText, text.defaultStateText, draft.stateText) { draft = draft.copy(stateText = it) }
                Text(
                    text.templateHelp,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(text.resetElapsedTimeOnPresenceChange)
                    Switch(
                        checked = draft.resetElapsedTimeOnPresenceChange,
                        onCheckedChange = { draft = draft.copy(resetElapsedTimeOnPresenceChange = it) },
                    )
                }
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(text.useAppIconForLargeImage)
                    Switch(
                        checked = draft.useAppIconForLargeImage,
                        onCheckedChange = { draft = draft.copy(useAppIconForLargeImage = it) },
                    )
                }
                PresenceTextField(text.largeImageKeyOrUrl, text.discordAssetKeyOrUrl, draft.largeImageKey) {
                    draft = draft.copy(largeImageKey = it)
                }
                PresenceTextField(text.largeImageText, text.imageHoverText, draft.largeImageText) {
                    draft = draft.copy(largeImageText = it)
                }
                PresenceTextField(text.smallImageKeyOrUrl, text.discordAssetKeyOrUrl, draft.smallImageKey) {
                    draft = draft.copy(smallImageKey = it)
                }
                PresenceTextField(text.smallImageText, text.imageHoverText, draft.smallImageText) {
                    draft = draft.copy(smallImageText = it)
                }
            }
        },
        confirmButton = {
            Button(onClick = { onSave(displayName, draft) }) {
                Text(text.save)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(text.cancel)
            }
        },
    )
}

@Composable
private fun PresenceScreen(
    settings: AppSettings,
    currentPackageName: String,
    currentAppName: String,
    config: ConfigUtility,
) {
    val context = LocalContext.current
    val text = LocalizedTextProvider.current
    val scope = rememberCoroutineScope()
    var selectedPackage by remember(settings.packageNames) {
        mutableStateOf(
            currentPackageName
                .takeIf { it in settings.packageNames }
                ?: settings.packageNames.firstOrNull().orEmpty(),
        )
    }
    var draft by remember { mutableStateOf(ProgramPresenceSettings()) }
    var displayName by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    val selectedSettings = settings.programSettings[selectedPackage] ?: ProgramPresenceSettings()
    val selectedDisplayName = settings.appDisplayNames[selectedPackage]
        ?: selectedPackage.takeIf { it.isNotBlank() }?.let { appLabel(context, it) }
        ?: ""

    LaunchedEffect(settings.packageNames, currentPackageName) {
        if (selectedPackage !in settings.packageNames) {
            selectedPackage = currentPackageName
                .takeIf { it in settings.packageNames }
                ?: settings.packageNames.firstOrNull().orEmpty()
        }
    }

    LaunchedEffect(selectedPackage, selectedSettings, selectedDisplayName) {
        draft = selectedSettings
        displayName = selectedDisplayName
    }

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        InfoCard(text.presenceCustomizer) {
            Text(text.presenceCustomizerDescription, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(6.dp))
            KeyValueRow(text.currentApp, currentAppName.ifBlank { text.notDetected })
            KeyValueRow(text.packageName, currentPackageName.ifBlank { text.notDetected })
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(
                    onClick = {
                        scope.launch {
                            config.refreshSettings()
                            message = text.presenceReloaded
                        }
                    },
                ) {
                    Text(text.refreshPresence)
                }
            }
            if (message.isNotBlank()) {
                AssistChip(onClick = { message = "" }, label = { Text(message) })
            }
        }

        if (settings.packageNames.isEmpty()) {
            InfoCard(text.currentPresence) {
                Text(text.noRegisteredAppsForPresence, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            return@Column
        }

        InfoCard(text.selectPresenceApp) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                settings.packageNames.forEach { packageName ->
                    val name = settings.appDisplayNames[packageName] ?: appLabel(context, packageName)
                    FilterChip(
                        selected = selectedPackage == packageName,
                        onClick = { selectedPackage = packageName },
                        label = { Text(name) },
                    )
                }
            }
        }

        InfoCard(text.currentPresence) {
            PresenceTextField(text.displayName, text.displayNameExample, displayName) { displayName = it }
            KeyValueRow(text.packageName, selectedPackage)
            HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
            Text(text.activityType, fontWeight = FontWeight.SemiBold)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                DiscordActivity.ActivityType.entries.forEach { type ->
                    FilterChip(
                        selected = draft.activityType == type,
                        onClick = { draft = draft.copy(activityType = type) },
                        label = { Text(activityTypeText(type, text)) },
                    )
                }
            }
            PresenceTextField(text.detailText, text.defaultDetailText, draft.detailText) { draft = draft.copy(detailText = it) }
            PresenceTextField(text.stateText, text.defaultStateText, draft.stateText) { draft = draft.copy(stateText = it) }
            Text(
                text.templateHelp,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(text.resetElapsedTimeOnPresenceChange)
                Switch(
                    checked = draft.resetElapsedTimeOnPresenceChange,
                    onCheckedChange = { draft = draft.copy(resetElapsedTimeOnPresenceChange = it) },
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(text.useAppIconForLargeImage)
                Switch(
                    checked = draft.useAppIconForLargeImage,
                    onCheckedChange = { draft = draft.copy(useAppIconForLargeImage = it) },
                )
            }
            PresenceTextField(text.largeImageKeyOrUrl, text.discordAssetKeyOrUrl, draft.largeImageKey) {
                draft = draft.copy(largeImageKey = it)
            }
            PresenceTextField(text.largeImageText, text.imageHoverText, draft.largeImageText) {
                draft = draft.copy(largeImageText = it)
            }
            PresenceTextField(text.smallImageKeyOrUrl, text.discordAssetKeyOrUrl, draft.smallImageKey) {
                draft = draft.copy(smallImageKey = it)
            }
            PresenceTextField(text.smallImageText, text.imageHoverText, draft.smallImageText) {
                draft = draft.copy(smallImageText = it)
            }
            Button(
                onClick = {
                    scope.launch {
                        config.setAppDisplayName(selectedPackage, displayName)
                        config.setProgramSettings(selectedPackage, draft)
                    }
                },
                enabled = selectedPackage.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(text.save)
            }
        }
    }
}

@Composable
private fun MusicScreen(
    enabledPlatforms: Set<MusicPlatform>,
    activePlatform: MusicPlatform?,
    status: String,
    track: String,
    artist: String,
    album: String,
    isPlaying: Boolean,
    artworkUrl: String?,
    onStartAll: () -> Unit,
    onStopAll: () -> Unit,
    onStartPlatform: (MusicPlatform) -> Unit,
    onStopPlatform: (MusicPlatform) -> Unit,
) {
    val text = LocalizedTextProvider.current
    val stateEnabled = enabledPlatforms.isNotEmpty()
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        InfoCard(text.musicPlatforms) {
            KeyValueRow(text.operation, if (stateEnabled) text.running else text.stopped)
            KeyValueRow(text.discordStatus, presenceStatusText(status, text))
            KeyValueRow(text.enabledPlatforms, enabledPlatforms.joinToString { it.displayName }.ifBlank { text.none })
            Spacer(Modifier.height(10.dp))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = onStartAll, enabled = enabledPlatforms.size < MusicPlatform.entries.size) {
                    Text(text.startAllMusicPlatforms)
                }
                OutlinedButton(onClick = onStopAll, enabled = stateEnabled) {
                    Text(text.stopAll)
                }
            }
        }

        MusicPlatform.entries.forEach { platform ->
            MusicPlatformCard(
                platform = platform,
                enabled = platform in enabledPlatforms,
                isActive = platform == activePlatform && isPlaying,
                track = track,
                artist = artist,
                album = album,
                artworkUrl = artworkUrl,
                onStart = { onStartPlatform(platform) },
                onStop = { onStopPlatform(platform) },
            )
        }

        InfoCard(text.howItWorks) {
            Text(text.mediaSessionDescription)
            Text(text.artworkLookupDescription)
            Text(text.discordMusicDescription)
        }
    }
}

@Composable
private fun MusicPlatformCard(
    platform: MusicPlatform,
    enabled: Boolean,
    isActive: Boolean,
    track: String,
    artist: String,
    album: String,
    artworkUrl: String?,
    onStart: () -> Unit,
    onStop: () -> Unit,
) {
    val text = LocalizedTextProvider.current
    ElevatedCard(shape = RoundedCornerShape(8.dp)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(platform.displayName, fontWeight = FontWeight.SemiBold)
                    Text(
                        platform.packageName,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.MiddleEllipsis,
                    )
                }
                StatusChip(
                    if (isActive) text.playing else if (enabled) text.running else text.stopped,
                    if (isActive) Color(0xFF00796B) else if (enabled) Color(0xFF2E7D32) else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (isActive) {
                HorizontalDivider()
                KeyValueRow(text.track, track.ifBlank { text.none })
                KeyValueRow(text.artist, artist.ifBlank { text.none })
                KeyValueRow(text.album, album.ifBlank { text.none })
                if (!artworkUrl.isNullOrBlank()) KeyValueRow(text.albumImage, artworkUrl)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = onStart, enabled = !enabled) { Text(text.enable) }
                OutlinedButton(onClick = onStop, enabled = enabled) { Text(text.stop) }
            }
        }
    }
}

@Composable
private fun PermissionsScreen(permissions: PermissionService) {
    val context = LocalContext.current
    val text = LocalizedTextProvider.current
    var refreshKey by remember { mutableStateOf(0) }
    val usageGranted = remember(refreshKey) { permissions.hasUsageAccess() }
    val appNotificationGranted = remember(refreshKey) { permissions.hasPostNotificationsAccess() }
    val notificationGranted = remember(refreshKey) { permissions.hasNotificationListenerAccess() }
    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) {
        refreshKey += 1
    }

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        PermissionCard(
            title = text.usageAccess,
            description = text.usageAccessDescription,
            granted = usageGranted,
            onOpen = { context.startActivity(permissions.usageAccessSettingsIntent()) },
        )
        PermissionCard(
            title = text.appNotificationPermission,
            description = text.appNotificationPermissionDescription,
            granted = appNotificationGranted,
            onOpen = {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                } else {
                    context.startActivity(permissions.appNotificationSettingsIntent())
                }
            },
        )
        PermissionCard(
            title = text.notificationAccess,
            description = text.notificationAccessDescription,
            granted = notificationGranted,
            onOpen = { context.startActivity(permissions.notificationListenerSettingsIntent()) },
        )
        OutlinedButton(onClick = { refreshKey += 1 }) {
            Text(text.refreshPermissionStatus)
        }
    }
}

@Composable
private fun PermissionCard(title: String, description: String, granted: Boolean, onOpen: () -> Unit) {
    val text = LocalizedTextProvider.current
    InfoCard(title) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(if (granted) text.granted else text.required, color = if (granted) Color(0xFF2E7D32) else Color(0xFFC62828))
            StatusChip(if (granted) "OK" else text.settingsRequired, if (granted) Color(0xFF2E7D32) else Color(0xFFC62828))
        }
        Text(description, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(10.dp))
        Button(onClick = onOpen, enabled = !granted) {
            Text(text.openSettings)
        }
    }
}

@Composable
private fun SettingsScreen(settings: AppSettings, config: ConfigUtility) {
    val context = LocalContext.current
    val text = LocalizedTextProvider.current
    val scope = rememberCoroutineScope()
    val permissions = remember { PermissionService(context) }
    val notificationPermissionGranted = remember(settings.showForegroundAppNotification) {
        permissions.hasPostNotificationsAccess()
    }

    InfoCard(text.appSettings) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(text.showForegroundApp, fontWeight = FontWeight.SemiBold)
                Text(
                    text.showForegroundAppDescription,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Switch(
                checked = settings.showForegroundAppIndicator,
                onCheckedChange = { enabled ->
                    scope.launch {
                        config.setSettings(settings.copy(showForegroundAppIndicator = enabled))
                    }
                },
            )
        }
        HorizontalDivider(modifier = Modifier.padding(vertical = 10.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(text.showForegroundAppNotification, fontWeight = FontWeight.SemiBold)
                Text(
                    text.showForegroundAppNotificationDescription,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                if (settings.showForegroundAppNotification && !notificationPermissionGranted) {
                    Text(
                        text.notificationPermissionMissing,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }
            Switch(
                checked = settings.showForegroundAppNotification,
                onCheckedChange = { enabled ->
                    scope.launch {
                        config.setSettings(settings.copy(showForegroundAppNotification = enabled))
                    }
                },
            )
        }
        HorizontalDivider(modifier = Modifier.padding(vertical = 10.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(text.discordAutoConnect, fontWeight = FontWeight.SemiBold)
                Text(
                    if (settings.hasCompletedDiscordOnboarding) {
                        text.discordAutoConnectDescriptionOn
                    } else {
                        text.discordAutoConnectDescriptionOff
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Switch(
                checked = settings.hasCompletedDiscordOnboarding,
                onCheckedChange = { enabled ->
                    scope.launch {
                        config.setSettings(settings.copy(hasCompletedDiscordOnboarding = enabled))
                    }
                },
            )
        }
        HorizontalDivider(modifier = Modifier.padding(vertical = 10.dp))
        Text(text.language)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            AppLanguage.entries.forEach { language ->
                FilterChip(
                    selected = settings.preferredLanguage == language,
                    onClick = {
                        scope.launch {
                            config.setSettings(settings.copy(preferredLanguage = language))
                        }
                    },
                    label = { Text(languageText(language, text)) },
                )
            }
        }
        HorizontalDivider(modifier = Modifier.padding(vertical = 10.dp))
        KeyValueRow(text.registeredPackages, text.countItems(settings.packageNames.size))
        KeyValueRow(text.customPresenceSettings, text.countItems(settings.programSettings.size))
    }
}

@Composable
private fun InfoCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            content()
        }
    }
}

@Composable
private fun MetricCard(title: String, value: String, detail: String, tint: Color, modifier: Modifier = Modifier) {
    Card(modifier = modifier.height(132.dp), shape = RoundedCornerShape(8.dp)) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = tint, maxLines = 1)
            Text(
                detail,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun WarningCard(title: String, message: String) {
    Card(
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(title, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onErrorContainer)
            Text(message, color = MaterialTheme.colorScheme.onErrorContainer)
        }
    }
}

@Composable
private fun KeyValueRow(label: String, value: String) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun StatusChip(text: String, tint: Color) {
    Surface(shape = MaterialTheme.shapes.small, color = tint.copy(alpha = 0.12f)) {
        Text(text, color = tint, modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp), style = MaterialTheme.typography.labelMedium)
    }
}

@Composable
private fun PresenceTextField(label: String, placeholder: String, value: String, onValueChange: (String) -> Unit) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        placeholder = { Text(placeholder) },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun NumberStepper(label: String, value: Int, min: Int, max: Int, onValueChange: (Int) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column {
            Text(label, fontWeight = FontWeight.SemiBold)
            Text("$value", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = { onValueChange((value - 1).coerceAtLeast(min)) }, enabled = value > min) {
                Text("-")
            }
            OutlinedButton(onClick = { onValueChange((value + 1).coerceAtMost(max)) }, enabled = value < max) {
                Text("+")
            }
        }
    }
}

private fun tabTitle(tab: AppTab, text: LocalizedText): String = when (tab) {
    AppTab.OVERVIEW -> text.tabOverview
    AppTab.DISCORD -> text.tabDiscord
    AppTab.PROGRAMS -> text.tabPrograms
    AppTab.PRESENCE -> text.tabPresence
    AppTab.MUSIC -> text.tabMusic
    AppTab.PERMISSIONS -> text.tabPermissions
    AppTab.SETTINGS -> text.tabSettings
}

private fun dashboardStatusText(status: DiscordDashboardStatus, text: LocalizedText): String = when (status) {
    DiscordDashboardStatus.NOT_CONFIGURED -> text.notConfiguredValue
    DiscordDashboardStatus.CONFIGURED -> text.configured
    DiscordDashboardStatus.AUTHORIZING -> text.authorizing
    DiscordDashboardStatus.CONNECTING -> text.connecting
    DiscordDashboardStatus.READY -> text.ready
    DiscordDashboardStatus.UNAUTHORIZED -> text.unauthorized
    DiscordDashboardStatus.FAILED -> text.failed
}

private fun authorizationText(status: DiscordAuthorizationStatus, text: LocalizedText): String = when (status) {
    DiscordAuthorizationStatus.AUTHORIZED -> text.authorized
    DiscordAuthorizationStatus.UNAUTHORIZED -> text.unauthorized
    DiscordAuthorizationStatus.UNKNOWN -> text.unknown
}

private fun presenceStatusText(status: String, text: LocalizedText): String = when (status) {
    "Not Connected" -> text.noConnectedAccount
    "Configuring..." -> text.connecting
    "Configured" -> text.configured
    "Idle" -> text.standby
    "Not Tracked" -> text.untracked
    "Authorization Required" -> text.unauthorized
    "Active" -> text.active
    "Update Failed" -> text.failed
    else -> status
}

private fun statusColor(status: DiscordDashboardStatus): Color = when (status) {
    DiscordDashboardStatus.READY -> Color(0xFF2E7D32)
    DiscordDashboardStatus.CONFIGURED,
    DiscordDashboardStatus.AUTHORIZING,
    DiscordDashboardStatus.CONNECTING -> Color(0xFFEF6C00)
    DiscordDashboardStatus.FAILED,
    DiscordDashboardStatus.UNAUTHORIZED -> Color(0xFFC62828)
    DiscordDashboardStatus.NOT_CONFIGURED -> Color(0xFF616161)
}

private fun activityTypeText(type: DiscordActivity.ActivityType, text: LocalizedText): String = when (type) {
    DiscordActivity.ActivityType.PLAYING -> text.playingActivity
    DiscordActivity.ActivityType.STREAMING -> text.streamingActivity
    DiscordActivity.ActivityType.LISTENING -> text.listeningActivity
    DiscordActivity.ActivityType.WATCHING -> text.watchingActivity
    DiscordActivity.ActivityType.COMPETING -> text.competingActivity
}

private fun languageText(language: AppLanguage, text: LocalizedText): String = when (language) {
    AppLanguage.SYSTEM -> text.languageSystem
    AppLanguage.KOREAN -> text.languageKorean
    AppLanguage.ENGLISH -> text.languageEnglish
    AppLanguage.JAPANESE -> text.languageJapanese
}

private fun maskApplicationId(value: String): String {
    if (value.isBlank()) return ""
    if (value.length <= 6) return "*".repeat(value.length)
    return value.take(3) + "*".repeat(value.length - 6) + value.takeLast(3)
}

private fun appLabel(context: Context, packageName: String): String {
    val packageManager = context.packageManager
    return runCatching {
        val appInfo: ApplicationInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getApplicationInfo(packageName, PackageManager.ApplicationInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.getApplicationInfo(packageName, 0)
        }
        packageManager.getApplicationLabel(appInfo).toString()
    }.getOrDefault(packageName.substringAfterLast('.').ifBlank { packageName })
}

private fun installedApplications(context: Context): List<InstalledAppInfo> {
    val packageManager = context.packageManager
    val applications = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        packageManager.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0))
    } else {
        @Suppress("DEPRECATION")
        packageManager.getInstalledApplications(0)
    }

    return applications
        .mapNotNull { appInfo ->
            val packageName = appInfo.packageName.orEmpty()
            if (packageName.isBlank()) {
                null
            } else {
                val isSystemApp = appInfo.flags and ApplicationInfo.FLAG_SYSTEM != 0 ||
                    appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP != 0
                InstalledAppInfo(
                    label = packageManager.getApplicationLabel(appInfo)?.toString()
                        ?.takeIf { it.isNotBlank() }
                        ?: packageName.substringAfterLast('.'),
                    packageName = packageName,
                    isSystemApp = isSystemApp,
                )
            }
        }
        .distinctBy { it.packageName }
        .sortedWith(
            compareBy<InstalledAppInfo> { it.label.lowercase() }
                .thenBy { it.packageName },
        )
}

@Preview(showBackground = true)
@Composable
private fun CraftPresencePreview() {
    MaterialTheme {
        Header(
            title = "CraftPresence",
            subtitle = "Android에서 앱과 음악 상태를 Discord Rich Presence로 보냅니다.",
        )
    }
}
