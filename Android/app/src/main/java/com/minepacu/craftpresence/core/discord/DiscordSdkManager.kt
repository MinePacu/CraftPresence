package com.minepacu.craftpresence.core.discord

import android.content.Context
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class DiscordSdkManager(
    private val appContext: Context,
    private val gateway: DiscordGateway = AndroidDiscordGateway(),
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val mutex = Mutex()
    private val tokenStore = DiscordTokenStore(appContext)

    private var configuredApplicationId: String? = null
    private var sessionId: Long = 0
    private var lastActivity: DiscordActivity? = null
    private var priorityJob: Job? = null
    private val priorityOwners = mutableSetOf<String>()

    private val _state = MutableStateFlow(DiscordState())
    val state: StateFlow<DiscordState> = _state.asStateFlow()

    suspend fun configure(
        applicationId: String? = DiscordAppConfig.applicationId(appContext),
        autoAuthorize: Boolean = true,
        allowInteractiveAuthorization: Boolean = false,
    ) {
        val validationError = DiscordAppConfig.validationError(applicationId)
        if (validationError != null) {
            mutex.withLock {
                sessionId += 1
                configuredApplicationId = null
                lastActivity = null
            }
            stopActivityPriority()
            _state.value = DiscordState(
                authorizationStatus = DiscordAuthorizationStatus.UNAUTHORIZED,
                dashboardStatus = DiscordDashboardStatus.FAILED,
                lastErrorMessage = validationError.message,
            )
            return
        }

        val normalizedId = applicationId?.trim().orEmpty()
        mutex.withLock {
            if (configuredApplicationId != normalizedId) {
                sessionId += 1
                configuredApplicationId = normalizedId
                lastActivity = null
                gateway.configure(normalizedId)
                _state.value = DiscordState(dashboardStatus = DiscordDashboardStatus.CONFIGURED)
            }
        }

        if (autoAuthorize) {
            authorizeIfNeeded(allowInteractiveAuthorization = allowInteractiveAuthorization)
        }
    }

    suspend fun authorizeIfNeeded(allowInteractiveAuthorization: Boolean = true): DiscordUser {
        mutex.withLock {
            if (gateway.isAuthorized()) {
                val user = gateway.currentUser()
                _state.value = DiscordState(
                    authorizationStatus = DiscordAuthorizationStatus.AUTHORIZED,
                    currentUser = user,
                    dashboardStatus = DiscordDashboardStatus.READY,
                )
                return user
            }
            if (configuredApplicationId == null) throw DiscordSdkError.NotConfigured
            _state.value = _state.value.copy(dashboardStatus = DiscordDashboardStatus.AUTHORIZING)
        }

        val applicationId = mutex.withLock { configuredApplicationId }.orEmpty()
        val storedRefreshToken = tokenStore.refreshToken(applicationId)
        if (storedRefreshToken.isNotBlank()) {
            runCatching {
                val result = gateway.refreshAuthorization(storedRefreshToken)
                tokenStore.setRefreshToken(applicationId, result.refreshToken)
                _state.value = DiscordState(
                    authorizationStatus = DiscordAuthorizationStatus.AUTHORIZED,
                    currentUser = result.user,
                    dashboardStatus = DiscordDashboardStatus.READY,
                )
                return result.user
            }.onFailure {
                tokenStore.clearRefreshToken(applicationId)
            }
        }

        if (!allowInteractiveAuthorization) {
            _state.value = DiscordState(
                authorizationStatus = DiscordAuthorizationStatus.UNAUTHORIZED,
                dashboardStatus = DiscordDashboardStatus.UNAUTHORIZED,
                lastErrorMessage = "Discord authorization is required.",
            )
            throw DiscordSdkError.Unauthorized
        }

        return try {
            val result = gateway.authorize()
            tokenStore.setRefreshToken(applicationId, result.refreshToken)
            _state.value = DiscordState(
                authorizationStatus = DiscordAuthorizationStatus.AUTHORIZED,
                currentUser = result.user,
                dashboardStatus = DiscordDashboardStatus.READY,
            )
            result.user
        } catch (error: Exception) {
            _state.value = DiscordState(
                authorizationStatus = DiscordAuthorizationStatus.UNAUTHORIZED,
                dashboardStatus = DiscordDashboardStatus.FAILED,
                lastErrorMessage = error.message,
            )
            throw error
        }
    }

    suspend fun logout() {
        mutex.withLock {
            lastActivity = null
        }
        tokenStore.clearRefreshToken(mutex.withLock { configuredApplicationId })
        stopActivityPriority()
        gateway.logout()
        _state.value = DiscordState(
            authorizationStatus = DiscordAuthorizationStatus.UNAUTHORIZED,
            dashboardStatus = DiscordDashboardStatus.UNAUTHORIZED,
        )
    }

    suspend fun fetchCurrentUser(): DiscordUser {
        val user = gateway.currentUser()
        _state.value = _state.value.copy(
            authorizationStatus = DiscordAuthorizationStatus.AUTHORIZED,
            currentUser = user,
            dashboardStatus = DiscordDashboardStatus.READY,
            lastErrorMessage = null,
        )
        return user
    }

    suspend fun updateActivity(activity: DiscordActivity) {
        if (!gateway.isAuthorized()) {
            authorizeIfNeeded(allowInteractiveAuthorization = false)
        }
        gateway.updateActivity(activity)
        mutex.withLock {
            lastActivity = activity
        }
        _state.value = _state.value.copy(dashboardStatus = DiscordDashboardStatus.READY)
    }

    suspend fun clearActivity() {
        mutex.withLock {
            lastActivity = null
        }
        gateway.clearActivity()
    }

    fun retainActivityPriority(owner: String) {
        synchronized(priorityOwners) {
            priorityOwners += owner
            if (priorityJob?.isActive == true) return
            priorityJob = scope.launch {
                while (isActive) {
                    val activity = mutex.withLock { lastActivity }
                    if (activity != null) {
                        runCatching { updateActivity(activity) }
                    }
                    delay(ACTIVITY_PRIORITY_INTERVAL_MS)
                }
            }
        }
    }

    fun releaseActivityPriority(owner: String) {
        synchronized(priorityOwners) {
            priorityOwners -= owner
            if (priorityOwners.isEmpty()) {
                stopActivityPriority()
            }
        }
    }

    private fun stopActivityPriority() {
        synchronized(priorityOwners) {
            priorityOwners.clear()
            priorityJob?.cancel()
            priorityJob = null
        }
    }

    companion object {
        private const val ACTIVITY_PRIORITY_INTERVAL_MS = 5_000L

        @Volatile private var instance: DiscordSdkManager? = null

        fun getInstance(context: Context): DiscordSdkManager {
            return instance ?: synchronized(this) {
                instance ?: DiscordSdkManager(context.applicationContext).also { instance = it }
            }
        }
    }
}
