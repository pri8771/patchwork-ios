import SwiftUI
import PatchworkCore

/// The retention surface: how much of the map is filled, broken down by level, plus a recent
/// timeline. Framing is strictly non-punitive — cumulative counters only, no streaks to break.
struct ProgressScreen: View {
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var store: StoreManager
    @State private var showShare = false
    @State private var showPaywall = false
    @State private var selectedLevel: RegionKind = .place

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    headlineCard
                    statRow
                    levelPicker
                    regionList
                    if !appStore.recentClaims.isEmpty { recentSection }
                }
                .padding(Theme.Spacing.l)
            }
            .background(Theme.Palette.paper.ignoresSafeArea())
            .navigationTitle("Your Map")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showShare = true } label: { Image(systemName: "square.and.arrow.up") }
                }
            }
            .sheet(isPresented: $showShare) {
                ShareSheetView(isPro: store.isPro, onUpgrade: { showShare = false; showPaywall = true })
            }
            .sheet(isPresented: $showPaywall) { PaywallScreen() }
        }
    }

    private var headlineCard: some View {
        Card {
            HStack(spacing: Theme.Spacing.xl) {
                ProgressRing(
                    progress: Double(appStore.patchesFilled) / Double(max(1, appStore.patchesTotal)),
                    size: 132, label: "filled")
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("\(appStore.patchesFilled)")
                        .font(Theme.Font.display(40))
                        .foregroundStyle(Theme.Palette.ink)
                    Text("of \(appStore.patchesTotal) patches")
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                    if appStore.patchesThisMonth > 0 {
                        Pill(text: "+\(appStore.patchesThisMonth) this month", color: Theme.Palette.success)
                            .padding(.top, Theme.Spacing.xs)
                    }
                }
                Spacer()
            }
        }
    }

    private var statRow: some View {
        HStack(spacing: Theme.Spacing.m) {
            if let s = appStore.snapshot {
                if let counties = s.summary(for: .county) {
                    Card { StatTile(value: "\(counties.startedRegions)",
                                    caption: "of \(counties.totalRegions) counties") }
                }
                if let states = s.summary(for: .state) {
                    Card { StatTile(value: "\(states.startedRegions)",
                                    caption: states.startedRegions == 1 ? "state started" : "states started",
                                    tint: Theme.Palette.accent) }
                }
            }
        }
    }

    private var levelPicker: some View {
        Picker("Level", selection: $selectedLevel) {
            Text("Cities").tag(RegionKind.place)
            Text("Counties").tag(RegionKind.county)
            Text("States").tag(RegionKind.state)
        }
        .pickerStyle(.segmented)
    }

    private var regionList: some View {
        VStack(spacing: Theme.Spacing.m) {
            let items = appStore.progress(kind: selectedLevel).filter { $0.totalZCTACount > 0 }
            if items.isEmpty {
                Card { Text("Nothing here yet — claim a patch to begin.")
                    .font(Theme.Font.callout).foregroundStyle(Theme.Palette.inkSecondary) }
            } else {
                ForEach(items) { RegionProgressRow(progress: $0) }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeader(title: "Recently colored")
            Card {
                VStack(spacing: Theme.Spacing.m) {
                    ForEach(appStore.recentClaims.prefix(6), id: \.persistentModelID) { event in
                        HStack(spacing: Theme.Spacing.m) {
                            PatchSwatch(patchColor: PatchPalette.color(for: event.zctaIndex), size: 26)
                            Text("ZIP-like \(event.code)")
                                .font(Theme.Font.callout)
                                .foregroundStyle(Theme.Palette.ink)
                            Spacer()
                            Text(event.timestamp, format: .relative(presentation: .named))
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.inkTertiary)
                        }
                    }
                }
            }
        }
    }
}

private struct RegionProgressRow: View {
    let progress: RegionProgress

    var body: some View {
        Card(padding: Theme.Spacing.m) {
            VStack(spacing: Theme.Spacing.s) {
                HStack {
                    Text(progress.region.name)
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Palette.ink)
                    if progress.isComplete {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.Palette.success)
                    }
                    Spacer()
                    Text("\(progress.percentComplete)%")
                        .font(Theme.Font.statSmall)
                        .foregroundStyle(progress.isComplete ? Theme.Palette.success : Theme.Palette.ink)
                }
                ProgressBar(progress: progress.completion,
                            tint: progress.isComplete ? Theme.Palette.success : Theme.Palette.accent)
                HStack {
                    Text("\(progress.visitedZCTACount) of \(progress.totalZCTACount) patches")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                    Spacer()
                }
            }
        }
    }
}
