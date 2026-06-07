// Magnet.swift — a thin reader over a magnet: URL for a human-friendly name.

import Foundation

struct Magnet {
    let url: URL

    private var queryItems: [URLQueryItem] {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }

    /// `dn` (display name) if present, else the info hash, else a generic label.
    var displayName: String {
        if let dn = queryItems.first(where: { $0.name == "dn" })?.value, !dn.isEmpty {
            return dn
        }
        if let hash = infoHash { return hash }
        return "magnet link"
    }

    /// The btih info hash from `xt=urn:btih:<hash>`, if any.
    var infoHash: String? {
        guard let xt = queryItems.first(where: { $0.name == "xt" })?.value else { return nil }
        return xt.split(separator: ":").last.map(String.init)
    }
}
