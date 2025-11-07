import SwiftUI
import Combine

struct DiscordTestView: View {
    private var sdkManager = DiscordSDKManager.shared
    
    @State private var applicationID: String = ""
    @State private var configMessage: String = ""
    @State private var actionMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var currentUser: Any? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Form {
                Section("Configuration") {
                    HStack {
                        Text("APPLICATION_ID:")
                            .bold()
                        Spacer()
                        Text(applicationID.isEmpty ? "Not loaded" : applicationID)
                            .foregroundColor(applicationID.isEmpty ? .secondary : .primary)
                            .multilineTextAlignment(.trailing)
                    }
                    Button("Configure DiscordSDKManager") {
                        Task {
                            await configureSDK()
                        }
                    }
                    .disabled(isLoading || applicationID.isEmpty)
                    if !configMessage.isEmpty {
                        Text(configMessage)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Authorization") {
                    HStack {
                        Text("Status:")
                            .bold()
                        Spacer()
                        Text(statusText(for: sdkManager.authorizationStatus))
                            .foregroundColor(color(for: sdkManager.authorizationStatus))
                    }
                    if let userAny = currentUser {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current User:")
                                .bold()
                            let usernameText: String = formatUsername(from: userAny)
                            Text("Username: \(usernameText)")
                            Text("User: \(String(describing: userAny))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("No user authorized")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Button("Authorize") {
                            Task {
                                await authorize()
                            }
                        }
                        .disabled(isLoading)
                        Spacer()
                        Button("Logout") {
                            Task {
                                await logout()
                            }
                        }
                        .disabled(isLoading || sdkManager.authorizationStatus != .authorized)
                    }
                    HStack {
                        Button("Refresh User") {
                            Task { await loadCurrentUser() }
                        }
                        .disabled(isLoading)
                    }
                }

                Section("Activity") {
                    HStack {
                        Button("Update Activity") {
                            Task {
                                await updateActivity()
                            }
                        }
                        .disabled(isLoading || sdkManager.authorizationStatus != .authorized)
                        Spacer()
                        Button("Clear Activity") {
                            Task {
                                await clearActivity()
                            }
                        }
                        .disabled(isLoading || sdkManager.authorizationStatus != .authorized)
                    }
                }

                if !actionMessage.isEmpty {
                    Section {
                        Text(actionMessage)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .onAppear {
            loadApplicationID()
            Task { await loadCurrentUser() }
        }
        .disabled(isLoading)
        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView()
                }
            }
        }
    }
    
    private func loadApplicationID() {
        // 1) Read from Info.plist
        let plistValue = Bundle.main.object(forInfoDictionaryKey: "APPLICATION_ID") as? String
        // print("[DiscordTestView] Info.plist APPLICATION_ID = \(plistValue ?? "nil")")

        // 2) Read from environment
        let envValue = ProcessInfo.processInfo.environment["APPLICATION_ID"]
        // print("[DiscordTestView] ENV APPLICATION_ID = \(envValue ?? "nil")")

        // 3) Resolved by DiscordAppConfig (plist > env > fallback)
        let resolved = DiscordAppConfig.applicationId
        // print("[DiscordTestView] Resolved APPLICATION_ID (DiscordAppConfig) = \(resolved)")

        if let id = plistValue, !id.isEmpty {
            applicationID = id
        } else {
            applicationID = ""
        }
    }
    
    private func configureSDK() async {
        configMessage = ""
        actionMessage = ""
        isLoading = true
        do {
            try await sdkManager.configure(applicationId: applicationID)
            configMessage = "Successfully configured with APPLICATION_ID."
        } catch {
            configMessage = "Failed to configure SDK: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func authorize() async {
        actionMessage = ""
        isLoading = true
        do {
            try await sdkManager.authorizeIfNeeded()
            actionMessage = "Authorization successful."
            await loadCurrentUser()
        } catch {
            actionMessage = "Authorization failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func loadCurrentUser() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // If sdkManager.currentUser() is async/throws, use try await. Adjust as needed.
            if let user = try? await (sdkManager.currentUser() as Any?) {
                self.currentUser = user
            } else {
                self.currentUser = nil
            }
        }
    }
    
    private func logout() async {
        actionMessage = ""
        isLoading = true
        do {
            try await sdkManager.logout()
            actionMessage = "Logged out successfully."
            await loadCurrentUser()
        } catch {
            actionMessage = "Logout failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func updateActivity() async {
        actionMessage = ""
        isLoading = true
        do {
            try await sdkManager.updateActivity(state: "Using DiscordSDKManager", details: "Testing Activity", largeImageKey: "large_image", smallImageKey: "small_image")
            actionMessage = "Activity updated successfully."
        } catch {
            actionMessage = "Update activity failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func clearActivity() async {
        actionMessage = ""
        isLoading = true
        do {
            try await sdkManager.clearActivity()
            actionMessage = "Activity cleared successfully."
        } catch {
            actionMessage = "Clear activity failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func formatUsername(from anyUser: Any) -> String {
        // Try to extract common properties via reflection
        let mirror = Mirror(reflecting: anyUser)
        var name: String?
        var discriminator: String?
        var idText: String?
        for child in mirror.children {
            switch child.label ?? "" {
            case "username", "name", "userName":
                name = String(describing: child.value)
            case "discriminator", "tag":
                discriminator = String(describing: child.value)
            case "id", "userID", "userId":
                idText = String(describing: child.value)
            default:
                break
            }
        }
        if let name = name {
            if let disc = discriminator, !disc.isEmpty, disc != "0" {
                return "\(name)#\(disc)"
            }
            return name
        }
        if let idText = idText { return idText }
        return String(describing: anyUser)
    }
    
    private func color(for status: DiscordSDKManager.AuthorizationStatus) -> Color {
        switch status {
        case .authorized:
            return .green
        case .unauthorized:
            return .red
        case .unknown:
            return .gray
        }
    }

    private func statusText(for status: DiscordSDKManager.AuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "Authorized"
        case .unauthorized:
            return "Unauthorized"
        case .unknown:
            return "Unknown"
        }
    }
}

struct DiscordTestView_Previews: PreviewProvider {
    static var previews: some View {
        DiscordTestView()
    }
}
