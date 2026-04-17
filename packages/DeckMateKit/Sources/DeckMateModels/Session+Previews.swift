import Foundation

public extension Session {
    /// Fixture sessions for SwiftUI previews and early UI development.
    /// Not shipping data — real sessions come from the HelmLog server via
    /// `DeckMateAPI.APIClient`.
    static let previews: [Session] = {
        let iso = ISO8601DateFormatter()
        let jan = iso.date(from: "2026-01-11T14:30:00Z")!
        let feb = iso.date(from: "2026-02-07T13:00:00Z")!
        let mar = iso.date(from: "2026-03-22T15:15:00Z")!
        return [
            Session(
                id: 1,
                kind: .race,
                name: "Frostbite #3",
                startUtc: jan,
                endUtc: jan.addingTimeInterval(5400),
                boatId: "GBR-12345"
            ),
            Session(
                id: 2,
                kind: .audio,
                name: "Post-race debrief",
                startUtc: feb,
                endUtc: feb.addingTimeInterval(900),
                boatId: "GBR-12345"
            ),
            Session(
                id: 3,
                kind: .race,
                name: "Spring Series #1",
                startUtc: mar,
                endUtc: mar.addingTimeInterval(7200),
                boatId: "GBR-12345"
            ),
        ]
    }()
}
