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
                SessionRow(session: session)
            }
            .navigationTitle("Sessions")
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
        case .audio: "waveform"
        }
    }
}

#Preview {
    ContentView()
}
