//
//  ContentView.swift
//  DeckMateWatch Watch App
//
//  Created by Dan Weatbrook on 4/17/26.
//

import SwiftUI
import DeckMateKit

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List(Session.previews) { session in
                SessionRow(session: session)
            }
            .navigationTitle("Sessions")
        }
    }
}

private struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(session.startUtc, format: .dateTime.day().month().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var icon: String {
        switch session.kind {
        case .race: "flag.checkered"
        case .audio: "waveform"
        }
    }
}

#Preview {
    ContentView()
}
