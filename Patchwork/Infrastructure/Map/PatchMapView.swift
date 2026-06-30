import SwiftUI
import MapKit
import PatchworkCore
import PatchworkData
import PatchworkGeo

/// SwiftUI shell over a UIKit `MKMapView` (locked decision #3). Renders the user's filled
/// patches as translucent `MKMultiPolygon` overlays. Performance strategy:
///  - viewport culling: only ZCTA overlays intersecting the visible rect are built;
///  - LOD / county fallback: when zoomed out past a threshold, individual ZCTAs collapse into
///    one merged overlay per county, shaded by completion — far fewer overlays at national scale;
///  - the heavy geometry stays bundled read-only and is never re-fetched.
struct PatchMapView: UIViewRepresentable {
    let geoStore: GeoDataStore
    /// Indices of visited ZCTAs (the filled patches).
    let visitedIndices: Set<Int>
    /// Bumped whenever `visitedIndices` changes, to trigger an overlay rebuild.
    let visitedVersion: Int
    /// Completion (0…1) per county region id, for the far-zoom shading.
    let countyCompletion: [String: Double]
    /// A request to recenter the camera (e.g. after a claim or "find me").
    var recenter: MKCoordinateRegion?
    /// Called when the user taps inside a ZCTA.
    var onTapZCTA: ((Int) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.pointOfInterestFilter = .excludingAll
        map.showsUserLocation = true
        map.showsCompass = true
        map.mapType = .mutedStandard
        // Start framed to the dataset bounds.
        let b = geoStore.metadata.bounds
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (b.minY + b.maxY) / 2,
                                           longitude: (b.minX + b.maxX) / 2),
            span: MKCoordinateSpan(latitudeDelta: (b.maxY - b.minY) * 1.15,
                                   longitudeDelta: (b.maxX - b.minX) * 1.15))
        map.setRegion(region, animated: false)

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        map.addGestureRecognizer(tap)

        context.coordinator.rebuildOverlays(on: map)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coord = context.coordinator
        if coord.lastVisitedVersion != visitedVersion {
            coord.lastVisitedVersion = visitedVersion
            coord.parent = self
            coord.rebuildOverlays(on: map)
        } else {
            coord.parent = self
        }
        if let recenter, !coord.regionsEqual(recenter, coord.lastRecenter) {
            coord.lastRecenter = recenter
            map.setRegion(recenter, animated: true)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: PatchMapView
        var lastVisitedVersion = -1
        var lastRecenter: MKCoordinateRegion?
        /// Above this latitude span (roughly multi-metro / continental zoom) we switch to
        /// county-fallback rendering. Below it, the individual ZCTA quilt shows.
        private let countyFallbackSpan = 1.2
        /// Cached merged county overlays (built once).
        private var countyOverlays: [PatchOverlay] = []
        private var regionUpdateWorkItem: DispatchWorkItem?

        init(_ parent: PatchMapView) {
            self.parent = parent
            super.init()
        }

        func regionsEqual(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion?) -> Bool {
            guard let b else { return false }
            return abs(a.center.latitude - b.center.latitude) < 1e-6 &&
                   abs(a.center.longitude - b.center.longitude) < 1e-6 &&
                   abs(a.span.latitudeDelta - b.span.latitudeDelta) < 1e-6
        }

        private func buildCountyOverlaysIfNeeded() {
            guard countyOverlays.isEmpty else { return }
            for region in parent.geoStore.regions(of: .county) {
                var polys: [MKPolygon] = []
                for member in region.members {
                    polys.append(contentsOf:
                        MapGeometry.mkPolygons(from: parent.geoStore.polygons(forIndex: member.zctaIndex)))
                }
                guard !polys.isEmpty else { continue }
                countyOverlays.append(PatchOverlay(polygons: polys,
                                                   kind: .countyFill(regionID: region.region.id)))
            }
        }

        /// Rebuilds overlays for the current viewport + zoom level.
        func rebuildOverlays(on map: MKMapView) {
            map.removeOverlays(map.overlays)
            let span = map.region.span.latitudeDelta

            if span > countyFallbackSpan {
                // Far zoom: one merged overlay per county.
                buildCountyOverlaysIfNeeded()
                map.addOverlays(countyOverlays)
                return
            }

            // Near zoom: per-ZCTA patches + outlines, culled to the visible rect.
            let visibleRect = map.visibleMapRect
            var newOverlays: [PatchOverlay] = []
            let features = parent.geoStore.resolver.features
            for feature in features {
                let b = feature.boundingBox
                let fRect = MKMapRect(
                    origin: MKMapPoint(CLLocationCoordinate2D(latitude: b.maxY, longitude: b.minX)),
                    size: MKMapSize(width: 0, height: 0))
                let corner2 = MKMapPoint(CLLocationCoordinate2D(latitude: b.minY, longitude: b.maxX))
                let rect = fRect.union(MKMapRect(origin: corner2, size: MKMapSize(width: 0, height: 0)))
                guard visibleRect.intersects(rect) else { continue }

                let polys = MapGeometry.mkPolygons(from: feature.polygons)
                guard !polys.isEmpty else { continue }
                if parent.visitedIndices.contains(feature.id) {
                    newOverlays.append(PatchOverlay(polygons: polys, kind: .patch(zctaIndex: feature.id)))
                } else {
                    newOverlays.append(PatchOverlay(polygons: polys, kind: .outline(zctaIndex: feature.id)))
                }
            }
            map.addOverlays(newOverlays)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Debounce viewport-driven rebuilds so panning stays smooth.
            regionUpdateWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self, weak mapView] in
                guard let self, let mapView else { return }
                self.rebuildOverlays(on: mapView)
            }
            regionUpdateWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let patch = overlay as? PatchOverlay else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKMultiPolygonRenderer(multiPolygon: patch)
            switch patch.kind {
            case .patch(let idx):
                let color = UIColor(patchColor: PatchPalette.color(for: idx))
                renderer.fillColor = color.withAlphaComponent(0.55)
                renderer.strokeColor = color.withAlphaComponent(0.95)
                renderer.lineWidth = 1
            case .outline:
                renderer.fillColor = .clear
                renderer.strokeColor = UIColor.label.withAlphaComponent(0.16)
                renderer.lineWidth = 0.5
            case .countyFill(let regionID):
                let completion = parent.countyCompletion[regionID] ?? 0
                let accent = UIColor(Theme.Palette.accent)
                renderer.fillColor = accent.withAlphaComponent(0.10 + 0.55 * completion)
                renderer.strokeColor = accent.withAlphaComponent(0.45)
                renderer.lineWidth = 1
            }
            return renderer
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MKMapView, let onTap = parent.onTapZCTA else { return }
            let point = gesture.location(in: map)
            let coordinate = map.convert(point, toCoordinateFrom: map)
            if let idx = parent.geoStore.resolveIndex(
                Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)) {
                onTap(idx)
            }
        }
    }
}

extension UIColor {
    /// Builds a UIColor from a `PatchworkCore.PatchColor`.
    convenience init(patchColor: PatchColor) {
        self.init(hue: patchColor.hue, saturation: patchColor.saturation,
                  brightness: patchColor.brightness, alpha: 1.0)
    }
}
