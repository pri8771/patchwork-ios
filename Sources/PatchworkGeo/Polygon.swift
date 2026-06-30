import Foundation

/// A single closed polygon: one exterior ring plus zero or more holes.
///
/// Rings are stored as ordered vertex lists; an explicit closing vertex (first == last) is
/// optional and handled by the containment math either way. Point-in-polygon is the narrow
/// phase of ZCTA resolution — the broad phase (the R-tree) decides *which* polygons to test.
public struct GeoPolygon: Sendable {
    public let exterior: [Point2D]
    public let holes: [[Point2D]]
    public let boundingBox: BoundingBox

    public init(exterior: [Point2D], holes: [[Point2D]] = []) {
        self.exterior = exterior
        self.holes = holes
        self.boundingBox = BoundingBox(points: exterior)
            ?? BoundingBox(minX: 0, minY: 0, maxX: 0, maxY: 0)
    }

    /// True if `p` is inside the polygon (outside any hole).
    ///
    /// - Parameter boundaryInclusive: when true, points exactly on the exterior boundary
    ///   count as inside. ZCTA resolution uses this so a coordinate on a shared border is
    ///   "contained" by both adjacent polygons; the resolver then breaks the tie by stable
    ///   id ordering (locked V1 boundary rule). Points on a *hole* boundary are always
    ///   treated as inside the polygon (they sit on the ring, not in the void).
    public func contains(_ p: Point2D, boundaryInclusive: Bool = true) -> Bool {
        guard boundingBox.contains(p) else { return false }
        let onExterior = boundaryInclusive && GeoPolygon.isOnRing(p, ring: exterior)
        guard onExterior || GeoPolygon.rayCastInside(p, ring: exterior) else { return false }
        // Inside the exterior: reject only if strictly inside a hole (not merely on its edge).
        for hole in holes {
            if GeoPolygon.rayCastInside(p, ring: hole), !GeoPolygon.isOnRing(p, ring: hole) {
                return false
            }
        }
        return true
    }

    // MARK: - Ring math

    /// Even-odd ray-casting test for strict interior of a single ring. Boundary results are
    /// intentionally not relied upon here; callers add an explicit on-edge check when needed.
    static func rayCastInside(_ p: Point2D, ring: [Point2D]) -> Bool {
        let n = ring.count
        guard n >= 3 else { return false }
        var inside = false
        var j = n - 1
        for i in 0..<n {
            let a = ring[i]
            let b = ring[j]
            // Does a horizontal ray from p cross edge (a,b)?
            if (a.y > p.y) != (b.y > p.y) {
                let t = (p.y - a.y) / (b.y - a.y)
                let xCross = a.x + t * (b.x - a.x)
                if p.x < xCross { inside.toggle() }
            }
            j = i
        }
        return inside
    }

    /// True if `p` lies on any edge segment of `ring` (within a tiny epsilon).
    static func isOnRing(_ p: Point2D, ring: [Point2D], epsilon: Double = 1e-12) -> Bool {
        let n = ring.count
        guard n >= 2 else { return false }
        var j = n - 1
        for i in 0..<n {
            if isOnSegment(p, a: ring[j], b: ring[i], epsilon: epsilon) { return true }
            j = i
        }
        return false
    }

    /// True if `p` lies on segment `a–b`.
    static func isOnSegment(_ p: Point2D, a: Point2D, b: Point2D, epsilon: Double) -> Bool {
        // Collinearity via cross product, then bounds check along the segment.
        let cross = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
        let abLenSq = (b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)
        if abLenSq == 0 { // degenerate segment (a == b)
            let dx = p.x - a.x, dy = p.y - a.y
            return dx * dx + dy * dy <= epsilon * epsilon
        }
        // Perpendicular distance squared = cross² / |ab|².
        if (cross * cross) > epsilon * epsilon * abLenSq { return false }
        let dot = (p.x - a.x) * (b.x - a.x) + (p.y - a.y) * (b.y - a.y)
        return dot >= -epsilon && dot <= abLenSq + epsilon
    }
}

/// A geographic feature with a stable id and one or more polygons (ZCTAs can be multipart,
/// e.g. islands). `id` is the stable identifier used for the boundary tie-break and maps to
/// a `ZCTAIndex` in the data layer.
public struct GeoFeature: Sendable {
    public let id: Int
    public let polygons: [GeoPolygon]
    public let boundingBox: BoundingBox

    public init(id: Int, polygons: [GeoPolygon]) {
        self.id = id
        self.polygons = polygons
        var box = polygons.first?.boundingBox ?? BoundingBox(minX: 0, minY: 0, maxX: 0, maxY: 0)
        for poly in polygons.dropFirst() { box.expand(toInclude: poly.boundingBox) }
        self.boundingBox = box
    }

    public func contains(_ p: Point2D, boundaryInclusive: Bool = true) -> Bool {
        guard boundingBox.contains(p) else { return false }
        for poly in polygons where poly.contains(p, boundaryInclusive: boundaryInclusive) {
            return true
        }
        return false
    }
}
