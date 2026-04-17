import Foundation

/// A recorded sailing session — a race, a practice, a debrief, or a
/// server-synthesized block. Shape matches what `GET /api/sessions`
/// returns on the HelmLog server (`../helmlog/src/helmlog/routes/sessions.py`).
///
/// Keep field names aligned with the server JSON. If the server renames a
/// column, add a `CodingKeys` mapping here rather than renaming in Swift.
public struct Session: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let kind: Kind
    public let name: String
    public let startUtc: Date
    public let endUtc: Date?
    public let boatId: String?
    public let coOpId: String?
    /// If set, the session is embargoed until this instant — the UI must
    /// not render track or instrument data while an embargo is active.
    public let embargoUntil: Date?

    public enum Kind: String, Codable, Sendable, CaseIterable {
        case race
        case practice
        case debrief
        case synthesized
    }

    public init(
        id: Int,
        kind: Kind,
        name: String,
        startUtc: Date,
        endUtc: Date? = nil,
        boatId: String? = nil,
        coOpId: String? = nil,
        embargoUntil: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.startUtc = startUtc
        self.endUtc = endUtc
        self.boatId = boatId
        self.coOpId = coOpId
        self.embargoUntil = embargoUntil
    }

    /// The server returns the kind field as `"type"`; we expose it as `kind`
    /// in Swift because `type` is a keyword-adjacent name that shadows
    /// common Swift idioms. Other fields rely on the decoder's
    /// `.convertFromSnakeCase` strategy, which runs before these CodingKeys
    /// are matched — so raw values here are already camelCase.
    private enum CodingKeys: String, CodingKey {
        case id
        case kind = "type"
        case name
        case startUtc
        case endUtc
        case boatId
        case coOpId
        case embargoUntil
    }
}

public extension Session {
    /// `true` if the session is currently embargoed per co-op policy.
    /// UI that shows peer data should check this before rendering.
    func isEmbargoed(now: Date = .now) -> Bool {
        guard let until = embargoUntil else { return false }
        return until > now
    }
}
