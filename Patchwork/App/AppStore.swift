import SwiftUI
import MapKit
import SwiftData
import PatchworkCore
import PatchworkData
import PatchworkGeo

/// The app's central state container. Owns the loaded geodata, the in-memory visited bitset, and
/// the derived progress; coordinates claiming, persistence, export/import, and reset. Everything
/// it does is on device.
@MainActor
final class AppStore: ObservableObject {
    enum LoadState: Equatable {
        case loading
        case ready
        case failed(String)
    }

    /// The outcome of a claim attempt, surfaced to the user.
    enum ClaimOutcome: Equatable {
        case filledNew(ZCTAInfo)        // a patch you hadn't colored before
        case alreadyFilled(ZCTAInfo)    // you were already here
        case outsideCoverage            // not in the current dataset's area
    }

    @Published private(set) var loadState: LoadState = .loading
    @Published private(set) var visitedIndices: Set<Int> = []
    @Published private(set) var visitedVersion = 0
    @Published private(set) var snapshot: ProgressSnapshot?
    @Published private(set) var countyCompletion: [String: Double] = [:]
    @Published private(set) var recentClaims: [ClaimEventRecord] = []
    @Published var recenter: MKCoordinateRegion?
    @Published var lastOutcome: ClaimOutcome?
    @Published var errorMessage: String?

    let location: LocationService
    let store: StoreManager
    private let modelContext: ModelContext
    private(set) var geoStore: GeoDataStore?
    private var visited = VisitedBitset(capacity: 0)
    private var datasetID = "sample"

    init(modelContext: ModelContext, location: LocationService, store: StoreManager) {
        self.modelContext = modelContext
        self.location = location
        self.store = store
    }

    // MARK: - Loading

    func bootstrap() async {
        guard case .loading = loadState else { return }
        do {
            // Load the heavy geodata (decode polygons + build the spatial index) off the main actor.
            let loaded = try await Task.detached(priority: .userInitiated) {
                try GeoDataStore.bundled()
            }.value
            self.geoStore = loaded
            self.datasetID = loaded.metadata.dataset
            self.visited = loaded.makeEmptyBitset()
            restoreState()
            seedDemoIfRequested()
            recompute()
            loadState = .ready
            await store.loadProducts()
        } catch {
            loadState = .failed("Couldn’t load Patchwork’s map data. \(error.localizedDescription)")
        }
    }

    private func restoreState() {
        guard let geoStore else { return }
        let id = datasetID
        let descriptor = FetchDescriptor<MapStateRecord>(
            predicate: #Predicate { $0.datasetID == id })
        if let record = try? modelContext.fetch(descriptor).first,
           let restored = try? VisitedBitset(serialized: record.bitsetData),
           restored.capacity == geoStore.zctaCount {
            visited = restored
        }
        loadRecentClaims()
    }

    /// Screenshot/demo affordance: when launched with `-PWDemoSeed`, fills a representative set
    /// of patches so the map and progress views are populated. Never triggered in production
    /// (the argument is only ever passed by tooling) and not persisted.
    private func seedDemoIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-PWDemoSeed"), let geoStore else { return }
        for id in ["06075", "P_Oakland", "P_Berkeley", "P_San_Francisco"] {
            geoStore.region(id: id)?.members.forEach { visited.insert($0.zctaIndex) }
        }
        // A scattering of partial counties for visual variety.
        for i in stride(from: 200, to: 360, by: 2) { visited.insert(i) }
    }

    // MARK: - Derived state

    private func recompute() {
        guard let geoStore else { return }
        visitedIndices = Set(visited.visitedIndices)
        visitedVersion += 1
        snapshot = geoStore.snapshot(visited: visited)
        var counties: [String: Double] = [:]
        for p in geoStore.progress(kind: .county, visited: visited) {
            counties[p.region.id] = p.completion
        }
        countyCompletion = counties
    }

    var patchesFilled: Int { visited.count }
    var patchesTotal: Int { geoStore?.zctaCount ?? 0 }

    func info(for index: Int) -> ZCTAInfo? { geoStore?.info(forIndex: index) }

    func countyName(for id: String?) -> String? {
        guard let id else { return nil }
        return geoStore?.region(id: id)?.region.name
    }

    func progress(kind: RegionKind) -> [RegionProgress] {
        guard let geoStore else { return [] }
        return geoStore.progress(kind: kind, visited: visited).sorted {
            if $0.completion != $1.completion { return $0.completion > $1.completion }
            return $0.region.name < $1.region.name
        }
    }

    // MARK: - Claiming

