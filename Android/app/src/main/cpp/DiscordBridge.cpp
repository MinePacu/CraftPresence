#include <jni.h>

#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>

#include <android/log.h>

#define DISCORDPP_IMPLEMENTATION
#include <discordpp.h>

namespace {

constexpr const char* kTag = "CraftPresenceDiscord";
constexpr auto kAuthTimeout = std::chrono::seconds(120);
constexpr auto kOperationTimeout = std::chrono::seconds(15);
constexpr auto kReadyTimeout = std::chrono::seconds(10);

std::mutex g_mutex;
std::shared_ptr<discordpp::Client> g_client;
std::string g_application_id;

struct PendingDiscordOperation {
    std::mutex mutex;
    bool completed = false;
    bool timedOut = false;
    std::string error;
    std::string refreshToken;
};

using PendingDiscordOperationPtr = std::shared_ptr<PendingDiscordOperation>;

std::string resultMessage(const discordpp::ClientResult& result) {
    auto message = result.Error();
    if (!message.empty()) return message;
    return result.ToString();
}

/** Parses the configured Discord application ID into the numeric form required by discordpp. */
uint64_t parseApplicationId() {
    try {
        return std::stoull(g_application_id);
    } catch (...) {
        return 0;
    }
}

/** Runs pending Discord SDK callbacks and converts SDK exceptions into Android log entries. */
void pumpCallbacks() {
    try {
        discordpp::RunCallbacks();
    } catch (const std::exception& error) {
        __android_log_print(ANDROID_LOG_ERROR, kTag, "RunCallbacks failed: %s", error.what());
    } catch (...) {
        __android_log_print(ANDROID_LOG_ERROR, kTag, "RunCallbacks failed with unknown error");
    }
}

/** Pumps callbacks until an asynchronous SDK operation finishes or times out. */
bool waitUntil(
    const std::function<bool()>& isDone,
    std::chrono::steady_clock::duration timeout
) {
    const auto deadline = std::chrono::steady_clock::now() + timeout;
    while (!isDone()) {
        pumpCallbacks();
        if (std::chrono::steady_clock::now() >= deadline) return false;
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
    pumpCallbacks();
    return true;
}

PendingDiscordOperationPtr makePendingOperation() {
    return std::make_shared<PendingDiscordOperation>();
}

bool isOperationCompleted(const PendingDiscordOperationPtr& operation) {
    std::lock_guard<std::mutex> lock(operation->mutex);
    return operation->completed;
}

bool isOperationFinished(const PendingDiscordOperationPtr& operation) {
    std::lock_guard<std::mutex> lock(operation->mutex);
    return operation->completed || operation->timedOut;
}

void markOperationTimedOut(const PendingDiscordOperationPtr& operation) {
    std::lock_guard<std::mutex> lock(operation->mutex);
    if (!operation->completed) operation->timedOut = true;
}

bool storeRefreshTokenIfActive(
    const PendingDiscordOperationPtr& operation,
    const std::string& refreshToken
) {
    std::lock_guard<std::mutex> lock(operation->mutex);
    if (operation->completed || operation->timedOut) return false;
    operation->refreshToken = refreshToken;
    return true;
}

void completeOperation(
    const PendingDiscordOperationPtr& operation,
    const std::string& error = ""
) {
    std::lock_guard<std::mutex> lock(operation->mutex);
    if (operation->completed || operation->timedOut) return;
    operation->error = error;
    operation->completed = true;
}

std::string operationError(const PendingDiscordOperationPtr& operation) {
    std::lock_guard<std::mutex> lock(operation->mutex);
    return operation->error;
}

std::string operationRefreshToken(const PendingDiscordOperationPtr& operation) {
    std::lock_guard<std::mutex> lock(operation->mutex);
    return operation->refreshToken;
}

/** Returns a thread-safe snapshot of the active Discord client. */
std::shared_ptr<discordpp::Client> clientSnapshot() {
    std::lock_guard<std::mutex> lock(g_mutex);
    return g_client;
}

/** Converts a nullable Java string to a UTF-8 C++ string. */
std::string jstringToString(JNIEnv* env, jstring value) {
    if (value == nullptr) return "";
    const char* chars = env->GetStringUTFChars(value, nullptr);
    std::string result = chars == nullptr ? "" : chars;
    if (chars != nullptr) env->ReleaseStringUTFChars(value, chars);
    return result;
}

/** Converts a UTF-8 C++ string to a Java string. */
jstring stringToJstring(JNIEnv* env, const std::string& value) {
    return env->NewStringUTF(value.c_str());
}

/** Builds the string-array result consumed by `AndroidDiscordGateway`. */
jobjectArray userResult(
    JNIEnv* env,
    bool success,
    const std::string& id,
    const std::string& username,
    const std::string& error,
    const std::string& refreshToken = ""
) {
    auto stringClass = env->FindClass("java/lang/String");
    auto result = env->NewObjectArray(5, stringClass, stringToJstring(env, ""));
    env->SetObjectArrayElement(result, 0, stringToJstring(env, success ? "true" : "false"));
    env->SetObjectArrayElement(result, 1, stringToJstring(env, id));
    env->SetObjectArrayElement(result, 2, stringToJstring(env, username));
    env->SetObjectArrayElement(result, 3, stringToJstring(env, error));
    env->SetObjectArrayElement(result, 4, stringToJstring(env, refreshToken));
    return result;
}

/** Returns an error message when the Discord client has not been configured. */
std::optional<std::string> ensureClient() {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_client) return std::nullopt;
    return "Discord SDK is not configured.";
}

/** Waits until Discord authentication and user data are both ready. */
std::optional<std::string> waitForReady(discordpp::Client* client) {
    const bool ready = waitUntil([client] {
        try {
            return client->IsAuthenticated() && client->GetCurrentUserV2().has_value();
        } catch (...) {
            return false;
        }
    }, kReadyTimeout);

    if (!ready) return "Discord SDK did not become ready in time.";
    return std::nullopt;
}

/** Maps Kotlin activity type values to discordpp activity types. */
discordpp::ActivityTypes activityTypeFromInt(jint value) {
    switch (value) {
        case 1: return discordpp::ActivityTypes::Streaming;
        case 2: return discordpp::ActivityTypes::Listening;
        case 3: return discordpp::ActivityTypes::Watching;
        case 5: return discordpp::ActivityTypes::Competing;
        case 0:
        default: return discordpp::ActivityTypes::Playing;
    }
}

/** Sends a Rich Presence update through the active Discord client. */
std::optional<std::string> updateRichPresence(discordpp::Activity activity) {
    auto client = clientSnapshot();
    if (!client) return "Discord SDK is not configured.";

    if (!client->IsAuthenticated()) return "Discord is not authorized.";

    if (auto readyError = waitForReady(client.get())) return readyError;

    auto operation = makePendingOperation();

    try {
        client->UpdateRichPresence(std::move(activity), [operation](discordpp::ClientResult result) {
            completeOperation(operation, result.Successful() ? "" : resultMessage(result));
        });
    } catch (const std::exception& exception) {
        return exception.what();
    }

    const bool finished = waitUntil([operation] { return isOperationCompleted(operation); }, kOperationTimeout);
    if (!finished) {
        markOperationTimedOut(operation);
        return "Discord activity update timed out.";
    }
    const auto error = operationError(operation);
    if (!error.empty()) return error;
    return std::nullopt;
}

} // namespace

