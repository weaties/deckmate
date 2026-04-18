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
        let badges: [(label: String, systemImage: String, present: Bool)] = [
            ("Track", "map", session.hasTrack),
            ("Audio", "waveform", session.hasAudio),
            ("Video", "play.rectangle", session.hasVideo),
            ("Transcript", "text.bubble", session.hasTranscript),
            ("Results", "trophy", session.hasResults),
            ("Crew", "person.3", session.hasCrew),
            ("Sails", "flag.2.crossed", session.hasSails),
            ("Notes", "note.text", session.hasNotes),
        ]
        let present = badges.filter(\.present)
        if !present.isEmpty {
            Section("Attached content") {
                let cols = [GridItem(.adaptive(minimum: 90), spacing: 12)]
                LazyVGrid(columns: cols, alignment: .leading, spacing: 10) {
                    ForEach(present, id: \.label) { badge in
                        Label(badge.label, systemImage: badge.systemImage)
                            .foregroundStyle(.tint)
                            .font(.callout)
                    }
                }
                .padding(.vertical, 4)
            }
        }
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

#Preview("Loaded") {
    NavigationStack {
        SessionDetailView(session: Session.previews[0])
            .environment(ServerConfiguration())
    }
}
