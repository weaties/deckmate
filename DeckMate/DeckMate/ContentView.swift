//
//  ContentView.swift
//  DeckMate
//
//  Created by Dan Weatbrook on 4/17/26.
//

import SwiftUI
import DeckMateKit

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List(Session.previews) { session in
                NavigationLink(value: session) {
                    SessionRow(session: session)
                }
            }
            .navigationTitle("Sessions")
            .navigationDestination(for: Session.self) { session in
                SessionDetailView(session: session)
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

    var body: some View {
        Form {
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

#Preview("List") {
    ContentView()
}

#Preview("Detail") {
    NavigationStack {
        SessionDetailView(session: Session.previews[0])
    }
}