/** Initializes the native Discord client for an Android application ID. */
extern "C" JNIEXPORT jstring JNICALL
Java_com_minepacu_craftpresence_core_discord_NativeDiscordBridge_configure(
    JNIEnv* env,
    jobject,
    jstring applicationId
) {
    const auto appId = jstringToString(env, applicationId);
    try {
        auto client = std::make_shared<discordpp::Client>();
        const uint64_t numericId = std::stoull(appId);
        client->SetApplicationId(numericId);

        std::lock_guard<std::mutex> lock(g_mutex);
        g_application_id = appId;
        g_client = std::move(client);
        return nullptr;
    } catch (const std::exception& error) {
        return stringToJstring(env, error.what());
    } catch (...) {
        return stringToJstring(env, "Failed to configure Discord SDK.");
    }
}

/** Runs interactive Discord authorization and returns the current user plus refresh token. */
extern "C" JNIEXPORT jobjectArray JNICALL
Java_com_minepacu_craftpresence_core_discord_NativeDiscordBridge_authorize(JNIEnv* env, jobject) {
    auto client = clientSnapshot();
    if (!client) return userResult(env, false, "", "", "Discord SDK is not configured.");

    const uint64_t clientId = parseApplicationId();
    if (clientId == 0) return userResult(env, false, "", "", "Invalid Discord application ID.");

    if (client->IsAuthenticated()) {
        auto user = client->GetCurrentUserV2();
        if (user.has_value()) {
            return userResult(env, true, std::to_string(user->Id()), user->Username(), "");
        }
    }

    auto operation = makePendingOperation();

    try {
        discordpp::AuthorizationArgs args;
        args.SetClientId(clientId);
        args.SetScopes(discordpp::Client::GetDefaultPresenceScopes());

        auto verifier = client->CreateAuthorizationCodeVerifier();
        const std::string verifierValue = verifier.Verifier();
        args.SetCodeChallenge(verifier.Challenge());

        client->Authorize(std::move(args), [client, clientId, verifierValue, operation](
            discordpp::ClientResult result,
            std::string code,
            std::string redirectUri
        ) {
            if (isOperationFinished(operation)) return;
            if (!result.Successful()) {
                completeOperation(operation, resultMessage(result));
                return;
            }

            client->GetToken(clientId, code, verifierValue, redirectUri, [client, operation](
                discordpp::ClientResult tokenResult,
                std::string accessToken,
                std::string refreshToken,
                discordpp::AuthorizationTokenType tokenType,
                int32_t,
                std::string
            ) {
                if (isOperationFinished(operation)) return;
                if (!tokenResult.Successful()) {
                    completeOperation(operation, resultMessage(tokenResult));
                    return;
                }

                if (!storeRefreshTokenIfActive(operation, refreshToken)) return;
                client->UpdateToken(tokenType, accessToken, [client, operation](discordpp::ClientResult updateResult) {
                    if (isOperationFinished(operation)) return;
                    if (!updateResult.Successful()) {
                        completeOperation(operation, resultMessage(updateResult));
                        return;
                    }
                    std::string error;
                    try {
                        client->Connect();
                    } catch (const std::exception& exception) {
                        error = exception.what();
                    }
                    completeOperation(operation, error);
                });
            });
        });
    } catch (const std::exception& exception) {
        return userResult(env, false, "", "", exception.what());
    }

    const bool finished = waitUntil([operation] { return isOperationCompleted(operation); }, kAuthTimeout);
    if (!finished) {
        markOperationTimedOut(operation);
        return userResult(env, false, "", "", "Discord authorization timed out.");
    }
    const auto error = operationError(operation);
    if (!error.empty()) return userResult(env, false, "", "", error);

    if (auto readyError = waitForReady(client.get())) {
        return userResult(env, false, "", "", *readyError);
    }

    auto user = client->GetCurrentUserV2();
    if (!user.has_value()) return userResult(env, false, "", "", "Discord user is unavailable.");

    const auto refreshToken = operationRefreshToken(operation);
    return userResult(env, true, std::to_string(user->Id()), user->Username(), "", refreshToken);
}

