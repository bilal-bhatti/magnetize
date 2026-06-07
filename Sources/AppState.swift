// AppState.swift — the brain. Holds config (RPC URL in UserDefaults, credentials
// in the Keychain), drives the Transmission client, keeps a recent-sends list,
// and queues any magnet that arrives before the app is configured.

import SwiftUI
import AppKit

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    static let defaultRPC = "http://localhost:9091/transmission/rpc"

    // Config (password is mirrored in memory only for the settings form; the
    // Keychain is the source of truth and is written on Save).
    @Published var rpcURLString: String
    @Published var username: String
    @Published var password: String

    @Published var recents: [SentItem]
    @Published var lastStatus = "Ready"
    @Published var launchAtLogin: Bool

    private let client = TransmissionClient()
    private var pending: [URL] = []

    /// Only the RPC URL is required; credentials are optional (a server may run
    /// without RPC auth).
    var isConfigured: Bool {
        !rpcURLString.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Whether the user has entered any credential (used only to phrase 401s).
    private var hasCredentials: Bool {
        !username.isEmpty || !password.isEmpty
    }

    /// True until the user saves settings for the first time (no RPC URL stored).
    var isFirstRun: Bool {
        UserDefaults.standard.string(forKey: Keys.rpcURL) == nil
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Keys.rpcURL)
        rpcURLString = (saved?.isEmpty == false) ? saved! : AppState.defaultRPC

        if let creds = Keychain.load() {
            username = creds.username
            password = creds.password
        } else {
            username = ""
            password = ""
        }

        launchAtLogin = LoginItem.isEnabled
        recents = AppState.loadRecents()
    }

    // MARK: - Incoming magnets

    func handleIncoming(_ url: URL) {
        guard url.scheme?.lowercased() == "magnet" else { return }
        guard isConfigured else {
            pending.append(url)
            lastStatus = "Configure Magnetize, then it'll send."
            Notify.post("Magnetize", "Set your Transmission server to send this magnet.")
            openSettings()
            return
        }
        send(url)
    }

    private func send(_ url: URL) {
        guard let config = makeConfig() else {
            record(name: "magnet link", status: "Bad RPC URL", ok: false)
            return
        }
        let magnet = Magnet(url: url)
        lastStatus = "Sending \(magnet.displayName)…"
        Task {
            switch await client.add(magnet, config: config) {
            case .added(let n):
                record(name: n, status: "Sent", ok: true)
                Notify.post("Magnetize", "Sent: \(n)")
            case .duplicate(let n):
                record(name: n, status: "Already in Transmission", ok: true)
                Notify.post("Magnetize", "Already in Transmission: \(n)")
            case .authFailed:
                let status = hasCredentials ? "Wrong credentials" : "Server requires a login"
                record(name: magnet.displayName, status: status, ok: false)
                Notify.post("Magnetize", hasCredentials
                    ? "Wrong credentials — open Settings to fix."
                    : "This server requires a login — open Settings.")
                openSettings()
            case .failed(let msg):
                record(name: magnet.displayName, status: "Failed: \(msg)", ok: false)
                Notify.post("Magnetize", "Failed: \(msg)")
            }
        }
    }

    // MARK: - Settings actions

    func saveSettings() {
        UserDefaults.standard.set(rpcURLString, forKey: Keys.rpcURL)
        if hasCredentials {
            Keychain.save(.init(username: username, password: password))
        } else {
            Keychain.delete() // moved to a no-auth server: don't leave a stale entry
        }
        let queued = pending
        pending.removeAll()
        queued.forEach(send)
        lastStatus = queued.isEmpty ? "Settings saved"
            : "Settings saved — sending \(queued.count) queued magnet\(queued.count == 1 ? "" : "s")"
    }

    func testConnection() {
        guard let config = makeConfig() else { lastStatus = "Bad RPC URL"; return }
        lastStatus = "Testing…"
        Task {
            switch await client.test(config) {
            case .ok:         lastStatus = "Connected ✓"
            case .authFailed: lastStatus = hasCredentials
                ? "Wrong username or password"
                : "This server requires a username and password"
            case .failed(let m): lastStatus = "Failed: \(m)"
            }
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        LoginItem.set(on)
        launchAtLogin = LoginItem.isEnabled
    }

    func openTransmissionWeb() {
        // http://host:9091/transmission/rpc  ->  http://host:9091/transmission/web/
        var target = rpcURLString
        if let range = target.range(of: "/rpc") {
            target = String(target[..<range.lowerBound]) + "/web/"
        }
        if let url = URL(string: target) { NSWorkspace.shared.open(url) }
    }

    private var settingsWindow: NSWindow?

    func openSettings() {
        // SwiftUI's Settings scene + showSettingsWindow: is unreliable for a
        // menu bar agent app, so we own the window directly.
        NSApp.activate(ignoringOtherApps: true)
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView().environmentObject(self))
            let win = NSWindow(contentViewController: hosting)
            win.title = "Magnetize Settings"
            win.styleMask = [.titled, .closable]
            win.isReleasedWhenClosed = false
            win.center()
            settingsWindow = win
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.orderFrontRegardless()
    }

    // MARK: - Helpers

    private func makeConfig() -> TransmissionClient.Config? {
        let trimmed = rpcURLString.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed) else { return nil }
        return .init(rpcURL: url, username: username, password: password)
    }

    private func record(name: String, status: String, ok: Bool) {
        lastStatus = status
        recents.insert(SentItem(name: name, status: status, ok: ok), at: 0)
        if recents.count > 20 { recents.removeLast(recents.count - 20) }
        AppState.saveRecents(recents)
    }

    // MARK: - Persistence

    private enum Keys {
        static let rpcURL = "rpcURL"
        static let recents = "recents"
    }

    private static func loadRecents() -> [SentItem] {
        guard let data = UserDefaults.standard.data(forKey: Keys.recents),
              let items = try? JSONDecoder().decode([SentItem].self, from: data)
        else { return [] }
        return items
    }

    private static func saveRecents(_ items: [SentItem]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Keys.recents)
        }
    }
}
