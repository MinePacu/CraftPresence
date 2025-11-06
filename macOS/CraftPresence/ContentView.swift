//
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

struct ContentView: View {
    // MARK: Types & Identifiers

    private enum DetailSelection: Equatable {
        case overview
        case programs
        case about
        case item(Item)
        case discordTest
        case none

        static func == (lhs: DetailSelection, rhs: DetailSelection) -> Bool {
            switch (lhs, rhs) {
            case (.overview, .overview): return true
            case (.programs, .programs): return true
            case (.about, .about): return true
            case (.discordTest, .discordTest): return true
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

    // MARK: Settings Model

    // Program Settings UI State
    @State private var activityType: ActivityType = .playing
    @State private var detailText: String = ""
    @State private var stateText: String = ""

    @State private var useAppIconForLargeImage: Bool = true
    @State private var largeImageKey: String = ""
    @State private var largeImageText: String = ""

    @State private var smallImageKey: String = ""
    @State private var smallImageText: String = ""

    @State private var partyCurrent: Int = 1
    @State private var partyMax: Int = 1

    enum ActivityType: String, CaseIterable, Identifiable {
        case playing = "Playing"
        case streaming = "Streaming"
        case listening = "Listening"
        case watching = "Watching"
        case competing = "Competing"

        var id: String { rawValue }
        var localizedLabel: String { rawValue }
    }

    // MARK: Body

    var body: some View {
        // MARK: Sidebar (Navigation List)
        NavigationSplitView {
            List(selection: Binding(get: {
                switch selection {
                case .overview: return "overview"
                case .programs: return "programs"
                case .about: return "about"
                case .discordTest: return "discordTest"
                case .item(let item): return "item-\(item.id)"
                case .none: return nil
                }
            }, set: { newValue in
                guard let key = newValue else { return }
                if key == "overview" { selection = .overview }
                else if key == "programs" { selection = .programs }
                else if key == "about" { selection = .about }
                else if key == "discordTest" { selection = .discordTest }
                else if key.hasPrefix("item-") {
                    if let idString = key.split(separator: "-").last,
                       let match = items.first(where: { "\($0.id)" == idString }) {
                        selection = .item(match)
                    }
                }
            })) {
                Section("Menu") {
                    SidebarRow(title: "OverView", systemImage: "rectangle.and.text.magnifyingglass", isSelected: selection == .overview, tint: .pink) {
                        if selection != .overview { selectionStack.append(selection) }
                        selection = .overview
                    }
                    SidebarRow(title: "Programs", systemImage: "list.bullet.rectangle", isSelected: selection == .programs, tint: .pink) {
                        if selection != .programs { selectionStack.append(selection) }
                        selection = .programs
                    }
                    SidebarRow(title: "About", systemImage: "info.circle", isSelected: selection == .about, tint: .pink) {
                        if selection != .about { selectionStack.append(selection) }
                        selection = .about
                    }
                    SidebarRow(title: "DiscordTest", systemImage: "gamecontroller", isSelected: selection == .discordTest, tint: .pink) {
                        if selection != .discordTest { selectionStack.append(selection) }
                        selection = .discordTest
                    }
                }

                Section("Test") {
                    ForEach(items) { item in
                        SidebarRow(title: item.timestamp.formatted(date: .numeric, time: .standard), systemImage: "clock", isSelected: {item
                            if case .item(let selected) = selection { return selected.id == item.id }
                            return false
                        }(), tint: .gray) {
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
            Group {
                // MARK: Detail - Overview
                switch selection {
                case .overview:
                    VStack(alignment: .leading, spacing: 12) {
                        Label("OverView", systemImage: "rectangle.and.text.magnifyingglass")
                            .font(.title2).bold()
                        Label {
                            HStack(spacing: 0) {
                                Text("현재 포그라운드 창: ")
                                Text(activeAppName ?? "알 수 없음").foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "macwindow") }
                        Label {
                            HStack(spacing: 0) {
                                Text("창 타이틀: ")
                                Text(activeWindowTitle ?? "알 수 없음").foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "text.quote") }
                        Label {
                            HStack(spacing: 0) {
                                Text("Bundle ID: ")
                                Text(activeBundleID ?? "알 수 없음").foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "barcode.viewfinder") }
                        Label {
                            let isTracked = (activeBundleID != nil) && programIDs.contains(activeBundleID!)
                            if isTracked {
                                Text("Programs에 등록됨")
                                    .foregroundStyle(.green)
                            } else {
                                Text("Programs에 미등록")
                                    .foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "checkmark.seal") }
                        // Placeholder for Discord Rich Presence summary
                        Label {
                            Text("Discord Rich Presence: ") + Text("연결되지 않음").foregroundStyle(.secondary)
                        } icon: { Image(systemName: "gamecontroller") }
                        Spacer()
                    }
                    //.padding(.vertical, 4)
                // MARK: Detail - Programs
                case .programs:
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Programs", systemImage: "list.bullet.rectangle")
                            .font(.title2).bold()
                        Text("어떤 프로그램을 Rich Presence로 표시할지 선택하세요.")
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Button {
                                #if os(macOS)
                                // Present an open panel to pick an application (.app)
                                let panel = NSOpenPanel()
                                panel.title = "Select an Application"
                                panel.message = "응용프로그램(.app)을 선택하세요."
                                panel.canChooseFiles = true
                                panel.canChooseDirectories = false
                                panel.allowsMultipleSelection = false
                                panel.allowedContentTypes = [.application]
                                panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
                                if panel.runModal() == .OK, let url = panel.url {
                                    // Try to read bundle identifier from the selected app bundle
                                    if let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier {
                                        Task {
                                            do {
                                                let updated = try await ConfigUtility.shared.addBundleID(bundleID)
                                                programIDs = updated.bundleIDs
                                            } catch {
                                                print("Failed to save bundleID: \(error)")
                                            }
                                        }
                                    } else {
                                        print("선택한 항목에서 bundleID를 읽을 수 없습니다: \(String(describing: panel.url))")
                                    }
                                }
                                #else
                                // iOS and other platforms typically cannot pick installed apps
                                print("Add Program is only supported on macOS in this build.")
                                #endif
                            } label: {
                                Label("Add Program", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(false)
                        }

                        Group {
                            if isLoadingPrograms {
                                ProgressView("불러오는 중...")
                            } else if programIDs.isEmpty {
                                ContentUnavailableView("등록된 프로그램이 없습니다", systemImage: "list.bullet", description: Text("Add Program 버튼을 눌러 응용프로그램(.app)을 선택하세요."))
                            } else {
                                List {
                                    ForEach(programIDs, id: \.self) { id in
                                        HStack {
                                            Image(systemName: "app.badge")
                                                .imageScale(.medium)
                                            Text(id)
                                                .font(.body)
                                            Spacer()
                                            HStack(spacing: 8) {
                                                Button(role: .destructive) {
                                                    Task {
                                                        do {
                                                            let updated = try await ConfigUtility.shared.removeBundleID(id)
                                                            programIDs = updated.bundleIDs
                                                        } catch {
                                                            print("Failed to remove bundleID: \(error)")
                                                        }
                                                    }
                                                } label: {
                                                    Image(systemName: "trash")
                                                }
                                                .buttonStyle(.borderless)

                                                Button {
                                                    selectedProgramIDForSettings = id
                                                    showingProgramSettings = true
                                                } label: {
                                                    Image(systemName: "gearshape")
                                                }
                                                .buttonStyle(.borderless)
                                                .help("설정")
                                            }
                                        }
                                    }
                                }
    #if os(iOS)
                                .listStyle(.insetGrouped)
    #else
                                .listStyle(.inset)
    #endif
                            }
                        }

                        Spacer()
                    }
                    // MARK: Programs - Settings Sheet
                    .sheet(isPresented: $showingProgramSettings) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Button("취소") {
                                        showingProgramSettings = false
                                    }
                                    Spacer()
                                    Button("저장") {
                                        // TODO: Persist settings for selectedProgramIDForSettings
                                        // Hook for save logic via ConfigUtility per bundle ID
                                        showingProgramSettings = false
                                    }
                                    .keyboardShortcut(.defaultAction)
                                }
                                .padding(.bottom, 4)

                                Divider()

                                Form {
                                    Section {
                                        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 10) {
                                            GridRow(alignment: .firstTextBaseline) {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    Text("활동 유형")
                                                        .font(.headline)
                                                    Picker("활동 유형", selection: $activityType) {
                                                        ForEach(ActivityType.allCases) { t in
                                                            Text(t.localizedLabel).tag(t)
                                                        }
                                                    }
                                                    .pickerStyle(.segmented)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            GridRow(alignment: .firstTextBaseline) {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    Text("세부 내용")
                                                        .font(.headline)
                                                    TextField("예: 게임 이름 또는 작업 설명", text: $detailText)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            GridRow(alignment: .firstTextBaseline) {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    Text("상태 메시지")
                                                        .font(.headline)
                                                    TextField("예: 현재 단계, 챕터 등", text: $stateText)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }
                                    }

                                    Divider()

                                    Section {
                                        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 10) {
                                            GridRow {
                                                Toggle("큰 이미지에 앱 아이콘 사용", isOn: $useAppIconForLargeImage)
                                                    .help("활성화 시 큰 이미지는 앱 아이콘으로 표시됩니다.")
                                            }
                                            if !useAppIconForLargeImage {
                                                GridRow {
                                                    VStack(alignment: .leading, spacing: 6) {
                                                        Text("큰 이미지 키")
                                                            .font(.headline)
                                                        TextField("Discord 개발자 포털에 등록된 키", text: $largeImageKey)
                                                    }
                                                }
                                            }
                                            GridRow {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    Text("큰 이미지 텍스트")
                                                        .font(.headline)
                                                    TextField("큰 이미지에 표시될 텍스트", text: $largeImageText)
                                                }
                                            }
                                            GridRow {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    Text("작은 이미지 키")
                                                        .font(.headline)
                                                    TextField("Discord 개발자 포털에 등록된 키", text: $smallImageKey)
                                                }
                                            }
                                            GridRow {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    Text("작은 이미지 텍스트")
                                                        .font(.headline)
                                                    TextField("작은 이미지에 표시될 텍스트", text: $smallImageText)
                                                }
                                            }
                                        }
                                    }

                                    Divider()

                                    Section {
                                        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 10) {
                                            GridRow {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    Text("현재 인원")
                                                        .font(.headline)
                                                    HStack {
                                                        Stepper(value: $partyCurrent, in: 0...max(0, partyMax)) { EmptyView() }
                                                        Text("\(partyCurrent)")
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }
                                            }
                                            GridRow {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    Text("최대 인원")
                                                        .font(.headline)
                                                    HStack {
                                                        Stepper(value: $partyMax, in: max(1, partyCurrent)...99) { EmptyView() }
                                                        Text("\(partyMax)")
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 20)
                        .frame(minWidth: 720, idealWidth: 820)
                        .frame(maxHeight: 720)
                        .onAppear {
                            // TODO: Load existing settings for selectedProgramIDForSettings
                            // Reset or populate fields here as needed
                        }
                    }
                    .task {
                        // Load saved bundle IDs when entering Programs
                        do {
                            let current = await ConfigUtility.shared.currentSettings()
                            programIDs = current.bundleIDs
                        }
                        isLoadingPrograms = false
                    }
                    //.padding(.vertical, 4)

                // MARK: Detail - About
                case .about:
                    VStack(alignment: .leading, spacing: 12) {
                        Label("About", systemImage: "info.circle")
                            .font(.title2).bold()

                        Group {
                            InfoRow(label: "App Name", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Unknown")
                            InfoRow(label: "Version", value: {
                                let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                                let b = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String
                                switch (v, b) { case let (v?, b?): return "\(v) (\(b))"; case let (v?, nil): return v; case let (nil, b?): return b; default: return "Unknown" }
                            }())
                            InfoRow(label: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "Unknown")
                            InfoRow(label: "Executable Path", value: Bundle.main.executableURL?.path(percentEncoded: false) ?? "-")
    #if os(macOS)
                            InfoRow(label: "Accessibility Permission", value: AXIsProcessTrusted() ? "Granted" : "Not Granted")
    #endif
                        }

                        Divider().padding(.vertical, 4)

                        Group {
                            Label {
                                Text("현재 포그라운드 창: ") + Text(activeAppName ?? "알 수 없음").foregroundStyle(.secondary)
                            } icon: { Image(systemName: "macwindow") }
                            Label {
                                Text("창 타이틀: ") + Text(activeWindowTitle ?? "알 수 없음").foregroundStyle(.secondary)
                            } icon: { Image(systemName: "text.quote") }
                            Label {
                                Text("Bundle ID: ") + Text(activeBundleID ?? "알 수 없음").foregroundStyle(.secondary)
                            } icon: { Image(systemName: "barcode.viewfinder") }
                        }

                        Spacer()
                    }

                // MARK: Detail - DiscordTest
                case .discordTest:
                    DiscordTestView()

                // MARK: Detail - Item
                case .item(let item):
                    Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                // MARK: Detail - None
                case .none:
                    EmptyView()
                }
            }
            .navigationTitle("")
            //.padding(.leading, 12)
    #if os(macOS)
            .toolbarBackground(.hidden, for: .windowToolbar)
    #endif
    #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
    #endif
    #if os(macOS)
            .toolbar {
                if !selectionStack.isEmpty {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            if let last = selectionStack.popLast() {
                                selection = last
                            }
                        } label: {
                            Label("뒤로", systemImage: "chevron.left")
                        }
                    }
                }
            }
    #endif
        }
        .task {
            // Subscribe to ProgramDetector updates
            ProgramDetector.shared.start()
    #if os(macOS)
            // Log current Accessibility permission state
            let initialTrusted = AXIsProcessTrusted()
            // logging disabled

            // If not trusted, prompt System Settings and poll until trusted or timeout
            if !initialTrusted {
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                AXIsProcessTrustedWithOptions(options)

                Task.detached(priority: .utility) {
                    // Poll up to 10 seconds (0.5s x 20)
                    for _ in 0..<20 {
                        if Task.isCancelled { break }
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        if AXIsProcessTrusted() { break }
                    }
                }
            }
    #endif
            Task.detached(priority: .utility) {
                for await update in ProgramDetector.shared.updatesStream() {
                    if Task.isCancelled { break }
    #if os(macOS)
                    // Debounce and safely re-fetch title via AX to avoid stale/invalid elements
                    // Use update.pid if available, fallback to nil which tries to get focused app
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
    }

    // MARK: - Actions

    // Add sample Item to SwiftData (unused in UI)
    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    // MARK: - macOS AX Helpers
#if os(macOS)
    /// Attempts to fetch the focused window title using AX API with small delay and limited retries.
    /// - Parameters:
    ///   - pid: Optional process ID to target. If nil, attempts to infer via frontmost app.
    ///   - retries: Number of attempts.
    ///   - delayNanoseconds: Delay between attempts.
    /// - Returns: The window title string if available.
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
        // Early-out if not trusted to avoid noisy AX errors
        guard AXIsProcessTrusted() else {
            return nil
        }
        // Resolve application AX element
        let appAX: AXUIElement?
        if let pid = pid {
            appAX = AXUIElementCreateApplication(pid)
        } else {
            // Try system-wide focused app
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

        // Get focused window
        var windowObj: AnyObject?
        let winErr = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowObj)
        if winErr != .success {
            return nil
        }
        guard let windowEl = windowObj as! AXUIElement? else {
            return nil
        }

        // Get title
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

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

// MARK: - Reusable Views

private struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.headline)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct SidebarRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    var tint: Color = .accentColor
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
        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
        .listRowBackground(Color.clear)
    }
}


#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

