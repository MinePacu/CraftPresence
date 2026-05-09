package com.minepacu.craftpresence

import android.Manifest
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Bundle
import androidx.activity.SystemBarStyle
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.lifecycle.lifecycleScope
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.layout.ContentScale
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
import androidx.compose.material3.NavigationRail
import androidx.compose.material3.NavigationRailItem
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
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Apps
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.FileDownload
import androidx.compose.material.icons.filled.FileUpload
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.runtime.CompositionLocalProvider
import com.discord.socialsdk.DiscordSocialSdkInit
import com.minepacu.craftpresence.core.config.AppLanguage
import com.minepacu.craftpresence.core.config.AppSettings
import com.minepacu.craftpresence.core.config.AppliedPresencePayload
import com.minepacu.craftpresence.core.config.ConfigUtility
import com.minepacu.craftpresence.core.config.PresencePreset
import com.minepacu.craftpresence.core.config.ProgramPresenceSettings
import com.minepacu.craftpresence.core.discord.DiscordActivity
import com.minepacu.craftpresence.core.discord.DiscordAppConfig
import com.minepacu.craftpresence.core.discord.DiscordAuthorizationStatus
import com.minepacu.craftpresence.core.discord.DiscordDashboardStatus
import com.minepacu.craftpresence.core.discord.DiscordPresenceSource
import com.minepacu.craftpresence.core.discord.DiscordSdkManager
import com.minepacu.craftpresence.core.media.MusicPlatform
import com.minepacu.craftpresence.core.permissions.PermissionService
import com.minepacu.craftpresence.core.presence.AppleMusicPresenceManager
import com.minepacu.craftpresence.core.presence.ProgramPresenceManager
import com.minepacu.craftpresence.core.programs.ProgramDetector
import com.minepacu.craftpresence.core.programs.ForegroundAppMonitorService
import com.minepacu.craftpresence.ui.localization.LocalizedText
import com.minepacu.craftpresence.ui.localization.LocalizedTextProvider
import com.minepacu.craftpresence.ui.localization.rememberLocalizedText
import com.minepacu.craftpresence.ui.theme.CraftPresenceTheme
import androidx.core.graphics.drawable.toBitmap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.URL
import java.nio.charset.Charset
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

internal val LightStatusBarScrim: Int = 0xE6FBFDF8.toInt()
internal val DarkStatusBarScrim: Int = 0xE6101411.toInt()

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        DiscordSocialSdkInit.setEngineActivity(this)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.auto(
                lightScrim = LightStatusBarScrim,
                darkScrim = DarkStatusBarScrim,
            ),
            navigationBarStyle = SystemBarStyle.auto(
                lightScrim = android.graphics.Color.TRANSPARENT,
                darkScrim = android.graphics.Color.TRANSPARENT,
            ),
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
        setContent {
            CraftPresenceTheme {
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
    PRESENCE(Icons.Filled.Edit),
    MUSIC(Icons.Filled.MusicNote),
    SETTINGS(Icons.Filled.Settings),
}

private enum class SettingsPanel {
    MAIN,
    DISCORD,
    PROGRAMS,
    PERMISSIONS,
}

private const val UI_DETECTOR_OWNER = "craftpresence-ui"

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
    val permissions = remember { PermissionService(context) }

    val settings by config.settings.collectAsState()
    val discordState by discord.state.collectAsState()
    val programState by programPresence.state.collectAsState()
    val musicState by musicPresence.state.collectAsState()
    val foreground by detector.updates.collectAsState()

    var selectedTab by remember { mutableStateOf(AppTab.OVERVIEW) }
    var settingsPanel by remember { mutableStateOf(SettingsPanel.MAIN) }
    var showDiscordOnboarding by remember { mutableStateOf(false) }
    var discordOnboardingSkippedForLaunch by remember { mutableStateOf(false) }
    var automaticDiscordMessage by remember { mutableStateOf("") }
    var showInstalledAppPicker by remember { mutableStateOf(false) }
    var installedAppSearch by remember { mutableStateOf("") }
    var installedApps by remember { mutableStateOf(emptyList<InstalledAppInfo>()) }
    var installedAppsLoading by remember { mutableStateOf(false) }
    var showSystemApps by remember { mutableStateOf(true) }
    val foregroundDisplayEnabled = settings.showForegroundAppIndicator
    val foregroundNotificationEnabled = settings.showForegroundAppNotification
    val shouldRunProgramPresence = settings.programPresenceEnabled &&
        settings.packageNames.isNotEmpty() &&
        settings.hasCompletedDiscordOnboarding
    val shouldRunBackgroundForegroundMonitor = foregroundNotificationEnabled || shouldRunProgramPresence
    val text = rememberLocalizedText(settings.preferredLanguage)
    val scope = rememberCoroutineScope()
    val statusBarTopPadding = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val discordConnected = discordState.authorizationStatus == DiscordAuthorizationStatus.AUTHORIZED ||
        discordState.dashboardStatus == DiscordDashboardStatus.READY
    val discordConnectionInProgress = discordState.dashboardStatus == DiscordDashboardStatus.AUTHORIZING ||
        discordState.dashboardStatus == DiscordDashboardStatus.CONNECTING
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
        runCatching {
            discord.configure(
                autoAuthorize = true,
                allowInteractiveAuthorization = false,
            )
        }.onSuccess {
            automaticDiscordMessage = ""
        }.onFailure {
            automaticDiscordMessage = if (settings.hasCompletedDiscordOnboarding) {
                it.message ?: text.discordAutoConnectFailed
            } else {
                ""
            }
        }
    }

    LaunchedEffect(discordConnected, discordConnectionInProgress, discordOnboardingSkippedForLaunch) {
        showDiscordOnboarding = !discordConnected &&
            !discordConnectionInProgress &&
            !discordOnboardingSkippedForLaunch
        if (discordConnected) {
            discordOnboardingSkippedForLaunch = false
        }
    }

    LaunchedEffect(foregroundDisplayEnabled, shouldRunBackgroundForegroundMonitor) {
        if (foregroundDisplayEnabled && !shouldRunBackgroundForegroundMonitor) {
            detector.start(UI_DETECTOR_OWNER)
        } else {
            detector.stop(UI_DETECTOR_OWNER)
        }
    }

    LaunchedEffect(shouldRunProgramPresence, programState.isEnabled) {
        if (shouldRunProgramPresence) {
            programPresence.startMonitoring()
        } else if (programState.isEnabled) {
            programPresence.stopMonitoring()
        }
    }

    LaunchedEffect(shouldRunBackgroundForegroundMonitor) {
        ForegroundAppMonitorService.setEnabled(context, shouldRunBackgroundForegroundMonitor)
    }

    DisposableEffect(Unit) {
        onDispose {
            detector.stop(UI_DETECTOR_OWNER)
        }
    }

    CompositionLocalProvider(LocalizedTextProvider provides text) {
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val useNavigationRail = maxWidth >= 600.dp
            val contentMaxWidth = if (useNavigationRail) 920.dp else maxWidth
            val horizontalContentPadding = if (useNavigationRail) 24.dp else 18.dp
            val verticalContentPadding = if (useNavigationRail) 24.dp else 18.dp
            val selectTab: (AppTab) -> Unit = { tab ->
                selectedTab = tab
                if (tab == AppTab.SETTINGS) {
                    settingsPanel = SettingsPanel.MAIN
                }
            }

            Scaffold(
                containerColor = MaterialTheme.colorScheme.background,
                contentWindowInsets = WindowInsets(0.dp),
                bottomBar = {
                    if (!useNavigationRail) {
                        AppBottomNavigation(
                            selectedTab = selectedTab,
                            onSelectTab = selectTab,
                        )
                    }
                },
            ) { innerPadding ->
                Row(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(innerPadding),
                ) {
                    if (useNavigationRail) {
                        AppNavigationRail(
                            selectedTab = selectedTab,
                            onSelectTab = selectTab,
                            topPadding = statusBarTopPadding,
                        )
                    }
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight(),
                        contentAlignment = Alignment.TopCenter,
                    ) {
                        LazyColumn(
                            modifier = Modifier
                                .fillMaxHeight()
                                .fillMaxWidth()
                                .widthIn(max = contentMaxWidth),
                            contentPadding = PaddingValues(
                                start = horizontalContentPadding,
                                top = statusBarTopPadding + verticalContentPadding,
                                end = horizontalContentPadding,
                                bottom = verticalContentPadding,
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
                            currentActivity = discordState.currentActivity,
                            currentActivitySource = discordState.currentActivitySource,
                            programEnabled = programState.isEnabled,
                            musicEnabled = musicState.isEnabled,
                            foregroundDisplayEnabled = foregroundDisplayEnabled,
                            foregroundApp = if (foregroundDisplayEnabled) foreground.appName.orEmpty() else "",
                            foregroundPackage = if (foregroundDisplayEnabled) foreground.packageName.orEmpty() else "",
                            foregroundTracked = foregroundDisplayEnabled && foreground.packageName in settings.packageNames,
                            musicTrack = musicState.currentTrack,
                            musicArtist = musicState.currentArtist,
                            lastError = discordState.lastErrorMessage,
                            onOpenDiscord = {
                                selectedTab = AppTab.SETTINGS
                                settingsPanel = SettingsPanel.DISCORD
                            },
                            onOpenPrograms = {
                                selectedTab = AppTab.SETTINGS
                                settingsPanel = SettingsPanel.PROGRAMS
                            },
                            onOpenSettings = {
                                selectedTab = AppTab.SETTINGS
                                settingsPanel = SettingsPanel.MAIN
                            },
                            onOpenPresence = { selectedTab = AppTab.PRESENCE },
                        )
                    }
                }

                AppTab.PRESENCE -> {
                    item {
                        PresenceScreen(
                            settings = settings,
                            currentPackageName = foreground.packageName.orEmpty(),
                            currentAppName = foreground.appName.orEmpty(),
                            config = config,
                            discord = discord,
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

                AppTab.SETTINGS -> {
                    when (settingsPanel) {
                        SettingsPanel.MAIN -> {
                            item {
                                SettingsHomeScreen(
                                    settings = settings,
                                    config = config,
                                    onOpenDiscord = { settingsPanel = SettingsPanel.DISCORD },
                                    onOpenPrograms = { settingsPanel = SettingsPanel.PROGRAMS },
                                    onOpenPermissions = { settingsPanel = SettingsPanel.PERMISSIONS },
                                )
                            }
                        }
                        SettingsPanel.DISCORD -> {
                            item {
                                SettingsSubpageHeader(
                                    title = text.tabDiscord,
                                    onBack = { settingsPanel = SettingsPanel.MAIN },
                                )
                            }
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
                                    onDisconnect = {
                                        discordOnboardingSkippedForLaunch = true
                                    },
                                )
                            }
                        }
                        SettingsPanel.PROGRAMS -> {
                            item {
                                SettingsSubpageHeader(
                                    title = text.tabPrograms,
                                    onBack = {
                                        settingsPanel = SettingsPanel.MAIN
                                        showInstalledAppPicker = false
                                    },
                                )
                            }
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
                        SettingsPanel.PERMISSIONS -> {
                            item {
                                SettingsSubpageHeader(
                                    title = text.tabPermissions,
                                    onBack = { settingsPanel = SettingsPanel.MAIN },
                                )
                            }
                            item {
                                PermissionsScreen(permissions = permissions)
                            }
                        }
                    }
                }
                        }
                    }
                }
            }
        }
        }

        if (showDiscordOnboarding) {
            DiscordOnboardingScreen(
                context = context,
                manager = discord,
                config = config,
                settings = settings,
                status = discordState.dashboardStatus,
                lastError = discordState.lastErrorMessage,
                onConnected = {
                    discordOnboardingSkippedForLaunch = false
                    showDiscordOnboarding = false
                },
                onSkip = {
                    discordOnboardingSkippedForLaunch = true
                    showDiscordOnboarding = false
                },
            )
        }
    }
}

