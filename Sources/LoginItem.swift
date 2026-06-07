// LoginItem.swift — "Launch at login" via the modern SMAppService API (macOS 13+).
// No helper bundle or login-items plist needed; the main app registers itself.

import Foundation
import ServiceManagement

enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else       { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Magnetize: login item toggle failed: \(error.localizedDescription)")
        }
    }
}
