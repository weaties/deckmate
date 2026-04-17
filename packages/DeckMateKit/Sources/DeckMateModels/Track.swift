import Foundation

/// A GPS coordinate pair in decimal degrees (WGS84). Non-`Codable`
/// on purpose — we control decoding in `DeckMateAPI` because the server
/// returns a GeoJSON `LineString` whose `[longitude, latitude]` order is
/// opposite the Swift convention.
///
/// Apps wanting a `CLLocationCoordinate2D` (for MapKit) convert at the
/// call site — keeping `DeckMateKit` free of `CoreLocation` so tests
/// stay fast and the kit compiles on targets that don't import it.
public struct TrackCoordinate: Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// A recorded GPS track for one session. Matches the shape of
/// `GET /api/sessions/{id}/track` on the HelmLog server after the
/// GeoJSON envelope has been unwrapped by `APIClient`.
///
/// The client side stores parallel arrays of `coordinates` and
/// `timestamps` — the server emits them that way because it's what
/// `MapLibre` / similar JS consumers want. Views that render the track
/// as a polyline only need `coordinates`; a scrubber can cross-reference
/// the two by index.
public struct Track: Hashable, Sendable {
    public let sessionId: Int
    public let coordinates: [TrackCoordinate]
    public let timestamps: [Date]

    public init(sessionId: Int, coordinates: [TrackCoordinate], timestamps: [Date]) {
        self.sessionId = sessionId
        self.coordinates = coordinates
        self.timestamps = timestamps
    }

    /// Empty sentinel — for sessions with no recorded GPS fixes.
    public static func empty(sessionId: Int) -> Track {
        Track(sessionId: sessionId, coordinates: [], timestamps: [])
    }

    public var isEmpty: Bool { coordinates.isEmpty }
}

/// A single decoded instrument sample at a point in time. This is the
/// canonical "tick" the Live race-day view consumes via the WebSocket.
/// Still `Codable` because the live stream decodes per-tick.
///
/// Units:
///   - `twsKnots` / `awsKnots` / `sogKnots` — knots
///   - `twaDegrees` / `awaDegrees` / `cogDegrees` / `hdgDegrees` — degrees true
///   - `lat` / `lon` — WGS84, decimal degrees
public struct InstrumentTick: Codable, Hashable, Sendable {
    public let timestampUtc: Date
    public let lat: Double?
    public let lon: Double?
    public let sogKnots: Double?
    public let cogDegrees: Double?
    public let hdgDegrees: Double?
    public let bspKnots: Double?
    public let twsKnots: Double?
    public let twaDegrees: Double?
    public let awsKnots: Double?
    public let awaDegrees: Double?

    public init(
        timestampUtc: Date,
        lat: Double? = nil,
        lon: Double? = nil,
        sogKnots: Double? = nil,
        cogDegrees: Double? = nil,
        hdgDegrees: Double? = nil,
        bspKnots: Double? = nil,
        twsKnots: Double? = nil,
        twaDegrees: Double? = nil,
        awsKnots: Double? = nil,
        awaDegrees: Double? = nil
    ) {
        self.timestampUtc = timestampUtc
        self.lat = lat
        self.lon = lon
        self.sogKnots = sogKnots
        self.cogDegrees = cogDegrees
        self.hdgDegrees = hdgDegrees
        self.bspKnots = bspKnots
        self.twsKnots = twsKnots
        self.twaDegrees = twaDegrees
        self.awsKnots = awsKnots
        self.awaDegrees = awaDegrees
    }
}
