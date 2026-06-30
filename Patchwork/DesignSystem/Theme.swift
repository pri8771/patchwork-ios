import SwiftUI
import PatchworkCore

/// Patchwork's design language — "a personal map quilt."
///
/// The patches are the hero, so the chrome stays calm: a warm paper field, soft ink text, and
/// one confident terracotta accent. Vibrant translucent patch colors (from `PatchPalette`)
/// supply all the color energy. Numerals use a rounded design because completion percentages
/// are the emotional payoff and rounded digits feel friendly and collectible.
enum Theme {

    // MARK: - Color

    enum Palette {
        /// Warm off-white "paper" page background.
        static let paper = Color(light: .init(red: 0.984, green: 0.973, blue: 0.953),
                                 dark: .init(red: 0.082, green: 0.075, blue: 0.059))
        /// Slightly raised surface for cards.
        static let surface = Color(light: .init(red: 1.0, green: 0.996, blue: 0.988),
                                   dark: .init(red: 0.137, green: 0.125, blue: 0.106))
        /// A second surface tone for nested fills.
        static let surfaceMuted = Color(light: .init(red: 0.957, green: 0.941, blue: 0.910),
                                        dark: .init(red: 0.180, green: 0.165, blue: 0.141))
        /// Primary ink for headlines/body.
        static let ink = Color(light: .init(red: 0.105, green: 0.094, blue: 0.078),
                               dark: .init(red: 0.965, green: 0.957, blue: 0.937))
        /// Secondary ink for supporting copy.
        static let inkSecondary = Color(light: .init(red: 0.357, green: 0.333, blue: 0.298),
                                        dark: .init(red: 0.702, green: 0.682, blue: 0.643))
        /// Tertiary ink for captions/footnotes.
        static let inkTertiary = Color(light: .init(red: 0.560, green: 0.533, blue: 0.490),
                                       dark: .init(red: 0.522, green: 0.502, blue: 0.467))
        /// Terracotta brand accent (also the asset-catalog AccentColor).
        static let accent = Color(light: .init(red: 0.886, green: 0.376, blue: 0.247),
                                  dark: .init(red: 0.945, green: 0.451, blue: 0.318))
        /// A warm amber used for highlights and milestone moments.
        static let amber = Color(light: .init(red: 0.945, green: 0.706, blue: 0.298),
                                 dark: .init(red: 0.965, green: 0.745, blue: 0.361))
        /// Sage green for "complete" affirmations (never red/failure — completion is positive).
        static let success = Color(light: .init(red: 0.353, green: 0.580, blue: 0.451),
                                   dark: .init(red: 0.451, green: 0.690, blue: 0.545))
        /// Hairline separators.
        static let hairline = Color(light: .init(red: 0.894, green: 0.875, blue: 0.835),
                                    dark: .init(red: 0.247, green: 0.227, blue: 0.196))
    }

    // MARK: - Typography

    enum Font {
        static func display(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .bold, design: .rounded)
        }
        static let largeTitle = SwiftUI.Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = SwiftUI.Font.system(size: 24, weight: .bold, design: .rounded)
        static let headline = SwiftUI.Font.system(size: 18, weight: .semibold, design: .rounded)
        static let body = SwiftUI.Font.system(size: 16, weight: .regular)
        static let callout = SwiftUI.Font.system(size: 15, weight: .medium)
        static let caption = SwiftUI.Font.system(size: 13, weight: .regular)
        static let stat = SwiftUI.Font.system(size: 30, weight: .heavy, design: .rounded)
        static let statSmall = SwiftUI.Font.system(size: 20, weight: .bold, design: .rounded)
    }

    // MARK: - Metrics

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 22
        static let pill: CGFloat = 999
    }
}

extension Color {
    /// Builds a dynamic color that adapts to light/dark appearance.
    init(light: Color, dark: Color) {
        self = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    /// Converts a `PatchworkCore.PatchColor` to a SwiftUI color at a given opacity.
    init(_ patch: PatchColor, opacity: Double = 1.0) {
        self = Color(hue: patch.hue, saturation: patch.saturation,
                     brightness: patch.brightness, opacity: opacity)
    }
}
