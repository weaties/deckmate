import Foundation
import DeckMateModels

/// Internal wire type for `GET /api/sessions/{id}/track`.
///
/// The server returns GeoJSON — a `FeatureCollection` with a single
/// `LineString` feature. This isn't the shape any view wants to deal with,
/// so we decode it here and then flatten to `Track` before returning.
///
/// GeoJSON's `[longitude, latitude]` ordering is the historical JSON
/// convention but the opposite of what people say aloud ("lat/long"), so
/// we translate once at this boundary and never think about it again in
/// the app.
struct TrackGeoJSON: Decodable {
    let features: [Feature]

    struct Feature: Decodable {
        let geometry: Geometry
        let properties: Properties
    }

    struct Geometry: Decodable {
        let coordinates: [[Double]]  // [[lon, lat], [lon, lat], ...]
    }

    struct Properties: Decodable {
        let timestamps: [String]
    }

    /// Flatten the envelope to a domain `Track`.
    ///
    /// - Parameter sessionId: the ID the caller passed — used when the
    ///   server returns an empty FeatureCollection (no recorded GPS fixes),
    ///   since the empty response doesn't echo the session ID back.
    func toTrack(sessionId: Int) -> Track {
        guard let feature = features.first else {
            return .empty(sessionId: sessionId)
        }
        let coords: [TrackCoordinate] = feature.geometry.coordinates.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            return TrackCoordinate(latitude: pair[1], longitude: pair[0])
        }
        let times: [Date] = feature.properties.timestamps.compactMap {
            DeckMateISO8601.parse($0)
        }
        return Track(sessionId: sessionId, coordinates: coords, timestamps: times)
    }
}
