import Foundation
import PatchworkCore
import PatchworkGeo

/// Metadata describing the loaded geodata bundle.
public struct GeoMetadata: Sendable {
    public let dataset: String          // "sample" | "national" …
    public let datasetName: String
    public let tigerVintage: String     // pinned TIGER/Line vintage, e.g. "2025"
    public let zctaCount: Int
    public let bounds: BoundingBox
    public let note: String
}

/// Per-ZCTA display info for the "you claimed this patch" surface.
public struct ZCTAInfo: Sendable, Hashable {
    public let index: ZCTAIndex
    public let code: ZCTACode
    public let countyID: String?
    public let stateID: String?
    public let placeName: String?
}

/// Loads the bundled, read-only geodata and exposes everything the app needs at runtime:
/// the on-device coordinate→ZCTA resolver, the weighted region tables for rollups, ZCTA fill
/// geometry for the map, and code/label lookups. All on device; nothing touches the network.
///
/// Loading is the one heavyweight step (decode polygons + build the spatial index), so the app
/// does it once off the main thread at launch.
public final class GeoDataStore: @unchecked Sendable {
    public let metadata: GeoMetadata
    public let resolver: FeatureResolver

    private let infoByIndex: [ZCTAInfo]
    private let indexByCode: [String: ZCTAIndex]
    private let regionsByKindMap: [RegionKind: [WeightedRegion]]
    private let regionByID: [String: WeightedRegion]
    private let engine = RollupEngine()

    public var zctaCount: Int { metadata.zctaCount }

    /// Loads the geodata bundled inside the `PatchworkData` resource bundle.
    public static func bundled() throws -> GeoDataStore {
        guard let url = Bundle.module.url(forResource: "patchwork-sample", withExtension: "sqlite") else {
            throw SQLiteDatabase.DBError.missingFile("patchwork-sample.sqlite (Bundle.module)")
        }
        return try GeoDataStore(url: url)
    }

    public init(url: URL) throws {
        let db = try SQLiteDatabase(path: url.path)

        // --- meta ---
        var meta: [String: String] = [:]
        try db.query("SELECT key, value FROM meta") { row in
            if let k = row.text(0), let v = row.text(1) { meta[k] = v }
        }
        func metaDouble(_ k: String, _ d: Double) -> Double { Double(meta[k] ?? "") ?? d }

        // --- zctas: build features + info + code map ---
        var features: [GeoFeature] = []
        var info: [ZCTAInfo] = []
        var indexByCode: [String: ZCTAIndex] = [:]
        var loadError: Error?
        try db.query("""
            SELECT idx, code, county_id, state_id, place_name, geom
            FROM zcta ORDER BY idx
        """) { row in
            guard loadError == nil else { return }
            let idx = row.int(0)
            let code = row.text(1) ?? ""
            let polygons: [GeoPolygon]
            do {
                polygons = try GeometryCodec.decode(row.blob(5))
            } catch {
                loadError = error
                return
            }
            features.append(GeoFeature(id: idx, polygons: polygons))
            info.append(ZCTAInfo(
                index: idx, code: ZCTACode(code),
                countyID: row.text(2), stateID: row.text(3), placeName: row.text(4)))
            indexByCode[code] = idx
        }
        if let loadError { throw loadError }

        // --- regions + weighted members ---
        var regionRows: [String: Region] = [:]
        try db.query("SELECT id, name, kind, parent_id FROM region") { row in
            guard let id = row.text(0), let name = row.text(1),
                  let kindRaw = row.text(2), let kind = RegionKind(rawValue: kindRaw) else { return }
            regionRows[id] = Region(id: id, name: name, kind: kind, parentID: row.text(3))
        }
        var membersByRegion: [String: [RegionMember]] = [:]
        try db.query("SELECT region_id, zcta_idx, weight FROM region_member") { row in
            guard let rid = row.text(0) else { return }
            membersByRegion[rid, default: []].append(
                RegionMember(zctaIndex: row.int(1), weight: row.double(2)))
        }

        var regionByID: [String: WeightedRegion] = [:]
        var regionsByKind: [RegionKind: [WeightedRegion]] = [:]
        for (id, region) in regionRows {
            let weighted = WeightedRegion(region: region, members: membersByRegion[id] ?? [])
            regionByID[id] = weighted
            regionsByKind[region.kind, default: []].append(weighted)
        }
        // Stable display order within a level.
        for kind in regionsByKind.keys {
            regionsByKind[kind]?.sort { $0.region.name < $1.region.name }
        }

        self.resolver = FeatureResolver(features: features)
        self.infoByIndex = info
        self.indexByCode = indexByCode
        self.regionByID = regionByID
        self.regionsByKindMap = regionsByKind
        self.metadata = GeoMetadata(
            dataset: meta["dataset"] ?? "unknown",
            datasetName: meta["dataset_name"] ?? "Patchwork geodata",
            tigerVintage: meta["tiger_vintage"] ?? "2025",
            zctaCount: features.count,
            bounds: BoundingBox(
                minX: metaDouble("lon_min", -125), minY: metaDouble("lat_min", 32),
                maxX: metaDouble("lon_max", -113), maxY: metaDouble("lat_max", 42)),
            note: meta["note"] ?? "")
    }

    // MARK: - Lookups

    /// Resolves a coordinate to a ZCTA index, fully on device. Returns nil outside coverage.
    public func resolveIndex(_ coordinate: Coordinate) -> ZCTAIndex? {
        resolver.resolve(coordinate)
    }

    public func info(forIndex index: ZCTAIndex) -> ZCTAInfo? {
        guard index >= 0 && index < infoByIndex.count else { return nil }
        return infoByIndex[index]
    }

    public func index(forCode code: String) -> ZCTAIndex? { indexByCode[code] }

    public func code(forIndex index: ZCTAIndex) -> ZCTACode? {
        info(forIndex: index)?.code
    }

    public var allInfo: [ZCTAInfo] { infoByIndex }

    /// Fill geometry for a ZCTA, for the map overlay layer.
    public func polygons(forIndex index: ZCTAIndex) -> [GeoPolygon] {
        guard index >= 0 && index < resolver.features.count else { return [] }
        return resolver.features[index].polygons
    }

    // MARK: - Regions & rollups

    public func regions(of kind: RegionKind) -> [WeightedRegion] {
        regionsByKindMap[kind] ?? []
    }

    public func region(id: String) -> WeightedRegion? { regionByID[id] }

    public var availableLevels: [RegionKind] {
        RegionKind.allCases.filter { !(regionsByKindMap[$0]?.isEmpty ?? true) }
    }

    /// A fresh empty bitset sized to this dataset.
    public func makeEmptyBitset() -> VisitedBitset {
        VisitedBitset(capacity: metadata.zctaCount)
    }

    /// Per-region completion for one level.
    public func progress(kind: RegionKind, visited: VisitedBitset) -> [RegionProgress] {
        engine.progress(for: regions(of: kind), visited: visited)
    }

    /// The headline snapshot across all available levels (drives Progress + share card).
    public func snapshot(visited: VisitedBitset) -> ProgressSnapshot {
        var byKind: [RegionKind: [RegionProgress]] = [:]
        for kind in availableLevels where kind != .country {
            byKind[kind] = progress(kind: kind, visited: visited)
        }
        return ProgressSnapshot.build(
            visited: visited, patchesTotal: metadata.zctaCount,
            progressByKind: byKind, engine: engine)
    }
}
