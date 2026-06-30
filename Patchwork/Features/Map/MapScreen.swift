import SwiftUI
import CoreLocation
import PatchworkCore
import PatchworkData

/// The home surface: the live map plus the primary "Claim Current Patch" action. The first
/// patch colored here is the product's core delight moment.
struct MapScreen: View {
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var location: LocationService
    @State private var showLocationHelp = false

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer
            VStack(spacing: Theme.Spacing.m) {
                if let outcome = appStore.lastOutcome {
                    ClaimOutcomeCard(outcome: outcome) {
                        withAnimation { appStore.lastOutcome = nil }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if isLocationDenied {
                    LocationDeniedBanner { openSettings() }
                }
                claimButton
            }
            .padding(Theme.Spacing.l)
        }
        .overlay(alignment: .top) { headerBar }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appStore.lastOutcome)
        .alert("Location", isPresented: Binding(
            get: { appStore.errorMessage != nil },
            set: { if !$0 { appStore.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appStore.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var mapLayer: some View {
        if let geoStore = appStore.geoStore {
            PatchMapView(
                geoStore: geoStore,
                visitedIndices: appStore.visitedIndices,
                visitedVersion: appStore.visitedVersion,
                countyCompletion: appStore.countyCompletion,
                recenter: appStore.recenter,
                onTapZCTA: { idx in appStore.claim(index: idx, recenterToPatch: false) }
            )
            .ignoresSafeArea(edges: .top)
        } else {
            Color.clear
        }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(appStore.patchesFilled) patches")
                    .font(Theme.Font.headline)
                    .foregroundStyle(Theme.Palette.ink)
                if let snapshot = appStore.snapshot, let city = snapshot.summary(for: .place) {
                    Text("\(city.startedRegions) of \(city.totalRegions) cities started")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
            Spacer()
            Button {
                Task { await appStore.centerOnCurrentLocation() }
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent)
                    .padding(Theme.Spacing.m)
                    .background(Theme.Palette.surface, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.Palette.hairline, lineWidth: 1))
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
        .padding(.vertical, Theme.Spacing.s)
        .background(
            LinearGradient(colors: [Theme.Palette.paper.opacity(0.92), .clear],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        )
    }

    private var claimButton: some View {
        PrimaryButton(
            title: "Claim Current Patch",
            systemImage: "mappin.and.ellipse",
            isLoading: location.isResolving
        ) {
            Task { await appStore.claimCurrentLocation() }
        }
    }

    private var isLocationDenied: Bool {
        location.authorizationStatus == .denied || location.authorizationStatus == .restricted
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// The card that animates up after a claim, celebrating the patch (or explaining why none filled).
private struct ClaimOutcomeCard: View {
    let outcome: AppStore.ClaimOutcome
    let onDismiss: () -> Void
    @EnvironmentObject private var appStore: AppStore

    var body: some View {
        Card {
            HStack(spacing: Theme.Spacing.m) {
                icon
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.Font.headline).foregroundStyle(Theme.Palette.ink)
                    Text(subtitle).font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkSecondary)
                }
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Palette.inkTertiary)
                }
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch outcome {
        case .filledNew(let info), .alreadyFilled(let info):
            PatchSwatch(patchColor: PatchPalette.color(for: info.index),
                        filled: true, size: 40)
        case .outsideCoverage:
            Image(systemName: "mappin.slash")
                .font(.system(size: 22))
                .foregroundStyle(Theme.Palette.inkSecondary)
                .frame(width: 40, height: 40)
        }
    }

    private var title: String {
        switch outcome {
        case .filledNew: return "New patch! 🎉"
        case .alreadyFilled: return "Already yours"
        case .outsideCoverage: return "Outside the map"
        }
    }

    private var subtitle: String {
        switch outcome {
        case .filledNew(let info), .alreadyFilled(let info):
            let area = info.placeName ?? appStore.countyName(for: info.countyID) ?? "your area"
            return "ZIP-like \(info.code.value) · \(area)"
        case .outsideCoverage:
            return "You’re outside this map’s coverage area."
        }
    }
}

private struct LocationDeniedBanner: View {
    let onOpenSettings: () -> Void

    var body: some View {
        Card(padding: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "location.slash.fill")
                    .foregroundStyle(Theme.Palette.amber)
                Text("Location is off. Turn it on to claim where you are.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                Spacer()
                Button("Settings", action: onOpenSettings)
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Palette.accent)
            }
        }
    }
}
