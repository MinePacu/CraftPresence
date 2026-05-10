//  ContentView.swift
//  CraftPresence

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit
#if os(macOS)
import ApplicationServices
#endif

// MARK: - ContentView

/// Root container view that coordinates navigation, foreground app tracking, and Rich Presence updates.
struct ContentView: View {
    // MARK: Types & Identifiers

    /// Navigation targets presented in the split view detail column.
    private enum DetailSelection: Equatable {
        case overview
        case programs
        case builtin
        case about
        case item(Item)
        case discordTest
        case nowPlayingTest
        case none

        static func == (lhs: DetailSelection, rhs: DetailSelection) -> Bool {
            switch (lhs, rhs) {
            case (.overview, .overview): return true
            case (.programs, .programs): return true
            case (.builtin, .builtin): return true
            case (.about, .about): return true
            case (.discordTest, .discordTest): return true
            case (.nowPlayingTest, .nowPlayingTest): return true
            case (.none, .none): return true
            case let (.item(li), .item(ri)): return li.id == ri.id
            default: return false
            }
        }
    }

    // MARK: State & Model Bindings

    @State private var selectionStack: [DetailSelection] = []

    @State private var selection: DetailSelection = .overview

    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var programIDs: [String] = []
    @State private var isLoadingPrograms: Bool = true
    @State private var showingProgramSettings: Bool = false
    @State private var selectedProgramIDForSettings: String? = nil
    @State private var activeAppName: String? = nil
    @State private var activeBundleID: String? = nil
    @State private var activeWindowTitle: String? = nil
    @State private var lastProgramPresenceSignature: String? = nil
    @State private var lastProgramPresenceBundleID: String? = nil

    // Settings presentation
    @AppStorage("menuBarOnlyEnabled") private var menuBarOnlyEnabled: Bool = false
    @EnvironmentObject private var localizationManager: LocalizationManager
#if os(macOS)
    @Environment(\.openSettings) private var openSettings
#endif

    // MARK: Body

