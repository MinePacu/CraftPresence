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

    // Party size settings
    @State private var partyCurrent: Int = 1
    @State private var partyMax: Int = 1

    // Image picking & previews
    @State private var selectedLargeImage: Image? = nil
    @State private var selectedSmallImage: Image? = nil

    // macOS-only: store NSImage for better fidelity when needed
    #if os(macOS)
    @State private var selectedLargeNSImage: NSImage? = nil
    @State private var selectedSmallNSImage: NSImage? = nil
    #endif

    // iOS-only: PhotosPicker state
    #if os(iOS)
    @State private var isPickingLargeImage: Bool = false
    @State private var isPickingSmallImage: Bool = false
    #endif

    // Settings presentation
    @State private var showingSettings: Bool = false
    @AppStorage("menuBarOnlyEnabled") private var menuBarOnlyEnabled: Bool = false

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
                Section("Menu") {
                    SidebarRow(title: "OverView", systemImage: "rectangle.and.text.magnifyingglass", isSelected: selection == .overview, tint: .pink) {
                        if selection != .overview { selectionStack.append(selection) }
                        selection = .overview
                    }
                    SidebarRow(title: "Programs", systemImage: "list.bullet.rectangle", isSelected: selection == .programs, tint: .pink) {
                        if selection != .programs { selectionStack.append(selection) }
                        selection = .programs
                    }
                    SidebarRow(title: "Built-in", systemImage: "bolt.fill", isSelected: selection == .builtin, tint: .pink) {
                        if selection != .builtin { selectionStack.append(selection) }
                        selection = .builtin
                    }
                    SidebarRow(title: "About", systemImage: "info.circle", isSelected: selection == .about, tint: .pink) {
                        if selection != .about { selectionStack.append(selection) }
                        selection = .about
                    }
                }

                Section("Test") {
                    SidebarRow(title: "DiscordTest", systemImage: "gamecontroller", isSelected: selection == .discordTest, tint: .pink) {
                        if selection != .discordTest { selectionStack.append(selection) }
                        selection = .discordTest
                    }
                    SidebarRow(title: "NowPlayingTest", systemImage: "music.note", isSelected: selection == .nowPlayingTest, tint: .pink) {
                        if selection != .nowPlayingTest { selectionStack.append(selection) }
                        selection = .nowPlayingTest
                    }
                    ForEach(items) { item in
                        SidebarRow(title: item.timestamp.formatted(date: .numeric, time: .standard), systemImage: "clock", isSelected: {
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
                        selectedProgramIDForSettings: $selectedProgramIDForSettings,
                        activityType: $activityType,
                        detailText: $detailText,
                        stateText: $stateText,
                        useAppIconForLargeImage: $useAppIconForLargeImage,
                        largeImageKey: $largeImageKey,
                        largeImageText: $largeImageText,
                        smallImageKey: $smallImageKey,
                        smallImageText: $smallImageText,
                        selectedLargeNSImage: $selectedLargeNSImage,
                        selectedSmallNSImage: $selectedSmallNSImage,
                        selectedLargeImage: $selectedLargeImage,
                        selectedSmallImage: $selectedSmallImage,
                        partyCurrent: $partyCurrent,
                        partyMax: $partyMax
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
                    Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
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
                            Label("뒤로", systemImage: "chevron.left")
                        }
                    }
                }
                // 설정 버튼
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("설정", systemImage: "gearshape")
                    }
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
        .task {
            // Subscribe to ProgramDetector updates
            ProgramDetector.shared.start()
    #if os(macOS)
            // Log current Accessibility permission state
            let initialTrusted = AXIsProcessTrusted()
            if !initialTrusted {
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                AXIsProcessTrustedWithOptions(options)
                Task.detached(priority: .utility) {
                    for _ in 0..<20 {
                        if Task.isCancelled { break }
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        if AXIsProcessTrusted() { break }
                    }
                }
            }
    #endif
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
    }

    // MARK: - Actions

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

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }

    // MARK: - Helpers
    private func applyMenuBarMode(_ enabled: Bool) {
        #if os(macOS)
        if enabled {
            LSUIElementController.shared.enableMenuBarOnly()
        } else {
            LSUIElementController.shared.disableMenuBarOnly()
        }
        #endif
    }
}

// MARK: - Reusable Views

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
