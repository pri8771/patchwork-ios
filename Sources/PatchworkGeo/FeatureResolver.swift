import Foundation

/// Resolves a coordinate to the feature (ZCTA) that contains it, fully on device.
///
/// The pipeline is locked V1 decision #7: spatial index (broad phase) → candidate polygons →
/// point-in-polygon (narrow phase). There is no network reverse-geocoding. When a point lies
/// exactly on a shared border and multiple features contain it, the tie is broken by the
/// smallest stable feature id — deterministic and reproducible.
public struct FeatureResolver: Sendable {
    public let features: [GeoFeature]
    private let index: SpatialIndex
    /// Maps a feature's array position to its stable id, for tie-breaking.
    private let idForPosition: [Int]

    /// Builds a resolver over `features`. Features may be supplied in any order; the resolver
    /// indexes them by array position and tie-breaks by `GeoFeature.id`.
    public init(features: [GeoFeature], nodeSize: Int = 16) {
        self.features = features
        self.index = SpatialIndex(boxes: features.map(\.boundingBox), nodeSize: nodeSize)
        self.idForPosition = features.map(\.id)
    }

    /// Returns the stable id of the feature containing `coordinate`, or nil if none does.
    public func resolve(_ coordinate: Coordinate) -> Int? {
        resolve(coordinate.point)
    }

    /// Returns the stable id of the feature containing planar point `p`, or nil.
    public func resolve(_ p: Point2D) -> Int? {
        var bestID: Int? = nil
        for position in index.query(point: p) {
            let feature = features[position]
            guard feature.contains(p, boundaryInclusive: true) else { continue }
            // Boundary tie-break: keep the smallest stable id among all containers.
            if bestID == nil || feature.id < bestID! {
                bestID = feature.id
            }
        }
        return bestID
    }

    /// Reference implementation: scans every feature with no spatial index. Used only by tests
    /// to prove the indexed path returns identical results — never on the runtime path.
    public func resolveByBruteForce(_ p: Point2D) -> Int? {
        var bestID: Int? = nil
        for feature in features where feature.contains(p, boundaryInclusive: true) {
            if bestID == nil || feature.id < bestID! { bestID = feature.id }
        }
        return bestID
    }
}
