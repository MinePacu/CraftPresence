//  ContentView.swift
//  CraftPresence

import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
import ApplicationServices
#endif

// MARK: - ContentView

/// Root container view that coordinates navigation, foreground app tracking, and Rich Presence updates.
struct ContentView: View {
    // MARK: Types & Identifiers

    /// Navigation targets presented in the split view detail column.
    private enum DetailSelection: Equatable, Hashable {
        case overview
        case customPresence
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
            case (.customPresence, .customPresence): return true
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

        func hash(into hasher: inout Hasher) {
            switch self {
            case .overview:
                hasher.combine("overview")
            case .customPresence:
                hasher.combine("customPresence")
            case .programs:
                hasher.combine("programs")
            case .builtin:
                hasher.combine("builtin")
            case .about:
                hasher.combine("about")
            case .discordTest:
                hasher.combine("discordTest")
            case .nowPlayingTest:
                hasher.combine("nowPlayingTest")
            case .none:
                hasher.combine("none")
            case .item(let item):
                hasher.combine("item")
                hasher.combine(item.id)
            }
        }
    }

    // MARK: State & Model Bindings

    @State private var selectionStack: [DetailSelection] = []

    @State private var selection: DetailSelection = .overview

    @State private var items: [Item] = []
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
    @State private var showingSettings: Bool = false
    @AppStorage("menuBarOnlyEnabled") private var menuBarOnlyEnabled: Bool = false
    @EnvironmentObject private var localizationManager: LocalizationManager

    // MARK: Body

