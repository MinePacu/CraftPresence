package com.minepacu.craftpresence.core.discord

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class DiscordSdkManager(
    private val appContext: Context,
    private val gateway: DiscordGateway = AndroidDiscordGateway(),
) {
    private val mutex = Mutex()

    private var configuredApplicationId: String? = null
    private var sessionId: Long = 0

    private val _state = MutableStateFlow(DiscordState())
    val state: StateFlow<DiscordState> = _state.asStateFlow()

    suspend fun configure(
        applicationId: String? = DiscordAppConfig.applicationId(appContext),
        autoAuthorize: Boolean = true,
    ) {
        val validationError = DiscordAppConfig.validationError(applicationId)
        if (validationError != null) {
            mutex.withLock {
                sessionId += 1
                configuredApplicationId = null
            }
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
                gateway.configure(normalizedId)
                _state.value = DiscordState(dashboardStatus = DiscordDashboardStatus.CONFIGURED)
            }
        }

        if (autoAuthorize) {
            authorizeIfNeeded()
        }
    }

    suspend fun authorizeIfNeeded(): DiscordUser {
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

        return try {
            val user = gateway.authorize()
            _state.value = DiscordState(
                authorizationStatus = DiscordAuthorizationStatus.AUTHORIZED,
                currentUser = user,
                dashboardStatus = DiscordDashboardStatus.READY,
            )
            user
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
            authorizeIfNeeded()
        }
        gateway.updateActivity(activity)
        _state.value = _state.value.copy(dashboardStatus = DiscordDashboardStatus.READY)
    }

    suspend fun clearActivity() {
        gateway.clearActivity()
    }

    companion object {
        @Volatile private var instance: DiscordSdkManager? = null

        fun getInstance(context: Context): DiscordSdkManager {
            return instance ?: synchronized(this) {
                instance ?: DiscordSdkManager(context.applicationContext).also { instance = it }
            }
        }
    }
}
