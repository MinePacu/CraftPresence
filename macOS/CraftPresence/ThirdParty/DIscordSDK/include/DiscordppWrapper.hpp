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

// Swift에서 호출할 수 있는 C 스타일 함수 포인터 타입 정의
typedef void (*AuthorizeCallback)(void* context, bool success, const char* error);
typedef void (*LogoutCallback)(void* context, bool success, const char* error);
typedef void (*UserCallback)(void* context, bool success, const char* id, const char* username, const char* error);
typedef void (*ActivityCallback)(void* context, bool success, const char* error);

class DiscordppWrapper {
private:
    std::shared_ptr<discordpp::Client> client;
    std::string applicationId;
    uint64_t numericApplicationId = 0;
    std::optional<discordpp::AuthorizationCodeVerifier> currentCodeVerifier;
    std::string currentCodeVerifierValue;
    std::string lastRefreshToken;

public:
    DiscordppWrapper(const std::string& appId);
    ~DiscordppWrapper();
    
    bool isAuthorized() const;
    bool isConnected() const;
    void authorize(void* context, AuthorizeCallback callback);
    void logout(void* context, LogoutCallback callback);
    void getCurrentUser(void* context, UserCallback callback);
    void updateActivity(const std::string& name,
                       const std::string& state,
                       const std::string& details,
                       const std::string& largeImageKey,
                       const std::string& smallImageKey,
                       int64_t startTimestamp,
                       int64_t endTimestamp,
                       int32_t activityType,
                       void* context,
                       ActivityCallback callback);
    void clearActivity(void* context, ActivityCallback callback);
    void runCallbacks();

private:
    void exchangeCodeForToken(const std::string& code,
                              const std::string& redirectUri,
                              const std::string& codeVerifier,
                              void* context,
                              AuthorizeCallback callback);
    void applyAccessToken(discordpp::AuthorizationTokenType tokenType,
                          const std::string& accessToken,
                          void* context,
                          AuthorizeCallback callback);
    uint64_t resolvedApplicationId() const;
    static std::string messageFromResult(const discordpp::ClientResult& result);
};


#endif /* DiscordppWrapper_hpp */
