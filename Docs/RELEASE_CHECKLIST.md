# Release Checklist

This checklist tracks V1 readiness. Most items are intentionally unchecked after Build Task 1.

## Architecture and Policy

- [x] Locked V1 decisions documented.
- [x] V1 hard exclusions documented.
- [x] Local-only/offline-first privacy posture documented.
- [ ] Dependency review confirms no backend, Firebase, Mapbox, MapLibre, analytics SDK, ads SDK, accounts, web, React Native, or Flutter additions.

## App Foundation

- [ ] Swift package and/or Xcode project exists.
- [ ] iOS 17+ target is configured.
- [ ] SwiftUI app shell exists.
- [ ] UIKit `MKMapView` bridge exists.
- [ ] SwiftData local persistence exists.

## Geodata

- [ ] 2025 TIGER/Line vintage is pinned in tooling.
- [ ] Offline Census pipeline exists.
- [ ] Runtime geodata is compressed SQLite and/or binary, not giant runtime GeoJSON.
- [ ] Coordinate-to-ZCTA lookup is fully local.
- [ ] Weighted rollup lookup tables are generated and validated.

## Privacy and Monetization

- [ ] While-Using permission flow exists.
- [ ] "Claim Current Patch" action exists.
- [ ] StoreKit 2 Free, Pro annual, and Lifetime flows exist.
- [ ] No ads or data sales are present.
- [ ] Export/import/reset/privacy controls exist.

## Quality

- [ ] Swift package tests pass.
- [ ] Xcode build has been verified in an Xcode-capable environment.
- [ ] Performance guardrails are measured.
- [ ] Release hardening is complete.
