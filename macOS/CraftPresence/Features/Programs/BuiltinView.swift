//
//  BuiltinView.swift
//  CraftPresence
//
//  Created by 노현수 on 11/11/25.
//

import SwiftUI

struct BuiltinView: View {
    @StateObject private var appleMusicManager = AppleMusicPresenceManager.shared
    @StateObject private var xcodeManager = XcodePresenceManager.shared
    @State private var isVSCodeEnabled: Bool = false
    @State private var showAppleMusicDetail: Bool = false
    @State private var showXcodeDetail: Bool = false
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        NavigationStack {
            List {
                // Title Row to match other views' appearance when toolbar title is hidden
                Section {
                    Text(t("builtin.title"))
                        .font(.largeTitle.bold())
                        .padding(.vertical, 4)
                }

                Section {
                    BuiltinProgramRow(
                        title: "Apple Music",
                        subtitle: appleMusicManager.isPlaying 
                            ? "\(appleMusicManager.currentTrack) - \(appleMusicManager.currentArtist)"
                            : t("builtin.apple_music.subtitle"),
                        systemImage: "music.note",
                        isEnabled: $appleMusicManager.isEnabled,
                        statusText: appleMusicManager.isEnabled 
                            ? (appleMusicManager.isPlaying ? t("builtin.status.playing") : t("builtin.status.idle"))
                            : t("builtin.status.disabled")
                    ) {
                        showAppleMusicDetail = true
                    }
                    
                    BuiltinProgramRow(
                        title: "Xcode",
                        subtitle: xcodeManager.isActive
                            ? "\(xcodeManager.currentProject) - \(xcodeManager.currentFile)"
                            : t("builtin.xcode.subtitle"),
                        systemImage: "hammer",
                        isEnabled: $xcodeManager.isEnabled,
                        statusText: xcodeManager.isEnabled
                            ? (xcodeManager.isActive ? t("builtin.status.working") : t("builtin.status.idle"))
                            : t("builtin.status.disabled")
                    ) {
                        showXcodeDetail = true
                    }
                    
                    BuiltinProgramRow(
                        title: "Visual Studio Code",
                        subtitle: t("builtin.vscode.subtitle"),
                        systemImage: "curlybraces",
                        isEnabled: $isVSCodeEnabled,
                        statusText: isVSCodeEnabled ? t("builtin.status.enabled") : t("builtin.status.disabled")
                    ) {
                        // TODO: 상세 설정 화면으로 이동하거나 시트를 표시
                    }
                }
            }
            // Keep empty title so ContentView can control toolbar appearance consistently
            .navigationTitle("")
            .sheet(isPresented: $showAppleMusicDetail) {
                AppleMusicDetailView()
            }
            .sheet(isPresented: $showXcodeDetail) {
                XcodeDetailView()
            }
        }
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }
}

// MARK: - Apple Music Detail View
struct AppleMusicDetailView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var manager = AppleMusicPresenceManager.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label("상태", systemImage: "info.circle")
                        Spacer()
                        Text(manager.isPlaying ? "재생 중" : "대기 중")
                            .foregroundStyle(manager.isPlaying ? .green : .secondary)
                    }
                    
                    HStack {
                        Label("Discord", systemImage: "network")
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(manager.discordStatus == "Connected" || manager.discordStatus == "Active" ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)
                            Text(manager.discordStatus)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if manager.isPlaying {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("곡")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(manager.currentTrack)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("아티스트")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(manager.currentArtist)
                            }
                            
                            HStack {
                                Text("앨범")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(manager.currentAlbum)
                            }
                        }
                    }
                } header: {
                    Text("현재 재생 정보")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Discord Rich Presence에 표시")
                            .font(.headline)
                        Text("활성화하면 현재 재생 중인 Apple Music 곡 정보가 Discord 프로필에 실시간으로 표시됩니다. 15초마다 자동으로 업데이트됩니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Label("자동 업데이트", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        Text("15초")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("설정")
                } footer: {
                    Text("Music.app이 백그라운드에서 실행 중이어야 하며, Apple Events 권한이 필요합니다.")
                }
                
                Section {
                    Button(role: .destructive) {
                        Task {
                            try? await DiscordSDKManager.shared.clearActivity()
                        }
                    } label: {
                        Label("Discord 상태 초기화", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Apple Music 설정")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 450, height: 400)
    }
}

// MARK: - Xcode Detail View
struct XcodeDetailView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var manager = XcodePresenceManager.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label("상태", systemImage: "info.circle")
                        Spacer()
                        Text(manager.isActive ? "작업 중" : "대기 중")
                            .foregroundStyle(manager.isActive ? .green : .secondary)
                    }
                    
                    HStack {
                        Label("Discord", systemImage: "network")
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(manager.discordStatus == "Connected" || manager.discordStatus == "Active" ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)
                            Text(manager.discordStatus)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if manager.isActive {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("프로젝트")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(manager.currentProject)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("현재 파일")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(manager.currentFile)
                            }
                        }
                    }
                } header: {
                    Text("현재 작업 정보")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Discord Rich Presence에 표시")
                            .font(.headline)
                        Text("활성화하면 현재 작업 중인 Xcode 프로젝트와 파일 정보가 Discord 프로필에 실시간으로 표시됩니다. 15초마다 자동으로 업데이트됩니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Label("자동 업데이트", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        Text("15초")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("설정")
                } footer: {
                    Text("Xcode가 백그라운드에서 실행 중이어야 하며, Apple Events 권한이 필요합니다.")
                }
                
                Section {
                    Button(role: .destructive) {
                        Task {
                            try? await DiscordSDKManager.shared.clearActivity()
                        }
                    } label: {
                        Label("Discord 상태 초기화", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Xcode 설정")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 450, height: 400)
    }
}

private struct BuiltinProgramRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var isEnabled: Bool
    let statusText: String
    var onConfigure: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(isEnabled ? .blue : .secondary)
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.headline)
                        Spacer()
                        // Use Toggle instead of checkbox; keep label hidden to place on trailing side
                        Toggle("활성화", isOn: $isEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            HStack {
                Label(statusText, systemImage: isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(isEnabled ? .green : .secondary)
                    .font(.caption)
                Spacer()
                Button {
                    onConfigure()
                } label: {
                    Label("설정", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    BuiltinView()
}
