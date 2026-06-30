import Foundation

/// A color for a single patch, expressed in HSB plus a derived RGBA so callers in either
/// SwiftUI (HSB-friendly) or UIKit/Core Graphics (RGBA-friendly) can render it. Values are
/// all in `0...1`. `PatchworkCore` deliberately imports no UI framework.
public struct PatchColor: Hashable, Sendable {
    public let hue: Double
    public let saturation: Double
    public let brightness: Double
    public let red: Double
    public let green: Double
    public let blue: Double

    init(hue: Double, saturation: Double, brightness: Double) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
        let (r, g, b) = PatchColor.hsbToRGB(h: hue, s: saturation, v: brightness)
        self.red = r
        self.green = g
        self.blue = b
    }

    static func hsbToRGB(h: Double, s: Double, v: Double) -> (Double, Double, Double) {
        guard s > 0 else { return (v, v, v) }
        let hh = (h.truncatingRemainder(dividingBy: 1.0) + 1.0).truncatingRemainder(dividingBy: 1.0) * 6.0
        let i = Int(hh)
        let f = hh - Double(i)
        let p = v * (1 - s)
        let q = v * (1 - s * f)
        let t = v * (1 - s * (1 - f))
        switch i % 6 {
        case 0: return (v, t, p)
        case 1: return (q, v, p)
        case 2: return (p, v, t)
        case 3: return (p, q, v)
        case 4: return (t, p, v)
        default: return (v, p, q)
        }
    }
}

/// Assigns each ZCTA a stable, pleasant fill color so the filled map reads like a quilt of
/// distinct patches. Colors are deterministic in the ZCTA index, so a given patch is always
/// the same color across launches and on the share card.
///
/// Hues are spread by the golden angle (≈137.5°), a low-discrepancy sequence that keeps
/// successive indices far apart on the color wheel and avoids long runs of similar hues.
/// Saturation/brightness alternate gently within tasteful bounds to add variety without
/// clashing, matching the warm, collectible feel of the Patchwork design system.
public enum PatchPalette {
    /// Golden-angle conjugate in turns (137.50776…° / 360°).
    private static let goldenRatioConjugate = 0.6180339887498949

    /// Returns the deterministic patch color for a ZCTA index.
    public static func color(for index: ZCTAIndex) -> PatchColor {
        let i = Double(max(0, index))
        // Golden-angle hue rotation.
        let hue = (i * goldenRatioConjugate).truncatingRemainder(dividingBy: 1.0)
        // Gentle 3-step cycles in saturation/brightness keep adjacent patches from looking
        // flat without ever going muddy or neon.
        let satSteps: [Double] = [0.62, 0.55, 0.70]
        let briSteps: [Double] = [0.92, 0.86, 0.80]
        let s = satSteps[index % satSteps.count]
        let b = briSteps[(index / satSteps.count) % briSteps.count]
        return PatchColor(hue: hue, saturation: s, brightness: b)
    }
}
