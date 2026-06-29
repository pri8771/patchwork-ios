# Patchwork V1 Architecture

## Overview

Patchwork V1 is a native iOS, US-only, offline-first map-completion game. Users color translucent postal-area patches by physically entering them. Completion rolls up from ZCTA-level coverage into city, county, state, and country progress as map zoom changes.

## Non-Negotiable Architecture Constraints

- Native iOS only.
- SwiftUI app shell.
- Map rendering through MapKit using a UIKit `MKMapView` bridge.
- Overlay rendering via `MKOverlay`, `MKMultiPolygon`, and `MKMultiPolygonRenderer`.
- All geography and location processing runs on device.
- No backend, accounts, analytics, ads, Firebase, Mapbox, MapLibre, React Native, Flutter, web code, or server receipt validation.

## Baseline Module Layout

- `Patchwork/App`: future iOS app entry point, scene composition, and app lifecycle.
- `Patchwork/DesignSystem`: future shared colors, typography, components, and visual tokens.
- `Patchwork/Features`: future feature-level SwiftUI screens and flows.
- `Patchwork/Infrastructure`: future platform adapters such as location, StoreKit, persistence wiring, and MapKit bridge code.
- `Patchwork/Resources`: future bundled assets, sample geodata, local strings, and app resources.
- `Sources/PatchworkCore`: future pure Swift domain models and algorithms that do not depend on UI frameworks.
- `Sources/PatchworkGeo`: future geometry, spatial index, point-in-polygon, and rollup logic.
- `Sources/PatchworkData`: future persistence, bundled geodata repository, and read-only asset access.
- `Tests`: future Swift package tests.
- `Tools/geo_build`: future offline Census/TIGER processing scripts and pipeline documentation.
- `Docs`: canonical project documentation.

## Data Architecture

Patchwork V1 geography is Census-derived and pinned to the 2025 TIGER/Line vintage. Runtime geodata must be shipped as compressed SQLite and/or binary assets. Giant runtime GeoJSON is forbidden; GeoJSON may only appear as an intermediate or debug artifact in tooling.

User progress is represented as a compact visited-ZCTA bitset. Heavy geodata is bundled read-only; user state is stored locally via SwiftData on iOS 17+.

## Geospatial Runtime Path

1. Location sample is obtained with user permission.
2. Coordinate is resolved locally through a spatial index.
3. Candidate polygons are checked with point-in-polygon.
4. Matching ZCTA bit is set in the visited bitset.
5. City, county, state, and country completion are computed from precomputed weighted-overlap lookup tables.
6. Runtime rollups use weighted sums and do not perform spatial intersections.

## Map Rendering Strategy

The app uses a SwiftUI shell containing a UIKit `MKMapView` bridge. Filled patches render as translucent MapKit overlays. Performance strategy is:

- viewport culling;
- level-of-detail geometry simplification;
- county/state fallback at broader zoom levels;
- avoid loading or rendering all high-detail ZCTA polygons at once.

## Monetization

StoreKit 2 is the only V1 monetization path. V1 supports Free, Pro annual by default, and Lifetime. V1 has no ads and no data sales.
