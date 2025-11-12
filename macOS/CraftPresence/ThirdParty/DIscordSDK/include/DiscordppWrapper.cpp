//
//  DiscordppWrapper.cpp
//  CraftPresence

#include "DiscordppWrapper.hpp"
#define DISCORDPP_IMPLEMENTATION
#include "discordpp.h"
#include <iostream>
#include <optional>
#include <os/log.h>
// Logging control: define DISCORDPP_WRAPPER_DISABLE_LOGS to strip logs at compile time
#ifndef DISCORDPP_WRAPPER_DISABLE_LOGS
#define DPW_LOG_INFO(fmt, ...)  os_log_info(OS_LOG_DEFAULT, fmt, ##__VA_ARGS__)
#define DPW_LOG_ERROR(fmt, ...) os_log_error(OS_LOG_DEFAULT, fmt, ##__VA_ARGS__)
#else
#define DPW_LOG_INFO(fmt, ...)
#define DPW_LOG_ERROR(fmt, ...)
#endif

DiscordppWrapper::DiscordppWrapper(const std::string& appId) : applicationId(appId) {
    try {
        client = std::make_shared<discordpp::Client>();
        if (client) {
            // 애플리케이션 ID 설정
            if (!appId.empty()) {
                try {
                    numericApplicationId = std::stoull(appId);
                    DPW_LOG_INFO("[DiscordppWrapper] Parsed APPLICATION_ID: %llu from string: %s", numericApplicationId, appId.c_str());
                } catch (...) {
                    numericApplicationId = 0;
                    DPW_LOG_ERROR("[DiscordppWrapper] Failed to parse APPLICATION_ID from string: %s", appId.c_str());
                }
            }
            if (numericApplicationId != 0) {
                client->SetApplicationId(numericApplicationId);
                DPW_LOG_INFO("[DiscordppWrapper] SetApplicationId called with: %llu", numericApplicationId);
            } else {
                DPW_LOG_ERROR("[DiscordppWrapper] numericApplicationId is 0, not calling SetApplicationId");
            }
        }
    } catch (const std::exception& e) {
        // 에러 처리
        DPW_LOG_ERROR("[DiscordppWrapper] Exception during initialization: %s", e.what());
        client.reset();
    }
}

DiscordppWrapper::~DiscordppWrapper() {
    client.reset();
}

bool DiscordppWrapper::isAuthorized() const {
    if (!client) return false;
    try {
        return client->IsAuthenticated();
    } catch (const std::exception& e) {
        return false;
    }
}

bool DiscordppWrapper::isConnected() const {
    if (!client) return false;
    try {
        // IsAuthenticated()와 사용자 정보가 모두 사용 가능한지 확인
        if (!client->IsAuthenticated()) {
            return false;
        }
        
        // 사용자 정보를 가져올 수 있는지 확인
        auto userOpt = client->GetCurrentUserV2();
        return userOpt.has_value();
    } catch (const std::exception& e) {
        return false;
    }
}