    var body: some View {
        // MARK: Sidebar (Navigation List)
        NavigationSplitView {
            List(selection: Binding(get: {
                switch selection {
                case .overview: return "overview"
                case .programs: return "programs"
                case .builtin: return "builtin"
                case .about: return "about"
                case .discordTest: return "discordTest"
                case .nowPlayingTest: return "nowPlayingTest"
                case .item(let item): return "item-\(item.id)"
                case .none: return nil
                }
            }, set: { newValue in
                guard let key = newValue else { return }
                let previousSelection = selection
                if key == "overview" { selection = .overview }
                else if key == "programs" { selection = .programs }
                else if key == "builtin" { selection = .builtin }
                else if key == "about" { selection = .about }
                else if key == "discordTest" { selection = .discordTest }
                else if key == "nowPlayingTest" { selection = .nowPlayingTest }
                else if key.hasPrefix("item-") {
                    if let idString = key.split(separator: "-").last,
                       let match = items.first(where: { "\($0.id)" == idString }) {
                        selection = .item(match)
                    }
                }
                if previousSelection != selection {
                    selectionStack.append(previousSelection)
                }
            })) {
                Section(t("sidebar.section.menu")) {
                    Label(t("sidebar.overview"), systemImage: "rectangle.and.text.magnifyingglass")
                        .tag("overview")
                        .accessibilityIdentifier("sidebar.overview")
                    Label(t("sidebar.programs"), systemImage: "list.bullet.rectangle")
                        .tag("programs")
                        .accessibilityIdentifier("sidebar.programs")
                    Label(t("sidebar.builtin"), systemImage: "bolt.fill")
                        .tag("builtin")
                        .accessibilityIdentifier("sidebar.builtin")
                    Label(t("sidebar.about"), systemImage: "info.circle")
                        .tag("about")
                        .accessibilityIdentifier("sidebar.about")
                }

                Section(t("sidebar.section.test")) {
                    Label(t("sidebar.discord_test"), systemImage: "gamecontroller")
                        .tag("discordTest")
                        .accessibilityIdentifier("sidebar.discordTest")
                    Label(t("sidebar.now_playing_test"), systemImage: "music.note")
                        .tag("nowPlayingTest")
                        .accessibilityIdentifier("sidebar.nowPlayingTest")
                    ForEach(items) { item in
                        Label(item.timestamp.formatted(date: .numeric, time: .standard), systemImage: "clock")
                        .tag("item-\(item.id)")
                        .accessibilityIdentifier("sidebar.item.\(item.id)")
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            Group {
                // MARK: Detail - Overview
                switch selection {
                case .overview:
                    OverviewView(
                        activeAppName: activeAppName,
                        activeWindowTitle: activeWindowTitle,
                        activeBundleID: activeBundleID,
                        programIDs: programIDs
                    )
                // MARK: Detail - Programs
                case .programs:
                    ProgramsView(
                        programIDs: $programIDs,
                        isLoadingPrograms: $isLoadingPrograms,
                        showingProgramSettings: $showingProgramSettings,
                        selectedProgramIDForSettings: $selectedProgramIDForSettings
                    )
                    .task {
                        do {
                            let current = await ConfigUtility.shared.currentSettings()
                            programIDs = current.bundleIDs
                        }
                        isLoadingPrograms = false
                    }
                // MARK: Detail - Built-in
                case .builtin:
                    BuiltinView()
                // MARK: Detail - About
                case .about:
                    AboutView(
                        activeAppName: activeAppName,
                        activeWindowTitle: activeWindowTitle,
                        activeBundleID: activeBundleID
                    )
                // MARK: Detail - DiscordTest
                case .discordTest:
                    DiscordTestView()

                // MARK: Detail - NowPlayingTest
                case .nowPlayingTest:
                    NowPlayingTestView()

                // MARK: Detail - Item
                case .item(let item):
                    Text(t("content.item_at") + " " + item.timestamp.formatted(date: .numeric, time: .standard))
                // MARK: Detail - None
                case .none:
                    EmptyView()
                }
            }
            .navigationTitle("")
    #if os(macOS)
            .toolbarBackground(.hidden, for: .windowToolbar)
    #endif
    #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
    #endif
    #if os(macOS)
            .toolbar {
                // 뒤로 버튼
                if !selectionStack.isEmpty {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            if let last = selectionStack.popLast() {
                                selection = last
                            }
                        } label: {
                            Label(t("toolbar.back"), systemImage: "chevron.left")
                        }
                    }
                }
                // 설정 버튼
                ToolbarItem(placement: .automatic) {
                    Button {
                        openSettings()
                    } label: {
                        Label(t("toolbar.settings"), systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("toolbar.settings")
                }
            }
    #endif
        }
        .task {
            applyAutomationStateIfNeeded()

            guard !AutomationLaunchOptions.shouldDisableProgramDetector else {
                do {
                    let current = await ConfigUtility.shared.currentSettings()
                    await MainActor.run {
                        self.programIDs = current.bundleIDs
                    }
                }
                return
            }

            // Subscribe to ProgramDetector updates
            ProgramDetector.shared.start()
            do {
                let current = await ConfigUtility.shared.currentSettings()
                await MainActor.run {
                    self.programIDs = current.bundleIDs
                }
            }

            for await update in ProgramDetector.shared.updatesStream() {
                if Task.isCancelled { break }
    #if os(macOS)
                let stabilizedTitle = await fetchFocusedWindowTitleWithRetries(pid: nil, retries: 4, delayNanoseconds: 150_000_000) ?? update.windowTitle
                await MainActor.run {
                    self.activeAppName = update.appName
                    self.activeBundleID = update.bundleID
                    self.activeWindowTitle = stabilizedTitle
                }
                await handleProgramPresenceUpdate(
                    appName: update.appName,
                    bundleID: update.bundleID,
                    windowTitle: stabilizedTitle
                )
    #else
                await MainActor.run {
                    self.activeAppName = update.appName
                    self.activeBundleID = update.bundleID
                    self.activeWindowTitle = update.windowTitle
                }
                await handleProgramPresenceUpdate(
                    appName: update.appName,
                    bundleID: update.bundleID,
                    windowTitle: update.windowTitle
                )
    #endif
            }
        }
        .onAppear {
            // 앱이 보일 때 저장된 설정을 즉시 반영
            applyMenuBarMode(menuBarOnlyEnabled)
        }
    }

    // MARK: - Actions

    /// Inserts a timestamped sample item into the local SwiftData store.
    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

#if os(macOS)
    /// Attempts to fetch the focused window title using AX API with small delay and limited retries.
    private func fetchFocusedWindowTitleWithRetries(pid: pid_t? = nil,
                                                    retries: Int = 4,
                                                    delayNanoseconds: UInt64 = 150_000_000) async -> String? {
        for attempt in 0..<max(1, retries) {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            if let title = fetchFocusedWindowTitleOnce(pid: pid) {
                return title
            }
        }
        return nil
    }

    /// Single-shot attempt to obtain the focused window title via AX.
    private func fetchFocusedWindowTitleOnce(pid: pid_t? = nil) -> String? {
        guard AXIsProcessTrusted() else {
            return nil
        }
        let appAX: AXUIElement?
        if let pid = pid {
            appAX = AXUIElementCreateApplication(pid)
        } else {
            let systemWide = AXUIElementCreateSystemWide()
            var focusedApp: AnyObject?
            let appErr = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp)
            if appErr != .success {
                return nil
            }
            appAX = focusedApp as! AXUIElement?
        }

        guard let appElement = appAX else {
            return nil
        }

        var windowObj: AnyObject?
        let winErr = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowObj)
        if winErr != .success {
            return nil
        }
        guard let windowEl = windowObj as! AXUIElement? else {
            return nil
        }

        var titleObj: AnyObject?
        let titleErr = AXUIElementCopyAttributeValue(windowEl, kAXTitleAttribute as CFString, &titleObj)
        if titleErr != .success {
            return nil
        }
        guard let title = titleObj as? String, !title.isEmpty else {
            return nil
        }
        return title
    }
#endif

    // MARK: - Data Operations

    /// Deletes stored sample items from the SwiftData context.
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }

