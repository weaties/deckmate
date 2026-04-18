//
//  SessionDetailView.swift
//  DeckMate
//
//  Detail screen for a single session: track map, summary (wind +
//  results), identifying metadata, and availability badges.
//

import SwiftUI
import DeckMateKit

struct SessionDetailView: View {
    let session: Session
    @Environment(ServerConfiguration.self) private var config
    @State private var summary: SummaryState = .idle
    @State private var playingVideo: PlayingVideo?

    /// Wraps a URL in an Identifiable so it can drive a sheet via
    /// `.sheet(item:)` — avoids a separate `isPresenting` boolean and
    /// lets us carry the URL into the sheet in one shot.
    private struct PlayingVideo: Identifiable {
        let id = UUID()
        let url: URL
        let youTubeVideoId: String?
    }

    private enum SummaryState {
        case idle
        case loading
        case loaded(SessionSummary)
        case failed(FailureReason)
    }

    var body: some View {
        Form {
            if let api = config.apiClient() {
                Section("Track") {
                    TrackMapView(session: session, api: api)
                        .listRowInsets(EdgeInsets())
                }
            }

            summarySection

            Section("Overview") {
                if let event = session.event {
                    LabeledContent("Event", value: event)
                }
                if let label = session.shortNumberLabel {
                    LabeledContent("Race", value: label)
                }
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

            availabilitySection

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
        .navigationTitle(session.event ?? session.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadSummary() }
        .sheet(item: $playingVideo) { video in
            videoSheet(for: video)
        }
    }

    @ViewBuilder
    private func videoSheet(for video: PlayingVideo) -> some View {
        NavigationStack {
            Group {
                if let id = video.youTubeVideoId {
                    YouTubePlayerView(videoId: id)
                } else {
                    // Non-YouTube URL — we don't know how to embed it, so
                    // just prompt to open externally. Rare; helmlog stores
                    // YouTube URLs by convention.
                    ContentUnavailableView {
                        Label("Unsupported video", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text("This video isn't hosted on YouTube.")
                    } actions: {
                        Link("Open in browser", destination: video.url)
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Video")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { playingVideo = nil }
                }
                // Escape hatch for videos the uploader has embed-restricted.
                // YouTube errors 152 / 153 render inside the iframe with
                // their own "Watch on YouTube" link, but surfacing the same
                // action in our own toolbar means users don't have to read
                // YouTube's error text to know it's available.
                ToolbarItem(placement: .primaryAction) {
                    Link(destination: canonicalWatchURL(for: video)) {
                        Label("Open on YouTube", systemImage: "arrow.up.right.square")
                    }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 320)
    }

    /// Best-effort canonical watch URL. For a YouTube ID we rebuild the
    /// `youtube.com/watch?v=...` form (so the YouTube app on iOS picks
    /// it up); otherwise we hand back the original URL unchanged.
    private func canonicalWatchURL(for video: PlayingVideo) -> URL {
        if let id = video.youTubeVideoId,
           let url = URL(string: "https://www.youtube.com/watch?v=\(id)") {
            return url
        }
        return video.url
    }

    @ViewBuilder
    private var summarySection: some View {
        switch summary {
        case .idle, .loading:
            Section("Summary") {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .padding(.vertical, 8)
            }
        case .loaded(let s):
            if s.wind != nil || !s.results.isEmpty {
                Section("Summary") {
                    if let wind = s.wind {
                        WindRow(wind: wind)
                    }
                    if !s.results.isEmpty {
                        ResultsTable(results: s.results)
                    }
                }
            }
        case .failed(let reason):
            Section("Summary") {
                Label(reason.message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
    }

    @ViewBuilder
    private var availabilitySection: some View {
        let present = attachedKinds
        if !present.isEmpty {
            Section("Attached content") {
                let cols = [GridItem(.adaptive(minimum: 90), spacing: 12)]
                LazyVGrid(columns: cols, alignment: .leading, spacing: 10) {
                    ForEach(present, id: \.self) { kind in
                        attachedBadge(for: kind)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var attachedKinds: [AttachedKind] {
        var result: [AttachedKind] = []
        if session.hasTrack { result.append(.track) }
        if session.hasAudio { result.append(.audio) }
        if session.hasVideo { result.append(.video) }
        if session.hasTranscript { result.append(.transcript) }
        if session.hasResults { result.append(.results) }
        if session.hasCrew { result.append(.crew) }
        if session.hasSails { result.append(.sails) }
        if session.hasNotes { result.append(.notes) }
        return result
    }

    @ViewBuilder
    private func attachedBadge(for kind: AttachedKind) -> some View {
        switch kind {
        case .video:
            if let raw = session.firstVideoUrl, let url = URL(string: raw) {
                Button {
                    playingVideo = PlayingVideo(
                        url: url,
                        youTubeVideoId: youTubeVideoID(from: url)
                    )
                } label: {
                    Label(kind.label, systemImage: kind.systemImage)
                        .foregroundStyle(.tint)
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play video")
            } else {
                plainBadge(for: kind)
            }
        default:
            plainBadge(for: kind)
        }
    }

    private func plainBadge(for kind: AttachedKind) -> some View {
        Label(kind.label, systemImage: kind.systemImage)
            .foregroundStyle(.tint)
            .font(.callout)
    }

    private func loadSummary() async {
        guard case .idle = summary, let api = config.apiClient() else { return }
        summary = .loading
        do {
            let fetched = try await api.summary(for: session.id)
            summary = .loaded(fetched)
        } catch {
            summary = .failed(FailureReason(error))
        }
    }

    private func durationString(from start: Date, to end: Date) -> String {
        let seconds = end.timeIntervalSince(start)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? ""
    }
}

private struct WindRow: View {
    let wind: SessionSummary.Wind

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Avg wind")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(wind.avgTwsKnots, specifier: "%.1f")")
                        .font(.title3.weight(.semibold))
                    Text("kts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Divider().frame(height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("From")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(wind.avgTwdDegrees.rounded()))°")
                        .font(.title3.weight(.semibold))
                    Text(compassCardinal(from: wind.avgTwdDegrees))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "location.north.fill")
                .rotationEffect(.degrees(wind.avgTwdDegrees))
                .foregroundStyle(.tint)
                .imageScale(.large)
        }
    }

    private func compassCardinal(from degrees: Double) -> String {
        let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let i = Int(((degrees + 22.5).truncatingRemainder(dividingBy: 360)) / 45)
        return dirs[(i + 8) % 8]
    }
}

private struct ResultsTable: View {
    let results: [SessionSummary.RaceResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Results")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(results) { result in
                HStack(spacing: 8) {
                    placeBadge(result)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(result.boatName)
                            .font(.callout)
                            .lineLimit(1)
                        if let sail = result.sailNumber, !sail.isEmpty {
                            Text("Sail #\(sail)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let code = result.statusCode, !code.isEmpty {
                        Text(code)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func placeBadge(_ result: SessionSummary.RaceResult) -> some View {
        let text: String = {
            if result.dnf { return "DNF" }
            if result.dns { return "DNS" }
            if let p = result.place { return "\(p)" }
            return "—"
        }()
        let color: Color = {
            if result.dnf || result.dns { return .secondary }
            switch result.place {
            case 1: return .yellow
            case 2: return Color(white: 0.7)
            case 3: return .brown
            default: return .gray
            }
        }()
        Text(text)
            .font(.caption.bold().monospacedDigit())
            .foregroundStyle(.white)
            .frame(minWidth: 28, minHeight: 22)
            .background(color, in: RoundedRectangle(cornerRadius: 5))
    }
}

/// The eight kinds of optional content a session can carry. Driving the
/// Attached Content grid off a real type (rather than a tuple) makes it
/// easier to add per-kind tap behaviour as we go — video opens external,
/// notes will push a sheet, audio will want an AVPlayer, etc.
private enum AttachedKind: Hashable {
    case track, audio, video, transcript, results, crew, sails, notes

    var label: String {
        switch self {
        case .track: "Track"
        case .audio: "Audio"
        case .video: "Video"
        case .transcript: "Transcript"
        case .results: "Results"
        case .crew: "Crew"
        case .sails: "Sails"
        case .notes: "Notes"
        }
    }

    var systemImage: String {
        switch self {
        case .track: "map"
        case .audio: "waveform"
        case .video: "play.rectangle"
        case .transcript: "text.bubble"
        case .results: "trophy"
        case .crew: "person.3"
        case .sails: "flag.2.crossed"
        case .notes: "note.text"
        }
    }
}

#Preview("Loaded") {
    NavigationStack {
        SessionDetailView(session: Session.previews[0])
            .environment(ServerConfiguration())
    }
}
