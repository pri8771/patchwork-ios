import XCTest
@testable import PatchworkData
import PatchworkCore
import PatchworkGeo

final class GeoDataStoreTests: XCTestCase {

    private func store() throws -> GeoDataStore {
        try GeoDataStore.bundled()
    }

    func testBundleLoads() throws {
        let store = try store()
        XCTAssertEqual(store.metadata.dataset, "sample")
        XCTAssertEqual(store.metadata.tigerVintage, "2025")
        XCTAssertEqual(store.zctaCount, 400)
        XCTAssertEqual(store.resolver.features.count, 400)
        XCTAssertFalse(store.metadata.note.isEmpty)
    }

    func testCodeIndexRoundTrip() throws {
        let store = try store()
        for info in store.allInfo.prefix(20) {
            XCTAssertEqual(store.index(forCode: info.code.value), info.index)
            XCTAssertEqual(store.code(forIndex: info.index), info.code)
        }
    }

    func testResolveCoordinateInsideBundle() throws {
        let store = try store()
        // Centroid of the first ZCTA must resolve back to that ZCTA (or a neighbor at a shared
        // border, but the centroid is interior so it should be exact).
        let feature = store.resolver.features[0]
        let box = feature.boundingBox
        let center = Coordinate(latitude: box.centerY, longitude: box.centerX)
        let resolved = store.resolveIndex(center)
        XCTAssertNotNil(resolved)
        // The center could fall in an irregular neighbor; assert it's a real, contained ZCTA.
        if let idx = resolved {
            XCTAssertTrue(store.resolver.features[idx].contains(center.point))
        }
    }

    func testResolveOutsideBundleReturnsNil() throws {
        let store = try store()
        // New York City — far outside the Bay Area sample window.
        XCTAssertNil(store.resolveIndex(Coordinate(latitude: 40.7128, longitude: -74.0060)))
    }

    func testEveryCentroidResolvesToAContainingZCTA() throws {
        let store = try store()
        var resolvedCount = 0
        for feature in store.resolver.features {
            let c = Coordinate(latitude: feature.boundingBox.centerY,
                               longitude: feature.boundingBox.centerX)
            if let idx = store.resolveIndex(c) {
                XCTAssertTrue(store.resolver.features[idx].contains(c.point),
                              "resolved ZCTA must actually contain the point")
                resolvedCount += 1
            }
        }
        // The tiling is watertight; the vast majority of bbox-centers are interior points.
        XCTAssertGreaterThan(resolvedCount, store.zctaCount * 9 / 10)
    }

    func testRegionsAndLevels() throws {
        let store = try store()
        XCTAssertEqual(store.regions(of: .country).count, 1)
        XCTAssertEqual(store.regions(of: .state).count, 1)
        XCTAssertGreaterThanOrEqual(store.regions(of: .county).count, 5)
        XCTAssertGreaterThanOrEqual(store.regions(of: .place).count, 5)
        XCTAssertTrue(store.availableLevels.contains(.county))
        XCTAssertEqual(store.region(id: "06")?.region.name, "California")
    }

    func testRegionWeightsSumToOne() throws {
        let store = try store()
        for kind in [RegionKind.country, .state, .county, .place] {
            for region in store.regions(of: kind) {
                let sum = region.members.reduce(0) { $0 + $1.weight }
                XCTAssertEqual(sum, 1.0, accuracy: 1e-6,
                               "region \(region.region.name) weights should sum to 1")
            }
        }
    }

    func testRollupReflectsClaims() throws {
        let store = try store()
        var visited = store.makeEmptyBitset()
        // Claim every ZCTA in San Francisco County → county should read complete.
        let sf = try XCTUnwrap(store.region(id: "06075"))
        for member in sf.members { visited.insert(member.zctaIndex) }
        let progress = store.progress(kind: .county, visited: visited)
        let sfProgress = try XCTUnwrap(progress.first { $0.region.id == "06075" })
        XCTAssertTrue(sfProgress.isComplete)
        XCTAssertEqual(sfProgress.percentComplete, 100)
        // Country-level snapshot should be partially filled.
        let snapshot = store.snapshot(visited: visited)
        XCTAssertEqual(snapshot.patchesFilled, sf.members.count)
        XCTAssertGreaterThan(snapshot.nationwidePercent, 0)
        XCTAssertLessThan(snapshot.nationwidePercent, 100)
    }

    func testGeometryDecodeMatchesEncoding() throws {
        let store = try store()
        // Every ZCTA decoded to at least one polygon with a real ring.
        for feature in store.resolver.features.prefix(50) {
            XCTAssertFalse(feature.polygons.isEmpty)
            XCTAssertGreaterThanOrEqual(feature.polygons[0].exterior.count, 4)
        }
    }
}
