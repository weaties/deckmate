//
//  VideoDebugView.swift
//  DeckMate
//
//  Paste an arbitrary YouTube URL and try playback with each of the
//  embed strategies we know about. Used to diagnose which embed path
//  works for which videos.
//

import SwiftUI

/// A standalone debug screen for video playback. Paste a URL, pick
/// an embed strategy, see what the player does.
///
/// Kept in the app (not DeckMateKit) because it pulls in WebKit and
/// is a developer utility, not shipping feature surface.
struct VideoDebugView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var urlString: String = ""
    @State private var parsedInfo: ParsedInfo?
    @State private var attempt: PlaybackAttempt?

    private struct ParsedInfo {
        let url: URL
        let videoId: String?
    }

    private struct PlaybackAttempt: Identifiable {
        let id = UUID()
        let videoId: String
        let strategy: EmbedStrategy
    }

    enum EmbedStrategy: String, CaseIterable, Identifiable {
        /// HTML wrapper but baseURL points at youtube-nocookie.com and
        /// the iframe uses the nocookie embed host. The privacy-enhanced
        /// host has a different (more permissive) embed policy — works
        /// for Corvo 105's sailing videos where the regular host errored.
        /// This is the default strategy.
        case noCookieEmbed = "youtube-nocookie.com (default)"
        /// HTML wrapper around an iframe, baseURL = youtube.com,
        /// oembed-matched attributes. Previous default; fails on some
        /// account-specific restrictions.
        case wrappedIframe = "Wrapped iframe on youtube.com"
        /// Just load `youtube.com/embed/ID` directly in the WKWebView.
        case directEmbedURL = "Direct embed URL"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://www.youtube.com/watch?v=…", text: $urlString, axis: .vertical)
                        .autocorrectionDisabled()
                        .lineLimit(1...3)
                        #if os(iOS) || os(visionOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                        .onChange(of: urlString) { _, _ in parseURL() }
                } header: {
                    Text("YouTube URL")
                } footer: {
                    Text("Accepts youtube.com/watch?v=…, youtu.be/…, or youtube.com/embed/… forms.")
                }

                if let info = parsedInfo {
                    Section("Parsed") {
                        LabeledContent("URL", value: info.url.absoluteString)
                            .lineLimit(2)
                        LabeledContent("Video ID", value: info.videoId ?? "— (not a YouTube URL)")
                    }

                    if let id = info.videoId {
                        Section {
                            ForEach(EmbedStrategy.allCases) { strategy in
                                Button {
                                    attempt = PlaybackAttempt(videoId: id, strategy: strategy)
                                } label: {
                                    HStack {
                                        Text(strategy.rawValue)
                                        Spacer()
                                        Image(systemName: "play.circle")
                                    }
                                }
                            }
                        } header: {
                            Text("Try embed strategies")
                        } footer: {
                            Text("Each button opens a sheet using a different embed approach. The first that plays your video without a YouTube error is the winner.")
                        }

                        Section {
                            Link(destination: URL(string: "https://www.youtube.com/watch?v=\(id)")!) {
                                HStack {
                                    Text("Open on YouTube")
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                }
                            }
                        } footer: {
                            Text("Control — confirms the video plays outside the app.")
                        }
                    }
                }
            }
            .navigationTitle("Video Debug")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $attempt) { a in
                playbackSheet(for: a)
            }
        }
        .frame(minWidth: 480, minHeight: 480)
    }

    @ViewBuilder
    private func playbackSheet(for attempt: PlaybackAttempt) -> some View {
        NavigationStack {
            YouTubePlayerView(videoId: attempt.videoId, strategy: attempt.strategy)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(attempt.strategy.rawValue)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { self.attempt = nil }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Link(destination: URL(string: "https://www.youtube.com/watch?v=\(attempt.videoId)")!) {
                            Label("Open on YouTube", systemImage: "arrow.up.right.square")
                        }
                    }
                }
        }
        .frame(minWidth: 480, minHeight: 320)
    }

    private func parseURL() {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            parsedInfo = nil
            return
        }
        parsedInfo = ParsedInfo(url: url, videoId: youTubeVideoID(from: url))
    }
}

#Preview {
    VideoDebugView()
}