    var body: some View {
        Group {
#if os(iOS)
            if isPad {
                ipadSettingsNavigation
            } else {
                compactNavigation
            }
#else
            regularNavigation
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
            Task(priority: .utility) {
                for await update in ProgramDetector.shared.updatesStream() {
                    if Task.isCancelled { break }
    #if os(macOS)
                    let stabilizedTitle = await fetchFocusedWindowTitleWithRetries(pid: nil, retries: 4, delayNanoseconds: 150_000_000) ?? update.windowTitle
                    await MainActor.run {
                        self.activeAppName = update.appName
                        self.activeBundleID = update.bundleID
                        self.activeWindowTitle = stabilizedTitle
                    }
    #else
                    await MainActor.run {
                        self.activeAppName = update.appName
                        self.activeBundleID = update.bundleID
                        self.activeWindowTitle = update.windowTitle
                    }
    #endif
                }
            }
            do {
                let current = await ConfigUtility.shared.currentSettings()
                await MainActor.run {
                    self.programIDs = current.bundleIDs
                }
            }
        }
        .onAppear {
            // 앱이 보일 때 저장된 설정을 즉시 반영
            applyMenuBarMode(menuBarOnlyEnabled)
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
    }

    // MARK: Navigation

    private var regularNavigation: some View {
        // MARK: Sidebar (Navigation List)
        NavigationSplitView {
            List(selection: Binding(get: {
                switch selection {
                case .overview: return "overview"
                case .customPresence: return "customPresence"
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
                if key == "overview" { selection = .overview }
                else if key == "customPresence" { selection = .customPresence }
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
            })) {
                Section(t("sidebar.section.menu")) {
                    SidebarRow(title: t("sidebar.overview"), systemImage: "rectangle.and.text.magnifyingglass", isSelected: selection == .overview, tint: .pink, accessibilityIdentifier: "sidebar.overview") {
                        if selection != .overview { selectionStack.append(selection) }
                        selection = .overview
                    }
                    SidebarRow(title: t("sidebar.custom_presence"), systemImage: "slider.horizontal.3", isSelected: selection == .customPresence, tint: .pink, accessibilityIdentifier: "sidebar.customPresence") {
                        if selection != .customPresence { selectionStack.append(selection) }
                        selection = .customPresence
                    }
                    SidebarRow(title: t("sidebar.programs"), systemImage: "list.bullet.rectangle", isSelected: selection == .programs, tint: .pink, accessibilityIdentifier: "sidebar.programs") {
                        if selection != .programs { selectionStack.append(selection) }
                        selection = .programs
                    }
                    SidebarRow(title: t("sidebar.about"), systemImage: "info.circle", isSelected: selection == .about, tint: .pink, accessibilityIdentifier: "sidebar.about") {
                        if selection != .about { selectionStack.append(selection) }
                        selection = .about
                    }
                }

                Section(t("sidebar.section.test")) {
                    SidebarRow(title: t("sidebar.discord_test"), systemImage: "gamecontroller", isSelected: selection == .discordTest, tint: .pink, accessibilityIdentifier: "sidebar.discordTest") {
                        if selection != .discordTest { selectionStack.append(selection) }
                        selection = .discordTest
                    }
                    SidebarRow(title: t("sidebar.now_playing_test"), systemImage: "music.note", isSelected: selection == .nowPlayingTest, tint: .pink, accessibilityIdentifier: "sidebar.nowPlayingTest") {
                        if selection != .nowPlayingTest { selectionStack.append(selection) }
                        selection = .nowPlayingTest
                    }
                    ForEach(items) { item in
                        SidebarRow(title: item.timestamp.formatted(date: .numeric, time: .standard), systemImage: "clock", isSelected: {
                            if case .item(let selected) = selection { return selected.id == item.id }
                            return false
                        }(), tint: .gray, accessibilityIdentifier: "sidebar.item.\(item.id)") {
                            selectionStack.append(selection)
                            selection = .item(item)
                        }
                        .tag("item-\(item.id)")
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            detailContent(for: selection)
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
                        showingSettings = true
                    } label: {
                        Label(t("toolbar.settings"), systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("toolbar.settings")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingView()
                    .onAppear {
                        // 설정 화면을 열 때 현재 값 적용을 한 번 더 보장
                        applyMenuBarMode(menuBarOnlyEnabled)
                    }
            }
    #endif
        }
    }

#if os(iOS)
    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var compactNavigation: some View {
        NavigationStack {
            CPSettingsPage {
                CPHeaderCard(
                    title: "CraftPresence",
                    subtitle: t("overview.subtitle"),
                    systemImage: "sparkles",
                    tint: .pink
                )

                CPGroupedSection {
                    NavigationLink(value: DetailSelection.overview) {
                        CPNavigationRow(
                            title: t("sidebar.overview"),
                            subtitle: nil,
                            systemImage: "rectangle.and.text.magnifyingglass",
                            tint: .pink
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sidebar.overview")
                    CPSectionDivider()

                    NavigationLink(value: DetailSelection.customPresence) {
                        CPNavigationRow(
                            title: t("sidebar.custom_presence"),
                            subtitle: nil,
                            systemImage: "slider.horizontal.3",
                            tint: .blue
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sidebar.customPresence")
                    CPSectionDivider()

                    NavigationLink(value: DetailSelection.programs) {
                        CPNavigationRow(
                            title: t("sidebar.programs"),
                            subtitle: nil,
                            systemImage: "list.bullet.rectangle",
                            tint: .orange
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sidebar.programs")
                    CPSectionDivider()

                    NavigationLink(value: DetailSelection.about) {
                        CPNavigationRow(
                            title: t("sidebar.about"),
                            subtitle: nil,
                            systemImage: "info.circle",
                            tint: .gray
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sidebar.about")
                }

                CPGroupedSection {
                    NavigationLink(value: DetailSelection.discordTest) {
                        CPNavigationRow(
                            title: t("sidebar.discord_test"),
                            subtitle: nil,
                            systemImage: "gamecontroller",
                            tint: .purple
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sidebar.discordTest")
                    CPSectionDivider()

                    NavigationLink(value: DetailSelection.nowPlayingTest) {
                        CPNavigationRow(
                            title: t("sidebar.now_playing_test"),
                            subtitle: nil,
                            systemImage: "music.note",
                            tint: .green
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sidebar.nowPlayingTest")

                    ForEach(items) { item in
                        CPSectionDivider()
                        NavigationLink(value: DetailSelection.item(item)) {
                            CPNavigationRow(
                                title: item.timestamp.formatted(date: .numeric, time: .standard),
                                subtitle: nil,
                                systemImage: "clock",
                                tint: .gray
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("sidebar.item.\(item.id)")
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label(t("toolbar.settings"), systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("toolbar.settings")
                }
            }
            .navigationDestination(for: DetailSelection.self) { selection in
                detailContent(for: selection)
                    .navigationTitle(title(for: selection))
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingView()
        }
    }

    private var ipadSettingsNavigation: some View {
        GeometryReader { proxy in
            HStack(spacing: 18) {
                ipadSidebar
                    .frame(width: min(max(proxy.size.width * 0.34, 320), 380))

                VStack(spacing: 0) {
                    ZStack {
                        Text(title(for: selection))
                            .font(.headline)

                        HStack {
                            Spacer()
                            Button {
                                showingSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .imageScale(.large)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.primary)
                            .accessibilityLabel(t("toolbar.settings"))
                            .accessibilityIdentifier("toolbar.settings")
                        }
                    }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 13)
                        .padding(.bottom, 14)
                        .padding(.horizontal, 8)

                    detailContent(for: selection)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .background(CPStyle.pageBackground.ignoresSafeArea())
        }
        .sheet(isPresented: $showingSettings) {
            SettingView()
        }
    }

    private var ipadSidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            ipadSearchField

            VStack(alignment: .leading, spacing: 14) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CraftPresence")
                            .font(.headline.weight(.semibold))
                        Text(t("overview.subtitle"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                } icon: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 42, height: 42)
                        .background(.pink.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                }
            }

            VStack(spacing: 14) {
                CPGroupedSection {
                    ipadSidebarButton(.overview, title: t("sidebar.overview"), systemImage: "rectangle.and.text.magnifyingglass", tint: .pink)
                    CPSectionDivider()
                    ipadSidebarButton(.customPresence, title: t("sidebar.custom_presence"), systemImage: "slider.horizontal.3", tint: .blue)
                    CPSectionDivider()
                    ipadSidebarButton(.programs, title: t("sidebar.programs"), systemImage: "list.bullet.rectangle", tint: .orange)
                    CPSectionDivider()
                    ipadSidebarButton(.about, title: t("sidebar.about"), systemImage: "info.circle", tint: .gray)
                }

                CPGroupedSection {
                    ipadSidebarButton(.discordTest, title: t("sidebar.discord_test"), systemImage: "gamecontroller", tint: .purple)
                    CPSectionDivider()
                    ipadSidebarButton(.nowPlayingTest, title: t("sidebar.now_playing_test"), systemImage: "music.note", tint: .green)

                    ForEach(items) { item in
                        CPSectionDivider()
                        ipadSidebarButton(.item(item), title: item.timestamp.formatted(date: .numeric, time: .standard), systemImage: "clock", tint: .gray)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 54)
        .padding(.bottom, 18)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var ipadSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            Text(t("common.search"))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Image(systemName: "mic")
                .foregroundStyle(.secondary)
        }
        .font(.body)
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Color.secondary.opacity(0.11), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func ipadSidebarButton(
        _ target: DetailSelection,
        title: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        Button {
            selection = target
        } label: {
            HStack(spacing: 12) {
                CPRowIcon(systemImage: systemImage, tint: tint)
                Text(title)
                    .font(.body)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if selection == target {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.secondary.opacity(0.22))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier(for: target))
    }
#endif

    @ViewBuilder
    private func detailContent(for selection: DetailSelection) -> some View {
        switch selection {
        case .overview:
            OverviewView(
                activeAppName: activeAppName,
                activeWindowTitle: activeWindowTitle,
                activeBundleID: activeBundleID,
                programIDs: programIDs
            )
        case .customPresence:
            CustomPresenceView()
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
        case .builtin:
            BuiltinView()
        case .about:
            AboutView(
                activeAppName: activeAppName,
                activeWindowTitle: activeWindowTitle,
                activeBundleID: activeBundleID
            )
        case .discordTest:
            DiscordTestView()
        case .nowPlayingTest:
            NowPlayingTestView()
        case .item(let item):
            Text(t("content.item_at") + " " + item.timestamp.formatted(date: .numeric, time: .standard))
        case .none:
            EmptyView()
        }
    }

    private func title(for selection: DetailSelection) -> String {
        switch selection {
        case .overview:
            return t("sidebar.overview")
        case .customPresence:
            return t("sidebar.custom_presence")
        case .programs:
            return t("sidebar.programs")
        case .builtin:
            return t("sidebar.builtin")
        case .about:
            return t("sidebar.about")
        case .discordTest:
            return t("sidebar.discord_test")
        case .nowPlayingTest:
            return t("sidebar.now_playing_test")
        case .item(let item):
            return item.timestamp.formatted(date: .numeric, time: .standard)
        case .none:
            return ""
        }
    }

    private func accessibilityIdentifier(for selection: DetailSelection) -> String {
        switch selection {
        case .overview:
            return "sidebar.overview"
        case .customPresence:
            return "sidebar.customPresence"
        case .programs:
            return "sidebar.programs"
        case .builtin:
            return "sidebar.builtin"
        case .about:
            return "sidebar.about"
        case .discordTest:
            return "sidebar.discordTest"
        case .nowPlayingTest:
            return "sidebar.nowPlayingTest"
        case .item(let item):
            return "sidebar.item.\(item.id)"
        case .none:
            return "sidebar.none"
        }
    }

    // MARK: - Actions

    /// Inserts a timestamped sample item into local view state.
    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            items.append(newItem)
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

    /// Deletes stored sample items from local view state.
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            items.remove(atOffsets: offsets)
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

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "craftpresence" else { return }

        if url.host == "overview" {
            selection = .overview
            return
        }

        if url.host == "presets" || url.host == "custom-presence" {
            selection = .customPresence
            return
        }

        if url.host == "presence", url.path == "/stop" {
            selection = .overview
            Task {
                try? await DiscordSDKManager.shared.clearAppliedPresence()
                _ = try? await ConfigUtility.shared.setActiveCustomPresencePreset(id: nil)
                _ = try? await ConfigUtility.shared.setLastCustomPresence(nil)
                await PresenceLiveActivityController.shared.end()
            }
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

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Reusable Views

/// Reusable sidebar button row used throughout the app's primary navigation list.
private struct SidebarRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    var tint: Color = .accentColor
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .imageScale(.medium)
                Text(title)
                    .font(.body)
                    .lineLimit(1)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tint.gradient)
                            .opacity(0.9)
                    }
                }
            )
            .foregroundStyle(isSelected ? Color.white : .primary)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
        .listRowBackground(Color.clear)
    }
}

#if os(iOS)
import UIKit
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
