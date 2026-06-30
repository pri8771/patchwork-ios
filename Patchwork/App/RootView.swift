import SwiftUI

/// Routes between onboarding, the loading state, and the main app.
struct RootView: View {
    @EnvironmentObject private var appStore: AppStore
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some View {
        ZStack {
            Theme.Palette.paper.ignoresSafeArea()

            if !hasOnboarded {
                OnboardingView { hasOnboarded = true }
                    .transition(.opacity)
            } else {
                switch appStore.loadState {
                case .loading:
                    LoadingView()
                case .failed(let message):
                    LoadFailedView(message: message)
                case .ready:
                    MainTabView()
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: hasOnboarded)
        .animation(.easeInOut(duration: 0.3), value: appStore.loadState)
    }
}

struct MainTabView: View {
    @State private var selection = MainTabView.initialTab

    var body: some View {
        TabView(selection: $selection) {
            MapScreen()
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(0)
            ProgressScreen()
                .tabItem { Label("Progress", systemImage: "chart.pie.fill") }
                .tag(1)
            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(2)
        }
    }

    /// Dev/screenshot affordance: `-PWStartTab progress|settings` opens a tab directly.
    private static var initialTab: Int {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-PWStartTab"), i + 1 < args.count else { return 0 }
        switch args[i + 1] {
        case "progress": return 1
        case "settings": return 2
        default: return 0
        }
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "map.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.Palette.accent)
            ProgressView()
            Text("Laying out your map…")
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.inkSecondary)
        }
    }
}

private struct LoadFailedView: View {
    let message: String
    @EnvironmentObject private var appStore: AppStore

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Palette.amber)
            Text("Something went wrong")
                .font(Theme.Font.title)
                .foregroundStyle(Theme.Palette.ink)
            Text(message)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
    }
}
