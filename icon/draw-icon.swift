// draw-icon.swift — renders a 1024x1024 "Magnetize" app icon (red horseshoe
// magnet on a dark rounded square) to a PNG using AppKit offscreen (no window
// server, no third-party tools).  Run:  swift draw-icon.swift <out.png>
//
// Styled after Apple's "Liquid Glass" look: a translucent gloss sheen over the
// tile, a depth shadow + vertical gradient on the magnet, a specular highlight
// across its top, and glassy gradient pole tips.
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/magnetize.png"

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
}
func white(_ a: CGFloat) -> NSColor { NSColor(calibratedWhite: 1, alpha: a) }

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
else { fatalError("could not create bitmap rep") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// --- background: rounded square with a subtle vertical gradient ---
let bgRect = NSRect(x: 0, y: 0, width: size, height: size)
let bg = NSBezierPath(roundedRect: bgRect, xRadius: 230, yRadius: 230)
NSGradient(starting: rgb(0.19, 0.22, 0.30), ending: rgb(0.08, 0.09, 0.13))!
    .draw(in: bg, angle: -90)

// --- horseshoe magnet (U shape) ---
let cx = size / 2
let r: CGFloat = 112          // arc radius = half the gap between the legs
let leftX = cx - r            // 400
let rightX = cx + r           // 624
let legBottom: CGFloat = 282    // shifted up 32 so the magnet's bbox centers vertically
let curveY: CGFloat = 632
let w: CGFloat = 150          // stroke thickness

let u = NSBezierPath()
u.move(to: NSPoint(x: leftX, y: legBottom))
u.line(to: NSPoint(x: leftX, y: curveY))
u.appendArc(withCenter: NSPoint(x: cx, y: curveY), radius: r,
            startAngle: 180, endAngle: 0, clockwise: true)   // over the top
u.line(to: NSPoint(x: rightX, y: legBottom))
u.lineWidth = w
u.lineCapStyle = .butt        // flat ends for the poles

// Solid outline of the stroked U, so we can fill it with a gradient and clip
// gloss highlights to its exact shape.
let magnet = NSBezierPath(cgPath: u.cgPath.copy(
    strokingWithWidth: w, lineCap: .butt, lineJoin: .miter, miterLimit: 10))

// --- depth shadow cast by the magnet, then its glassy red body ---
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowOffset = NSSize(width: 0, height: -18)
shadow.shadowBlurRadius = 36
shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.45)
shadow.set()
NSGradient(starting: rgb(0.70, 0.10, 0.13), ending: rgb(0.93, 0.27, 0.30))!
    .draw(in: magnet, angle: 90)   // deeper red at the bottom, brighter on top
NSGraphicsContext.restoreGraphicsState()

// --- specular gloss: a soft sheen clipped to the upper half of the magnet ---
NSGraphicsContext.saveGraphicsState()
magnet.addClip()
NSGradient(starting: white(0), ending: white(0.34))!
    .draw(in: NSRect(x: 0, y: curveY - 40, width: size, height: r + w / 2 + 40), angle: 90)
// crisp rim light along the very top of the arc
let rim = NSBezierPath()
rim.appendArc(withCenter: NSPoint(x: cx, y: curveY), radius: r + w / 2 - 10,
              startAngle: 150, endAngle: 30, clockwise: true)
rim.lineWidth = 10
white(0.55).setStroke()
rim.stroke()
NSGraphicsContext.restoreGraphicsState()

// --- glassy silver pole tips ---
let tipH: CGFloat = 78
for px in [leftX, rightX] {
    let tip = NSRect(x: px - w / 2, y: legBottom - tipH, width: w, height: tipH)
    NSGradient(starting: rgb(0.70, 0.73, 0.79), ending: rgb(0.93, 0.95, 0.98))!
        .draw(in: NSBezierPath(rect: tip), angle: 90)
    // thin highlight band near the top edge of the tip
    white(0.6).setFill()
    NSBezierPath(rect: NSRect(x: tip.minX, y: tip.maxY - 10, width: tip.width, height: 8)).fill()
}

// --- overall glass sheen: a broad soft highlight sweeping the top of the tile ---
NSGraphicsContext.saveGraphicsState()
bg.addClip()
NSGradient(starting: white(0.16), ending: white(0))!
    .draw(in: NSRect(x: 0, y: size * 0.52, width: size, height: size * 0.48), angle: -90)
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.current?.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png encode") }
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
