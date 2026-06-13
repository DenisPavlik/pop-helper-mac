import SwiftUI
import AppKit

@main
struct PoPHelperApp: App {
    @StateObject private var app = AppState()

    init() {
        // When launched via `swift run` (no .app bundle) the process starts as a
        // background agent; promote it so the window shows and gets focus.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("PoP Helper") {
            ContentView()
                .environmentObject(app)
        }
        .windowResizability(.contentMinSize)
    }
}
