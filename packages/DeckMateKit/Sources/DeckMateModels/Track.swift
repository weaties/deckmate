import Foundation

/// A single decoded instrument sample at a point in time. This is the
/// canonical "tick" the Live race-day view consumes.
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

/// A track — the full time series of `InstrumentTick`s for one session.
public struct Track: Codable, Hashable, Sendable {
    public let sessionId: Int
    public let ticks: [InstrumentTick]

    public init(sessionId: Int, ticks: [InstrumentTick]) {
        self.sessionId = sessionId
        self.ticks = ticks
    }
}
