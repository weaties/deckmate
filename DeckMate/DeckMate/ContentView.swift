//
//  ContentView.swift
//  DeckMate
//
//  Created by Dan Weatbrook on 4/17/26.
//

import SwiftUI
import DeckMateKit

struct ContentView: View {
    @Environment(ServerConfiguration.self) private var config
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if let api = config.apiClient() {
                    HistoryList(api: api)
                } else {
                    ContentUnavailableView {
                        Label("No server configured", systemImage: "sailboat")
                    } description: {
                        Text("Point DeckMate at your HelmLog server to see sessions.")
                    } actions: {
                        Button("Open Settings") { showingSettings = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gear")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(for: Session.self) { session in
                SessionDetailView(session: session)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

private struct HistoryList: View {
    let api: APIClient
    @State private var vm: HistoryViewModel?

    var body: some View {
        Group {
            if let vm {
                content(for: vm)
            } else {
                ProgressView("Loading…")
            }
        }
        .task {
            if vm == nil {
                vm = HistoryViewModel(api: api)
            }
            if vm?.sessions.isEmpty == true, case .idle = vm?.status {
                await vm?.load()
            }
        }
        .refreshable {
            await vm?.load()
        }
    }

    @ViewBuilder
    private func content(for vm: HistoryViewModel) -> some View {
        switch (vm.status, vm.sessions.isEmpty) {
        case (.idle, _), (.loadingFirstPage, true):
            ProgressView("Loading…")
        case (.settled, true):
            ContentUnavailableView(
                "No sessions yet",
                systemImage: "tray",
                description: Text("Start a session on the boat and it'll appear here.")
            )
        case (.failed(let reason), true):
            ContentUnavailableView {
                Label("Couldn't load sessions", systemImage: "exclamationmark.triangle")
            } description: {
                Text(reason.message)
            } actions: {
                Button("Try Again") {
                    Task { await vm.load() }
                }
            }
        default:
            sessionList(vm: vm)
        }
    }

    private func sessionList(vm: HistoryViewModel) -> some View {
        List {
            ForEach(vm.sessions) { session in
                NavigationLink(value: session) {
                    SessionRow(session: session)
                }
                .onAppear {
                    if session == vm.sessions.last {
                        Task { await vm.loadMoreIfNeeded() }
                    }
                }
            }

            if vm.hasMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }

            if case .failed(let reason) = vm.status, !vm.sessions.isEmpty {
                // Non-blocking error row — the list is already populated
                // from a prior page; only this attempt failed.
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(reason.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Retry") {
                        Task { await vm.loadMoreIfNeeded() }
                    }
                    .font(.footnote)
                }
                .listRowSeparator(.hidden)
            }
        }
    }
}

private struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .imageScale(.large)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let label = session.shortNumberLabel {
                        Text(label)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.tint.opacity(0.15), in: Capsule())
                            .foregroundStyle(.tint)
                    }
                    Text(session.event ?? session.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(session.startUtc, format: .dateTime.day().month().year().hour().minute())
                    if session.event != nil, session.event != session.name {
                        Text("·")
                        Text(session.name)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            SessionAvailabilityIndicators(session: session)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        switch session.kind {
        case .race: "flag.checkered"
        case .practice: "sailboat"
        case .synthesized: "sparkles"
        case .debrief: "waveform"
        }
    }
}

/// Row of small SF Symbols showing which optional content types are
/// attached to a session. Keeps the list dense but informative — a
/// session with audio + video + results looks visually different from
/// a plain track-only session.
struct SessionAvailabilityIndicators: View {
    let session: Session

    var body: some View {
        HStack(spacing: 6) {
            indicator(session.hasTrack, systemImage: "map")
            indicator(session.hasAudio, systemImage: "waveform")
            indicator(session.hasVideo, systemImage: "play.rectangle")
            indicator(session.hasResults, systemImage: "trophy")
            indicator(session.hasNotes, systemImage: "note.text")
        }
    }

    @ViewBuilder
    private func indicator(_ present: Bool, systemImage: String) -> some View {
        if present {
            Image(systemName: systemImage)
        }
    }
}

#Preview("Unconfigured") {
    ContentView()
        .environment(ServerConfiguration())
}
