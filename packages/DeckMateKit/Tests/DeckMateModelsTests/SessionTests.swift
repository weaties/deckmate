import XCTest
@testable import DeckMateModels

final class SessionTests: XCTestCase {
    func testDecodesRaceFromServerJSON() throws {
        // Shape copied from a real `GET /api/sessions` response: the field
        // is named `type`, not `kind`, and peer/embargo fields are absent.
        let json = """
        {
            "id": 42,
            "type": "race",
            "name": "Thursday night #3",
            "start_utc": "2026-04-17T18:00:00.000Z",
            "end_utc": null
        }
        """.data(using: .utf8)!

        let session = try DeckMateJSON.decoder.decode(Session.self, from: json)
        XCTAssertEqual(session.id, 42)
        XCTAssertEqual(session.kind, .race)
        XCTAssertEqual(session.name, "Thursday night #3")
        XCTAssertNil(session.endUtc)
        XCTAssertNil(session.boatId)
        XCTAssertNil(session.embargoUntil)
        XCTAssertFalse(session.isEmbargoed())
    }

    func testDecodesAllKnownKinds() throws {
        for kind in Session.Kind.allCases {
            let json = """
            {
                "id": 1,
                "type": "\(kind.rawValue)",
                "name": "t",
                "start_utc": "2026-04-17T18:00:00.000Z"
            }
            """.data(using: .utf8)!
            let session = try DeckMateJSON.decoder.decode(Session.self, from: json)
            XCTAssertEqual(session.kind, kind)
        }
    }

    func testIsEmbargoedWhenUntilIsInFuture() {
        let future = Date.now.addingTimeInterval(3600)
        let s = Session(
            id: 1, kind: .race, name: "t",
            startUtc: .now, embargoUntil: future
        )
        XCTAssertTrue(s.isEmbargoed())
    }

    func testIsNotEmbargoedWhenUntilIsInPast() {
        let past = Date.now.addingTimeInterval(-3600)
        let s = Session(
            id: 1, kind: .race, name: "t",
            startUtc: .now, embargoUntil: past
        )
        XCTAssertFalse(s.isEmbargoed())
    }
}
