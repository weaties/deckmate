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
/// Exposes a single `state: LoadState<SessionListPage>` that views observe;
/// the screen renders a spinner, a list, or an error row based on which
/// case is current. Views never call `APIClient` directly — they call
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

    public private(set) var state: LoadState<SessionListPage> = .idle

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

    /// Kick off a load. Callers invoke this from `.task { … }` on appear,
    /// or from a pull-to-refresh. Transitions state to `.loading` first so
    /// the UI can show a spinner even when the network call returns fast.
    public func load() async {
        state = .loading
        do {
            let page = try await loader(pageSize, 0)
            state = .loaded(page)
        } catch {
            state = .failed(FailureReason(error))
        }
    }

    /// Returns the sessions from the current `.loaded` state, or `nil`
    /// for any other state. Convenient when views want to render
    /// incrementally without unwrapping the enum each time.
    public var sessions: [Session]? {
        guard case .loaded(let page) = state else { return nil }
        return page.sessions
    }
}

/// Generic loading state — idle until asked, in-flight, succeeded with a
/// value, or failed with a reason. Parameterised over the success payload
/// so the same shape works for other screens (polars, tracks, etc.).
public enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(FailureReason)
}

/// A display-safe representation of an error — holds the underlying error
/// for diagnostics plus a short message suitable for the UI. We don't
/// surface `Error` directly because it isn't `Equatable`/`Sendable` in a
/// useful way, and views shouldn't be deciding how to stringify errors.
public struct FailureReason: Sendable, Hashable {
    public let message: String

    public init(_ error: Error) {
        #if canImport(DeckMateAPI)
        if let apiError = error as? APIError {
            self.message = Self.describe(apiError)
            return
        }
        #endif
        self.message = "\(error)"
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
}
