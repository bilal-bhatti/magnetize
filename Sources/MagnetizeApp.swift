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

    // .torrent files opened with Magnetize arrive as an OpenDocuments Apple Event,
    // which AppKit routes here — separate from our GetURL handler above, so the
    // two don't collide.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.isFileURL {
            Task { @MainActor in AppState.shared.handleTorrentFile(url) }
        }
    }
}

@main
struct MagnetizeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(state)
        } label: {
            // SwiftUI ignores .font() on a MenuBarExtra label, so size the glyph
            // via an NSImage symbol configuration and let it render as a template.
            Image(nsImage: Self.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }

    /// The menu bar glyph at a larger point size than the SwiftUI default.
    /// Template-rendered so macOS tints it for light/dark menu bars.
    private static let menuBarIcon: NSImage = {
        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        let image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Magnetize")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image ?? NSImage()
    }()
}
