import SwiftUI
import Combine
import Discordpp

struct DiscordTestView: View {
    private var sdkManager = DiscordSDKManager.shared
    
    @State private var applicationID: String = ""
    @State private var configMessage: String = ""
    @State private var actionMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var currentUser: DiscordUser? = nil
    
    var body: some View {
        SwiftUI.NavigationView {
            SwiftUI.Form {
                SwiftUI.Section(header: Text("Configuration")) {
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
                
                SwiftUI.Section(header: Text("Authorization")) {
                    HStack {
                        Text("Status:")
                            .bold()
                        Spacer()
                        Text(statusText(for: sdkManager.authorizationStatus))
                            .foregroundColor(color(for: sdkManager.authorizationStatus))
                    }
                    if let user = currentUser {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current User:")
                                .bold()
                            Text("Username: \(user.username)#\(user.discriminator)")
                            Text("User ID: \(user.id)")
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
                }
                
                SwiftUI.Section(header: Text("Activity")) {
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
                    SwiftUI.Section {
                        Text(actionMessage)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("DiscordSDK Tester")
            .onAppear {
                loadApplicationID()
                if sdkManager.authorizationStatus == .authorized {
                    Task { await loadCurrentUser() }
                }
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
    }
    
    private func loadApplicationID() {
        if let id = Bundle.main.object(forInfoDictionaryKey: "APPLICATION_ID") as? String {
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
        do {
            // Attempt to fetch the current DiscordUser from the SDK manager
            let user = try await sdkManager.currentUser()
            self.currentUser = user
        } catch {
            // If the SDK indicates no user or an error, clear the current user
            self.currentUser = nil
        }
    }
    
    private func logout() async {
        actionMessage = ""
        isLoading = true
        do {
            try await sdkManager.logout()
            actionMessage = "Logged out successfully."
            self.currentUser = nil
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
