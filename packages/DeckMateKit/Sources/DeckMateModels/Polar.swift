import Foundation

/// A polar performance baseline — target boatspeed as a function of
/// (true wind speed, true wind angle). Mirrors `GET /api/polar/...` on the
/// server (`../helmlog/src/helmlog/routes/polar.py`).
///
/// `cells` is a sparse table keyed by (rounded TWS knots, rounded TWA deg).
/// A `nil` means "no sample yet" rather than zero.
public struct Polar: Codable, Hashable, Sendable {
    public let boatId: String
    public let builtAtUtc: Date
    public let cells: [PolarCell]

    public init(boatId: String, builtAtUtc: Date, cells: [PolarCell]) {
        self.boatId = boatId
        self.builtAtUtc = builtAtUtc
        self.cells = cells
    }
}

public struct PolarCell: Codable, Hashable, Sendable {
    public let twsKnots: Double
    public let twaDegrees: Double
    public let targetBspKnots: Double
    public let sampleCount: Int
    /// 0.0 to 1.0 — how confident we are in this target given samples and
    /// consistency. UI must show "—" below `minConfidenceForDisplay`.
    public let confidence: Double

    public init(
        twsKnots: Double,
        twaDegrees: Double,
        targetBspKnots: Double,
        sampleCount: Int,
        confidence: Double
    ) {
        self.twsKnots = twsKnots
        self.twaDegrees = twaDegrees
        self.targetBspKnots = targetBspKnots
        self.sampleCount = sampleCount
        self.confidence = confidence
    }
}

public extension Polar {
    /// Minimum confidence before a target is safe to surface in the UI.
    /// See CLAUDE.md EARS rule: "WHEN polar confidence < 0.5 THE Live view
    /// SHALL display '—' instead of a target".
    static let minConfidenceForDisplay: Double = 0.5
}
