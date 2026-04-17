//
//  TrackMapView.swift
//  DeckMate
//
//  Renders a Session's recorded GPS track on a MapKit map.
//

import SwiftUI
import MapKit
import DeckMateKit

/// Loads and renders a session's track.
///
/// Owns its load state locally via @State — small enough that pulling out
/// a ViewModel isn't worth the ceremony. If we add scrubbing, per-point
/// overlays, or playback, that changes and we extract one.
struct TrackMapView: View {
    let session: Session
    let api: APIClient

    @State private var phase: Phase = .loading

    private enum Phase {
        case loading
        case loaded(Track)
        case failed(FailureReason)
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 240)
            case .loaded(let track) where track.isEmpty:
                ContentUnavailableView(
                    "No track recorded",
                    systemImage: "location.slash",
                    description: Text("This session has no GPS fixes.")
                )
                .frame(minHeight: 240)
            case .loaded(let track):
                MapCanvas(track: track)
            case .failed(let reason):
                ContentUnavailableView {
                    Label("Couldn't load track", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(reason.message)
                } actions: {
                    Button("Try Again") { Task { await load() } }
                }
                .frame(minHeight: 240)
            }
        }
        .task { await load() }
    }

    private func load() async {
        phase = .loading
        do {
            let track = try await api.track(for: session.id)
            phase = .loaded(track)
        } catch {
            phase = .failed(FailureReason(error))
        }
    }
}

/// The actual MapKit canvas once the track is loaded. Split out so the
/// parent's switch statement stays shallow.
private struct MapCanvas: View {
    let track: Track

    var body: some View {
        Map(initialPosition: .region(region)) {
            MapPolyline(coordinates: coordinates)
                .stroke(.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            if let start = coordinates.first {
                Annotation("Start", coordinate: start) {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(.green)
                        .background(Circle().fill(.white).frame(width: 18, height: 18))
                }
            }
            if let end = coordinates.last, coordinates.count > 1 {
                Annotation("End", coordinate: end) {
                    Image(systemName: "flag.checkered")
                        .foregroundStyle(.red)
                        .background(Circle().fill(.white).frame(width: 18, height: 18))
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .frame(minHeight: 240)
    }

    /// Bounding box around the track, padded 15% so the polyline doesn't
    /// sit flush against the edge of the map.
    private var region: MKCoordinateRegion {
        guard let first = track.coordinates.first else {
            return MKCoordinateRegion()
        }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for c in track.coordinates.dropFirst() {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        let latCenter = (minLat + maxLat) / 2
        let lonCenter = (minLon + maxLon) / 2
        let latDelta = max((maxLat - minLat) * 1.3, 0.005)
        let lonDelta = max((maxLon - minLon) * 1.3, 0.005)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latCenter, longitude: lonCenter),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }

    private var coordinates: [CLLocationCoordinate2D] {
        track.coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }
}

#Preview("Loaded") {
    MapCanvas(track: .preview)
}
