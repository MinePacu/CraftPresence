import SwiftUI
import Combine

struct DiscordTestView: View {
    @StateObject private var sdkManager = DiscordSDKManager.shared
    
    @State private var applicationID: String = ""
    @State private var configMessage: String = ""
    @State private var actionMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var activityName: String = "CraftPresence"
    @State private var activityStateText: String = "Using DiscordSDKManager"
    @State private var activityDetailsText: String = "Testing Activity"
    @State private var activityLargeImageKey: String = "large_image"
    @State private var activitySmallImageKey: String = "small_image"
    @State private var selectedActivityType: DiscordActivity.ActivityType = .playing
    @State private var includeStartTimestamp: Bool = false
    @State private var includeEndTimestamp: Bool = false
    @State private var activityStartDate: Date = .now
    @State private var activityEndDate: Date = .now
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Label("Discord Test", systemImage: "gamecontroller")
                    .font(.title2).bold()
                
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
                        if let user = sdkManager.currentUser {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current User:")
                                    .bold()
                                Text("Username: \(user.username)")
                                Text("ID: \(user.id)")
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
                                Task { await loadCurrentUser(showErrors: true) }
                            }
                            .disabled(isLoading)
                        }
                    }
                    
                    Section("Activity") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("App Name (e.g., CraftPresence)", text: $activityName)
                                .textFieldStyle(.roundedBorder)
                            TextField("State (optional)", text: $activityStateText)
                                .textFieldStyle(.roundedBorder)
                            TextField("Details (optional)", text: $activityDetailsText)
                                .textFieldStyle(.roundedBorder)
                            TextField("Large Image Key", text: $activityLargeImageKey)
                                .textFieldStyle(.roundedBorder)
                            TextField("Small Image Key", text: $activitySmallImageKey)
                                .textFieldStyle(.roundedBorder)
                            Picker("Activity Type", selection: $selectedActivityType) {
                                ForEach(DiscordActivity.ActivityType.allCases) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            Toggle("Include Start Timestamp", isOn: $includeStartTimestamp.animation())
                            if includeStartTimestamp {
                                DatePicker("Start Time", selection: $activityStartDate)
                                    .datePickerStyle(.compact)
                            }
                            Toggle("Include End Timestamp", isOn: $includeEndTimestamp.animation())
                            if includeEndTimestamp {
                                DatePicker("End Time", selection: $activityEndDate)
                                    .datePickerStyle(.compact)
                            }
                            Text("Leave a field empty to omit it from the payload.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Button("Update Activity") {
                                Task {
                                    await updateActivity()
                                }
                            }
                            .disabled(isLoading)
                            Spacer()
                            Button("Clear Activity") {
                                Task {
                                    await clearActivity()
                                }
                            }
                            .disabled(isLoading)
                        }
                    }
                    
                    if !actionMessage.isEmpty {
                        Section {
                            Text(actionMessage)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
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
        } else if let envId = envValue, !envId.isEmpty {
            applicationID = envId
        } else {
            applicationID = resolved
        }
    }
    
    private func configureSDK() async {
        configMessage = ""
        actionMessage = ""
        isLoading = true
        // configure는 throws하지 않으므로 try 불필요
        sdkManager.configure(applicationId: applicationID, autoAuthorize: false)
        configMessage = "Successfully configured with APPLICATION_ID."
        isLoading = false
    }
    
    private func authorize() async {
        actionMessage = ""
        isLoading = true
        do {
            _ = try await sdkManager.authorizeIfNeeded()
            actionMessage = "Authorization successful."
        } catch {
            actionMessage = "Authorization failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func loadCurrentUser(showErrors: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await sdkManager.currentUser()
        } catch {
            if showErrors {
                actionMessage = "Failed to load user: \(error.localizedDescription)"
            }
        }
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
            let nameValue = activityName.trimmingCharacters(in: .whitespacesAndNewlines)
            let stateValue = activityStateText.trimmingCharacters(in: .whitespacesAndNewlines)
            let detailsValue = activityDetailsText.trimmingCharacters(in: .whitespacesAndNewlines)
            let largeKeyValue = activityLargeImageKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let smallKeyValue = activitySmallImageKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let startDate = includeStartTimestamp ? activityStartDate : nil
            let endDate = includeEndTimestamp ? activityEndDate : nil
            
            var activity = DiscordActivity()
            activity.name = nameValue.isEmpty ? nil : nameValue
            activity.state = stateValue.isEmpty ? nil : stateValue
            activity.details = detailsValue.isEmpty ? nil : detailsValue
            activity.assets = .init(
                largeImage: largeKeyValue.isEmpty ? nil : largeKeyValue,
                smallImage: smallKeyValue.isEmpty ? nil : smallKeyValue
            )
            activity.timestamps = .init(start: startDate, end: endDate)
            activity.type = selectedActivityType
            
            try await sdkManager.updateActivity(
                name: activity.name,
                state: activity.state,
                details: activity.details,
                largeImageKey: activity.assets.largeImage,
                smallImageKey: activity.assets.smallImage,
                start: activity.timestamps.start,
                end: activity.timestamps.end,
                activityType: activity.type
            )
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
