import SwiftUI
import Combine

// Mock DiscordSDKManager for demonstration purposes
// Remove or replace with actual DiscordSDKManager when integrating
class DiscordSDKManager: ObservableObject {
    enum AuthorizationStatus: String {
        case authorized = "Authorized"
        case unauthorized = "Unauthorized"
        case unknown = "Unknown"
    }
    
    struct UserInfo {
        let username: String
        let discriminator: String
        let id: String
    }
    
    @Published var authorizationStatus: AuthorizationStatus = .unknown
    @Published var currentUser: UserInfo? = nil
    
    static let shared = DiscordSDKManager()
    
    private init() {}
    
    func configure(with applicationID: String) async throws {
        // Simulate some configuration delay
        try await Task.sleep(nanoseconds: 300_000_000)
        // Configuration logic here
    }
    
    func authorize() async throws {
        // Simulate authorization
        try await Task.sleep(nanoseconds: 500_000_000)
        authorizationStatus = .authorized
        currentUser = UserInfo(username: "TestUser", discriminator: "1234", id: "567890")
    }
    
    func logout() async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        authorizationStatus = .unauthorized
        currentUser = nil
    }
    
    func updateActivity() async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
        // Update activity logic
    }
    
    func clearActivity() async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        // Clear activity logic
    }
}

struct DiscordSDKTesterView: View {
    @StateObject private var sdkManager = DiscordSDKManager.shared
    
    @State private var applicationID: String = ""
    @State private var configMessage: String = ""
    @State private var actionMessage: String = ""
    @State private var isLoading: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Configuration")) {
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
                
                Section(header: Text("Authorization")) {
                    HStack {
                        Text("Status:")
                            .bold()
                        Spacer()
                        Text(sdkManager.authorizationStatus.rawValue)
                            .foregroundColor(color(for: sdkManager.authorizationStatus))
                    }
                    if let user = sdkManager.currentUser {
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
                
                Section(header: Text("Activity")) {
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
            .navigationTitle("DiscordSDK Tester")
            .onAppear {
                loadApplicationID()
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
            try await sdkManager.configure(with: applicationID)
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
            try await sdkManager.authorize()
            actionMessage = "Authorization successful."
        } catch {
            actionMessage = "Authorization failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func logout() async {
        actionMessage = ""
        isLoading = true
        do {
            try await sdkManager.logout()
            actionMessage = "Logged out successfully."
        } catch {
            actionMessage = "Logout failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func updateActivity() async {
        actionMessage = ""
        isLoading = true
        do {
            try await sdkManager.updateActivity()
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
}

struct DiscordSDKTesterView_Previews: PreviewProvider {
    static var previews: some View {
        DiscordSDKTesterView()
    }
}
