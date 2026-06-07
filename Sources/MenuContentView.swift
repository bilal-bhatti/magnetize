// MenuContentView.swift — the popover shown from the menu bar icon.

import SwiftUI
import AppKit

struct MenuContentView: View {
    @EnvironmentObject var state: AppState

    private var clipboardMagnet: URL? {
        guard let s = NSPasteboard.general.string(forType: .string),
              s.hasPrefix("magnet:"), let url = URL(string: s) else { return nil }
        return url
    }

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
            Spacer(minLength: 0)
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

    // MARK: - Actions

    private var actions: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let magnet = clipboardMagnet {
                MenuRow(title: "Send magnet from clipboard", systemImage: "doc.on.clipboard") {
                    state.handleIncoming(magnet)
                }
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
    let action: () -> Void
    @State private var hovering = false

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
            .foregroundStyle(hovering ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(hovering ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .onHover { hovering = $0 }
    }
}
