import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct ProgramsView: View {
    @Binding var programIDs: [String]
    @Binding var isLoadingPrograms: Bool
    @Binding var showingProgramSettings: Bool
    @Binding var selectedProgramIDForSettings: String?

    // Settings fields
    @Binding var activityType: ContentView.ActivityType
    @Binding var detailText: String
    @Binding var stateText: String
    @Binding var useAppIconForLargeImage: Bool
    @Binding var largeImageKey: String
    @Binding var largeImageText: String
    @Binding var smallImageKey: String
    @Binding var smallImageText: String

    #if os(macOS)
    @Binding var selectedLargeNSImage: NSImage?
    @Binding var selectedSmallNSImage: NSImage?
    #endif

    #if os(iOS)
    @Binding var isPickingLargeImage: Bool
    @Binding var isPickingSmallImage: Bool
    @Binding var selectedLargeImage: Image?
    @Binding var selectedSmallImage: Image?
    #else
    @Binding var selectedLargeImage: Image?
    @Binding var selectedSmallImage: Image?
    #endif

    @Binding var partyCurrent: Int
    @Binding var partyMax: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Programs", systemImage: "list.bullet.rectangle")
                .font(.title2).bold()
            Text("어떤 프로그램을 Rich Presence로 표시할지 선택하세요.")
                .foregroundStyle(.secondary)

            // Add buttons
            HStack(spacing: 8) {
                Button {
                    #if os(macOS)
                    let panel = NSOpenPanel()
                    panel.title = "Select an Application"
                    panel.message = "응용프로그램(.app)을 선택하세요."
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    panel.allowsMultipleSelection = false
                    panel.allowedContentTypes = [.application]
                    panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
                    if panel.runModal() == .OK, let url = panel.url {
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
                    print("Add Program is only supported on macOS in this build.")
                    #endif
                } label: {
                    Label("Add Program", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    Task {
                        do {
                            let updated = try await ConfigUtility.shared.addBundleID("com.apple.Music")
                            programIDs = updated.bundleIDs
                        } catch {
                            print("Failed to add Apple Music: \(error)")
                        }
                    }
                } label: {
                    Label("Add Apple Music", systemImage: "music.note")
                }
                .buttonStyle(.bordered)
                .disabled(programIDs.contains("com.apple.Music"))
                .help("macOS Music 앱(com.apple.Music)을 기본값으로 추가합니다.")
            }

            Group {
                if isLoadingPrograms {
                    ProgressView("불러오는 중...")
                } else if programIDs.isEmpty {
                    ContentUnavailableView("등록된 프로그램이 없습니다", systemImage: "list.bullet", description: Text("Add Program 버튼을 눌러 응용프로그램(.app)을 선택하세요."))
                } else {
                    List {
                        ForEach(programIDs, id: \._self) { id in
                            HStack {
                                Image(systemName: "app.badge").imageScale(.medium)
                                Text(id).font(.body)
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
                                    } label: { Image(systemName: "trash") }
                                    .buttonStyle(.borderless)

                                    Button {
                                        selectedProgramIDForSettings = id
                                        showingProgramSettings = true
                                    } label: { Image(systemName: "gearshape") }
                                    .buttonStyle(.borderless)
                                    .help("설정")
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .sheet(isPresented: $showingProgramSettings) {
            ProgramsSettingsSheet(
                activityType: $activityType,
                detailText: $detailText,
                stateText: $stateText,
                useAppIconForLargeImage: $useAppIconForLargeImage,
                largeImageKey: $largeImageKey,
                largeImageText: $largeImageText,
                smallImageKey: $smallImageKey,
                smallImageText: $smallImageText,
                selectedLargeImage: $selectedLargeImage,
                selectedSmallImage: $selectedSmallImage,
                partyCurrent: $partyCurrent,
                partyMax: $partyMax
            )
        }
    }
}

private struct ProgramsSettingsSheet: View {
    @Binding var activityType: ContentView.ActivityType
    @Binding var detailText: String
    @Binding var stateText: String
    @Binding var useAppIconForLargeImage: Bool
    @Binding var largeImageKey: String
    @Binding var largeImageText: String
    @Binding var smallImageKey: String
    @Binding var smallImageText: String
    @Binding var selectedLargeImage: Image?
    @Binding var selectedSmallImage: Image?
    @Binding var partyCurrent: Int
    @Binding var partyMax: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button("취소") { /* handled by parent via binding */ }
                    Spacer()
                    Button("저장") { /* TODO: persist per-bundle settings */ }
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.bottom, 4)
                Divider()
                Form {
                    Section {
                        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 10) {
                            GridRow(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("활동 유형").font(.headline)
                                    Picker("활동 유형", selection: $activityType) {
                                        ForEach(ContentView.ActivityType.allCases) { t in
                                            Text(t.localizedLabel).tag(t)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            GridRow(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("세부 내용").font(.headline)
                                    TextField("예: 게임 이름 또는 작업 설명", text: $detailText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            GridRow(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("상태 메시지").font(.headline)
                                    TextField("예: 현재 단계, 챕터 등", text: $stateText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    Divider()
                    Section {
                        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 10) {
                            GridRow { Toggle("큰 이미지에 앱 아이콘 사용", isOn: $useAppIconForLargeImage) }
                            GridRow {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("큰 이미지 키").font(.headline)
                                    TextField("Discord 개발자 포털에 등록된 키", text: $largeImageKey)
                                }
                            }
                            GridRow {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("큰 이미지 텍스트").font(.headline)
                                    TextField("큰 이미지에 표시될 텍스트", text: $largeImageText)
                                }
                            }
                            GridRow {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("작은 이미지 선택").font(.headline)
                                    RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08))
                                        .frame(width: 48, height: 48)
                                        .overlay(Image(systemName: "photo").imageScale(.medium).foregroundStyle(.secondary))
                                }
                            }
                            GridRow {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("작은 이미지 키").font(.headline)
                                    TextField("Discord 개발자 포털에 등록된 키", text: $smallImageKey)
                                }
                            }
                            GridRow {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("작은 이미지 텍스트").font(.headline)
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
                                    Text("현재 인원").font(.headline)
                                    HStack {
                                        Stepper(value: $partyCurrent, in: 0...max(0, partyMax)) { EmptyView() }
                                        Text("\(partyCurrent)").foregroundStyle(.secondary)
                                    }
                                }
                            }
                            GridRow {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("최대 인원").font(.headline)
                                    HStack {
                                        Stepper(value: $partyMax, in: max(1, partyCurrent)...99) { EmptyView() }
                                        Text("\(partyMax)").foregroundStyle(.secondary)
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
        }
    }
}

#Preview {
    @State var programIDs: [String] = ["com.apple.Music"]
    @State var isLoadingPrograms = false
    @State var showing = false
    @State var sel: String? = nil
    @State var activity: ContentView.ActivityType = .playing
    @State var detail = ""
    @State var state = ""
    @State var useIcon = true
    @State var largeKey = ""
    @State var largeText = ""
    @State var smallKey = ""
    @State var smallText = ""
    @State var partyCur = 1
    @State var partyMx = 1
    @State var largeImg: Image? = nil
    @State var smallImg: Image? = nil

    return ProgramsView(
        programIDs: $programIDs,
        isLoadingPrograms: $isLoadingPrograms,
        showingProgramSettings: $showing,
        selectedProgramIDForSettings: $sel,
        activityType: $activity,
        detailText: $detail,
        stateText: $state,
        useAppIconForLargeImage: $useIcon,
        largeImageKey: $largeKey,
        largeImageText: $largeText,
        smallImageKey: $smallKey,
        smallImageText: $smallText,
        selectedLargeImage: $largeImg,
        selectedSmallImage: $smallImg,
        partyCurrent: $partyCur,
        partyMax: $partyMx
    )
}
