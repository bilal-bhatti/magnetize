// TorrentSource.swift — the three things Magnetize can hand to Transmission: a
// magnet link or an http(s) .torrent URL (both sent as a `filename`, which
// Transmission resolves itself), or a downloaded .torrent file (sent as base64
// `metainfo`, so it works even when Transmission runs on another host and can't
// see our local file).

import Foundation

enum TorrentSource {
    case magnet(Magnet)
    case url(URL)
    case file(name: String, data: Data)

    /// A human-friendly label for the menu, notifications, and recents.
    var displayName: String {
        switch self {
        case .magnet(let m): return m.displayName
        case .url(let u): return Self.name(fromTorrentURL: u)
        case .file(let name, _): return name
        }
    }

    /// The `arguments` dict for Transmission's `torrent-add`.
    var addArguments: [String: Any] {
        switch self {
        case .magnet(let m):
            return ["filename": m.url.absoluteString]
        case .url(let u):
            return ["filename": u.absoluteString]
        case .file(_, let data):
            return ["metainfo": data.base64EncodedString()]
        }
    }

    /// Recognizes a URL Magnetize can send: a magnet: link, or an http(s) URL
    /// pointing at a .torrent file. Returns nil for anything else.
    static func from(url: URL) -> TorrentSource? {
        switch url.scheme?.lowercased() {
        case "magnet":
            return .magnet(Magnet(url: url))
        case "http", "https":
            return url.pathExtension.lowercased() == "torrent" ? .url(url) : nil
        default:
            return nil
        }
    }

    /// Reads a .torrent file off disk. The display name is the file name with the
    /// `.torrent` extension stripped (e.g. `ubuntu-26.04.iso`).
    static func file(at url: URL) -> TorrentSource? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let name = url.deletingPathExtension().lastPathComponent
        return .file(name: name.isEmpty ? "torrent file" : name, data: data)
    }

    /// `ubuntu-26.04.iso` from `…/ubuntu-26.04.iso.torrent`.
    private static func name(fromTorrentURL url: URL) -> String {
        let stem = url.deletingPathExtension().lastPathComponent
        return stem.isEmpty ? "torrent link" : stem
    }
}
