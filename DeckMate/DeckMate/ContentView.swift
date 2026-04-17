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
                Text(session.name)
                    .font(.headline)
                Text(session.startUtc, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

private struct SessionDetailView: View {
    let session: Session
    @Environment(ServerConfiguration.self) private var config

    var body: some View {
        Form {
            if let api = config.apiClient() {
                Section("Track") {
                    TrackMapView(session: session, api: api)
                        .listRowInsets(EdgeInsets())
                }
            }
            Section("Overview") {
                LabeledContent("Name", value: session.name)
                LabeledContent("Kind", value: session.kind.rawValue.capitalized)
                LabeledContent("ID", value: "\(session.id)")
            }
            Section("Timing") {
                LabeledContent(
                    "Start",
                    value: session.startUtc.formatted(date: .abbreviated, time: .shortened)
                )
                if let end = session.endUtc {
                    LabeledContent(
                        "End",
                        value: end.formatted(date: .abbreviated, time: .shortened)
                    )
                    LabeledContent("Duration", value: durationString(from: session.startUtc, to: end))
                }
            }
            if session.boatId != nil || session.coOpId != nil {
                Section("Ownership") {
                    if let boatId = session.boatId {
                        LabeledContent("Boat", value: boatId)
                    }
                    if let coOpId = session.coOpId {
                        LabeledContent("Co-op", value: coOpId)
                    }
                }
            }
        }
        .navigationTitle(session.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func durationString(from start: Date, to end: Date) -> String {
        let seconds = end.timeIntervalSince(start)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? ""
    }
}

#Preview("Unconfigured") {
    ContentView()
        .environment(ServerConfiguration())
}