    /// Recenters the map on the user's current location without claiming.
    func centerOnCurrentLocation() async {
        guard loadState == .ready else { return }
        do {
            let loc = try await location.requestCurrentLocation()
            recenter = MKCoordinateRegion(
                center: loc.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08))
        } catch {
            errorMessage = (error as? LocationService.LocationError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    /// Claims the patch the user is physically standing in (the primary delight moment).
    func claimCurrentLocation() async {
        guard loadState == .ready else { return }
        do {
            let location = try await location.requestCurrentLocation()
            claim(coordinate: Coordinate(latitude: location.coordinate.latitude,
                                         longitude: location.coordinate.longitude),
                  recenterToPatch: true)
        } catch {
            errorMessage = (error as? LocationService.LocationError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    /// Claims the patch containing a coordinate (used by Claim Current Patch and dev tools).
    func claim(coordinate: Coordinate, recenterToPatch: Bool) {
        guard let geoStore, let idx = geoStore.resolveIndex(coordinate) else {
            lastOutcome = .outsideCoverage
            return
        }
        claim(index: idx, recenterToPatch: recenterToPatch)
    }

    /// Claims a specific ZCTA index (used by map taps in a debug build and by claim flows).
    func claim(index idx: Int, recenterToPatch: Bool) {
        guard let geoStore, let info = geoStore.info(forIndex: idx) else { return }
        let isNew = visited.insert(idx)
        if isNew {
            persist()
            appendClaimEvent(index: idx, code: info.code.value)
            recompute()
            lastOutcome = .filledNew(info)
        } else {
            lastOutcome = .alreadyFilled(info)
        }
        if recenterToPatch {
            recenter = region(forIndex: idx)
        }
    }

    private func region(forIndex idx: Int) -> MKCoordinateRegion? {
        guard let geoStore, idx < geoStore.resolver.features.count else { return nil }
        let b = geoStore.resolver.features[idx].boundingBox
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (b.minY + b.maxY) / 2,
                                           longitude: (b.minX + b.maxX) / 2),
            span: MKCoordinateSpan(latitudeDelta: max(0.02, (b.maxY - b.minY) * 6),
                                   longitudeDelta: max(0.02, (b.maxX - b.minX) * 6)))
    }

    // MARK: - Persistence

    private func persist() {
        let id = datasetID
        let data = visited.serialized()
        let descriptor = FetchDescriptor<MapStateRecord>(
            predicate: #Predicate { $0.datasetID == id })
        if let record = try? modelContext.fetch(descriptor).first {
            record.bitsetData = data
            record.updatedAt = .now
        } else {
            modelContext.insert(MapStateRecord(datasetID: id, bitsetData: data))
        }
        try? modelContext.save()
    }

    private func appendClaimEvent(index: Int, code: String) {
        modelContext.insert(ClaimEventRecord(zctaIndex: index, code: code))
        try? modelContext.save()
        loadRecentClaims()
    }

    private func loadRecentClaims() {
        var descriptor = FetchDescriptor<ClaimEventRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.fetchLimit = 30
        recentClaims = (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Patches newly filled in the current calendar month (a cumulative, non-punitive counter).
    var patchesThisMonth: Int {
        let cal = Calendar.current
        return recentClaims.filter { cal.isDate($0.timestamp, equalTo: .now, toGranularity: .month) }.count
    }

    // MARK: - Reset / Export / Import

    func resetAllProgress() {
        guard let geoStore else { return }
        visited = geoStore.makeEmptyBitset()
        try? modelContext.delete(model: MapStateRecord.self)
        try? modelContext.delete(model: ClaimEventRecord.self)
        try? modelContext.save()
        recentClaims = []
        recompute()
    }

    func exportData() -> ProgressExport {
        let codes = visited.visitedIndices.compactMap { geoStore?.code(forIndex: $0)?.value }
        return ProgressExport(dataset: datasetID, zctaCodes: codes.sorted(), exportedAt: .now)
    }

    @discardableResult
    func importData(_ export: ProgressExport) -> Int {
        guard let geoStore else { return 0 }
        var imported = 0
        for code in export.zctaCodes {
            if let idx = geoStore.index(forCode: code), visited.insert(idx) {
                appendClaimEvent(index: idx, code: code)
                imported += 1
            }
        }
        if imported > 0 {
            persist()
            recompute()
        }
        return imported
    }
}

/// Versioned, human-readable export of progress (codes, not coordinates) — privacy-safe and
/// portable across reinstalls. Stays on device unless the user shares it.
struct ProgressExport: Codable {
    var version = 1
    var dataset: String
    var zctaCodes: [String]
    var exportedAt: Date
}