void DiscordppWrapper::authorize(void* context, AuthorizeCallback callback) {
    if (!client) {
        callback(context, false, "Client not initialized");
        return;
    }
    
    try {
        discordpp::AuthorizationArgs args;
        args.SetScopes(discordpp::Client::GetDefaultPresenceScopes());
        if (!applicationId.empty()) {
            args.SetClientId(std::stoull(applicationId));
            DPW_LOG_INFO("[DiscordppWrapper] authorize() - SetClientId: %s", applicationId.c_str());
        }
        
        // PKCE verifier를 생성하고 즉시 저장
        currentCodeVerifier = client->CreateAuthorizationCodeVerifier();
        if (currentCodeVerifier) {
            currentCodeVerifierValue = currentCodeVerifier->Verifier();
            DPW_LOG_INFO("[DiscordppWrapper] authorize() - PKCE Verifier created (length: %zu)", currentCodeVerifierValue.length());
            if (currentCodeVerifier->Challenge()) {
                args.SetCodeChallenge(currentCodeVerifier->Challenge());
                DPW_LOG_INFO("[DiscordppWrapper] authorize() - PKCE Challenge set");
            } else {
                DPW_LOG_ERROR("[DiscordppWrapper] authorize() - PKCE Challenge is NULL!");
            }
        } else {
            currentCodeVerifierValue = "";
            DPW_LOG_ERROR("[DiscordppWrapper] authorize() - Failed to create PKCE verifier!");
        }
        
        // Lambda에서 사용할 verifier를 명시적으로 캡처
        std::string capturedVerifier = currentCodeVerifierValue;
        DPW_LOG_INFO("[DiscordppWrapper] authorize() - About to call Authorize. Captured verifier: %s", capturedVerifier.c_str());
        
        client->Authorize(std::move(args), [this, context, callback, capturedVerifier](discordpp::ClientResult result, std::string code, std::string redirectUri) {
            DPW_LOG_INFO("[DiscordppWrapper] Authorize callback - Result: %d, Code: %s", result.Successful(), code.c_str());
            if (!result.Successful()) {
                const std::string message = messageFromResult(result);
                DPW_LOG_ERROR("[DiscordppWrapper] Authorize failed: %s", message.c_str());
                callback(context, false, message.c_str());
                return;
            }
            DPW_LOG_INFO("[DiscordppWrapper] Authorize callback - Verifier before exchange: %s", capturedVerifier.c_str());
            // 캡처한 verifier를 직접 전달
            exchangeCodeForToken(code, redirectUri, capturedVerifier, context, callback);
        });
    } catch (const std::exception& e) {
        DPW_LOG_ERROR("[DiscordppWrapper] authorize() exception: %s", e.what());
        callback(context, false, e.what());
    }
}

void DiscordppWrapper::exchangeCodeForToken(const std::string& code,
                                           const std::string& redirectUri,
                                           const std::string& codeVerifier,
                                           void* context,
                                           AuthorizeCallback callback) {
    DPW_LOG_INFO("[DiscordppWrapper] exchangeCodeForToken() - START");
    if (!client) {
        DPW_LOG_ERROR("[DiscordppWrapper] exchangeCodeForToken() - Client is NULL!");
        callback(context, false, "Client not initialized");
        return;
    }
    
    DPW_LOG_INFO("[DiscordppWrapper] exchangeCodeForToken() - Client exists: %p", client.get());
    
    const uint64_t clientId = resolvedApplicationId();
    DPW_LOG_INFO("[DiscordppWrapper] exchangeCodeForToken() - clientId: %llu", clientId);
    if (clientId == 0) {
        DPW_LOG_ERROR("[DiscordppWrapper] exchangeCodeForToken() - Invalid APPLICATION_ID (0)");
        callback(context, false, "Invalid APPLICATION_ID");
        return;
    }
    
    DPW_LOG_INFO("[DiscordppWrapper] exchangeCodeForToken() - codeVerifier: '%s' (length: %zu)", 
                codeVerifier.c_str(), codeVerifier.length());
    
    if (codeVerifier.empty()) {
        DPW_LOG_ERROR("[DiscordppWrapper] exchangeCodeForToken() - PKCE verifier is EMPTY!");
        callback(context, false, "Missing PKCE verifier");
        return;
    }
    
    DPW_LOG_INFO("[DiscordppWrapper] exchangeCodeForToken() - About to call GetToken...");
    
    try {
        client->GetToken(clientId,
                         code,
                         codeVerifier,
                         redirectUri,
                         [this, context, callback](discordpp::ClientResult result,
                                                   std::string accessToken,
                                                   std::string refreshToken,
                                                   discordpp::AuthorizationTokenType tokenType,
                                                   int32_t expiresIn,
                                                   std::string scopes) {
            DPW_LOG_INFO("[DiscordppWrapper] GetToken callback - Success: %d", result.Successful());
            if (!result.Successful()) {
                const std::string message = messageFromResult(result);
                DPW_LOG_ERROR("[DiscordppWrapper] GetToken failed: %s", message.c_str());
                callback(context, false, message.c_str());
                return;
            }
            DPW_LOG_INFO("[DiscordppWrapper] GetToken success - Applying access token");
            lastRefreshToken = refreshToken;
            applyAccessToken(tokenType, accessToken, context, callback);
        });
    } catch (const std::exception& e) {
        DPW_LOG_ERROR("[DiscordppWrapper] GetToken exception: %s", e.what());
        callback(context, false, e.what());
    }
}