/** Refreshes Discord authorization using a saved refresh token. */
extern "C" JNIEXPORT jobjectArray JNICALL
Java_com_minepacu_craftpresence_core_discord_NativeDiscordBridge_refreshAuthorization(
    JNIEnv* env,
    jobject,
    jstring refreshToken
) {
    auto client = clientSnapshot();
    if (!client) return userResult(env, false, "", "", "Discord SDK is not configured.");

    const uint64_t clientId = parseApplicationId();
    if (clientId == 0) return userResult(env, false, "", "", "Invalid Discord application ID.");

    const auto previousRefreshToken = jstringToString(env, refreshToken);
    if (previousRefreshToken.empty()) return userResult(env, false, "", "", "Discord refresh token is missing.");

    auto operation = makePendingOperation();

    try {
        client->RefreshToken(clientId, previousRefreshToken, [client, operation](
            discordpp::ClientResult tokenResult,
            std::string accessToken,
            std::string refreshedToken,
            discordpp::AuthorizationTokenType tokenType,
            int32_t,
            std::string
        ) {
            if (isOperationFinished(operation)) return;
            if (!tokenResult.Successful()) {
                completeOperation(operation, resultMessage(tokenResult));
                return;
            }

            if (!storeRefreshTokenIfActive(operation, refreshedToken)) return;
            client->UpdateToken(tokenType, accessToken, [client, operation](discordpp::ClientResult updateResult) {
                if (isOperationFinished(operation)) return;
                if (!updateResult.Successful()) {
                    completeOperation(operation, resultMessage(updateResult));
                    return;
                }
                std::string error;
                try {
                    client->Connect();
                } catch (const std::exception& exception) {
                    error = exception.what();
                }
                completeOperation(operation, error);
            });
        });
    } catch (const std::exception& exception) {
        return userResult(env, false, "", "", exception.what());
    }

    const bool finished = waitUntil([operation] { return isOperationCompleted(operation); }, kAuthTimeout);
    if (!finished) {
        markOperationTimedOut(operation);
        return userResult(env, false, "", "", "Discord token refresh timed out.");
    }
    const auto error = operationError(operation);
    if (!error.empty()) return userResult(env, false, "", "", error);

    if (auto readyError = waitForReady(client.get())) {
        return userResult(env, false, "", "", *readyError);
    }

    auto user = client->GetCurrentUserV2();
    if (!user.has_value()) return userResult(env, false, "", "", "Discord user is unavailable.");

    return userResult(env, true, std::to_string(user->Id()), user->Username(), "", operationRefreshToken(operation));
}