    // MARK: - Helpers
    /// Applies the user's menu-bar-only preference on macOS.
    private func applyMenuBarMode(_ enabled: Bool) {
        #if os(macOS)
        if enabled {
            LSUIElementController.shared.enableMenuBarOnly()
        } else {
            LSUIElementController.shared.disableMenuBarOnly()
        }
        #endif
    }

    /// Hydrates screen state from launch arguments when the app is running under UI automation.
    private func applyAutomationStateIfNeeded() {
        guard AutomationLaunchOptions.isUITesting else { return }

        if !AutomationLaunchOptions.seedBundleIDs.isEmpty {
            self.programIDs = AutomationLaunchOptions.seedBundleIDs.sorted()
            self.isLoadingPrograms = false
        }

        if let activeAppName = AutomationLaunchOptions.activeAppName {
            self.activeAppName = activeAppName
        }

        if let activeBundleID = AutomationLaunchOptions.activeBundleID {
            self.activeBundleID = activeBundleID
        }

        if let activeWindowTitle = AutomationLaunchOptions.activeWindowTitle {
            self.activeWindowTitle = activeWindowTitle
        }
    }

    @MainActor
    /// Renders the configured Discord activity for the current foreground program and sends it when needed.
    private func handleProgramPresenceUpdate(
        appName: String?,
        bundleID: String?,
        windowTitle: String?
    ) async {
        guard let bundleID, programIDs.contains(bundleID) else {
            if lastProgramPresenceBundleID != nil {
                lastProgramPresenceBundleID = nil
                lastProgramPresenceSignature = nil
                try? await DiscordSDKManager.shared.clearAppliedPresence(ifOwnedBy: .program)
            }
            return
        }

        let settings = await ConfigUtility.shared.programSettings(for: bundleID)
        let renderedDetails = renderProgramTemplate(
            settings.detailText,
            fallback: appName ?? bundleID,
            appName: appName,
            bundleID: bundleID,
            windowTitle: windowTitle
        )
        let renderedState = renderProgramTemplate(
            settings.stateText,
            fallback: windowTitle,
            appName: appName,
            bundleID: bundleID,
            windowTitle: windowTitle
        )
        let renderedLargeImageText = renderProgramTemplate(
            settings.largeImageText,
            fallback: appName,
            appName: appName,
            bundleID: bundleID,
            windowTitle: windowTitle
        )
        let renderedSmallImageText = renderProgramTemplate(
            settings.smallImageText,
            fallback: windowTitle,
            appName: appName,
            bundleID: bundleID,
            windowTitle: windowTitle
        )
        let resolvedParty = resolveProgramParty(for: settings, bundleID: bundleID)

        let signature = [
            bundleID,
            appName ?? "",
            windowTitle ?? "",
            settings.activityType.rawValue,
            renderedDetails ?? "",
            renderedState ?? "",
            renderedLargeImageText ?? "",
            renderedSmallImageText ?? "",
            settings.useAppIconForLargeImage ? "icon" : settings.largeImageKey,
            settings.smallImageKey,
            resolvedParty.id ?? "",
            resolvedParty.currentSize.map(String.init) ?? "",
            resolvedParty.maxSize.map(String.init) ?? ""
        ].joined(separator: "|")

        guard signature != lastProgramPresenceSignature else { return }

        do {
            let payload = AppliedPresencePayload(
                name: appName ?? bundleID,
                state: renderedState,
                details: renderedDetails,
                largeImageKey: settings.useAppIconForLargeImage ? nil : settings.largeImageKey.nilIfEmpty,
                largeImageText: renderedLargeImageText,
                smallImageKey: settings.smallImageKey.nilIfEmpty,
                smallImageText: renderedSmallImageText,
                partyID: resolvedParty.id,
                partyCurrent: resolvedParty.currentSize,
                partyMax: resolvedParty.maxSize,
                start: nil,
                end: nil,
                activityType: settings.activityType,
                source: .program
            )
            try await DiscordSDKManager.shared.publishAppliedPresence(payload)
            lastProgramPresenceBundleID = bundleID
            lastProgramPresenceSignature = signature
        } catch {
            // Leave the signature unchanged so a later state transition can retry.
        }
    }