void DiscordppWrapper::applyAccessToken(discordpp::AuthorizationTokenType tokenType,
                                       const std::string& accessToken,
                                       void* context,
                                       AuthorizeCallback callback) {
    if (!client) {
        callback(context, false, "Client not initialized");
        return;
    }
    
    DPW_LOG_INFO("[DiscordppWrapper] applyAccessToken - Updating token...");
    
    client->UpdateToken(tokenType, accessToken, [this, context, callback](discordpp::ClientResult result) {
        if (!result.Successful()) {
            const std::string message = messageFromResult(result);
            DPW_LOG_ERROR("[DiscordppWrapper] UpdateToken failed: %s", message.c_str());
            callback(context, false, message.c_str());
            return;
        }
        
        DPW_LOG_INFO("[DiscordppWrapper] Token updated successfully, connecting...");
        
        try {
            client->Connect();
            DPW_LOG_INFO("[DiscordppWrapper] Connect() called successfully");
        } catch (const std::exception& e) {
            DPW_LOG_ERROR("[DiscordppWrapper] Connect() exception: %s", e.what());
            callback(context, false, e.what());
            return;
        }
        
        // PKCE verifier 정리
        currentCodeVerifier.reset();
        currentCodeVerifierValue.clear();
        
        DPW_LOG_INFO("[DiscordppWrapper] Authorization complete, calling success callback");
        callback(context, true, nullptr);
    });
}

uint64_t DiscordppWrapper::resolvedApplicationId() const {
    if (numericApplicationId != 0) { return numericApplicationId; }
    if (client) {
        try {
            return client->GetApplicationId();
        } catch (...) {
            return 0;
        }
    }
    return 0;
}

std::string DiscordppWrapper::messageFromResult(const discordpp::ClientResult& result) {
    std::string message = result.Error();
    if (message.empty()) {
        message = result.ToString();
    }
    if (message.empty()) {
        message = "Discord SDK error";
    }
    return message;
}

void DiscordppWrapper::logout(void* context, LogoutCallback callback) {
    if (!client) {
        callback(context, false, "Client not initialized");
        return;
    }
    
    callback(context, true, nullptr);
}

void DiscordppWrapper::getCurrentUser(void* context, UserCallback callback) {
    if (!client) {
        DPW_LOG_ERROR("[DiscordppWrapper] getCurrentUser - Client not initialized");
        callback(context, false, nullptr, nullptr, "Client not initialized");
        return;
    }
    
    try {
        // 인증 상태 확인
        bool isAuth = client->IsAuthenticated();
        DPW_LOG_INFO("[DiscordppWrapper] getCurrentUser - IsAuthenticated: %d", isAuth);
        
        if (!isAuth) {
            DPW_LOG_ERROR("[DiscordppWrapper] getCurrentUser - Not authenticated yet");
            callback(context, false, nullptr, nullptr, "Not authenticated");
            return;
        }
        
        // 현재 사용자 가져오기
        auto userOpt = client->GetCurrentUserV2();
        if (userOpt.has_value()) {
            auto user = userOpt.value();
            
            // 원본 데이터 로깅
            auto rawId = user.Id();
            std::string rawUsername = user.Username();
            
            DPW_LOG_INFO("[DiscordppWrapper] Raw User ID (numeric): %lld", (long long)rawId);
            DPW_LOG_INFO("[DiscordppWrapper] Raw Username: %s", rawUsername.c_str());
            DPW_LOG_INFO("[DiscordppWrapper] Username length: %zu", rawUsername.length());
            
            // 수명이 보장되는 std::string 객체 생성
            std::string userIdStr = std::to_string(rawId);
            std::string usernameStr = rawUsername;
            
            DPW_LOG_INFO("[DiscordppWrapper] Sending User ID: %s, Username: %s", 
                        userIdStr.c_str(), usernameStr.c_str());
            
            // 콜백 호출 - Swift가 즉시 복사한다고 가정
            callback(context, true, userIdStr.c_str(), usernameStr.c_str(), nullptr);
            
            // 여기서 userIdStr과 usernameStr이 소멸되지만, 
            // Swift의 String(cString:)이 이미 복사를 완료했어야 함
        } else {
            DPW_LOG_ERROR("[DiscordppWrapper] User not available (GetCurrentUserV2 returned nullopt)");
            callback(context, false, nullptr, nullptr, "User not available");
        }
    } catch (const std::exception& e) {
        DPW_LOG_ERROR("[DiscordppWrapper] getCurrentUser exception: %s", e.what());
        callback(context, false, nullptr, nullptr, e.what());
    }
}