@Composable
private fun AppBottomNavigation(
    selectedTab: AppTab,
    onSelectTab: (AppTab) -> Unit,
) {
    val text = LocalizedTextProvider.current
    NavigationBar {
        AppTab.entries.forEach { tab ->
            val title = tabTitle(tab, text)
            NavigationBarItem(
                selected = selectedTab == tab,
                onClick = { onSelectTab(tab) },
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
}

@Composable
private fun AppNavigationRail(
    selectedTab: AppTab,
    onSelectTab: (AppTab) -> Unit,
    topPadding: Dp,
) {
    val text = LocalizedTextProvider.current
    NavigationRail(
        modifier = Modifier
            .fillMaxHeight()
            .padding(top = topPadding),
    ) {
        AppTab.entries.forEach { tab ->
            val title = tabTitle(tab, text)
            NavigationRailItem(
                selected = selectedTab == tab,
                onClick = { onSelectTab(tab) },
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
private fun DiscordOnboardingScreen(
    context: Context,
    manager: DiscordSdkManager,
    config: ConfigUtility,
    settings: AppSettings,
    status: DiscordDashboardStatus,
    lastError: String?,
    onConnected: () -> Unit,
    onSkip: () -> Unit,
) {
    val text = LocalizedTextProvider.current
    val scope = rememberCoroutineScope()
    var actionMessage by remember { mutableStateOf("") }
    val applicationId = remember { DiscordAppConfig.applicationId(context).orEmpty() }
    val validationMessage = remember(applicationId) {
        DiscordAppConfig.validationError(applicationId)?.message
    }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(
                    start = 22.dp,
                    top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + 28.dp,
                    end = 22.dp,
                    bottom = 28.dp,
                ),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Surface(
                    shape = RoundedCornerShape(18.dp),
                    color = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                ) {
                    Icon(
                        imageVector = Icons.Filled.SportsEsports,
                        contentDescription = null,
                        modifier = Modifier
                            .padding(18.dp)
                            .size(42.dp),
                    )
                }
                Text(
                    text.discordOnboardingTitle,
                    style = MaterialTheme.typography.headlineLarge,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text.discordOnboardingBody,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                AssistChip(
                    onClick = {},
                    label = { Text(text.discordOnboardingPriority) },
                )
            }

            InfoCard(text.discordConnect) {
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

            InfoCard(text.requirements) {
                Text(text.discordRequirementInstalled)
                Text(text.discordRequirementApplicationId)
                Text(text.discordRequirementRichPresence)
            }

            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
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
                                onConnected()
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
                TextButton(onClick = onSkip) {
                    Text(text.later)
                }
            }
        }
    }
}

@Composable
private fun OverviewScreen(
    settings: AppSettings,
    discordStatus: DiscordDashboardStatus,
    discordUser: String?,
    currentActivity: DiscordActivity?,
    currentActivitySource: DiscordPresenceSource,
    programEnabled: Boolean,
    musicEnabled: Boolean,
    foregroundDisplayEnabled: Boolean,
    foregroundApp: String,
    foregroundPackage: String,
    foregroundTracked: Boolean,
    musicTrack: String,
    musicArtist: String,
    lastError: String?,
    onOpenDiscord: () -> Unit,
    onOpenPrograms: () -> Unit,
    onOpenSettings: () -> Unit,
    onOpenPresence: () -> Unit,
) {
    val text = LocalizedTextProvider.current
    val discordReady = discordStatus == DiscordDashboardStatus.READY
    val hasRegisteredApps = settings.packageNames.isNotEmpty()
    val primaryAction = when {
        !discordReady -> OverviewAction(
            title = text.discordConnect,
            detail = text.discordOnboardingBody,
            button = if (settings.hasCompletedDiscordOnboarding) text.reconnect else text.connectAccount,
            onClick = onOpenDiscord,
        )
        !hasRegisteredApps -> OverviewAction(
            title = text.appToRegister,
            detail = text.appRegistrationDescription,
            button = text.chooseInstalledApp,
            onClick = onOpenPrograms,
        )
        !foregroundDisplayEnabled -> OverviewAction(
            title = text.showForegroundApp,
            detail = text.showForegroundAppDescription,
            button = text.tabSettings,
            onClick = onOpenSettings,
        )
        else -> OverviewAction(
            title = text.presenceCustomizer,
            detail = text.presenceCustomizerDescription,
            button = text.tabPresence,
            onClick = onOpenPresence,
        )
    }

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        OverviewActionCard(primaryAction)

        InfoCard(text.requirements) {
            ChecklistRow(
                title = "Discord",
                detail = discordUser ?: dashboardStatusText(discordStatus, text),
                complete = discordReady,
            )
            ChecklistRow(
                title = text.registeredApps,
                detail = text.countItems(settings.packageNames.size),
                complete = hasRegisteredApps,
            )
            ChecklistRow(
                title = text.showForegroundApp,
                detail = if (foregroundDisplayEnabled) text.on else text.off,
                complete = foregroundDisplayEnabled,
            )
            ChecklistRow(
                title = text.appRichPresence,
                detail = if (programEnabled) text.running else text.stopped,
                complete = programEnabled,
            )
        }

        InfoCard(text.actions) {
            OverviewShortcutRow(
                icon = Icons.Filled.SportsEsports,
                title = text.tabDiscord,
                detail = discordUser ?: dashboardStatusText(discordStatus, text),
                onClick = onOpenDiscord,
            )
            HorizontalDivider()
            OverviewShortcutRow(
                icon = Icons.Filled.Apps,
                title = text.registeredApps,
                detail = text.countItems(settings.packageNames.size),
                onClick = onOpenPrograms,
            )
            HorizontalDivider()
            OverviewShortcutRow(
                icon = Icons.Filled.Settings,
                title = text.tabSettings,
                detail = if (foregroundDisplayEnabled) text.showForegroundApp else text.setupHealthNeedsAttention,
                onClick = onOpenSettings,
            )
            HorizontalDivider()
            OverviewShortcutRow(
                icon = Icons.Filled.Edit,
                title = text.tabPresence,
                detail = text.presenceCustomizerDescription,
                onClick = onOpenPresence,
            )
        }

        InfoCard(text.actualPresence) {
            KeyValueRow(text.discordStatus, dashboardStatusText(discordStatus, text))
            if (!discordReady) {
                Text(text.presenceDisconnected, color = MaterialTheme.colorScheme.onSurfaceVariant)
            } else if (currentActivity == null) {
                Text(text.inactivePresence, color = MaterialTheme.colorScheme.onSurfaceVariant)
            } else {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(text.presenceSource, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    StatusChip(
                        text = presenceSourceText(currentActivitySource, text),
                        tint = presenceSourceTint(currentActivitySource),
                    )
                }
                KeyValueRow(text.activityType, activityTypeText(currentActivity.activityType, text))
                KeyValueRow(text.displayName, optionalPresenceValue(currentActivity.name, text))
                KeyValueRow(text.detailText, optionalPresenceValue(currentActivity.details, text))
                KeyValueRow(text.stateText, optionalPresenceValue(currentActivity.state, text))
                HorizontalDivider()
                Text(text.timestamps, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                KeyValueRow(text.startTimestamp, timestampPresenceText(currentActivity.startEpochSeconds, text))
                KeyValueRow(text.endTimestamp, timestampPresenceText(currentActivity.endEpochSeconds, text))
                HorizontalDivider()
                KeyValueRow(
                    text.largeImage,
                    imagePresenceText(
                        key = currentActivity.largeImageKey,
                        hoverText = currentActivity.largeImageText,
                        text = text,
                    ),
                )
                KeyValueRow(
                    text.smallImage,
                    imagePresenceText(
                        key = currentActivity.smallImageKey,
                        hoverText = currentActivity.smallImageText,
                        text = text,
                    ),
                )
            }
        }

        InfoCard(text.currentPresence) {
            KeyValueRow(text.discordStatus, dashboardStatusText(discordStatus, text))
            KeyValueRow(text.currentApp, if (foregroundDisplayEnabled) foregroundApp.ifBlank { text.unknown } else text.hidden)
            KeyValueRow(text.registrationStatus, if (!foregroundDisplayEnabled) text.hidden else if (foregroundTracked) text.tracked else text.untracked)
            KeyValueRow(
                text.music,
                if (musicTrack.isBlank()) {
                    if (musicEnabled) text.active else text.standby
                } else {
                    "$musicTrack - $musicArtist"
                },
            )
        }

        InfoCard(text.currentDetectionInfo) {
            KeyValueRow(text.display, if (foregroundDisplayEnabled) text.on else text.off)
            KeyValueRow(text.appName, if (foregroundDisplayEnabled) foregroundApp.ifBlank { text.unknown } else text.hidden)
            KeyValueRow(text.packageName, if (foregroundDisplayEnabled) foregroundPackage.ifBlank { text.unknown } else text.hidden)
            KeyValueRow(text.registrationStatus, if (!foregroundDisplayEnabled) text.hidden else if (foregroundTracked) text.tracked else text.untracked)
        }

        if (!lastError.isNullOrBlank()) {
            WarningCard(title = text.lastError, message = lastError)
        }
    }
}

@Composable
private fun OverviewShortcutRow(
    icon: ImageVector,
    title: String,
    detail: String,
    onClick: () -> Unit,
) {
    Surface(
        onClick = onClick,
        color = Color.Transparent,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier.padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Surface(
                shape = RoundedCornerShape(8.dp),
                color = MaterialTheme.colorScheme.surfaceVariant,
                contentColor = MaterialTheme.colorScheme.onSurfaceVariant,
            ) {
                Icon(icon, contentDescription = null, modifier = Modifier.padding(10.dp).size(20.dp))
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(title, fontWeight = FontWeight.SemiBold)
                Text(
                    detail,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Text("›", style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

private data class OverviewAction(
    val title: String,
    val detail: String,
    val button: String,
    val onClick: () -> Unit,
)

@Composable
private fun OverviewActionCard(action: OverviewAction) {
    val text = LocalizedTextProvider.current
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(text.actions, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onPrimaryContainer)
            Text(action.title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimaryContainer)
            Text(action.detail, color = MaterialTheme.colorScheme.onPrimaryContainer)
            Button(onClick = action.onClick) {
                Text(action.button)
            }
        }
    }
}

@Composable
private fun ChecklistRow(title: String, detail: String, complete: Boolean) {
    val text = LocalizedTextProvider.current
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, fontWeight = FontWeight.SemiBold)
            Text(detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        StatusChip(
            text = if (complete) text.granted else text.required,
            tint = if (complete) Color(0xFF2E7D32) else Color(0xFFC62828),
        )
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
    onDisconnect: () -> Unit,
) {
    val text = LocalizedTextProvider.current
    val scope = rememberCoroutineScope()
    var message by remember { mutableStateOf("") }
    val applicationId = remember { DiscordAppConfig.applicationId(context).orEmpty() }
    val validationMessage = remember(applicationId) {
        DiscordAppConfig.validationError(applicationId)?.message
    }
    val applicationConfigured = validationMessage == null
    val authorized = authorization == DiscordAuthorizationStatus.AUTHORIZED
    val connecting = status == DiscordDashboardStatus.AUTHORIZING || status == DiscordDashboardStatus.CONNECTING

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        DiscordSetupGuideCard(
            applicationConfigured = applicationConfigured,
            authorized = authorized,
            connected = status == DiscordDashboardStatus.READY,
            status = dashboardStatusText(status, text),
            account = username ?: text.noConnectedAccount,
            validationMessage = validationMessage,
            onConnect = {
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
            connectEnabled = !connecting && applicationConfigured,
        )

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
                    enabled = !connecting && applicationConfigured,
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
                    enabled = authorized,
                ) {
                    Text(text.refreshAccount)
                }
                OutlinedButton(
                    onClick = {
                        scope.launch {
                            manager.logout()
                            config.setSettings(settings.copy(hasCompletedDiscordOnboarding = false))
                            onDisconnect()
                            message = text.discordDisconnected
                        }
                    },
                    enabled = authorized,
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
private fun DiscordSetupGuideCard(
    applicationConfigured: Boolean,
    authorized: Boolean,
    connected: Boolean,
    status: String,
    account: String,
    validationMessage: String?,
    onConnect: () -> Unit,
    connectEnabled: Boolean,
) {
    val text = LocalizedTextProvider.current
    InfoCard(text.requirements) {
        ChecklistRow(
            title = "Application ID",
            detail = validationMessage ?: text.configured,
            complete = applicationConfigured,
        )
        ChecklistRow(
            title = text.authorization,
            detail = authorizationText(
                if (authorized) DiscordAuthorizationStatus.AUTHORIZED else DiscordAuthorizationStatus.UNAUTHORIZED,
                text,
            ),
            complete = authorized,
        )
        ChecklistRow(
            title = text.account,
            detail = account,
            complete = authorized,
        )
        ChecklistRow(
            title = text.discordStatus,
            detail = status,
            complete = connected,
        )
        Button(onClick = onConnect, enabled = connectEnabled) {
            Text(if (connected || authorized) text.reconnect else text.connectAccount)
        }
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
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
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
            AppIconImage(
                packageName = app.packageName,
                label = app.label,
                modifier = Modifier.size(44.dp),
            )
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
                AppIconImage(
                    packageName = packageName,
                    label = displayName,
                    modifier = Modifier.size(44.dp),
                )
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
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
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
                DiscordPresencePreview(
                    appName = displayName.ifBlank { title },
                    packageName = packageName,
                    settings = draft,
                    windowTitle = text.currentPresence,
                )
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
                PartySizeFields(settings = draft, onChange = { draft = it })
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
    discord: DiscordSdkManager,
) {
    val context = LocalContext.current
    val text = LocalizedTextProvider.current
    val scope = rememberCoroutineScope()
    val activePreset = settings.activePresencePresetID?.let { activeID ->
        settings.presencePresets.firstOrNull { it.id == activeID }
    }
    var customDraft by remember {
        mutableStateOf(
            activePreset ?: PresencePreset(
                id = UUID.randomUUID().toString(),
                title = text.customPresenceDefaultTitle,
                details = "",
                state = "",
                isDefault = false,
                updatedAt = iso8601Now(),
            ),
        )
    }
    var presetBeingEdited by remember { mutableStateOf<PresencePreset?>(null) }
    var message by remember { mutableStateOf("") }
    var selectedPackage by remember(settings.packageNames) {
        mutableStateOf(
            currentPackageName
                .takeIf { it in settings.packageNames }
                ?: settings.packageNames.firstOrNull().orEmpty(),
        )
    }
    var draft by remember { mutableStateOf(ProgramPresenceSettings()) }
    var displayName by remember { mutableStateOf("") }
    val selectedSettings = settings.programSettings[selectedPackage] ?: ProgramPresenceSettings()
    val selectedDisplayName = settings.appDisplayNames[selectedPackage]
        ?: selectedPackage.takeIf { it.isNotBlank() }?.let { appLabel(context, it) }
        ?: ""

    fun publishPreset(preset: PresencePreset, activePresetID: String?) {
        scope.launch {
            val now = System.currentTimeMillis() / 1000L
            val normalizedPreset = preset.normalizedForStorage()
            runCatching {
                discord.updateActivity(
                    normalizedPreset.toDiscordActivity(now),
                    DiscordPresenceSource.APP,
                )
                config.setAppliedPresence(AppliedPresencePayload.fromPreset(normalizedPreset, now))
                config.setActivePresencePresetID(activePresetID)
            }.onSuccess {
                if (activePresetID != null) {
                    customDraft = normalizedPreset
                }
                message = text.presetPublished(normalizedPreset.title)
            }.onFailure {
                message = it.message ?: text.discordConnectFailed
            }
        }
    }

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

    LaunchedEffect(activePreset?.id) {
        if (activePreset != null) {
            customDraft = activePreset
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        InfoCard(text.presenceCustomizer) {
            Text(text.customPresenceDescription, color = MaterialTheme.colorScheme.onSurfaceVariant)
            PresencePresetPreview(customDraft)
            HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
            PresencePresetEditorFields(
                preset = customDraft,
                onChange = { customDraft = it.copy(updatedAt = iso8601Now()) },
            )
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(
                    onClick = { publishPreset(customDraft, null) },
                    enabled = customDraft.title.isNotBlank(),
                ) {
                    Text(text.publishNow)
                }
                OutlinedButton(
                    onClick = {
                        scope.launch {
                            val preset = customDraft.copy(
                                id = customDraft.id.takeIf { existingID ->
                                    settings.presencePresets.any { it.id == existingID && !it.isDefault }
                                } ?: UUID.randomUUID().toString(),
                                isDefault = false,
                                updatedAt = iso8601Now(),
                            ).normalizedForStorage()
                            config.upsertPresencePreset(preset)
                            customDraft = preset
                            message = text.presetSaved
                        }
                    },
                    enabled = customDraft.title.isNotBlank(),
                ) {
                    Text(text.saveAsPreset)
                }
                OutlinedButton(
                    onClick = {
                        scope.launch {
                            discord.clearActivity()
                            config.setActivePresencePresetID(null)
                            config.setAppliedPresence(null)
                            message = text.presenceCleared
                        }
                    },
                ) {
                    Text(text.clearPresence)
                }
            }
            HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
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

        InfoCard(text.presetLibrary) {
            Text(text.presetLibraryDescription, color = MaterialTheme.colorScheme.onSurfaceVariant)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(
                    onClick = {
                        presetBeingEdited = PresencePreset(
                            id = UUID.randomUUID().toString(),
                            title = text.newPresetTitle,
                            details = "",
                            state = "",
                            isDefault = false,
                            updatedAt = iso8601Now(),
                        )
                    },
                ) {
                    Text(text.newPreset)
                }
                OutlinedButton(
                    onClick = {
                        scope.launch {
                            config.restoreDefaultPresencePresets()
                            message = text.defaultPresetsRestored
                        }
                    },
                ) {
                    Text(text.restoreDefaultPresets)
                }
            }
            if (settings.presencePresets.isEmpty()) {
                Text(text.noPresets, color = MaterialTheme.colorScheme.onSurfaceVariant)
            } else {
                settings.presencePresets.forEach { preset ->
                    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                    PresencePresetRow(
                        preset = preset,
                        isActive = preset.id == settings.activePresencePresetID,
                        onPublish = { publishPreset(preset, preset.id) },
                        onEdit = { presetBeingEdited = preset },
                        onDelete = {
                            scope.launch {
                                config.removePresencePreset(preset.id)
                                message = text.presetDeleted
                            }
                        },
                    )
                }
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
            DiscordPresencePreview(
                appName = displayName.ifBlank { selectedDisplayName.ifBlank { selectedPackage } },
                packageName = selectedPackage,
                settings = draft,
                windowTitle = currentAppName.ifBlank { text.currentPresence },
            )
            HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
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
            PartySizeFields(settings = draft, onChange = { draft = it })
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

    presetBeingEdited?.let { editing ->
        PresencePresetEditorDialog(
            initialPreset = editing,
            onDismiss = { presetBeingEdited = null },
            onSave = { preset ->
                scope.launch {
                    config.upsertPresencePreset(preset.normalizedForStorage())
                    presetBeingEdited = null
                    message = text.presetSaved
                }
            },
        )
    }
}

@Composable
private fun PresencePresetRow(
    preset: PresencePreset,
    isActive: Boolean,
    onPublish: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    val text = LocalizedTextProvider.current
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Top,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(preset.title.ifBlank { text.newPresetTitle }, fontWeight = FontWeight.SemiBold)
                    if (isActive) {
                        StatusChip(text.activePreset, Color(0xFF2E7D32))
                    }
                }
                Text(
                    preset.details.ifBlank { text.none },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    preset.state.ifBlank { text.none },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            StatusChip(activityTypeText(preset.activityType, text), MaterialTheme.colorScheme.onSurfaceVariant)
        }
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = onPublish) { Text(text.publish) }
            OutlinedButton(onClick = onEdit) { Text(text.editPreset) }
            OutlinedButton(onClick = onDelete, enabled = !preset.isDefault) { Text(text.delete) }
        }
    }
}

@Composable
private fun PresencePresetEditorDialog(
    initialPreset: PresencePreset,
    onDismiss: () -> Unit,
    onSave: (PresencePreset) -> Unit,
) {
    val text = LocalizedTextProvider.current
    var draft by remember(initialPreset) { mutableStateOf(initialPreset) }
    val scroll = rememberScrollState()

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(text.editPreset) },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(scroll),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                PresencePresetPreview(draft)
                PresencePresetEditorFields(
                    preset = draft,
                    onChange = { draft = it.copy(updatedAt = iso8601Now(), isDefault = initialPreset.isDefault) },
                )
            }
        },
        confirmButton = {
            Button(
                onClick = { onSave(draft.copy(updatedAt = iso8601Now())) },
                enabled = draft.title.isNotBlank(),
            ) {
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
private fun PresencePresetEditorFields(
    preset: PresencePreset,
    onChange: (PresencePreset) -> Unit,
) {
    val text = LocalizedTextProvider.current
    PresenceTextField(text.presetTitle, text.newPresetTitle, preset.title) {
        onChange(preset.copy(title = it))
    }
    Text(text.activityType, fontWeight = FontWeight.SemiBold)
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        DiscordActivity.ActivityType.entries.forEach { type ->
            FilterChip(
                selected = preset.activityType == type,
                onClick = { onChange(preset.copy(activityType = type)) },
                label = { Text(activityTypeText(type, text)) },
            )
        }
    }
    PresenceTextField(text.detailText, text.defaultDetailText, preset.details) {
        onChange(preset.copy(details = it))
    }
    PresenceTextField(text.stateText, text.defaultStateText, preset.state) {
        onChange(preset.copy(state = it))
    }
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text.usesElapsedTime)
        Switch(
            checked = preset.usesElapsedTime,
            onCheckedChange = { onChange(preset.copy(usesElapsedTime = it)) },
        )
    }
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text.resetElapsedTimeOnPublish)
        Switch(
            checked = preset.resetsElapsedTimeOnPublish,
            onCheckedChange = { onChange(preset.copy(resetsElapsedTimeOnPublish = it)) },
            enabled = preset.usesElapsedTime,
        )
    }
    PresenceTextField(text.largeImageKeyOrUrl, text.discordAssetKeyOrUrl, preset.largeImageKey) {
        onChange(preset.copy(largeImageKey = it))
    }
    PresenceTextField(text.largeImageText, text.imageHoverText, preset.largeImageText) {
        onChange(preset.copy(largeImageText = it))
    }
    PresenceTextField(text.smallImageKeyOrUrl, text.discordAssetKeyOrUrl, preset.smallImageKey) {
        onChange(preset.copy(smallImageKey = it))
    }
    PresenceTextField(text.smallImageText, text.imageHoverText, preset.smallImageText) {
        onChange(preset.copy(smallImageText = it))
    }
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text.usesParty)
        Switch(
            checked = preset.usesParty,
            onCheckedChange = { onChange(preset.copy(usesParty = it)) },
        )
    }
    if (preset.usesParty) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
            OutlinedTextField(
                value = preset.partyCurrent.toString(),
                onValueChange = { value ->
                    onChange(preset.copy(partyCurrent = value.filter(Char::isDigit).toIntOrNull() ?: 0))
                },
                label = { Text(text.partyCurrent) },
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
            OutlinedTextField(
                value = preset.partyMax.toString(),
                onValueChange = { value ->
                    onChange(preset.copy(partyMax = value.filter(Char::isDigit).toIntOrNull() ?: 0))
                },
                label = { Text(text.partyMax) },
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun PresencePresetPreview(preset: PresencePreset) {
    DiscordPresencePreview(
        appName = preset.title.ifBlank { LocalizedTextProvider.current.customPresenceDefaultTitle },
        packageName = "",
        settings = preset.toProgramPresenceSettings(),
        windowTitle = LocalizedTextProvider.current.currentPresence,
    )
}

@Composable
private fun DiscordPresencePreview(
    appName: String,
    packageName: String,
    settings: ProgramPresenceSettings,
    windowTitle: String,
) {
    val text = LocalizedTextProvider.current
    val resolvedAppName = appName.ifBlank { packageName.ifBlank { text.unknown } }
    val details = renderPresencePreviewText(
        template = settings.detailText.ifBlank { text.defaultDetailText },
        appName = resolvedAppName,
        packageName = packageName,
        windowTitle = windowTitle,
    ).ifBlank { text.defaultDetailText }
    val state = renderPresencePreviewText(
        template = settings.stateText.ifBlank { text.defaultStateText },
        appName = resolvedAppName,
        packageName = packageName,
        windowTitle = windowTitle,
    ).ifBlank { text.defaultStateText }
    val largeImageLabel = when {
        settings.useAppIconForLargeImage -> resolvedAppName.take(1).uppercase()
        settings.largeImageKey.isNotBlank() -> settings.largeImageKey.take(1).uppercase()
        else -> "CP"
    }
    val largeImageText = when {
        settings.useAppIconForLargeImage -> resolvedAppName
        settings.largeImageText.isNotBlank() -> settings.largeImageText
        settings.largeImageKey.isNotBlank() -> settings.largeImageKey
        else -> ""
    }
    val smallImageText = settings.smallImageText.ifBlank { settings.smallImageKey }
    val partyText = when {
        settings.partyCurrent > 0 && settings.partyMax >= settings.partyCurrent -> "$state (${settings.partyCurrent} of ${settings.partyMax})"
        else -> ""
    }
    val discordCardColor = Color(0xFF314D3A)
    val discordTextColor = Color(0xFFF2F7F1)
    val discordMutedTextColor = Color(0xFFC6D0C3)
    val discordGreen = Color(0xFF7AD88F)

    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        color = discordCardColor,
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(7.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    activityTypeText(settings.activityType, text),
                    style = MaterialTheme.typography.labelMedium,
                    color = discordTextColor,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                Text("...", style = MaterialTheme.typography.labelMedium, color = discordMutedTextColor)
            }
            Row(
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.Top,
            ) {
                Box {
                    if (settings.useAppIconForLargeImage) {
                        AppIconImage(
                            packageName = packageName,
                            label = resolvedAppName,
                            modifier = Modifier.size(56.dp),
                            shape = RoundedCornerShape(8.dp),
                        )
                    } else {
                        Surface(
                            modifier = Modifier
                                .size(56.dp)
                                .clip(RoundedCornerShape(8.dp)),
                            color = Color(0xFFE7EEE5),
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Text(
                                    largeImageLabel,
                                    color = discordCardColor,
                                    fontWeight = FontWeight.Bold,
                                )
                            }
                        }
                    }
                    if (settings.smallImageKey.isNotBlank() || settings.smallImageText.isNotBlank()) {
                        Surface(
                            modifier = Modifier
                                .align(Alignment.BottomEnd)
                                .size(20.dp)
                                .clip(CircleShape),
                            color = Color(0xFFE7EEE5),
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Text(
                                    settings.smallImageKey.take(1).uppercase().ifBlank { "S" },
                                    style = MaterialTheme.typography.labelSmall,
                                    color = discordCardColor,
                                    fontWeight = FontWeight.Bold,
                                )
                            }
                        }
                    }
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(resolvedAppName, color = discordTextColor, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(details, style = MaterialTheme.typography.bodySmall, color = discordTextColor, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    if (partyText.isBlank()) {
                        Text(state, style = MaterialTheme.typography.bodySmall, color = discordMutedTextColor, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                    if (largeImageText.isNotBlank()) {
                        Text(largeImageText, style = MaterialTheme.typography.labelSmall, color = discordMutedTextColor, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                    if (smallImageText.isNotBlank()) {
                        Text(smallImageText, style = MaterialTheme.typography.labelSmall, color = discordMutedTextColor, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("00:00:01", style = MaterialTheme.typography.labelSmall, color = discordGreen, maxLines = 1)
                        if (partyText.isNotBlank()) {
                            Text(
                                partyText,
                                style = MaterialTheme.typography.labelSmall,
                                color = discordTextColor,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.weight(1f),
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PartySizeFields(
    settings: ProgramPresenceSettings,
    onChange: (ProgramPresenceSettings) -> Unit,
) {
    val text = LocalizedTextProvider.current
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
        OutlinedTextField(
            value = settings.partyCurrent.toString(),
            onValueChange = { value ->
                onChange(settings.copy(partyCurrent = value.filter(Char::isDigit).toIntOrNull() ?: 0))
            },
            label = { Text(text.partyCurrent) },
            singleLine = true,
            modifier = Modifier.weight(1f),
        )
        OutlinedTextField(
            value = settings.partyMax.toString(),
            onValueChange = { value ->
                onChange(settings.copy(partyMax = value.filter(Char::isDigit).toIntOrNull() ?: 0))
            },
            label = { Text(text.partyMax) },
            singleLine = true,
            modifier = Modifier.weight(1f),
        )
    }
}

private fun renderPresencePreviewText(
    template: String,
    appName: String,
    packageName: String,
    windowTitle: String,
): String = template
    .replace("{app}", appName)
    .replace("{package}", packageName)
    .replace("{title}", windowTitle)
    .trim()

private fun PresencePreset.toProgramPresenceSettings(): ProgramPresenceSettings = ProgramPresenceSettings(
    activityType = activityType,
    presetID = id,
    detailText = details,
    stateText = state,
    useAppIconForLargeImage = false,
    largeImageKey = largeImageKey,
    largeImageText = largeImageText,
    smallImageKey = smallImageKey,
    smallImageText = smallImageText,
    resetElapsedTimeOnPresenceChange = resetsElapsedTimeOnPublish,
    partyCurrent = if (usesParty) partyCurrent else 0,
    partyMax = if (usesParty) partyMax else 0,
)

private fun PresencePreset.normalizedForStorage(): PresencePreset = copy(
    title = title.trim().ifBlank { "Custom Presence" },
    details = details.trim(),
    state = state.trim(),
    largeImageKey = largeImageKey.trim(),
    largeImageText = largeImageText.trim(),
    smallImageKey = smallImageKey.trim(),
    smallImageText = smallImageText.trim(),
    partyCurrent = partyCurrent.coerceAtLeast(0),
    partyMax = partyMax.coerceAtLeast(0),
    updatedAt = updatedAt.ifBlank { iso8601Now() },
)

private fun iso8601Now(): String {
    return SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }.format(Date())
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
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
                    AlbumArtworkImage(
                        artworkUrl = artworkUrl,
                        fallbackLabel = platform.displayName,
                        modifier = Modifier.size(72.dp),
                    )
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        KeyValueRow(text.track, track.ifBlank { text.none })
                        KeyValueRow(text.artist, artist.ifBlank { text.none })
                        KeyValueRow(text.album, album.ifBlank { text.none })
                    }
                }
            }
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = onStart, enabled = !enabled) { Text(text.enable) }
                OutlinedButton(onClick = onStop, enabled = enabled) { Text(text.stop) }
            }
        }
    }
}

@Composable
private fun SetupHealthCard(
    title: String,
    message: String,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
    complete: Boolean,
) {
    val container = if (complete) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.primaryContainer
    val content = if (complete) MaterialTheme.colorScheme.onSecondaryContainer else MaterialTheme.colorScheme.onPrimaryContainer
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = container),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(title, style = MaterialTheme.typography.labelLarge, color = content)
            Text(message, style = MaterialTheme.typography.bodyMedium, color = content)
            if (actionLabel != null && onAction != null) {
                Button(onClick = onAction) {
                    Text(actionLabel)
                }
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
    val permissionAction = when {
        !usageGranted -> PermissionSetupAction(
            title = text.usageAccess,
            detail = text.usageAccessDescription,
            destination = text.usageAccessSettingsDestination,
            onOpen = { context.startActivity(permissions.usageAccessSettingsIntent()) },
        )
        !appNotificationGranted -> PermissionSetupAction(
            title = text.appNotificationPermission,
            detail = text.appNotificationPermissionDescription,
            destination = text.appNotificationSettingsDestination,
            onOpen = {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                } else {
                    context.startActivity(permissions.appNotificationSettingsIntent())
                }
            },
        )
        !notificationGranted -> PermissionSetupAction(
            title = text.notificationAccess,
            detail = text.notificationAccessDescription,
            destination = text.notificationAccessSettingsDestination,
            onOpen = { context.startActivity(permissions.notificationListenerSettingsIntent()) },
        )
        else -> null
    }

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        SetupHealthCard(
            title = if (permissionAction == null) text.setupHealth else text.nextRequiredPermission,
            message = permissionAction?.destination ?: text.permissionReadyMessage,
            actionLabel = permissionAction?.let { text.openSettings },
            onAction = permissionAction?.onOpen,
            complete = permissionAction == null,
        )
        PermissionSetupGuideCard(
            usageGranted = usageGranted,
            appNotificationGranted = appNotificationGranted,
            notificationGranted = notificationGranted,
            action = permissionAction,
        )
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
private fun PermissionSetupGuideCard(
    usageGranted: Boolean,
    appNotificationGranted: Boolean,
    notificationGranted: Boolean,
    action: PermissionSetupAction?,
) {
    val text = LocalizedTextProvider.current
    InfoCard(text.requirements) {
        ChecklistRow(
            title = text.usageAccess,
            detail = text.usageAccessDescription,
            complete = usageGranted,
        )
        ChecklistRow(
            title = text.appNotificationPermission,
            detail = text.appNotificationPermissionDescription,
            complete = appNotificationGranted,
        )
        ChecklistRow(
            title = text.notificationAccess,
            detail = text.notificationAccessDescription,
            complete = notificationGranted,
        )
        HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
        if (action == null) {
            Text(text.granted, color = Color(0xFF2E7D32), fontWeight = FontWeight.SemiBold)
        } else {
            Text(action.title, fontWeight = FontWeight.SemiBold)
            Text(action.detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(action.destination, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(text.permissionReturnHint, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Button(onClick = action.onOpen) {
                Text(text.openSettings)
            }
        }
    }
}

private data class PermissionSetupAction(
    val title: String,
    val detail: String,
    val destination: String,
    val onOpen: () -> Unit,
)

@Composable
private fun PermissionCard(title: String, description: String, granted: Boolean, onOpen: () -> Unit) {
    val text = LocalizedTextProvider.current
    InfoCard(title) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                if (granted) text.granted else text.required,
                color = if (granted) Color(0xFF2E7D32) else Color(0xFFC62828),
                modifier = Modifier.weight(1f),
            )
            StatusChip(if (granted) text.granted else text.settingsRequired, if (granted) Color(0xFF2E7D32) else Color(0xFFC62828))
        }
        Text(description, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(10.dp))
        Button(onClick = onOpen, enabled = !granted) {
            Text(text.openSettings)
        }
    }
}

@Composable
private fun SettingsHomeScreen(
    settings: AppSettings,
    config: ConfigUtility,
    onOpenDiscord: () -> Unit,
    onOpenPrograms: () -> Unit,
    onOpenPermissions: () -> Unit,
) {
    val context = LocalContext.current
    val text = LocalizedTextProvider.current
    val permissions = remember { PermissionService(context) }
    val missingPermissionCount = listOf(
        permissions.hasUsageAccess(),
        permissions.hasPostNotificationsAccess(),
        permissions.hasNotificationListenerAccess(),
    ).count { !it }
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        SetupHealthCard(
            title = text.setupHealth,
            message = if (missingPermissionCount == 0) text.setupHealthReady else text.setupHealthNeedsAttention,
            actionLabel = if (missingPermissionCount == 0) null else text.continueSetup,
            onAction = if (missingPermissionCount == 0) null else onOpenPermissions,
            complete = missingPermissionCount == 0,
        )
        InfoCard(text.settingsDestinations) {
            SettingsDestinationRow(
                icon = Icons.Filled.SportsEsports,
                title = text.tabDiscord,
                description = text.discordSettingsDescription,
                status = if (settings.hasCompletedDiscordOnboarding) text.configured else text.required,
                statusTint = if (settings.hasCompletedDiscordOnboarding) Color(0xFF2E7D32) else Color(0xFFC62828),
                onClick = onOpenDiscord,
            )
            HorizontalDivider()
            SettingsDestinationRow(
                icon = Icons.Filled.Apps,
                title = text.tabPrograms,
                description = text.trackedAppsSettingsDescription,
                status = text.countItems(settings.packageNames.size),
                statusTint = if (settings.packageNames.isNotEmpty()) Color(0xFF2E7D32) else MaterialTheme.colorScheme.onSurfaceVariant,
                onClick = onOpenPrograms,
            )
            HorizontalDivider()
            SettingsDestinationRow(
                icon = Icons.Filled.Security,
                title = text.tabPermissions,
                description = text.permissionsSettingsDescription,
                status = if (missingPermissionCount == 0) text.granted else text.settingsRequired,
                statusTint = if (missingPermissionCount == 0) Color(0xFF2E7D32) else Color(0xFFC62828),
                onClick = onOpenPermissions,
            )
            HorizontalDivider()
            SettingsDestinationRow(
                icon = Icons.Filled.FileUpload,
                title = text.backupAndRestore,
                description = text.backupAndRestoreDescription,
                status = text.settingsImportExport,
                statusTint = MaterialTheme.colorScheme.onSurfaceVariant,
                onClick = {},
                enabled = false,
            )
        }
        SettingsScreen(settings = settings, config = config)
    }
}

@Composable
private fun SettingsDestinationRow(
    icon: ImageVector,
    title: String,
    description: String,
    status: String,
    statusTint: Color,
    onClick: () -> Unit,
    enabled: Boolean = true,
) {
    val contentAlpha = if (enabled) 1f else 0.62f
    Surface(
        onClick = onClick,
        enabled = enabled,
        color = Color.Transparent,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier.padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Surface(
                shape = RoundedCornerShape(8.dp),
                color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = contentAlpha),
                contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
            ) {
                Icon(icon, contentDescription = null, modifier = Modifier.padding(10.dp).size(20.dp))
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(title, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface.copy(alpha = contentAlpha))
                Text(
                    description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = contentAlpha),
                )
            }
            StatusChip(status, statusTint.copy(alpha = contentAlpha))
            if (enabled) {
                Text("›", style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun SettingsSubpageHeader(title: String, onBack: () -> Unit) {
    val text = LocalizedTextProvider.current
    InfoCard(title) {
        OutlinedButton(onClick = onBack) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = text.tabSettings)
            Spacer(Modifier.width(6.dp))
            Text(text.tabSettings)
        }
    }
}

@Composable
private fun SettingsScreen(settings: AppSettings, config: ConfigUtility) {
    val context = LocalContext.current
    val text = LocalizedTextProvider.current
    val scope = rememberCoroutineScope()
    var pendingSettingsImport by remember { mutableStateOf<String?>(null) }
    var showingImportConfirmation by remember { mutableStateOf(false) }
    var settingsTransferMessage by remember { mutableStateOf("") }
    val permissions = remember { PermissionService(context) }
    val notificationPermissionGranted = remember(settings.showForegroundAppNotification) {
        permissions.hasPostNotificationsAccess()
    }
    val settingsExporter = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.CreateDocument("application/json"),
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            runCatching {
                val backup = config.exportSettingsBackup()
                withContext(Dispatchers.IO) {
                    context.contentResolver.openOutputStream(uri)?.use { output ->
                        output.write(backup.toByteArray(Charsets.UTF_8))
                    } ?: throw IllegalStateException(text.settingsExportOpenFailed)
                }
            }.onSuccess {
                settingsTransferMessage = text.settingsExportSuccess
            }.onFailure {
                settingsTransferMessage = it.message ?: text.settingsTransferError
            }
        }
    }
    val settingsImporter = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            runCatching {
                val raw = withContext(Dispatchers.IO) {
                    context.contentResolver.openInputStream(uri)?.use { input ->
                        input.readBytes().toString(Charset.forName("UTF-8"))
                    } ?: throw IllegalStateException(text.settingsImportOpenFailed)
                }
                ConfigUtility.decodeSettingsBackup(raw)
                pendingSettingsImport = raw
                showingImportConfirmation = true
            }.onFailure {
                settingsTransferMessage = it.message ?: text.settingsTransferError
            }
        }
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
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(text.resetElapsedTimeOnScheduledPresetRestore, fontWeight = FontWeight.SemiBold)
                Text(
                    text.resetElapsedTimeOnScheduledPresetRestoreDescription,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Switch(
                checked = settings.resetElapsedTimeOnScheduledPresetRestore,
                onCheckedChange = { enabled ->
                    scope.launch {
                        config.setSettings(settings.copy(resetElapsedTimeOnScheduledPresetRestore = enabled))
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

    InfoCard(text.settingsImportExport) {
        Text(
            text.settingsImportExportDescription,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(
                onClick = {
                    settingsExporter.launch(ConfigUtility.defaultSettingsBackupFilename())
                },
            ) {
                Icon(Icons.Filled.FileUpload, contentDescription = null)
                Spacer(Modifier.width(6.dp))
                Text(text.settingsExport)
            }
            OutlinedButton(
                onClick = {
                    settingsImporter.launch(arrayOf("application/json", "text/json", "application/octet-stream"))
                },
            ) {
                Icon(Icons.Filled.FileDownload, contentDescription = null)
                Spacer(Modifier.width(6.dp))
                Text(text.settingsImport)
            }
        }
    }

    if (showingImportConfirmation) {
        AlertDialog(
            onDismissRequest = {
                showingImportConfirmation = false
                pendingSettingsImport = null
            },
            title = { Text(text.settingsImportConfirmTitle) },
            text = { Text(text.settingsImportConfirmMessage) },
            confirmButton = {
                Button(
                    onClick = {
                        val raw = pendingSettingsImport
                        showingImportConfirmation = false
                        pendingSettingsImport = null
                        if (raw != null) {
                            scope.launch {
                                runCatching {
                                    config.importSettingsBackup(raw)
                                }.onSuccess {
                                    settingsTransferMessage = text.settingsImportSuccess
                                }.onFailure {
                                    settingsTransferMessage = it.message ?: text.settingsTransferError
                                }
                            }
                        }
                    },
                ) {
                    Text(text.settingsImport)
                }
            },
            dismissButton = {
                TextButton(
                    onClick = {
                        showingImportConfirmation = false
                        pendingSettingsImport = null
                    },
                ) {
                    Text(text.cancel)
                }
            },
        )
    }

    if (settingsTransferMessage.isNotBlank()) {
        AlertDialog(
            onDismissRequest = { settingsTransferMessage = "" },
            title = { Text(text.settingsTransferResult) },
            text = { Text(settingsTransferMessage) },
            confirmButton = {
                Button(onClick = { settingsTransferMessage = "" }) {
                    Text(text.ok)
                }
            },
        )
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
    AppTab.PRESENCE -> text.tabPresence
    AppTab.MUSIC -> text.tabMusic
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

private fun presenceSourceText(source: DiscordPresenceSource, text: LocalizedText): String = when (source) {
    DiscordPresenceSource.APP -> text.appPresence
    DiscordPresenceSource.MUSIC -> text.musicPresence
    DiscordPresenceSource.NONE -> text.none
    DiscordPresenceSource.UNKNOWN -> text.unknown
}

private fun presenceSourceTint(source: DiscordPresenceSource): Color = when (source) {
    DiscordPresenceSource.APP -> Color(0xFF00796B)
    DiscordPresenceSource.MUSIC -> Color(0xFF6A1B9A)
    DiscordPresenceSource.NONE -> Color(0xFF616161)
    DiscordPresenceSource.UNKNOWN -> Color(0xFFEF6C00)
}

private fun optionalPresenceValue(value: String?, text: LocalizedText): String {
    return value?.takeIf { it.isNotBlank() } ?: text.none
}

private fun timestampPresenceText(value: Long?, text: LocalizedText): String {
    return value?.toString() ?: text.none
}

private fun imagePresenceText(key: String?, hoverText: String?, text: LocalizedText): String {
    val imageKey = key?.takeIf { it.isNotBlank() }
    val imageHoverText = hoverText?.takeIf { it.isNotBlank() }
    return when {
        imageKey == null && imageHoverText == null -> text.none
        imageKey == null -> imageHoverText.orEmpty()
        imageHoverText == null -> imageKey
        else -> "$imageKey ($imageHoverText)"
    }
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
