import XCTest
@testable import DeckMateKit

@MainActor
final class HistoryViewModelTests: XCTestCase {
    func testInitialStateIsIdle() {
        let vm = HistoryViewModel { _, _ in
            XCTFail("loader should not fire until load()")
            return SessionListPage(total: 0, sessions: [])
        }
        XCTAssertEqual(vm.status, .idle)
        XCTAssertTrue(vm.sessions.isEmpty)
        XCTAssertEqual(vm.total, 0)
        XCTAssertFalse(vm.hasMore)
    }

    func testLoadSettlesWithAccumulatedSessions() async {
        let vm = HistoryViewModel(pageSize: 25) { limit, offset in
            XCTAssertEqual(limit, 25)
            XCTAssertEqual(offset, 0)
            return SessionListPage(total: 3, sessions: Session.previews)
        }

        await vm.load()

        XCTAssertEqual(vm.status, .settled)
        XCTAssertEqual(vm.sessions.count, 3)
        XCTAssertEqual(vm.total, 3)
        XCTAssertFalse(vm.hasMore)
    }

    func testLoadResetsAccumulatedStateOnRefresh() async {
        var callCount = 0
        let vm = HistoryViewModel(pageSize: 2) { _, offset in
            callCount += 1
            if offset == 0 {
                return SessionListPage(
                    total: 4,
                    sessions: [Session.previews[0], Session.previews[1]]
                )
            }
            return SessionListPage(total: 4, sessions: [Session.previews[2]])
        }

        await vm.load()
        await vm.loadMoreIfNeeded()
        XCTAssertEqual(vm.sessions.count, 3)

        await vm.load()
        XCTAssertEqual(vm.sessions.count, 2, "refresh should reset accumulation")
        XCTAssertEqual(vm.total, 4)
    }

    func testLoadMoreAppendsNextPage() async {
        var capturedOffsets: [Int] = []
        let vm = HistoryViewModel(pageSize: 2) { _, offset in
            capturedOffsets.append(offset)
            if offset == 0 {
                return SessionListPage(
                    total: 3,
                    sessions: [Session.previews[0], Session.previews[1]]
                )
            }
            return SessionListPage(total: 3, sessions: [Session.previews[2]])
        }

        await vm.load()
        XCTAssertTrue(vm.hasMore)
        XCTAssertEqual(vm.sessions.count, 2)

        await vm.loadMoreIfNeeded()
        XCTAssertEqual(capturedOffsets, [0, 2])
        XCTAssertEqual(vm.sessions.count, 3)
        XCTAssertFalse(vm.hasMore)
        XCTAssertEqual(vm.status, .settled)
    }

    func testLoadMoreIsNoOpWhenNothingMoreToLoad() async {
        var callCount = 0
        let vm = HistoryViewModel(pageSize: 25) { _, _ in
            callCount += 1
            return SessionListPage(total: 1, sessions: [Session.previews[0]])
        }

        await vm.load()
        XCTAssertFalse(vm.hasMore)
        await vm.loadMoreIfNeeded()
        XCTAssertEqual(callCount, 1, "loadMoreIfNeeded should not fire a second request")
    }

    func testLoadMoreIsNoOpBeforeFirstLoad() async {
        let vm = HistoryViewModel { _, _ in
            XCTFail("loadMoreIfNeeded should not fire without a prior load()")
            return SessionListPage(total: 0, sessions: [])
        }
        await vm.loadMoreIfNeeded()
        XCTAssertEqual(vm.status, .idle)
    }

    func testLoadFailureMapsAPIErrorToFriendlyMessage() async {
        let vm = HistoryViewModel { _, _ in
            throw APIError.unauthorized
        }

        await vm.load()

        guard case .failed(let reason) = vm.status else {
            return XCTFail("expected .failed, got \(vm.status)")
        }
        XCTAssertTrue(reason.message.contains("Settings"),
                      "expected unauthorized message to mention Settings, got: \(reason.message)")
    }

    func testLoadMoreFailureKeepsExistingSessionsVisible() async {
        var callCount = 0
        let vm = HistoryViewModel(pageSize: 2) { _, _ in
            callCount += 1
            if callCount == 1 {
                return SessionListPage(
                    total: 5,
                    sessions: [Session.previews[0], Session.previews[1]]
                )
            }
            throw URLError(.notConnectedToInternet)
        }

        await vm.load()
        XCTAssertEqual(vm.sessions.count, 2)

        await vm.loadMoreIfNeeded()
        XCTAssertEqual(vm.sessions.count, 2, "failure should NOT wipe prior sessions")
        if case .failed(let reason) = vm.status {
            XCTAssertTrue(reason.message.contains("internet"))
        } else {
            XCTFail("expected .failed, got \(vm.status)")
        }
    }
}

@MainActor
final class FailureReasonTests: XCTestCase {
    func testURLErrorNotConnectedProducesShortMessage() {
        let reason = FailureReason(URLError(.notConnectedToInternet))
        XCTAssertEqual(reason.message, "No internet connection.")
    }

    func testURLErrorCannotFindHostMentionsSettings() {
        let reason = FailureReason(URLError(.cannotFindHost))
        XCTAssertTrue(reason.message.contains("Settings"))
    }

    func testURLErrorTimedOutMentionsServer() {
        let reason = FailureReason(URLError(.timedOut))
        XCTAssertTrue(reason.message.contains("server"))
    }

    func testURLErrorATSIsExplained() {
        let reason = FailureReason(URLError(.appTransportSecurityRequiresSecureConnection))
        XCTAssertTrue(reason.message.contains("plain-HTTP"))
    }

    func testAPIErrorUnauthorizedMentionsSettings() {
        let reason = FailureReason(APIError.unauthorized)
        XCTAssertTrue(reason.message.contains("Settings"))
    }

    func testUnknownErrorFallsBackToLocalizedDescription() {
        struct Boom: LocalizedError {
            var errorDescription: String? { "a custom thing went wrong" }
        }
        let reason = FailureReason(Boom())
        XCTAssertEqual(reason.message, "a custom thing went wrong")
    }
}
