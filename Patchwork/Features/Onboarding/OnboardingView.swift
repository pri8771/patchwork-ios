import SwiftUI

/// First-run flow. Sells the idea, then — before any system dialog — explains exactly what's
/// collected, why, and that everything stays on device (locked decision #10 trust posture).
struct OnboardingView: View {
    var onFinish: () -> Void
    @EnvironmentObject private var location: LocationService
    @State private var page = 0

    private let pages = OnboardingPage.all

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    OnboardingPageView(page: pages[i]).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            PageDots(count: pages.count, index: page)
                .padding(.bottom, Theme.Spacing.l)

            VStack(spacing: Theme.Spacing.m) {
                PrimaryButton(title: page == pages.count - 1 ? "Start coloring" : "Continue") {
                    advance()
                }
                if page == pages.count - 1 {
                    Text("You can turn location on later, in Settings.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.inkTertiary)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Palette.paper.ignoresSafeArea())
    }

    private func advance() {
        if page < pages.count - 1 {
            withAnimation { page += 1 }
        } else {
            Task {
                // Prime When-In-Use right as the user opts in, after they've seen the education page.
                _ = await location.requestWhenInUseAuthorization()
                onFinish()
            }
        }
    }
}

struct OnboardingPage {
    let icon: String
    let tint: Color
    let title: String
    let body: String
    let footnote: String?

    static let all: [OnboardingPage] = [
        OnboardingPage(
            icon: "map.fill", tint: Theme.Palette.accent,
            title: "Color the map you actually live",
            body: "Every postal area you walk into becomes a colored patch. Fill in your neighborhood, your city, your state — one place at a time.",
            footnote: nil),
        OnboardingPage(
            icon: "hand.tap.fill", tint: Theme.Palette.amber,
            title: "Tap to claim where you are",
            body: "Stand somewhere new and tap “Claim Current Patch.” Patchwork colors in the ZIP-like area you’re standing in and rolls it up into your city, county, and state.",
            footnote: "“ZIP-like patches” are Census ZCTA areas — close to mailing ZIP Codes, but not official USPS ZIP coverage."),
        OnboardingPage(
            icon: "lock.fill", tint: Theme.Palette.success,
            title: "Private by design",
            body: "Your location is used only when you tap to claim, and only to figure out which patch you’re in. It’s processed and stored entirely on this device — no account, no servers, nothing uploaded.",
            footnote: "No backend · No tracking · No ads · No data sales"),
    ]
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            ZStack {
                Circle()
                    .fill(page.tint.opacity(0.14))
                    .frame(width: 140, height: 140)
                Image(systemName: page.icon)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(page.tint)
            }
            VStack(spacing: Theme.Spacing.m) {
                Text(page.title)
                    .font(Theme.Font.largeTitle)
                    .foregroundStyle(Theme.Palette.ink)
                    .multilineTextAlignment(.center)
                Text(page.body)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                if let footnote = page.footnote {
                    Text(footnote)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.inkTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, Theme.Spacing.s)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            Spacer()
        }
    }
}

private struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Theme.Palette.accent : Theme.Palette.hairline)
                    .frame(width: i == index ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: index)
            }
        }
    }
}
