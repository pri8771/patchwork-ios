import SwiftUI
import UniformTypeIdentifiers

/// Settings: Pro status, the on-device privacy controls (export / import / reset), and the
/// honest explanation of what "ZIP-like patches" means. Reinforces the no-backend posture.
struct SettingsScreen: View {
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var store: StoreManager
    @State private var showPaywall = false
    @State private var showResetConfirm = false
    @State private var showImporter = false
    @State private var exportDocument: ProgressExportDocument?
    @State private var showExporter = false
    @State private var importResult: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    proCard
                    dataSection
                    privacySection
                    aboutSection
                }
                .padding(Theme.Spacing.l)
            }
            .background(Theme.Palette.paper.ignoresSafeArea())
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) { PaywallScreen() }
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("-PWShowPaywall") { showPaywall = true }
            }
            .confirmationDialog("Reset all progress?", isPresented: $showResetConfirm,
                                titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) { appStore.resetAllProgress() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently clears every patch you’ve colored on this device. Export first if you want a backup.")
            }
            .fileExporter(isPresented: $showExporter,
                          document: exportDocument,
                          contentType: .json,
                          defaultFilename: "patchwork-progress") { _ in }
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.json]) { result in handleImport(result) }
            .alert("Import", isPresented: Binding(
                get: { importResult != nil }, set: { if !$0 { importResult = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(importResult ?? "") }
        }
    }

    private var proCard: some View {
        Button { showPaywall = true } label: {
            Card {
                HStack(spacing: Theme.Spacing.m) {
                    Image(systemName: store.isPro ? "checkmark.seal.fill" : "sparkles")
                        .font(.system(size: 24))
                        .foregroundStyle(store.isPro ? Theme.Palette.success : Theme.Palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.isPro ? "Patchwork Pro" : "Upgrade to Pro")
                            .font(Theme.Font.headline).foregroundStyle(Theme.Palette.ink)
                        Text(store.isPro
                             ? (store.tier == .lifetime ? "Lifetime access" : "Annual subscription")
                             : "Palettes, clean share cards, region packs")
                            .font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkSecondary)
                    }
                    Spacer()
                    if !store.isPro { Image(systemName: "chevron.right").foregroundStyle(Theme.Palette.inkTertiary) }
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeader(title: "Your data")
            Card {
                VStack(spacing: 0) {
                    SettingsRow(icon: "square.and.arrow.up", title: "Export progress",
                                subtitle: "Save a backup file of your patches") {
                        exportDocument = ProgressExportDocument(export: appStore.exportData())
                        showExporter = true
                    }
                    Divider().overlay(Theme.Palette.hairline)
                    SettingsRow(icon: "square.and.arrow.down", title: "Import progress",
                                subtitle: "Restore from a backup file") { showImporter = true }
                    Divider().overlay(Theme.Palette.hairline)
                    SettingsRow(icon: "trash", title: "Reset all progress",
                                subtitle: "Clear every patch on this device",
                                tint: Theme.Palette.accent) { showResetConfirm = true }
                }
            }
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeader(title: "Privacy")
            Card {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    privacyLine("location.fill", "Location is used only when you tap to claim a patch.")
                    privacyLine("iphone", "Everything is processed and stored on this device.")
                    privacyLine("network.slash", "No account, no servers, no tracking, no ads, no data sales.")
                }
            }
        }
    }

    private func privacyLine(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: icon).foregroundStyle(Theme.Palette.success).frame(width: 24)
            Text(text).font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkSecondary)
            Spacer()
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeader(title: "About")
            Card {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    Text("About “ZIP-like patches”")
                        .font(Theme.Font.callout).foregroundStyle(Theme.Palette.ink)
                    Text("Patches are based on Census ZIP Code Tabulation Areas (ZCTAs) — close approximations of USPS ZIP Codes, not official ZIP delivery boundaries. Patchwork uses them to color the areas you visit.")
                        .font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkSecondary)
                    if let geoStore = appStore.geoStore {
                        Divider().overlay(Theme.Palette.hairline)
                        HStack {
                            Text("Map data").font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkSecondary)
                            Spacer()
                            Text("\(geoStore.metadata.datasetName) · TIGER \(geoStore.metadata.tigerVintage)")
                                .font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkTertiary)
                        }
                    }
                    HStack {
                        Text("Version").font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkSecondary)
                        Spacer()
                        Text("1.0").font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkTertiary)
                    }
                }
            }
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let needsAccess = url.startAccessingSecurityScopedResource()
            defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let export = try JSONDecoder.patchwork.decode(ProgressExport.self, from: data)
                let count = appStore.importData(export)
                importResult = count > 0 ? "Imported \(count) new patches." : "No new patches to import."
            } catch {
                importResult = "Couldn’t read that file."
            }
        case .failure:
            importResult = "Import cancelled."
        }
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var tint: Color = Theme.Palette.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: icon).font(.system(size: 18)).foregroundStyle(tint).frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(Theme.Font.callout).foregroundStyle(Theme.Palette.ink)
                    Text(subtitle).font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Theme.Palette.inkTertiary)
            }
            .padding(.vertical, Theme.Spacing.s)
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Export document

extension JSONDecoder {
    static var patchwork: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

extension JSONEncoder {
    static var patchwork: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

/// A FileDocument wrapper so progress can be exported through the system file exporter.
struct ProgressExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var export: ProgressExport

    init(export: ProgressExport) { self.export = export }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        export = try JSONDecoder.patchwork.decode(ProgressExport.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder.patchwork.encode(export)
        return FileWrapper(regularFileWithContents: data)
    }
}
