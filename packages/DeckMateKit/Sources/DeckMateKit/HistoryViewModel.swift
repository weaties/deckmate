import Foundation
import Observation

#if canImport(DeckMateAPI)
import DeckMateAPI
#endif
#if canImport(DeckMateModels)
import DeckMateModels
#endif

/// The view model backing the History screen.
///
/// Keeps an accumulated list of sessions across paginated loads and
/// exposes a small `Status` enum views switch on for loading / error /
/// idle rendering. Views never call `APIClient` directly — they call
/// `load()` on this type and observe the result.
///
/// Built with Swift's `@Observable` macro (iOS 17+), the modern successor
/// to `ObservableObject` + `@Published`. Any property the class stores is
/// observable by default; no per-property annotation needed.
///
/// `@MainActor` pins state mutations to the main actor so SwiftUI can read
/// them safely without additional hop annotations.
@Observable
@MainActor
public final class HistoryViewModel {
    /// Closure form of the "fetch a page of sessions" dependency. Using a
    /// closure instead of a protocol keeps tests trivial — no URLSession,
    /// no stubs, just a function that returns canned data.
    public typealias Loader = @Sendable (_ limit: Int, _ offset: Int) async throws -> SessionListPage

    /// Lifecycle of the view model. Views switch on this to render a
    /// spinner for the initial load, a subtle indicator for pagination,
    /// or an error panel. `.settled` means a page has been loaded and we
    /// are waiting for the user to scroll or refresh.
    public enum Status: Sendable, Hashable {
        case idle
        case loadingFirstPage
        case loadingMore
        case settled
        case failed(FailureReason)
    }

    public private(set) var status: Status = .idle
    public private(set) var sessions: [Session] = []
    public private(set) var total: Int = 0

    /// True when the server reports more sessions beyond what we've loaded.
    public var hasMore: Bool { sessions.count < total }

    private let loader: Loader
    private let pageSize: Int

    public init(pageSize: Int = 25, loader: @escaping Loader) {
        self.pageSize = pageSize
        self.loader = loader
    }

    /// Convenience — wrap an `APIClient` as a loader.
    public convenience init(pageSize: Int = 25, api: APIClient) {
        self.init(pageSize: pageSize) { limit, offset in
            try await api.sessions(limit: limit, offset: offset)
        }
    }

    /// Initial load or refresh. Wipes the accumulated state before calling
    /// so a pull-to-refresh always starts from offset 0.
    public func load() async {
        status = .loadingFirstPage
        sessions = []
        total = 0
        do {
            let page = try await loader(pageSize, 0)
            sessions = page.sessions
            total = page.total
            status = .settled
        } catch {
            status = .failed(FailureReason(error))
        }
    }

    /// Append the next page if one exists. No-op if already loading, if we
    /// have everything, or if the first load hasn't happened yet. Views
    /// call this from `.onAppear` on the last visible row.
    public func loadMoreIfNeeded() async {
        guard status == .settled, hasMore else { return }
        status = .loadingMore
        do {
            let page = try await loader(pageSize, sessions.count)
            sessions.append(contentsOf: page.sessions)
            total = page.total
            status = .settled
        } catch {
            // Don't wipe accumulated sessions — keep them visible so the
            // user can retry without losing scroll position.
            status = .failed(FailureReason(error))
        }
    }
}

/// A display-safe representation of an error — holds a short message
/// suitable for the UI. Views render `.message`, never `Error` directly.
///
/// Known error types are translated to friendly text with actionable
/// hints ("Check your server credential in Settings") rather than raw
/// NSError descriptions ("Error Domain=NSURLErrorDomain Code=-1003…").
public struct FailureReason: Sendable, Hashable {
    public let message: String

    public init(_ error: Error) {
        #if canImport(DeckMateAPI)
        if let apiError = error as? APIError {
            self.message = Self.describe(apiError)
            return
        }
        #endif
        if let urlError = error as? URLError {
            self.message = Self.describe(urlError)
            return
        }
        self.message = error.localizedDescription
    }

    public init(message: String) {
        self.message = message
    }

    #if canImport(DeckMateAPI)
    private static func describe(_ error: APIError) -> String {
        switch error {
        case .unauthorized: "Not signed in. Check your server credential in Settings."
        case .forbidden: "You don't have access to this resource."
        case .notFound: "The server returned 404."
        case .invalidURL(let p): "Bad URL: \(p)"
        case .invalidResponse: "The server returned a response we couldn't parse."
        case .decodingFailed: "The server sent unexpected data."
        case .client(let code): "Request failed (\(code))."
        case .server(let code): "Server error (\(code)). Try again shortly."
        case .notImplemented: "That feature isn't wired up yet."
        }
    }
    #endif

    private static func describe(_ error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet:
            return "No internet connection."
        case .timedOut:
            return "The server took too long to respond."
        case .cannotFindHost, .dnsLookupFailed:
            return "Couldn't resolve the server's hostname. Check the URL in Settings."
        case .cannotConnectToHost:
            return "Couldn't reach the server. It may be offline or on a different network."
        case .networkConnectionLost:
            return "The connection dropped mid-request. Try again."
        case .badURL:
            return "The server URL looks malformed. Check Settings."
        case .appTransportSecurityRequiresSecureConnection:
            return "This device won't allow plain-HTTP connections to that server."
        case .secureConnectionFailed, .serverCertificateUntrusted,
             .serverCertificateHasBadDate, .serverCertificateNotYetValid,
             .serverCertificateHasUnknownRoot, .clientCertificateRejected:
            return "The server's TLS certificate couldn't be verified."
        case .userCancelledAuthentication, .userAuthenticationRequired:
            return "Authentication is required. Set a credential in Settings."
        default:
            return "Network error: \(error.localizedDescription)"
        }
    }
}
