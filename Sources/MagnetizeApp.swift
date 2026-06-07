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
            // No SF Symbol for a magnet, so we draw the app icon's horseshoe "U"
            // ourselves as a monochrome template (macOS tints it to the menu bar).
            Image(nsImage: Self.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }

    /// A horseshoe magnet ("U", arc over the top — same orientation as the app
    /// icon) drawn as a stroked outline. Template-rendered so macOS tints it for
    /// light/dark menu bars and highlights.
    private static let menuBarIcon: NSImage = {
        let w: CGFloat = 15, h: CGFloat = 18
        let image = NSImage(size: NSSize(width: w, height: h), flipped: false) { _ in
            let lw: CGFloat = 2.4          // stroke weight
            let pad: CGFloat = 1.5         // breathing room inside the bounds
            let xL = pad + lw / 2          // centerline of the left leg
            let xR = w - pad - lw / 2      // …and the right leg
            let cx = (xL + xR) / 2
            let r = (xR - xL) / 2          // arc radius = half the gap between legs
            let topY = h - pad - r - lw / 2
            let bottomY = pad + lw / 2

            let u = NSBezierPath()
            u.move(to: NSPoint(x: xL, y: bottomY))
            u.line(to: NSPoint(x: xL, y: topY))
            u.appendArc(withCenter: NSPoint(x: cx, y: topY), radius: r,
                        startAngle: 180, endAngle: 0, clockwise: true)   // over the top
            u.line(to: NSPoint(x: xR, y: bottomY))
            u.lineWidth = lw
            u.lineCapStyle = .butt          // flat pole ends
            NSColor.black.setStroke()
            u.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
