import Foundation
@testable import PatchworkGeo

/// Deterministic SplitMix64 PRNG so synthetic fixtures and benchmark queries are byte-for-byte
/// reproducible run to run (a seedable generator; Swift's system RNG is not seedable).
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func double(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) * (1.0 / 9007199254740992.0) // 53-bit mantissa
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
    mutating func int(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }
}

enum SyntheticGeo {
    /// Generates an irregular convex-ish blob polygon with `vertexCount` vertices around
    /// `center`, with per-vertex radius jitter so it isn't a trivial circle/rectangle.
    static func blob(center: Point2D, baseRadius: Double, vertexCount: Int,
                     rng: inout SplitMix64) -> GeoPolygon {
        var pts: [Point2D] = []
        pts.reserveCapacity(vertexCount)
        for i in 0..<vertexCount {
            let angle = (Double(i) / Double(vertexCount)) * 2 * Double.pi
            let r = baseRadius * rng.double(in: 0.6...1.25)
            pts.append(Point2D(x: center.x + r * cos(angle), y: center.y + r * sin(angle)))
        }
        return GeoPolygon(exterior: pts)
    }

    /// Builds a non-degenerate stress set per the locked PR2 benchmark spec:
    /// ≥`count` polygons, ~50–200 vertices each, deliberately overlapping bounding boxes so the
    /// broad phase returns multiple candidates for many queries. Deterministic for a given seed.
    static func stressSet(count: Int, bounds: BoundingBox, seed: UInt64)
        -> (features: [GeoFeature], bounds: BoundingBox) {
        var rng = SplitMix64(seed: seed)
        var features: [GeoFeature] = []
        features.reserveCapacity(count)
        // Spacing chosen so radius > spacing → neighboring boxes overlap.
        let cols = Int(Double(count).squareRoot().rounded(.up))
        let cellW = bounds.width / Double(cols)
        let cellH = bounds.height / Double(cols)
        let baseRadius = max(cellW, cellH) * 0.9 // > half-cell ⇒ overlapping bboxes
        for i in 0..<count {
            let col = i % cols
            let row = i / cols
            let cx = bounds.minX + (Double(col) + 0.5) * cellW + rng.double(in: -cellW*0.25...cellW*0.25)
            let cy = bounds.minY + (Double(row) + 0.5) * cellH + rng.double(in: -cellH*0.25...cellH*0.25)
            let verts = rng.int(in: 50...200)
            let poly = blob(center: Point2D(x: cx, y: cy), baseRadius: baseRadius,
                            vertexCount: verts, rng: &rng)
            features.append(GeoFeature(id: i, polygons: [poly]))
        }
        return (features, bounds)
    }

    static func percentile(_ sortedAscending: [Double], _ p: Double) -> Double {
        guard !sortedAscending.isEmpty else { return 0 }
        let rank = p * Double(sortedAscending.count - 1)
        let lo = Int(rank.rounded(.down))
        let hi = Int(rank.rounded(.up))
        if lo == hi { return sortedAscending[lo] }
        let frac = rank - Double(lo)
        return sortedAscending[lo] * (1 - frac) + sortedAscending[hi] * frac
    }
}
