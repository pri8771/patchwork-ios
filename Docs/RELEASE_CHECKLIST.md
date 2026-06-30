# Release Checklist

V1 readiness. Updated after the implementation build.

## Architecture and Policy

- [x] Locked V1 decisions documented.
- [x] V1 hard exclusions documented.
- [x] Local-only/offline-first privacy posture documented.
- [x] Dependency review confirms no backend, Firebase, Mapbox, MapLibre, analytics SDK, ads SDK,
      accounts, web, React Native, or Flutter additions. (Only system frameworks + system SQLite.)

## App Foundation

- [x] Swift package and Xcode project exist (`Package.swift` + `project.yml`/xcodegen).
- [x] iOS 17+ target is configured.
- [x] SwiftUI app shell exists.
- [x] UIKit `MKMapView` bridge exists (`MKMultiPolygon` overlays, viewport culling, county LOD).
- [x] SwiftData local persistence exists (user state only, no iCloud).

## Geodata

- [x] 2025 TIGER/Line vintage is pinned in tooling.
- [x] Offline Census pipeline exists (stdlib sample builder + production skeleton).
- [x] Runtime geodata is compressed SQLite / binary, not giant runtime GeoJSON.
- [x] Coordinate-to-ZCTA lookup is fully local (R-tree + point-in-polygon).
- [x] Weighted rollup lookup tables are generated and validated (weights sum to 1.0 in tests).
- [ ] Full 33k-ZCTA national bundle generated and validated on real data. _(Deferred: run `build_real.py`.)_

## Privacy and Monetization

- [x] While-Using permission flow exists (with pre-permission education + ZCTA-honesty screens).
- [x] "Claim Current Patch" action exists.
- [x] StoreKit 2 Free + Pro annual + Lifetime flows exist (no ads, no data sales).
- [x] Export / import / reset privacy controls exist.
- [x] Share cards are privacy-safe (region-level only).
- [ ] Real StoreKit products configured in App Store Connect; pricing finalized.

## Quality

- [x] Swift package tests pass (`swift test`, 40 tests).
- [x] App-layer tests pass (`PatchworkTests`, 7 tests via `xcodebuild test`).
- [x] Xcode build verified in an Xcode-capable environment (Xcode 26, iOS 17+ simulator).
- [x] Lookup performance measured against the locked release-mode p95 gate (see RISK_LOG).
- [x] Core loop verified in the running app (claim → outcome → persist → rollup; tap-to-inspect).
- [ ] On-device performance pass on real iPhone hardware with the national bundle.
- [ ] App Store metadata, screenshots, privacy nutrition label, and signing.
- [ ] Full accessibility + Dynamic Type sweep on every screen (key controls labeled).
