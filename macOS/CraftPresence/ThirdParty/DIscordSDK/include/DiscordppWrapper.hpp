//
//  DiscordppWrapper.hpp
//  CraftPresence

#ifndef DiscordppWrapper_hpp
#define DiscordppWrapper_hpp

#include "discordpp.h"
#include "cdiscord.h"
#include <memory>
#include <string>
#include <functional>
#include <optional>

/// C callback used when authorization succeeds or fails.
typedef void (*AuthorizeCallback)(void* context, bool success, const char* error);

/// C callback used when logout succeeds or fails.
typedef void (*LogoutCallback)(void* context, bool success, const char* error);

/// C callback used to return the current Discord user to Swift.
typedef void (*UserCallback)(void* context, bool success, const char* id, const char* username, const char* error);

/// C callback used when Rich Presence updates or clears complete.
typedef void (*ActivityCallback)(void* context, bool success, const char* error);

/// Thin C++ wrapper around discordpp that exposes callback-safe methods to Swift.
class DiscordppWrapper {
private:
    std::shared_ptr<discordpp::Client> client;
    std::string applicationId;
    uint64_t numericApplicationId = 0;
    std::optional<discordpp::AuthorizationCodeVerifier> currentCodeVerifier;
    std::string currentCodeVerifierValue;
    std::string lastRefreshToken;

public:
    /// Creates a Discord SDK client for a Discord Developer Portal application ID.
    DiscordppWrapper(const std::string& appId);

    /// Releases the owned Discord SDK client.
    ~DiscordppWrapper();
    
    /// Returns whether the SDK currently has an authenticated user.
    bool isAuthorized() const;

    /// Returns whether the authenticated SDK session can provide current user data.
    bool isConnected() const;

    /// Starts Discord authorization and exchanges the authorization code for an SDK token.
    void authorize(void* context, AuthorizeCallback callback);

    /// Logs out of the current SDK session.
    void logout(void* context, LogoutCallback callback);

    /// Loads the current Discord user from the authenticated SDK session.
    void getCurrentUser(void* context, UserCallback callback);

    /// Publishes a Rich Presence activity to Discord.
    void updateActivity(const std::string& name,
                       const std::string& state,
                       const std::string& details,
                       const std::string& largeImageKey,
                       const std::string& largeImageText,
                       const std::string& smallImageKey,
                       const std::string& smallImageText,
                       const std::string& partyId,
                       int32_t partyCurrent,
                       int32_t partyMax,
                       int64_t startTimestamp,
                       int64_t endTimestamp,
                       int32_t activityType,
                       void* context,
                       ActivityCallback callback);

    /// Clears the currently published Rich Presence activity.
    void clearActivity(void* context, ActivityCallback callback);

    /// Pumps Discord SDK callbacks and must be called regularly while the SDK is active.
    void runCallbacks();

private:
    /// Exchanges an authorization code and PKCE verifier for Discord tokens.
    void exchangeCodeForToken(const std::string& code,
                              const std::string& redirectUri,
                              const std::string& codeVerifier,
                              void* context,
                              AuthorizeCallback callback);

    /// Applies an access token to the SDK client and connects the session.
    void applyAccessToken(discordpp::AuthorizationTokenType tokenType,
                          const std::string& accessToken,
                          void* context,
                          AuthorizeCallback callback);

    /// Returns the parsed application ID from wrapper or SDK state.
    uint64_t resolvedApplicationId() const;

    /// Extracts a human-readable error message from a Discord SDK result.
    static std::string messageFromResult(const discordpp::ClientResult& result);
};


#endif /* DiscordppWrapper_hpp */
