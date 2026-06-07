// MenuBarIcon.swift — the menu bar glyph. There's no magnet SF Symbol, so we
// draw the app icon's horseshoe "U" ourselves as a monochrome template image.
// (The app icon is a separate, richer artifact — a colored .icns rendered ahead
// of time by icon/draw-icon.swift; see the README for why they differ.)

import AppKit

enum MenuBarIcon {
    /// A horseshoe magnet ("U", arc over the top — same orientation as the app
    /// icon) drawn as a stroked outline. Template-rendered so macOS tints it for
    /// light/dark menu bars and highlights.
    static let image: NSImage = {
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
