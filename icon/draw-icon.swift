// draw-icon.swift — renders a 1024x1024 "Magnetize" app icon (red horseshoe
// magnet on a dark rounded square) to a PNG using AppKit offscreen (no window
// server, no third-party tools).  Run:  swift draw-icon.swift <out.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/magnetize.png"

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
else { fatalError("could not create bitmap rep") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// --- background: rounded square with a subtle vertical gradient ---
let bgRect = NSRect(x: 0, y: 0, width: size, height: size)
let bg = NSBezierPath(roundedRect: bgRect, xRadius: 185, yRadius: 185)
NSGradient(starting: rgb(0.17, 0.20, 0.27), ending: rgb(0.09, 0.10, 0.14))!
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
rgb(0.85, 0.17, 0.19).setStroke()
u.stroke()

// --- silver pole tips ---
let tipH: CGFloat = 78
for px in [leftX, rightX] {
    rgb(0.84, 0.86, 0.90).setFill()
    NSBezierPath(rect: NSRect(x: px - w / 2, y: legBottom - tipH, width: w, height: tipH)).fill()
}

NSGraphicsContext.current?.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png encode") }
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
