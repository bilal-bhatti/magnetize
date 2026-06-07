// MagnetizeApp.swift — entry point. A menu bar (LSUIElement) SwiftUI app that
// registers as the magnet: handler. macOS delivers a magnet click as a GURL
// Apple Event; we catch it in the AppDelegate and hand it to AppState.

import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Take over the GetURL Apple Event so magnet: clicks land here even when
        // the app was launched *by* the click. Installing our own handler also
        // means AppKit won't separately call the openURLs delegate (no dupes).
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Notify.requestAuth()
        // First run (settings never saved): open Settings so there's somewhere to
        // put the server details, rather than silently defaulting to localhost.
        if AppState.shared.isFirstRun {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                AppState.shared.openSettings()
            }
        }
    }

    @objc func handleGetURL(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let raw = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: raw) else { return }
        Task { @MainActor in AppState.shared.handleIncoming(url) }
    }
}

@main
struct MagnetizeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra("Magnetize", systemImage: "arrow.down.circle") {
            MenuContentView()
                .environmentObject(state)
        }
        .menuBarExtraStyle(.window)
    }
}
