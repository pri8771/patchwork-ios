// Generates the Patchwork app icon (1024×1024 PNG) using CoreGraphics.
// A warm "paper" field with a quilt of translucent colored patches and one filled hero patch,
// matching the in-app design language. Run: swift Tools/make_icon.swift <output.png>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let path = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Patchwork/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("ctx")
}

func goldenHSB(_ i: Int) -> (Double, Double, Double) {
    let phi = 0.6180339887498949
    let hue = (Double(i) * phi).truncatingRemainder(dividingBy: 1.0)
    let sats = [0.62, 0.55, 0.70]
    let bris = [0.95, 0.90, 0.85]
    return (hue, sats[i % 3], bris[(i / 3) % 3])
}
func hsb(_ h: Double, _ s: Double, _ b: Double, _ a: Double) -> CGColor {
    let hh = h * 6, i = Int(hh), f = hh - Double(i)
    let p = b * (1 - s), q = b * (1 - s * f), t = b * (1 - s * (1 - f))
    let (r, g, bl): (Double, Double, Double)
    switch i % 6 {
    case 0: (r, g, bl) = (b, t, p)
    case 1: (r, g, bl) = (q, b, p)
    case 2: (r, g, bl) = (p, b, t)
    case 3: (r, g, bl) = (p, q, b)
    case 4: (r, g, bl) = (t, p, b)
    default: (r, g, bl) = (b, p, q)
    }
    return CGColor(colorSpace: cs, components: [CGFloat(r), CGFloat(g), CGFloat(bl), CGFloat(a)])!
}

// Background: warm paper.
ctx.setFillColor(CGColor(colorSpace: cs, components: [0.984, 0.973, 0.953, 1])!)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Quilt grid of patches with rounded squares; a diagonal band is "filled" (opaque).
let cols = 5, rows = 5
let margin = 96.0
let gap = 26.0
let cell = (Double(size) - margin * 2 - gap * Double(cols - 1)) / Double(cols)
var idx = 7
for r in 0..<rows {
    for c in 0..<cols {
        let x = margin + Double(c) * (cell + gap)
        let y = margin + Double(r) * (cell + gap)
        let rect = CGRect(x: x, y: y, width: cell, height: cell)
        let rounded = CGPath(roundedRect: rect, cornerWidth: 26, cornerHeight: 26, transform: nil)
        let (h, s, b) = goldenHSB(idx)
        // Filled hero patches along the anti-diagonal; others translucent outlines/fills.
        let filled = (r + c) % 2 == 0
        ctx.addPath(rounded)
        ctx.setFillColor(hsb(h, s, b, filled ? 0.95 : 0.32))
        ctx.fillPath()
        if !filled {
            ctx.addPath(rounded)
            ctx.setStrokeColor(hsb(h, s, b * 0.8, 0.85))
            ctx.setLineWidth(8)
            ctx.strokePath()
        }
        idx += 3
    }
}

guard let image = ctx.makeImage() else { fatalError("image") }
let url = URL(fileURLWithPath: path)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("dest")
}
CGImageDestinationAddImage(dest, image, nil)
if CGImageDestinationFinalize(dest) {
    print("Wrote \(path)")
} else {
    fatalError("finalize")
}
