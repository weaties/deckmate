//
//  VideoPlayerView.swift
//  DeckMate
//
//  In-app video playback via YouTube's iframe embed, wrapped in a
//  WKWebView. Exposes several embed strategies so VideoDebugView can
//  test which one works for a given video.
//

import SwiftUI
import WebKit

/// Presents a YouTube video inline using the iframe embed API.
struct YouTubePlayerView: View {
    let videoId: String
    let strategy: VideoDebugView.EmbedStrategy

    init(videoId: String, strategy: VideoDebugView.EmbedStrategy = .noCookieEmbed) {
        self.videoId = videoId
        self.strategy = strategy
    }

    var body: some View {
        WebViewContainer(videoId: videoId, strategy: strategy)
            .ignoresSafeArea(edges: .bottom)
    }
}

/// Extract a YouTube video ID from the common URL forms helmlog records:
///   https://www.youtube.com/watch?v=ID
///   https://youtu.be/ID
///   https://www.youtube.com/embed/ID
///   plus any trailing `&t=...` / `&feature=...` query noise.
/// Returns `nil` for non-YouTube URLs.
func youTubeVideoID(from url: URL) -> String? {
    guard let host = url.host?.lowercased() else { return nil }
    if host == "youtu.be" || host.hasSuffix(".youtu.be") {
        let id = url.path.dropFirst()  // strip leading "/"
        return id.isEmpty ? nil : String(id)
    }
    guard host == "youtube.com" || host.hasSuffix(".youtube.com") else { return nil }
    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
       let v = components.queryItems?.first(where: { $0.name == "v" })?.value,
       !v.isEmpty {
        return v
    }
    let segments = url.path.split(separator: "/")
    if segments.count >= 2, segments[0] == "embed" {
        return String(segments[1])
    }
    return nil
}

// MARK: - Embed payloads

/// Build the `(url, html?)` pair the WebView should load for a given
/// strategy. When `html` is nil, the container navigates to `url`
/// directly; otherwise it loads the HTML string with `url` as the
/// baseURL. Extracted so a single webview type can handle every
/// strategy without branching logic leaking into representables.
fileprivate struct EmbedPayload {
    let html: String?
    let url: URL
}

fileprivate func embedPayload(
    videoId: String,
    strategy: VideoDebugView.EmbedStrategy
) -> EmbedPayload {
    switch strategy {
    case .wrappedIframe:
        return .init(
            html: wrappedIframeHTML(host: "https://www.youtube.com", videoId: videoId),
            url: URL(string: "https://www.youtube.com")!
        )
    case .directEmbedURL:
        return .init(
            html: nil,
            url: URL(string: "https://www.youtube.com/embed/\(videoId)?playsinline=1&rel=0&modestbranding=1")!
        )
    case .noCookieEmbed:
        return .init(
            html: wrappedIframeHTML(host: "https://www.youtube-nocookie.com", videoId: videoId),
            url: URL(string: "https://www.youtube-nocookie.com")!
        )
    }
}

private func wrappedIframeHTML(host: String, videoId: String) -> String {
    // `allow` list, `referrerpolicy`, and `feature=oembed` match what
    // YouTube's own oembed API hands back — needed for playback of
    // 360° / spherical videos and some restricted-ish uploads.
    """
    <!DOCTYPE html>
    <html>
    <head>
    <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
    <style>
    html, body { margin: 0; padding: 0; height: 100%; background: black; overflow: hidden; }
    .wrap { position: relative; width: 100%; height: 100%; }
    iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: 0; }
    </style>
    </head>
    <body>
    <div class="wrap">
    <iframe
        src="\(host)/embed/\(videoId)?feature=oembed&playsinline=1&rel=0&modestbranding=1"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
        referrerpolicy="strict-origin-when-cross-origin"
        allowfullscreen>
    </iframe>
    </div>
    </body>
    </html>
    """
}

// MARK: - Cross-platform WKWebView wrapper

#if os(iOS) || os(visionOS)
private struct WebViewContainer: UIViewRepresentable {
    let videoId: String
    let strategy: VideoDebugView.EmbedStrategy

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let key = "\(strategy.rawValue)|\(videoId)"
        guard context.coordinator.loadedKey != key else { return }
        context.coordinator.loadedKey = key
        let payload = embedPayload(videoId: videoId, strategy: strategy)
        if let html = payload.html {
            webView.loadHTMLString(html, baseURL: payload.url)
        } else {
            webView.load(URLRequest(url: payload.url))
        }
    }

    final class Coordinator {
        var loadedKey: String?
    }
}
#elseif os(macOS)
private struct WebViewContainer: NSViewRepresentable {
    let videoId: String
    let strategy: VideoDebugView.EmbedStrategy

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let key = "\(strategy.rawValue)|\(videoId)"
        guard context.coordinator.loadedKey != key else { return }
        context.coordinator.loadedKey = key
        let payload = embedPayload(videoId: videoId, strategy: strategy)
        if let html = payload.html {
            webView.loadHTMLString(html, baseURL: payload.url)
        } else {
            webView.load(URLRequest(url: payload.url))
        }
    }

    final class Coordinator {
        var loadedKey: String?
    }
}
#endif

#Preview {
    NavigationStack {
        YouTubePlayerView(videoId: "dQw4w9WgXcQ")
            .navigationTitle("Video")
    }
}
