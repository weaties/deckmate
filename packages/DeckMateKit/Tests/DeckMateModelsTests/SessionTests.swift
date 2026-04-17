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
        // Availability flags default to false when absent.
        XCTAssertFalse(session.hasTrack)
        XCTAssertFalse(session.hasAudio)
        XCTAssertFalse(session.hasVideo)
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

    func testDecodesEnrichedFieldsFromListResponse() throws {
        // Fields the server adds beyond the core: event/race_num/slug
        // metadata plus the has_* availability flags. Mix of true/false
        // values in each flavour SQLite might emit.
        let json = """
        {
            "id": 101,
            "type": "race",
            "name": "2026-04-17-R3",
            "slug": "2026-04-17-r3",
            "event": "Wednesday Night Series",
            "race_num": 3,
            "start_utc": "2026-04-17T18:00:00.000Z",
            "end_utc": "2026-04-17T19:15:00.000Z",
            "has_audio": 1,
            "has_track": true,
            "has_transcript": 0,
            "has_results": true,
            "has_crew": 0,
            "has_sails": 1,
            "has_notes": false,
            "first_video_url": "https://www.youtube.com/watch?v=abc123"
        }
        """.data(using: .utf8)!

        let s = try DeckMateJSON.decoder.decode(Session.self, from: json)
        XCTAssertEqual(s.event, "Wednesday Night Series")
        XCTAssertEqual(s.raceNum, 3)
        XCTAssertEqual(s.slug, "2026-04-17-r3")
        XCTAssertEqual(s.firstVideoUrl, "https://www.youtube.com/watch?v=abc123")
        XCTAssertTrue(s.hasVideo)
        XCTAssertTrue(s.hasAudio, "integer 1 should decode as true")
        XCTAssertTrue(s.hasTrack, "bool true should decode as true")
        XCTAssertFalse(s.hasTranscript, "integer 0 should decode as false")
        XCTAssertFalse(s.hasCrew)
        XCTAssertTrue(s.hasSails)
        XCTAssertTrue(s.hasResults)
        XCTAssertFalse(s.hasNotes)
        XCTAssertEqual(s.shortNumberLabel, "R3")
    }

    func testHasVideoFalseWhenVideoUrlIsEmpty() throws {
        let json = """
        {
            "id": 1, "type": "race", "name": "t",
            "start_utc": "2026-04-17T18:00:00.000Z",
            "first_video_url": ""
        }
        """.data(using: .utf8)!
        let s = try DeckMateJSON.decoder.decode(Session.self, from: json)
        XCTAssertFalse(s.hasVideo)
    }

    func testShortNumberLabelPracticeVariant() throws {
        let s = Session(id: 1, kind: .practice, name: "t", startUtc: .now, raceNum: 2)
        XCTAssertEqual(s.shortNumberLabel, "P2")
    }

    func testShortNumberLabelAbsentForDebriefs() throws {
        let s = Session(id: 1, kind: .debrief, name: "t", startUtc: .now, raceNum: 2)
        XCTAssertNil(s.shortNumberLabel)
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

final class SessionSummaryTests: XCTestCase {
    func testDecodesWindAndResults() throws {
        let json = """
        {
            "track": [],
            "events": [],
            "wind": {
                "avg_tws_kts": 8.4,
                "avg_twd_deg": 232
            },
            "results": [
                {"place": 1, "dnf": 0, "dns": 0, "status_code": null, "sail_number": "12345", "boat_name": "Swan"},
                {"place": 2, "dnf": 0, "dns": 0, "status_code": null, "sail_number": "67890", "boat_name": "Kestrel"},
                {"place": null, "dnf": 1, "dns": 0, "status_code": "DNF", "sail_number": "11111", "boat_name": "Limping Duck"}
            ]
        }
        """.data(using: .utf8)!

        let summary = try DeckMateJSON.decoder.decode(SessionSummary.self, from: json)
        XCTAssertEqual(summary.wind?.avgTwsKnots ?? 0, 8.4, accuracy: 0.001)
        XCTAssertEqual(summary.wind?.avgTwdDegrees ?? 0, 232, accuracy: 0.001)
        XCTAssertEqual(summary.results.count, 3)
        XCTAssertEqual(summary.results[0].place, 1)
        XCTAssertEqual(summary.results[0].boatName, "Swan")
        XCTAssertFalse(summary.results[0].dnf)
        XCTAssertTrue(summary.results[2].dnf)
        XCTAssertNil(summary.results[2].place)
    }

    func testDecodesWhenWindIsNull() throws {
        let json = """
        {
            "track": [], "events": [], "wind": null, "results": []
        }
        """.data(using: .utf8)!

        let summary = try DeckMateJSON.decoder.decode(SessionSummary.self, from: json)
        XCTAssertNil(summary.wind)
        XCTAssertTrue(summary.results.isEmpty)
    }
}
