import XCTest
@testable import PatchworkGeo

/// Locked PR2 correctness fixture: two adjacent polygons sharing an edge, a point clearly
/// inside each, a point outside both, a point exactly on the shared edge (deterministic tie),
/// and a concave shape. Synthetic + deterministic, no real-data licensing.
final class PointInPolygonTests: XCTestCase {

    // Polygon A: unit square [0,1] x [0,1]. Polygon B: [1,2] x [0,1]. They share edge x = 1.
    private func unitSquare(x0: Double, x1: Double, y0: Double, y1: Double) -> GeoPolygon {
        GeoPolygon(exterior: [
            Point2D(x: x0, y: y0), Point2D(x: x1, y: y0),
            Point2D(x: x1, y: y1), Point2D(x: x0, y: y1)
        ])
    }

    func testInsideEach() {
        let a = unitSquare(x0: 0, x1: 1, y0: 0, y1: 1)
        let b = unitSquare(x0: 1, x1: 2, y0: 0, y1: 1)
        XCTAssertTrue(a.contains(Point2D(x: 0.5, y: 0.5)))
        XCTAssertFalse(b.contains(Point2D(x: 0.5, y: 0.5)))
        XCTAssertTrue(b.contains(Point2D(x: 1.5, y: 0.5)))
        XCTAssertFalse(a.contains(Point2D(x: 1.5, y: 0.5)))
    }

    func testOutsideBoth() {
        let a = unitSquare(x0: 0, x1: 1, y0: 0, y1: 1)
        let b = unitSquare(x0: 1, x1: 2, y0: 0, y1: 1)
        let p = Point2D(x: 3.0, y: 3.0)
        XCTAssertFalse(a.contains(p))
        XCTAssertFalse(b.contains(p))
    }

    func testOnSharedEdgeBoundaryInclusive() {
        let a = unitSquare(x0: 0, x1: 1, y0: 0, y1: 1)
        let b = unitSquare(x0: 1, x1: 2, y0: 0, y1: 1)
        let onEdge = Point2D(x: 1.0, y: 0.5)
        // Boundary-inclusive: both adjacent polygons claim the shared point.
        XCTAssertTrue(a.contains(onEdge, boundaryInclusive: true))
        XCTAssertTrue(b.contains(onEdge, boundaryInclusive: true))
    }

    func testSharedEdgeTieBreaksByStableId() {
        // Feature ids 7 and 3 both contain the shared-edge point; smallest id (3) must win.
        let a = GeoFeature(id: 7, polygons: [unitSquare(x0: 0, x1: 1, y0: 0, y1: 1)])
        let b = GeoFeature(id: 3, polygons: [unitSquare(x0: 1, x1: 2, y0: 0, y1: 1)])
        let resolver = FeatureResolver(features: [a, b])
        XCTAssertEqual(resolver.resolve(Point2D(x: 1.0, y: 0.5)), 3)
    }

    func testConcaveContainment() {
        // An L-shaped (concave) polygon. The notch must read as outside.
        let l = GeoPolygon(exterior: [
            Point2D(x: 0, y: 0), Point2D(x: 4, y: 0), Point2D(x: 4, y: 1),
            Point2D(x: 1, y: 1), Point2D(x: 1, y: 4), Point2D(x: 0, y: 4)
        ])
        XCTAssertTrue(l.contains(Point2D(x: 0.5, y: 3.0)))   // in the vertical arm
        XCTAssertTrue(l.contains(Point2D(x: 3.0, y: 0.5)))   // in the horizontal arm
        XCTAssertFalse(l.contains(Point2D(x: 3.0, y: 3.0)))  // in the concave notch
    }

    func testPolygonWithHole() {
        // 0..10 square with a 4..6 square hole.
        let poly = GeoPolygon(
            exterior: [Point2D(x: 0, y: 0), Point2D(x: 10, y: 0),
                       Point2D(x: 10, y: 10), Point2D(x: 0, y: 10)],
            holes: [[Point2D(x: 4, y: 4), Point2D(x: 6, y: 4),
                     Point2D(x: 6, y: 6), Point2D(x: 4, y: 6)]]
        )
        XCTAssertTrue(poly.contains(Point2D(x: 1, y: 1)))    // in ring, outside hole
        XCTAssertFalse(poly.contains(Point2D(x: 5, y: 5)))   // strictly inside hole → outside
        XCTAssertTrue(poly.contains(Point2D(x: 4, y: 5)))    // on hole boundary → inside polygon
    }

    func testMultiPolygonFeature() {
        // Two disjoint islands form one feature.
        let f = GeoFeature(id: 1, polygons: [
            unitSquare(x0: 0, x1: 1, y0: 0, y1: 1),
            unitSquare(x0: 5, x1: 6, y0: 5, y1: 6)
        ])
        XCTAssertTrue(f.contains(Point2D(x: 0.5, y: 0.5)))
        XCTAssertTrue(f.contains(Point2D(x: 5.5, y: 5.5)))
        XCTAssertFalse(f.contains(Point2D(x: 3.0, y: 3.0)))
    }
}
