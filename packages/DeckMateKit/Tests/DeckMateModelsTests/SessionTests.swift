import XCTest
@testable import DeckMateModels

final class SessionTests: XCTestCase {
    func testDecodesFromSnakeCaseJSON() throws {
        let json = """
        {
            "id": 42,
            "kind": "race",
            "name": "Thursday night #3",
            "start_utc": "2026-04-17T18:00:00.000Z",
            "end_utc": null,
            "boat_id": "BOAT-001",
            "co_op_id": null,
            "embargo_until": null
        }
        """.data(using: .utf8)!

        let session = try DeckMateJSON.decoder.decode(Session.self, from: json)
        XCTAssertEqual(session.id, 42)
        XCTAssertEqual(session.kind, .race)
        XCTAssertNil(session.endUtc)
        XCTAssertFalse(session.isEmbargoed())
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
