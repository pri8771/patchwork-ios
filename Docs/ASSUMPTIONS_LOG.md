# Assumptions Log

_Last updated: 2026-06-29 after Build Task 1 of 18._

## Active Assumptions

1. Patchwork V1 targets iOS 17+ and uses SwiftData for user state only.
2. The first runnable implementation will be native iOS with a SwiftUI shell and MapKit rendered through a UIKit `MKMapView` bridge.
3. US-only V1 geography will be based on Census-derived ZCTA/county/state/Census-Place data pinned to the 2025 TIGER/Line vintage.
4. Runtime geodata will be bundled on device as compressed SQLite and/or binary assets, not giant runtime GeoJSON.
5. GeoJSON may be used only as an intermediate/debug artifact in offline tooling.
6. User-facing product copy will say "ZIP-like patches" or "postal areas" and will never say "official ZIP coverage."
7. The repository intentionally starts with documentation and empty placeholder folders before app code is introduced.
8. No backend, account system, analytics SDK, ad SDK, Firebase, Mapbox, MapLibre, React Native, Flutter, web code, iCloud sync, Android target, or multiplayer feature is planned for V1.

## Resolved Assumptions

- None yet.
