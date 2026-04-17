//
//  SettingsView.swift
//  DeckMate
//

import SwiftUI
import DeckMateKit

struct SettingsView: View {
    @Environment(ServerConfiguration.self) private var config
    @Environment(\.dismiss) private var dismiss

    @State private var urlString: String = ""
    @State private var token: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://corvopi-tst1:3002", text: $urlString)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        #if os(iOS) || os(visionOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                } header: {
                    Text("Server URL")
                } footer: {
                    Text("The HelmLog server's base URL. Private-network hosts like Tailscale MagicDNS names are supported.")
                }

                Section {
                    TextField("Bearer token", text: $token)
                        .autocorrectionDisabled()
                        #if os(iOS) || os(visionOS)
                        .textInputAutocapitalization(.never)
                        #endif
                } header: {
                    Text("Device API Key")
                } footer: {
                    Text("Generate a device API key in the HelmLog admin console (Users → Devices) with the 'viewer' role. Paste it here — it will be stored in the Keychain.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                if config.currentServer != nil {
                    Section {
                        Button("Clear configuration", role: .destructive) {
                            clear()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(urlString.isEmpty || token.isEmpty || isSaving)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                urlString = config.currentServer?.baseURL.absoluteString ?? ""
            }
        }
    }

    private func save() {
        errorMessage = nil
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme != nil, url.host != nil
        else {
            errorMessage = "That doesn't look like a valid URL."
            return
        }
        isSaving = true
        Task {
            do {
                try await config.save(url: url, bearerToken: token)
                dismiss()
            } catch {
                errorMessage = "Couldn't save: \(error)"
            }
            isSaving = false
        }
    }

    private func clear() {
        Task {
            try? await config.clear()
            urlString = ""
            token = ""
        }
    }
}

#Preview {
    SettingsView()
        .environment(ServerConfiguration())
}
