import Foundation

/// A planar 2D point. For geographic data we map `x = longitude`, `y = latitude` and treat
/// the small lat/lon neighborhood of a single ZCTA as locally planar — accurate enough for
/// point-in-polygon containment at ZCTA scale, and exactly what the offline pipeline assumes.
public struct Point2D: Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// A WGS84 geographic coordinate.
public struct Coordinate: Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Planar projection used by the geometry layer (`x = longitude`, `y = latitude`).
    public var point: Point2D { Point2D(x: longitude, y: latitude) }
}

/// An axis-aligned bounding box in planar coordinates. The broad phase of every spatial
/// query reduces to cheap bbox intersection tests over these.
public struct BoundingBox: Hashable, Sendable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    /// A zero-area box at a single point — the query box for a coordinate lookup.
    public init(point p: Point2D) {
        self.init(minX: p.x, minY: p.y, maxX: p.x, maxY: p.y)
    }

    /// The bounding box of a set of points. Returns nil for an empty input.
    public init?(points: [Point2D]) {
        guard let first = points.first else { return nil }
        var box = BoundingBox(minX: first.x, minY: first.y, maxX: first.x, maxY: first.y)
        for p in points.dropFirst() { box.expand(toInclude: p) }
        self = box
    }

    public var centerX: Double { (minX + maxX) / 2 }
    public var centerY: Double { (minY + maxY) / 2 }
    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }

    @inline(__always)
    public func contains(_ p: Point2D) -> Bool {
        p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY
    }

    @inline(__always)
    public func intersects(_ other: BoundingBox) -> Bool {
        minX <= other.maxX && maxX >= other.minX &&
        minY <= other.maxY && maxY >= other.minY
    }

    public mutating func expand(toInclude p: Point2D) {
        if p.x < minX { minX = p.x }
        if p.y < minY { minY = p.y }
        if p.x > maxX { maxX = p.x }
        if p.y > maxY { maxY = p.y }
    }

    public mutating func expand(toInclude other: BoundingBox) {
        if other.minX < minX { minX = other.minX }
        if other.minY < minY { minY = other.minY }
        if other.maxX > maxX { maxX = other.maxX }
        if other.maxY > maxY { maxY = other.maxY }
    }

    public func union(_ other: BoundingBox) -> BoundingBox {
        var b = self
        b.expand(toInclude: other)
        return b
    }
}
