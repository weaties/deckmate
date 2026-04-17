import Foundation

/// A recorded sailing session — a race, a practice, a debrief, or a
/// server-synthesized block. Shape matches what `GET /api/sessions`
/// returns on the HelmLog server (`../helmlog/src/helmlog/routes/sessions.py`).
///
/// Keep field names aligned with the server JSON. If the server renames a
/// column, add a `CodingKeys` mapping here rather than renaming in Swift.
public struct Session: Decodable, Hashable, Identifiable, Sendable {
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

    /// Human-readable event name ("Wednesday Night Series"). Races/practices
    /// derived from live sailing typically have an event; debriefs often
    /// don't.
    public let event: String?
    /// Race number within the event (e.g. 3 for "R3").
    public let raceNum: Int?
    /// URL-safe short identifier used in deep links on the server's web UI.
    public let slug: String?
    /// If a YouTube (or similar) video has been linked to this session,
    /// the first one's URL. `nil` if no video is attached.
    public let firstVideoUrl: String?

    /// Availability flags — cheap "does this session have X content?"
    /// indicators the server computes with `COUNT(*) > 0` so apps can
    /// show badges without fetching the full payloads.
    public let hasTrack: Bool
    public let hasAudio: Bool
    public let hasTranscript: Bool
    public let hasResults: Bool
    public let hasCrew: Bool
    public let hasSails: Bool
    public let hasNotes: Bool

    /// Derived: true iff a linked video URL exists.
    public var hasVideo: Bool {
        guard let url = firstVideoUrl else { return false }
        return !url.isEmpty
    }

    public enum Kind: String, Decodable, Sendable, CaseIterable {
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
        embargoUntil: Date? = nil,
        event: String? = nil,
        raceNum: Int? = nil,
        slug: String? = nil,
        firstVideoUrl: String? = nil,
        hasTrack: Bool = false,
        hasAudio: Bool = false,
        hasTranscript: Bool = false,
        hasResults: Bool = false,
        hasCrew: Bool = false,
        hasSails: Bool = false,
        hasNotes: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.startUtc = startUtc
        self.endUtc = endUtc
        self.boatId = boatId
        self.coOpId = coOpId
        self.embargoUntil = embargoUntil
        self.event = event
        self.raceNum = raceNum
        self.slug = slug
        self.firstVideoUrl = firstVideoUrl
        self.hasTrack = hasTrack
        self.hasAudio = hasAudio
        self.hasTranscript = hasTranscript
        self.hasResults = hasResults
        self.hasCrew = hasCrew
        self.hasSails = hasSails
        self.hasNotes = hasNotes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(Int.self, forKey: .id)
        self.kind = try c.decode(Kind.self, forKey: .kind)
        self.name = try c.decode(String.self, forKey: .name)
        self.startUtc = try c.decode(Date.self, forKey: .startUtc)
        self.endUtc = try c.decodeIfPresent(Date.self, forKey: .endUtc)
        self.boatId = try c.decodeIfPresent(String.self, forKey: .boatId)
        self.coOpId = try c.decodeIfPresent(String.self, forKey: .coOpId)
        self.embargoUntil = try c.decodeIfPresent(Date.self, forKey: .embargoUntil)
        self.event = try c.decodeIfPresent(String.self, forKey: .event)
        self.raceNum = try c.decodeIfPresent(Int.self, forKey: .raceNum)
        self.slug = try c.decodeIfPresent(String.self, forKey: .slug)
        self.firstVideoUrl = try c.decodeIfPresent(String.self, forKey: .firstVideoUrl)
        self.hasTrack = try Decode.flexibleBool(c, forKey: .hasTrack)
        self.hasAudio = try Decode.flexibleBool(c, forKey: .hasAudio)
        self.hasTranscript = try Decode.flexibleBool(c, forKey: .hasTranscript)
        self.hasResults = try Decode.flexibleBool(c, forKey: .hasResults)
        self.hasCrew = try Decode.flexibleBool(c, forKey: .hasCrew)
        self.hasSails = try Decode.flexibleBool(c, forKey: .hasSails)
        self.hasNotes = try Decode.flexibleBool(c, forKey: .hasNotes)
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
        case event
        case raceNum
        case slug
        case firstVideoUrl
        case hasTrack
        case hasAudio
        case hasTranscript
        case hasResults
        case hasCrew
        case hasSails
        case hasNotes
    }
}

public extension Session {
    /// `true` if the session is currently embargoed per co-op policy.
    /// UI that shows peer data should check this before rendering.
    func isEmbargoed(now: Date = .now) -> Bool {
        guard let until = embargoUntil else { return false }
        return until > now
    }

    /// A short sort-of-human label — "R3" for race 3, "P2" for practice 2,
    /// or `nil` if the session kind doesn't carry a race number.
    var shortNumberLabel: String? {
        guard let n = raceNum else { return nil }
        switch kind {
        case .race: return "R\(n)"
        case .practice: return "P\(n)"
        case .debrief, .synthesized: return nil
        }
    }
}
