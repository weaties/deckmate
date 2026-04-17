import Foundation

/// Helpers used by model types that need to absorb server-side shape
/// variations without a separate wire type.
enum Decode {
    /// The HelmLog server's SQLite-derived responses sometimes emit
    /// boolean-ish values as `0`/`1` integers rather than `true`/`false`
    /// (`SELECT COUNT(*) > 0` in SQLite round-trips as an int). This
    /// accepts either, and an optional default for missing keys.
    static func flexibleBool<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>,
        forKey key: K,
        default fallback: Bool = false
    ) throws -> Bool {
        if let b = try? container.decode(Bool.self, forKey: key) { return b }
        if let i = try? container.decode(Int.self, forKey: key) { return i != 0 }
        return fallback
    }
}
