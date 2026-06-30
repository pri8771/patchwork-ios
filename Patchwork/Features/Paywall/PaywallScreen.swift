import SwiftUI
import StoreKit

/// Patchwork Pro paywall (locked decision #9: Free + Pro annual default + Lifetime, no ads/data
/// sales). Pro unlocks cosmetics and polish, never core play — there's no patch cap or dark
/// pattern gating the actual game.
struct PaywallScreen: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var selection: String = StoreManager.annualID
    @State private var isPurchasing = false

    private let features = [
        ("paintpalette.fill", "Custom map palettes", "Recolor your quilt with curated themes."),
        ("photo.fill", "Watermark-free share cards", "Export your map in crisp high resolution."),
        ("chart.bar.fill", "Deep progress breakdowns", "Per-region detail and milestones."),
        ("shippingbox.fill", "All region packs", "Every future map pack, included."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    header
                    featureList
                    if store.isPro { proActiveCard } else { plans; purchaseButton }
                    restoreAndLegal
                }
                .padding(Theme.Spacing.l)
            }
            .background(Theme.Palette.paper.ignoresSafeArea())
            .navigationTitle("Patchwork Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
            .task { if store.products.isEmpty { await store.loadProducts() } }
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.m) {
            ZStack {
                Circle().fill(Theme.Palette.accent.opacity(0.14)).frame(width: 96, height: 96)
                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent)
            }
            Text("Make your map yours")
                .font(Theme.Font.title)
                .foregroundStyle(Theme.Palette.ink)
            Text("Everything you need to play is free, forever. Pro adds the finishing touches.")
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        Card {
            VStack(spacing: Theme.Spacing.l) {
                ForEach(features, id: \.0) { icon, title, subtitle in
                    HStack(spacing: Theme.Spacing.m) {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.Palette.accent)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(title).font(Theme.Font.callout).foregroundStyle(Theme.Palette.ink)
                            Text(subtitle).font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkSecondary)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var plans: some View {
        VStack(spacing: Theme.Spacing.m) {
            if let annual = store.annualProduct {
                PlanRow(title: "Pro Annual", price: annual.displayPrice + " / year",
                        badge: introBadge(for: annual) ?? "Best value",
                        isSelected: selection == annual.id) { selection = annual.id }
            }
            if let lifetime = store.lifetimeProduct {
                PlanRow(title: "Lifetime", price: lifetime.displayPrice + " once",
                        badge: "Pay once", isSelected: selection == lifetime.id) { selection = lifetime.id }
            }
            if store.products.isEmpty {
                if store.isLoadingProducts {
                    ProgressView().padding()
                } else {
                    VStack(spacing: Theme.Spacing.s) {
                        Text("The store is unavailable right now.")
                            .font(Theme.Font.callout).foregroundStyle(Theme.Palette.inkSecondary)
                        Button("Try again") { Task { await store.loadProducts() } }
                            .font(Theme.Font.callout).foregroundStyle(Theme.Palette.accent)
                    }
                    .padding()
                }
            }
        }
    }

    private func introBadge(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else {
            return nil
        }
        return "Free trial"
    }

    private var purchaseButton: some View {
        VStack(spacing: Theme.Spacing.s) {
            PrimaryButton(title: purchaseTitle, isLoading: isPurchasing,
                          enabled: !store.products.isEmpty) {
                Task { await purchaseSelected() }
            }
            Text("Cancel anytime. Subscriptions renew until cancelled.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.inkTertiary)
        }
    }

    private var purchaseTitle: String {
        if selection == StoreManager.lifetimeID { return "Unlock Lifetime" }
        if let annual = store.annualProduct, annual.subscription?.introductoryOffer != nil {
            return "Start free trial"
        }
        return "Subscribe"
    }

    private var proActiveCard: some View {
        Card {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 24)).foregroundStyle(Theme.Palette.success)
                VStack(alignment: .leading) {
                    Text("You’re a Pro").font(Theme.Font.headline).foregroundStyle(Theme.Palette.ink)
                    Text(store.tier == .lifetime ? "Lifetime access" : "Annual subscription")
                        .font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkSecondary)
                }
                Spacer()
            }
        }
    }

    private var restoreAndLegal: some View {
        VStack(spacing: Theme.Spacing.s) {
            Button("Restore purchases") { Task { await store.restore() } }
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.accent)
            HStack(spacing: Theme.Spacing.m) {
                Link("Terms", destination: URL(string: "https://patchworkapp.example/terms")!)
                Link("Privacy", destination: URL(string: "https://patchworkapp.example/privacy")!)
            }
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Palette.inkTertiary)
        }
    }

    private func purchaseSelected() async {
        guard let product = store.products.first(where: { $0.id == selection }) else { return }
        isPurchasing = true
        let success = await store.purchase(product)
        isPurchasing = false
        if success { dismiss() }
    }
}

private struct PlanRow: View {
    let title: String
    let price: String
    let badge: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Theme.Palette.accent : Theme.Palette.inkTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.Font.headline).foregroundStyle(Theme.Palette.ink)
                    Text(price).font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkSecondary)
                }
                Spacer()
                Pill(text: badge)
            }
            .padding(Theme.Spacing.l)
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .strokeBorder(isSelected ? Theme.Palette.accent : Theme.Palette.hairline,
                                  lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(PressableStyle())
    }
}
