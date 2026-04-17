import Foundation

/// Compact per-session summary returned by
/// `GET /api/sessions/{id}/summary`. Designed to be cheap enough for a
/// detail screen to fetch on appear — it elides the full track (that's
/// what `/track` is for) and focuses on numbers and results the user
/// wants at a glance.
///
/// Fields we model here are a subset of the server's response; the full
/// response also includes a downsampled track and an events array of
/// tack / gybe / rounding indices. Those aren't rendered in v0.1 so we
/// skip them — Codable ignores unknown keys.
public struct SessionSummary: Decodable, Sendable, Hashable {
    public let wind: Wind?
    public let results: [RaceResult]

    public init(wind: Wind?, results: [RaceResult]) {
        self.wind = wind
        self.results = results
    }

    /// Average wind during the session. `nil` when the server had no
    /// wind samples (no connected anemometer, or session was too short).
    public struct Wind: Decodable, Sendable, Hashable {
        public let avgTwsKnots: Double
        public let avgTwdDegrees: Double

        public init(avgTwsKnots: Double, avgTwdDegrees: Double) {
            self.avgTwsKnots = avgTwsKnots
            self.avgTwdDegrees = avgTwdDegrees
        }

        private enum CodingKeys: String, CodingKey {
            case avgTwsKnots = "avgTwsKts"
            case avgTwdDegrees = "avgTwdDeg"
        }
    }

    /// One row of the session's finish results. The server returns the
    /// top three finishers, plus our own boat if it isn't already in the
    /// top three.
    public struct RaceResult: Decodable, Sendable, Hashable, Identifiable {
        public let place: Int?
        public let dnf: Bool
        public let dns: Bool
        public let statusCode: String?
        public let sailNumber: String?
        public let boatName: String

        /// Stable identifier for SwiftUI `ForEach`. Sail number when we
        /// have one, else boat name + place for lesser uniqueness.
        public var id: String {
            if let sail = sailNumber, !sail.isEmpty { return "sail-\(sail)" }
            return "\(boatName)#\(place ?? 0)"
        }

        public init(
            place: Int?,
            dnf: Bool,
            dns: Bool,
            statusCode: String?,
            sailNumber: String?,
            boatName: String
        ) {
            self.place = place
            self.dnf = dnf
            self.dns = dns
            self.statusCode = statusCode
            self.sailNumber = sailNumber
            self.boatName = boatName
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.place = try c.decodeIfPresent(Int.self, forKey: .place)
            self.dnf = try Decode.flexibleBool(c, forKey: .dnf)
            self.dns = try Decode.flexibleBool(c, forKey: .dns)
            self.statusCode = try c.decodeIfPresent(String.self, forKey: .statusCode)
            self.sailNumber = try c.decodeIfPresent(String.self, forKey: .sailNumber)
            self.boatName = try c.decode(String.self, forKey: .boatName)
        }

        private enum CodingKeys: String, CodingKey {
            case place, dnf, dns, statusCode, sailNumber, boatName
        }
    }
}
