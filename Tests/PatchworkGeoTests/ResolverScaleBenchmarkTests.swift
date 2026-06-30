import XCTest
@testable import PatchworkGeo

/// Locked PR2 scale-sanity gate (see Patchwork.md conversation):
/// ≥10,000 synthetic polygons, ~50–200 vertices each, deliberately overlapping bounding boxes,
/// fixed-seed random queries across the full bounds, single-lookup p95 < 10 ms on the indexed
/// path in release mode. In DEBUG the measured p95 is printed but not asserted (debug timings
/// are not representative); the gate is enforced under `swift test -c release`. If the target
/// cannot be met, `Docs/RISK_LOG.md` records the named target, measured p95, and gap to 10 ms.
final class ResolverScaleBenchmarkTests: XCTestCase {

    func testIndexedLookupP95UnderThreshold() {
        let polygonCount = 10_000
        let queryCount = 5_000
        let bounds = BoundingBox(minX: -122.6, minY: 37.2, maxX: -121.7, maxY: 38.0) // Bay-Area-scale degrees
        let (features, qbounds) = SyntheticGeo.stressSet(count: polygonCount, bounds: bounds, seed: 2025)
        let resolver = FeatureResolver(features: features)

        // Pre-generate all query points (fixed seed) so timing excludes RNG cost.
        var rng = SplitMix64(seed: 777)
        var queries: [Point2D] = []
        queries.reserveCapacity(queryCount)
        for _ in 0..<queryCount {
            queries.append(Point2D(x: rng.double(in: qbounds.minX...qbounds.maxX),
                                   y: rng.double(in: qbounds.minY...qbounds.maxY)))
        }

        // Warm up (caches, first-touch faults) before measuring.
        for q in queries.prefix(200) { _ = resolver.resolve(q) }

        var timingsMs: [Double] = []
        timingsMs.reserveCapacity(queryCount)
        var sink = 0
        for q in queries {
            let start = DispatchTime.now().uptimeNanoseconds
            let id = resolver.resolve(q)
            let end = DispatchTime.now().uptimeNanoseconds
            timingsMs.append(Double(end - start) / 1_000_000.0)
            if id != nil { sink += 1 }
        }
        XCTAssertGreaterThanOrEqual(sink, 0) // keep the result observable

        timingsMs.sort()
        let p50 = SyntheticGeo.percentile(timingsMs, 0.50)
        let p95 = SyntheticGeo.percentile(timingsMs, 0.95)
        let p99 = SyntheticGeo.percentile(timingsMs, 0.99)
        let config: String = {
            #if DEBUG
            return "DEBUG"
            #else
            return "RELEASE"
            #endif
        }()
        print(String(format: "[scale-benchmark] config=%@ polygons=%d queries=%d p50=%.4fms p95=%.4fms p99=%.4fms",
                     config, polygonCount, queryCount, p50, p95, p99))

        #if !DEBUG
        XCTAssertLessThan(p95, 10.0,
            "indexed p95 \(p95)ms exceeded the 10ms gate; record target+measured+gap in Docs/RISK_LOG.md")
        #endif
    }
}
