import SwiftUI
import AppKit

@main
struct PoPHelperApp: App {
    @StateObject private var app = AppState()

    init() {
        // Headless self-test path (no Xcode/XCTest needed): `swift run PoPHelper --self-test`.
        if CommandLine.arguments.contains("--self-test") {
            exit(SelfTest.run() ? 0 : 1)
        }
        if CommandLine.arguments.contains("--status") {
            exit(CLI.statusReport() ? 0 : 1)
        }
        if CommandLine.arguments.contains("--verify-apply") {
            exit(CLI.verifyApply() ? 0 : 1)
        }
        if CommandLine.arguments.contains("--verify-packs") {
            exit(CLI.verifyPacks() ? 0 : 1)
        }
        // Apply a comma-separated set of tweak ids to the live mod (load-test loop).
        if let i = CommandLine.arguments.firstIndex(of: "--apply"), i + 1 < CommandLine.arguments.count {
            let ids = CommandLine.arguments[i + 1].split(separator: ",").map(String.init)
            exit(CLI.applyTweaks(ids: ids))
        }
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
