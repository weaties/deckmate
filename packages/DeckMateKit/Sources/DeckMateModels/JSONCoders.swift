import Foundation

/// Shared JSON decoder / encoder configured to match what the HelmLog
/// server emits: snake-case field names and ISO-8601 UTC timestamps.
///
/// Always go through these rather than `JSONDecoder()` at call sites — it
/// keeps the decoding rules in one place and makes fixture tests honest.
public enum DeckMateJSON {
    public static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601WithFractionalSeconds
        return d
    }()

    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601WithFractionalSeconds
        return e
    }()
}

private extension JSONDecoder.DateDecodingStrategy {
    /// The HelmLog server emits `2026-04-17T14:03:12.123Z` — ISO-8601 with
    /// fractional seconds. Foundation's default `.iso8601` rejects those,
    /// so we install a custom decoder here.
    static let iso8601WithFractionalSeconds = JSONDecoder.DateDecodingStrategy.custom { decoder in
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let date = DeckMateISO8601.parse(raw) {
            return date
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected ISO-8601 date with optional fractional seconds, got \(raw)"
        )
    }
}

private extension JSONEncoder.DateEncodingStrategy {
    static let iso8601WithFractionalSeconds = JSONEncoder.DateEncodingStrategy.custom { date, encoder in
        var container = encoder.singleValueContainer()
        try container.encode(DeckMateISO8601.format(date))
    }
}

enum DeckMateISO8601 {
    private static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let withoutFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ s: String) -> Date? {
        withFractional.date(from: s) ?? withoutFractional.date(from: s)
    }

    static func format(_ d: Date) -> String {
        withFractional.string(from: d)
    }
}