    /// Replaces supported placeholders in saved template strings with the latest detected program values.
    private func renderProgramTemplate(
        _ template: String,
        fallback: String?,
        appName: String?,
        bundleID: String,
        windowTitle: String?
    ) -> String? {
        let trimmed = template.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return fallback?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }

        let resolved = trimmed
            .replacingOccurrences(of: "{appName}", with: appName ?? "")
            .replacingOccurrences(of: "{bundleID}", with: bundleID)
            .replacingOccurrences(of: "{windowTitle}", with: windowTitle ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return resolved.nilIfEmpty
    }

    /// Converts stored party size settings into the Discord party payload expected by the SDK wrapper.
    private func resolveProgramParty(
        for settings: ProgramPresenceSettings,
        bundleID: String
    ) -> DiscordActivity.Party {
        guard settings.partyCurrent > 0, settings.partyMax >= settings.partyCurrent else {
            return .init(id: nil, currentSize: nil, maxSize: nil)
        }

        return .init(
            id: "program:\(bundleID)",
            currentSize: settings.partyCurrent,
            maxSize: settings.partyMax
        )
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }
}

extension ProgramPresenceSettings.ActivityType {
    var discordActivityType: DiscordActivity.ActivityType {
        switch self {
        case .playing:
            return .playing
        case .streaming:
            return .streaming
        case .listening:
            return .listening
        case .watching:
            return .watching
        case .competing:
            return .competing
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#if os(iOS)
import PhotosUI

private struct ImagePicker: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage) -> Void
        init(onPick: @escaping (UIImage) -> Void) { self.onPick = onPick }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { obj, _ in
                if let uiImage = obj as? UIImage {
                    DispatchQueue.main.async {
                        self.onPick(uiImage)
                    }
                }
            }
        }
    }
}
#endif

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
