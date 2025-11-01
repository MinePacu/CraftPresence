//
//  ContentView.swift
//  CraftPresence
//
//  Created by 노현수 on 10/31/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit
#if os(macOS)
import ApplicationServices
#endif

struct ContentView: View {
    private enum DetailSelection: Equatable {
        case overview
        case programs
        case item(Item)
        case none

        static func == (lhs: DetailSelection, rhs: DetailSelection) -> Bool {
            switch (lhs, rhs) {
            case (.overview, .overview): return true
            case (.programs, .programs): return true
            case (.none, .none): return true
            case let (.item(li), .item(ri)): return li.id == ri.id
            default: return false
            }
        }
    }

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

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(get: {
                switch selection {
                case .overview: return "overview"
                case .programs: return "programs"
                case .item(let item): return "item-\(item.id)"
                case .none: return nil
                }
            }, set: { newValue in
                guard let key = newValue else { return }
                if key == "overview" { selection = .overview }
                else if key == "programs" { selection = .programs }
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
                }

                Section("보관함") {
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
                    .sheet(isPresented: $showingProgramSettings) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "gearshape")
                                Text("프로그램 설정")
                                    .font(.title3).bold()
                            }
                            if let id = selectedProgramIDForSettings {
                                Text("선택된 Bundle ID: " + id)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("선택된 항목이 없습니다.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            Divider()
                            Text("여기에 프로그램별 상세 설정 UI를 추가하세요.")
                                .foregroundStyle(.secondary)
                            HStack {
                                Spacer()
                                Button("닫기") {
                                    showingProgramSettings = false
                                }
                                .keyboardShortcut(.cancelAction)
                            }
                        }
                        .padding(20)
                        .frame(minWidth: 360)
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
                case .item(let item):
                    Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
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
#if DEBUG
            print("[CraftPresence] Accessibility isTrusted (initial): \(initialTrusted)")
#endif

            // If not trusted, prompt System Settings and poll until trusted or timeout
            if !initialTrusted {
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                AXIsProcessTrustedWithOptions(options)

                Task.detached(priority: .utility) {
                    // Poll up to 10 seconds (0.5s x 20)
                    for _ in 0..<20 {
                        if Task.isCancelled { break }
                        try? await Task.sleep(nanoseconds: 500_000_000)
#if DEBUG
                        let trusted = AXIsProcessTrusted()
                        print("[CraftPresence] Accessibility isTrusted (poll): \(trusted)")
                        if trusted { break }
#else
                        if AXIsProcessTrusted() { break }
#endif
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

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

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
#if DEBUG
            if appErr != .success {
                print("[CraftPresence][AX] FocusedApplication error: \(appErr.rawValue)")
            }
#endif
            if appErr != .success {
                return nil
            }
            appAX = focusedApp as! AXUIElement?
        }

        guard let appElement = appAX else {
#if DEBUG
            print("[CraftPresence][AX] App AX element is nil")
#endif
            return nil
        }

        // Get focused window
        var windowObj: AnyObject?
        let winErr = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowObj)
#if DEBUG
        if winErr != .success {
            print("[CraftPresence][AX] FocusedWindow error: \(winErr.rawValue)")
        }
#endif
        if winErr != .success {
            return nil
        }
        guard let windowEl = windowObj as! AXUIElement? else {
#if DEBUG
            print("[CraftPresence][AX] FocusedWindow is nil")
#endif
            return nil
        }

        // Get title
        var titleObj: AnyObject?
        let titleErr = AXUIElementCopyAttributeValue(windowEl, kAXTitleAttribute as CFString, &titleObj)
#if DEBUG
        if titleErr != .success {
            print("[CraftPresence][AX] Title error: \(titleErr.rawValue)")
        }
#endif
        if titleErr != .success {
            return nil
        }
        guard let title = titleObj as? String, !title.isEmpty else {
#if DEBUG
            print("[CraftPresence][AX] Title empty or not string")
#endif
            return nil
        }
        return title
    }
#endif

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
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

