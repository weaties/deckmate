//
//  DeckMateApp.swift
//  DeckMate
//
//  Created by Dan Weatbrook on 4/17/26.
//

import SwiftUI
import DeckMateKit

@main
struct DeckMateApp: App {
    @State private var config = ServerConfiguration()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(config)
        }
    }
}
