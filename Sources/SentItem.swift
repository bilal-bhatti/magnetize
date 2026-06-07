// SentItem.swift — one row in the menu bar's "Recent" list.

import Foundation

struct SentItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let status: String
    let ok: Bool

    init(name: String, status: String, ok: Bool) {
        self.id = UUID()
        self.name = name
        self.status = status
        self.ok = ok
    }
}
