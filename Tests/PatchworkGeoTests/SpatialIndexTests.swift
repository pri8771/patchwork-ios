import XCTest
@testable import PatchworkGeo

final class SpatialIndexTests: XCTestCase {

    func testEmptyIndex() {
        let index = SpatialIndex(boxes: [])
        XCTAssertEqual(index.itemCount, 0)
        XCTAssertTrue(index.query(point: Point2D(x: 0, y: 0)).isEmpty)
    }

    func testSingleItem() {
        let index = SpatialIndex(boxes: [BoundingBox(minX: 0, minY: 0, maxX: 1, maxY: 1)])
        XCTAssertEqual(index.query(point: Point2D(x: 0.5, y: 0.5)), [0])
        XCTAssertTrue(index.query(point: Point2D(x: 2, y: 2)).isEmpty)
    }

    func testQueryMatchesBruteForceOnGrid() {
        // 10x10 grid of overlapping boxes.
        var boxes: [BoundingBox] = []
        for r in 0..<10 {
            for c in 0..<10 {
                boxes.append(BoundingBox(minX: Double(c), minY: Double(r),
                                         maxX: Double(c) + 1.5, maxY: Double(r) + 1.5))
            }
        }
        let index = SpatialIndex(boxes: boxes, nodeSize: 4)
        var rng = SplitMix64(seed: 99)
        for _ in 0..<500 {
            let q = BoundingBox(point: Point2D(x: rng.double(in: -1...11), y: rng.double(in: -1...11)))
            let fromIndex = Set(index.query(q))
            let brute = Set(boxes.indices.filter { boxes[$0].intersects(q) })
            XCTAssertEqual(fromIndex, brute)
        }
    }

    func testIndexNeverMissesContainers() {
        // The broad phase must be a superset of true containers (no false negatives).
        let (features, bounds) = SyntheticGeo.stressSet(
            count: 2000, bounds: BoundingBox(minX: 0, minY: 0, maxX: 1000, maxY: 1000), seed: 7)
        let resolver = FeatureResolver(features: features)
        var rng = SplitMix64(seed: 1234)
        for _ in 0..<1000 {
            let p = Point2D(x: rng.double(in: bounds.minX...bounds.maxX),
                            y: rng.double(in: bounds.minY...bounds.maxY))
            XCTAssertEqual(resolver.resolve(p), resolver.resolveByBruteForce(p))
        }
    }

    func testIndexPrunesCandidates() {
        // The index must return far fewer candidates than a full scan — proof it isn't scanning.
        let count = 5000
        let (features, bounds) = SyntheticGeo.stressSet(
            count: count, bounds: BoundingBox(minX: 0, minY: 0, maxX: 2000, maxY: 2000), seed: 42)
        let index = SpatialIndex(boxes: features.map(\.boundingBox))
        var rng = SplitMix64(seed: 555)
        var totalCandidates = 0
        let queries = 2000
        for _ in 0..<queries {
            let p = Point2D(x: rng.double(in: bounds.minX...bounds.maxX),
                            y: rng.double(in: bounds.minY...bounds.maxY))
            totalCandidates += index.query(point: p).count
        }
        let avgCandidates = Double(totalCandidates) / Double(queries)
        // Deliberately overlapping bboxes mean >1 candidate per query, but still a tiny
        // fraction of the full set. Generous bound; typically single digits.
        XCTAssertGreaterThan(avgCandidates, 1.0, "bboxes should overlap → multiple candidates")
        XCTAssertLessThan(avgCandidates, Double(count) * 0.05,
                          "index should prune to <5% of the set, got \(avgCandidates)")
    }
}
