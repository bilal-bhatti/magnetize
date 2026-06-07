// MenuContentView.swift — the popover shown from the menu bar icon.

import SwiftUI
import AppKit

struct MenuContentView: View {
    @EnvironmentObject var state: AppState

    /// A magnet link or http(s) .torrent URL sitting on the clipboard, if any.
    /// Read live (not as a computed property) so it refreshes every time the
    /// popover opens and while it's open — SwiftUI won't re-poll the pasteboard
    /// on its own since it isn't observable state.
    @State private var clipboardURL: URL?
    @State private var clipboardChangeCount = -1

    private let clipboardPoll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let statsPoll = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.vertical, 4)
            recentsSection
            Divider().padding(.vertical, 4)
            actions
        }
        .padding(.vertical, 6)
        .frame(width: 300)
        .onAppear {
            refreshClipboard()
            state.refreshStats()
        }
        .onReceive(clipboardPoll) { _ in refreshClipboard() }
        .onReceive(statsPoll) { _ in state.refreshStats() }
    }

    /// Re-reads the pasteboard, but only does the parsing work when its contents
    /// actually changed (cheap changeCount comparison otherwise).
    private func refreshClipboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != clipboardChangeCount else { return }
        clipboardChangeCount = pb.changeCount
        if let s = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: s), TorrentSource.from(url: url) != nil {
            clipboardURL = url
        } else {
            clipboardURL = nil
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(state.isConfigured ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text("Magnetize").font(.system(size: 13, weight: .semibold))
                Text(state.lastStatus)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 6)
            if let counts = state.counts {
                CountStrip(counts: counts)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
    }

    // MARK: - Recents

    @ViewBuilder
    private var recentsSection: some View {
        if state.recents.isEmpty {
            Text("No magnets sent yet")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
        } else {
            SectionLabel("Recent")
            ForEach(state.recents.prefix(6)) { RecentRow(item: $0) }
        }
    }

    /// Label for the clipboard row — reflects what's on the clipboard, or stays
    /// generic (and the row is disabled) when there's nothing to send.
    private var clipboardLabel: String {
        guard let url = clipboardURL else { return "Send from clipboard" }
        return url.scheme?.lowercased() == "magnet"
            ? "Send magnet from clipboard" : "Send torrent from clipboard"
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(alignment: .leading, spacing: 1) {
            MenuRow(title: clipboardLabel, systemImage: "doc.on.clipboard",
                    enabled: clipboardURL != nil) {
                if let url = clipboardURL { state.handleIncoming(url) }
            }
            MenuRow(title: "Test connection", systemImage: "bolt.horizontal") {
                state.testConnection()
            }
            MenuRow(title: "Open Transmission web UI", systemImage: "safari") {
                state.openTransmissionWeb()
            }
            MenuRow(title: "Settings…", systemImage: "gearshape") {
                state.openSettings()
            }
            Divider().padding(.horizontal, 10).padding(.vertical, 4)
            MenuRow(title: "Quit Magnetize", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

// MARK: - Building blocks

/// Compact downloading / paused / complete counter for the header. Each glyph
/// stays put so the numbers don't jump around as they update.
private struct CountStrip: View {
    let counts: TorrentCounts

    var body: some View {
        HStack(spacing: 7) {
            stat("arrow.down", counts.downloading)
            stat("pause", counts.paused)
            stat("checkmark", counts.complete)
            stat("exclamationmark.triangle", counts.failed, alert: true)
        }
        .help("Downloading · Paused · Complete · Failed")
    }

    private func stat(_ symbol: String, _ n: Int, alert: Bool = false) -> some View {
        HStack(spacing: 2) {
            Image(systemName: symbol).font(.system(size: 9, weight: .semibold))
            Text("\(n)").font(.system(size: 11).monospacedDigit())
        }
        .foregroundStyle(
            n == 0 ? AnyShapeStyle(.tertiary)
                   : alert ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary)
        )
    }
}

/// Small uppercase section heading aligned to the row text column.
private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 2)
            .padding(.bottom, 3)
    }
}

/// One recent-send row: status glyph, name + detail, relative time.
private struct RecentRow: View {
    let item: SentItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(item.ok ? Color.green : Color.red)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.status)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(Self.relative(item.date))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
    }

    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
    private static func relative(_ date: Date) -> String {
        formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// A full-width menu row with an aligned icon column and a hover highlight.
private struct MenuRow: View {
    let title: String
    let systemImage: String
    var enabled: Bool = true
    let action: () -> Void
    @State private var hovering = false

    private var foreground: AnyShapeStyle {
        if !enabled { return AnyShapeStyle(.tertiary) }
        return hovering ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.primary)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13))
                    .frame(width: 18, alignment: .center)
                Text(title).font(.system(size: 13))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .foregroundStyle(foreground)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(hovering && enabled ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.horizontal, 6)
        .onHover { hovering = enabled && $0 }
    }
}
