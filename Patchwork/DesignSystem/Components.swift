import SwiftUI
import PatchworkCore

// MARK: - Surfaces

/// A soft, rounded content card on the paper field.
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.Spacing.l
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: 1)
            )
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isLoading: Bool = false
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                if isLoading {
                    ProgressView().tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title).font(Theme.Font.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.l)
            .foregroundStyle(.white)
            .background(Theme.Palette.accent.opacity(enabled ? 1 : 0.4))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled || isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(Theme.Font.callout)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.m)
            .foregroundStyle(Theme.Palette.ink)
            .background(Theme.Palette.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Subtle press feedback used across tappable surfaces.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Progress

/// A circular completion ring with a centered percentage.
struct ProgressRing: View {
    var progress: Double            // 0...1
    var size: CGFloat = 120
    var lineWidth: CGFloat = 12
    var tint: Color = Theme.Palette.accent
    var label: String? = nil

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Palette.surfaceMuted, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            VStack(spacing: 0) {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(Theme.Font.display(size * 0.26))
                    .foregroundStyle(Theme.Palette.ink)
                if let label {
                    Text(label)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

/// A horizontal completion bar.
struct ProgressBar: View {
    var progress: Double
    var tint: Color = Theme.Palette.accent
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.surfaceMuted)
                Capsule().fill(tint)
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Stats & labels

/// A headline number with a caption, used in stat rows.
struct StatTile: View {
    let value: String
    let caption: String
    var tint: Color = Theme.Palette.ink

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(value).font(Theme.Font.stat).foregroundStyle(tint)
            Text(caption).font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil

    var body: some View {
        HStack {
            Text(title).font(Theme.Font.headline).foregroundStyle(Theme.Palette.ink)
            Spacer()
            if let action, let actionTitle {
                Button(actionTitle, action: action)
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Palette.accent)
            }
        }
    }
}

/// A small rounded tag.
struct Pill: View {
    let text: String
    var color: Color = Theme.Palette.accent

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.xs)
            .foregroundStyle(color)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }
}

/// A small colored quilt swatch for a patch/region.
struct PatchSwatch: View {
    let patchColor: PatchColor
    var filled: Bool = true
    var size: CGFloat = 28

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(Color(patchColor, opacity: filled ? 0.9 : 0.18))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(Color(patchColor, opacity: filled ? 0 : 0.7), lineWidth: 1.5)
            )
            .frame(width: size, height: size)
    }
}