/** Returns the current Discord user from the native SDK session. */
extern "C" JNIEXPORT jobjectArray JNICALL
Java_com_minepacu_craftpresence_core_discord_NativeDiscordBridge_currentUser(JNIEnv* env, jobject) {
    auto client = clientSnapshot();
    if (!client) return userResult(env, false, "", "", "Discord SDK is not configured.");

    try {
        auto user = client->GetCurrentUserV2();
        if (!user.has_value()) return userResult(env, false, "", "", "Discord user is unavailable.");
        return userResult(env, true, std::to_string(user->Id()), user->Username(), "");
    } catch (const std::exception& exception) {
        return userResult(env, false, "", "", exception.what());
    }
}

/** Disconnects the native Discord client. */
extern "C" JNIEXPORT jstring JNICALL
Java_com_minepacu_craftpresence_core_discord_NativeDiscordBridge_logout(JNIEnv* env, jobject) {
    auto client = clientSnapshot();
    if (!client) return stringToJstring(env, "Discord SDK is not configured.");
    try {
        client->Disconnect();
        return nullptr;
    } catch (const std::exception& exception) {
        return stringToJstring(env, exception.what());
    }
}

/** Converts Java activity fields into a Discord Rich Presence update. */
extern "C" JNIEXPORT jstring JNICALL
Java_com_minepacu_craftpresence_core_discord_NativeDiscordBridge_updateActivity(
    JNIEnv* env,
    jobject,
    jstring name,
    jstring state,
    jstring details,
    jstring largeImageKey,
    jstring largeImageText,
    jstring smallImageKey,
    jstring smallImageText,
    jstring partyId,
    jint partyCurrent,
    jint partyMax,
    jlong startEpochSeconds,
    jlong endEpochSeconds,
    jint activityType
) {
    discordpp::Activity activity;
    const auto nameString = jstringToString(env, name);
    activity.SetName(nameString.empty() ? "CraftPresence" : nameString);
    activity.SetType(activityTypeFromInt(activityType));

    const auto stateString = jstringToString(env, state);
    if (!stateString.empty()) activity.SetState(stateString);

    const auto detailsString = jstringToString(env, details);
    if (!detailsString.empty()) activity.SetDetails(detailsString);

    discordpp::ActivityAssets assets;
    bool hasAssets = false;
    const auto largeImage = jstringToString(env, largeImageKey);
    if (!largeImage.empty()) {
        assets.SetLargeImage(largeImage);
        hasAssets = true;
    }
    const auto largeText = jstringToString(env, largeImageText);
    if (!largeText.empty()) {
        assets.SetLargeText(largeText);
        hasAssets = true;
    }
    const auto smallImage = jstringToString(env, smallImageKey);
    if (!smallImage.empty()) {
        assets.SetSmallImage(smallImage);
        hasAssets = true;
    }
    const auto smallText = jstringToString(env, smallImageText);
    if (!smallText.empty()) {
        assets.SetSmallText(smallText);
        hasAssets = true;
    }
    if (hasAssets) activity.SetAssets(std::move(assets));

    if (startEpochSeconds > 0 || endEpochSeconds > 0) {
        discordpp::ActivityTimestamps timestamps;
        if (startEpochSeconds > 0) timestamps.SetStart(startEpochSeconds);
        if (endEpochSeconds > 0) timestamps.SetEnd(endEpochSeconds);
        activity.SetTimestamps(std::move(timestamps));
    }

    const auto party = jstringToString(env, partyId);
    if (!party.empty()) {
        discordpp::ActivityParty activityParty;
        activityParty.SetId(party);
        if (partyCurrent > 0) activityParty.SetCurrentSize(partyCurrent);
        if (partyMax > 0) activityParty.SetMaxSize(partyMax);
        activity.SetParty(std::move(activityParty));
    }

    if (auto error = updateRichPresence(std::move(activity))) {
        return stringToJstring(env, *error);
    }
    return nullptr;
}

