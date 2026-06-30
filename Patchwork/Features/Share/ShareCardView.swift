import SwiftUI
import PatchworkCore

/// The data behind a share card. Region-level only — counts and percentages, never ZCTA-level
/// fill, coordinates, or timestamps — so sharing can't reconstruct where the user lives or moves
/// (the locked privacy-safe-share rule from the Patchwork planning thread).
struct ShareCardModel {
    let patchesFilled: Int
    let nationwidePercent: Int
    let citiesStarted: Int
    let citiesTotal: Int
    let countiesStarted: Int
    let countiesTotal: Int
    let statesStarted: Int
    let datasetName: String
    let showWatermark: Bool

    static func from(snapshot: ProgressSnapshot, datasetName: String, isPro: Bool) -> ShareCardModel {
        let cities = snapshot.summary(for: .place)
        let counties = snapshot.summary(for: .county)
        let states = snapshot.summary(for: .state)
        return ShareCardModel(
            patchesFilled: snapshot.patchesFilled,
            nationwidePercent: snapshot.nationwidePercent,
            citiesStarted: cities?.startedRegions ?? 0,
            citiesTotal: cities?.totalRegions ?? 0,
            countiesStarted: counties?.startedRegions ?? 0,
            countiesTotal: counties?.totalRegions ?? 0,
            statesStarted: states?.startedRegions ?? 0,
            datasetName: datasetName,
            showWatermark: !isPro)
    }
}

/// A polished, shareable 3:4 card. The "quilt" motif is an abstract grid keyed only to the patch
/// *count*, not the real map, so it celebrates progress without leaking location.
struct ShareCardView: View {
    let model: ShareCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            quiltMotif
                .padding(.vertical, Theme.Spacing.xl)
            stats
            Spacer(minLength: 0)
            footer
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 540, height: 720)
        .background(
            LinearGradient(colors: [Theme.Palette.paper, Theme.Palette.surfaceMuted],
                           startPoint: .top, endPoint: .bottom))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("MY PATCHWORK")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(Theme.Palette.accent)
            Text("\(model.patchesFilled) patches colored")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Palette.ink)
            Text("across \(model.datasetName)")
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.inkSecondary)
        }
    }

    private var quiltMotif: some View {
        let columns = 8
        let rows = 5
        return VStack(spacing: 6) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 6) {
                    ForEach(0..<columns, id: \.self) { c in
                        let i = r * columns + c
                        let filled = i < min(model.patchesFilled, columns * rows)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(PatchPalette.color(for: i * 3 + 7),
                                        opacity: filled ? 0.9 : 0.16))
                            .frame(height: 52)
                    }
                }
            }
        }
    }

    private var stats: some View {
        HStack(spacing: Theme.Spacing.l) {
            shareStat("\(model.statesStarted)", "states")
            shareStat("\(model.countiesStarted)", "counties")
            shareStat("\(model.citiesStarted)", "cities")
            shareStat("\(model.nationwidePercent)%", "of map")
        }
    }

    private func shareStat(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.Palette.ink)
            Text(caption).font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "map.fill").foregroundStyle(Theme.Palette.accent)
                Text("Patchwork").font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Palette.ink)
            }
            Spacer()
            if model.showWatermark {
                Text("made with Patchwork")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.inkTertiary)
            }
        }
        .padding(.top, Theme.Spacing.m)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Palette.hairline).frame(height: 1)
        }
    }
}

/// The share sheet: previews the card, renders it to an image, and offers it via the system
/// share sheet. Free users see a small watermark; Pro removes it (and renders at higher scale).
struct ShareSheetView: View {
    let isPro: Bool
    let onUpgrade: () -> Void
    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    if let model {
                        ShareCardView(model: model)
                            .scaleEffect(0.56)
                            .frame(width: 540 * 0.56, height: 720 * 0.56)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                            .padding(.top, Theme.Spacing.l)

                        if let image = rendered(model: model) {
                            ShareLink(item: image, preview: SharePreview("My Patchwork", image: image)) {
                                Label("Share image", systemImage: "square.and.arrow.up")
                                    .font(Theme.Font.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Theme.Spacing.l)
                                    .foregroundStyle(.white)
                                    .background(Theme.Palette.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                            }
                            .padding(.horizontal, Theme.Spacing.l)
                        }

                        if !isPro {
                            Button(action: onUpgrade) {
                                Text("Remove watermark with Pro")
                                    .font(Theme.Font.callout)
                                    .foregroundStyle(Theme.Palette.accent)
                            }
                        }
                        Text("Shares show region totals only — never the exact places you’ve been.")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.inkTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.xl)
                    }
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.Palette.paper.ignoresSafeArea())
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private var model: ShareCardModel? {
        guard let snapshot = appStore.snapshot, let geoStore = appStore.geoStore else { return nil }
        return ShareCardModel.from(snapshot: snapshot,
                                   datasetName: geoStore.metadata.datasetName,
                                   isPro: isPro)
    }

    @MainActor
    private func rendered(model: ShareCardModel) -> Image? {
        let renderer = ImageRenderer(content: ShareCardView(model: model))
        renderer.scale = isPro ? max(displayScale, 3) : 2  // Pro renders at higher resolution
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}
