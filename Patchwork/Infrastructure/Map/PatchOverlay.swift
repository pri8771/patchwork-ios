import MapKit
import PatchworkGeo

/// What a map overlay represents, so the renderer can style it.
enum PatchOverlayKind {
    /// A visited ZCTA, drawn as a filled translucent patch.
    case patch(zctaIndex: Int)
    /// An unvisited ZCTA in the viewport, drawn as a faint outline (near zoom only).
    case outline(zctaIndex: Int)
    /// A whole county merged into one overlay, shaded by completion (far-zoom LOD fallback).
    case countyFill(regionID: String)
}

/// An `MKMultiPolygon` that carries Patchwork styling metadata. Subclassing keeps the overlay →
/// renderer mapping a constant-time lookup instead of a side table.
final class PatchOverlay: MKMultiPolygon {
    var kind: PatchOverlayKind = .outline(zctaIndex: -1)

    convenience init(polygons: [MKPolygon], kind: PatchOverlayKind) {
        self.init(polygons)
        self.kind = kind
    }
}

enum MapGeometry {
    /// Converts a feature's `GeoPolygon`s (x = lon, y = lat) into MapKit polygons, holes included.
    static func mkPolygons(from polygons: [GeoPolygon]) -> [MKPolygon] {
        polygons.map { poly in
            let exterior = poly.exterior.map {
                CLLocationCoordinate2D(latitude: $0.y, longitude: $0.x)
            }
            let interior = poly.holes.map { ring -> MKPolygon in
                let coords = ring.map { CLLocationCoordinate2D(latitude: $0.y, longitude: $0.x) }
                return MKPolygon(coordinates: coords, count: coords.count)
            }
            return MKPolygon(coordinates: exterior, count: exterior.count,
                             interiorPolygons: interior.isEmpty ? nil : interior)
        }
    }
}
