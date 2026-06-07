// Notifications.swift — result alerts. Prefers the native UserNotifications
// framework; if the user hasn't granted permission (or it's an ad-hoc build the
// system won't badge), it falls back to `osascript display notification`.

import Foundation
import UserNotifications

enum Notify {
    static func requestAuth() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func post(_ title: String, _ body: String) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                center.add(UNNotificationRequest(identifier: UUID().uuidString,
                                                 content: content, trigger: nil))
            default:
                fallback(title: title, body: body)
            }
        }
    }

    private static func fallback(title: String, body: String) {
        let script = "display notification \(quote(body)) with title \(quote(title))"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        try? task.run()
    }

    /// AppleScript string literal: wrap in quotes, escape backslashes and quotes.
    private static func quote(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
