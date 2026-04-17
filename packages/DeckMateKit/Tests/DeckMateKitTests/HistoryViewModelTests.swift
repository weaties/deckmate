import XCTest
@testable import DeckMateKit

@MainActor
final class HistoryViewModelTests: XCTestCase {
    func testInitialStateIsIdle() {
        let vm = HistoryViewModel { _, _ in
            XCTFail("loader should not fire until load()")
            return SessionListPage(total: 0, sessions: [])
        }
        guard case .idle = vm.state else {
            return XCTFail("expected .idle, got \(vm.state)")
        }
        XCTAssertNil(vm.sessions)
    }

    func testLoadTransitionsToLoaded() async {
        let page = SessionListPage(total: 3, sessions: Session.previews)
        let vm = HistoryViewModel { limit, offset in
            XCTAssertEqual(limit, 25)
            XCTAssertEqual(offset, 0)
            return page
        }

        await vm.load()

        guard case .loaded(let got) = vm.state else {
            return XCTFail("expected .loaded, got \(vm.state)")
        }
        XCTAssertEqual(got.total, 3)
        XCTAssertEqual(got.sessions.count, 3)
        XCTAssertEqual(vm.sessions?.count, 3)
    }

    func testLoadFailureMapsAPIErrorToFriendlyMessage() async {
        let vm = HistoryViewModel { _, _ in
            throw APIError.unauthorized
        }

        await vm.load()

        guard case .failed(let reason) = vm.state else {
            return XCTFail("expected .failed, got \(vm.state)")
        }
        XCTAssertTrue(reason.message.contains("Settings"),
                      "expected unauthorized message to mention Settings, got: \(reason.message)")
    }

    func testLoadFailureUnknownErrorFallsBack() async {
        struct Boom: Error {}
        let vm = HistoryViewModel { _, _ in throw Boom() }

        await vm.load()

        guard case .failed(let reason) = vm.state else {
            return XCTFail("expected .failed, got \(vm.state)")
        }
        XCTAssertFalse(reason.message.isEmpty)
    }

    func testReloadAfterFailureSucceeds() async {
        var attempt = 0
        let vm = HistoryViewModel { _, _ in
            attempt += 1
            if attempt == 1 { throw APIError.server(500) }
            return SessionListPage(total: 1, sessions: [Session.previews[0]])
        }

        await vm.load()
        guard case .failed = vm.state else {
            return XCTFail("first call should fail")
        }

        await vm.load()
        guard case .loaded = vm.state else {
            return XCTFail("second call should succeed")
        }
    }
}