void DiscordppWrapper::updateActivity(const std::string& name,
                                    const std::string& state,
                                    const std::string& details,
                                    const std::string& largeImageKey,
                                    const std::string& smallImageKey,
                                    int64_t startTimestamp,
                                    int64_t endTimestamp,
                                    int32_t activityType,
                                    void* context,
                                    ActivityCallback callback) {
    if (!client) {
        callback(context, false, "Client not initialized");
        return;
    }
    
    try {
        // discordpp Activity 객체 생성 및 설정
        discordpp::Activity activity;
        discordpp::ActivityTypes resolvedType = discordpp::ActivityTypes::Playing;
        if (activityType >= static_cast<int32_t>(discordpp::ActivityTypes::Playing) &&
            activityType <= static_cast<int32_t>(discordpp::ActivityTypes::HangStatus)) {
            resolvedType = static_cast<discordpp::ActivityTypes>(activityType);
        }
        activity.SetType(resolvedType);
        
        // 앱 이름 설정 (Rich Presence 타이틀)
        if (!name.empty()) {
            activity.SetName(name);
            DPW_LOG_INFO("[DiscordppWrapper] Setting activity name: %s", name.c_str());
        }
        
        // 상태 및 세부사항 설정
        if (!state.empty()) {
            activity.SetState(state);
        }
        if (!details.empty()) {
            activity.SetDetails(details);
        }
        
        // 이미지 에셋 설정
        if (!largeImageKey.empty() || !smallImageKey.empty()) {
            discordpp::ActivityAssets assets;
            if (!largeImageKey.empty()) {
                assets.SetLargeImage(largeImageKey);
            }
            if (!smallImageKey.empty()) {
                assets.SetSmallImage(smallImageKey);
            }
            activity.SetAssets(assets);
        }
        
        // 타임스탬프 설정
        if (startTimestamp > 0 || endTimestamp > 0) {
            discordpp::ActivityTimestamps timestamps;
            if (startTimestamp > 0) {
                timestamps.SetStart(static_cast<uint64_t>(startTimestamp));
            }
            if (endTimestamp > 0) {
                timestamps.SetEnd(static_cast<uint64_t>(endTimestamp));
            }
            activity.SetTimestamps(timestamps);
        }
        
        // 활동 업데이트
        client->UpdateRichPresence(std::move(activity), [context, callback](discordpp::ClientResult result) {
            if (result.Successful()) {
                callback(context, true, nullptr);
            } else {
                callback(context, false, result.Error().c_str());
            }
        });
        
    } catch (const std::exception& e) {
        callback(context, false, e.what());
    }
}

void DiscordppWrapper::clearActivity(void* context, ActivityCallback callback) {
    if (!client) {
        callback(context, false, "Client not initialized");
        return;
    }
    
    try {
        // 활동 클리어
        client->ClearRichPresence();
        callback(context, true, nullptr);
    } catch (const std::exception& e) {
        callback(context, false, e.what());
    }
}

void DiscordppWrapper::runCallbacks() {
    try {
        discordpp::RunCallbacks();
    } catch (const std::exception&) {
        // Ignore callback pump errors for now; Discord SDK typically reports via other APIs.
    }
}