/** Clears the currently published Discord Rich Presence activity. */
extern "C" JNIEXPORT jstring JNICALL
Java_com_minepacu_craftpresence_core_discord_NativeDiscordBridge_clearActivity(JNIEnv* env, jobject) {
    auto client = clientSnapshot();
    if (!client) return stringToJstring(env, "Discord SDK is not configured.");
    if (!client->IsAuthenticated()) return stringToJstring(env, "Discord is not authorized.");

    try {
        client->ClearRichPresence();
        pumpCallbacks();
    } catch (const std::exception& exception) {
        return stringToJstring(env, exception.what());
    }
    return nullptr;
}

/** Returns whether the native Discord client is authenticated. */
extern "C" JNIEXPORT jboolean JNICALL
Java_com_minepacu_craftpresence_core_discord_NativeDiscordBridge_isAuthorized(JNIEnv*, jobject) {
    auto client = clientSnapshot();
    if (!client) return JNI_FALSE;
    try {
        return client->IsAuthenticated() ? JNI_TRUE : JNI_FALSE;
    } catch (...) {
        return JNI_FALSE;
    }
}

/** Returns whether the native Discord client can currently provide user data. */
extern "C" JNIEXPORT jboolean JNICALL
Java_com_minepacu_craftpresence_core_discord_NativeDiscordBridge_isConnected(JNIEnv*, jobject) {
    auto client = clientSnapshot();
    if (!client) return JNI_FALSE;
    try {
        return client->IsAuthenticated() && client->GetCurrentUserV2().has_value() ? JNI_TRUE : JNI_FALSE;
    } catch (...) {
        return JNI_FALSE;
    }
}
