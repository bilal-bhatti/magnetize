// Notifications.swift — result alerts via the native UserNotifications
// framework. Posting asks for permission the first time if it hasn't been
// decided yet; once the user denies, the system suppresses delivery and there's
// nothing more we can do.

import Foundation
import UserNotifications
import os

enum Notify {
    private static let log = Logger(subsystem: "com.local.magnetize", category: "notifications")

    static func requestAuth() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// True when delivery is blocked (`.denied`) — used to surface a hint in the
    /// popover. Delivered on the main actor.
    static func isBlocked(_ completion: @escaping @Sendable (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let blocked = settings.authorizationStatus == .denied
            DispatchQueue.main.async { completion(blocked) }
        }
    }

    static func post(_ title: String, _ body: String) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                deliver(title: title, body: body)
            case .notDetermined:
                // First send before the launch prompt resolved — ask, then post.
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { deliver(title: title, body: body) }
                    else { log.warning("Notification permission not granted; \"\(title, privacy: .public)\" not shown") }
                }
            default:
                // denied/restricted — the system won't deliver regardless.
                log.warning("Notifications denied; \"\(title, privacy: .public)\" not shown. Enable in System Settings.")
            }
        }
    }

    private static func deliver(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
