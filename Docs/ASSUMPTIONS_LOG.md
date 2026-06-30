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

- The first runnable implementation is native iOS, SwiftUI shell, MapKit via a UIKit `MKMapView`
  bridge with `MKMultiPolygon` overlays — **implemented and simulator-verified.**
- Coordinate→ZCTA resolution is fully on-device (STR R-tree broad phase → point-in-polygon narrow
  phase → stable-id boundary tie) — **implemented and tested**; no network reverse-geocoding.
- Runtime geodata ships as compressed SQLite with a shared binary polygon encoding — **implemented**;
  a 400-ZCTA SF Bay Area sample bundle ships, with the production TIGER/Line pipeline skeletoned.
- User progress is a compact visited-ZCTA bitset persisted via SwiftData (user state only) —
  **implemented**; rollups are weighted sums over precomputed tables.

## New Assumptions (V1 implementation)

1. **Free vs Pro gating is non-punitive.** Core play (claiming, the map, basic progress) is free
   with no patch cap; Pro unlocks cosmetics/polish (palettes, watermark-free hi-res share cards,
   deeper breakdowns, future region packs). No dark patterns — consistent with the trust spine.
2. **Share cards are region-level only** (state/county/city counts + percentages, abstract quilt
   motif keyed to patch *count*) — never ZCTA-level fill, coordinates, or timestamps — so a share
   cannot reconstruct where the user lives or moves.
3. **The bundled dataset for V1 is the SF Bay Area sample.** Shipping nationally requires running
   `build_real.py` to produce `patchwork-national.sqlite`; the app reads either via the same schema.
4. **The Xcode project is generated** from `project.yml` via xcodegen (git-ignored), so the source
   of truth is the spec, not a checked-in `.pbxproj`.
5. **Dev/screenshot launch arguments** (`-PWDemoSeed`, `-PWStartTab`, `-PWShowPaywall`) are gated by
   `ProcessInfo` and never present in a production launch.
