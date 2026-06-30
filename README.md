# Patchwork iOS

Patchwork is a private, local-first iOS map-completion game.

> "Color the map you actually live."

Postal areas you physically enter become translucent colored patches that roll up into city, county, state, and country completion as you zoom out.

## V1 Product Rules

- Native iOS only.
- US-only V1.
- Offline-first and fully on-device.
- SwiftUI shell with MapKit rendered through a UIKit `MKMapView` bridge.
- Census-derived local ZCTA/county/state/Census-Place data pinned to the 2025 TIGER/Line vintage.
- Runtime geodata ships as compressed SQLite and/or binary assets, not giant runtime GeoJSON.
- Product copy must say "ZIP-like patches" or "postal areas," never "official ZIP coverage."

## Local-Only Rule

Patchwork V1 must not introduce a backend, Firebase, accounts, leaderboard, social graph, Mapbox, MapLibre, ads, analytics SDK, server receipt validation, iCloud sync, Android, web, multiplayer, React Native, or Flutter. Geography, location processing, user progress, and rollups stay on device.

## Repository Layout

- `Docs/`: canonical source-of-truth documentation.
- `Patchwork/App`: future app entry point and lifecycle code.
- `Patchwork/DesignSystem`: future visual system and shared UI tokens.
- `Patchwork/Features`: future feature screens and flows.
- `Patchwork/Infrastructure`: future platform integrations such as MapKit, location, persistence wiring, and StoreKit.
- `Patchwork/Resources`: future bundled assets and geodata resources.
- `Sources/PatchworkCore`: future pure domain logic.
- `Sources/PatchworkGeo`: future geospatial algorithms and rollups.
- `Sources/PatchworkData`: future persistence and geodata repository code.
- `Tests/`: future automated tests.
- `Tools/geo_build/`: future offline Census geodata pipeline.

## Repository Shape

- `Package.swift` + `Sources/` + `Tests/`: the pure, UI-independent libraries (`PatchworkCore`, `PatchworkGeo`, `PatchworkData`) and their `swift test` suite. No third-party dependencies; SQLite uses the system library.
- `project.yml`: the [xcodegen](https://github.com/yonsm/XcodeGen) spec for the iOS app. The `Patchwork.xcodeproj` is generated and git-ignored.
- `Patchwork/`: the SwiftUI app (App, DesignSystem, Features, Infrastructure, Resources). Links the local Swift package.
- `Tools/geo_build/`: the offline Census geodata pipeline (stdlib sample builder + production TIGER/Line skeleton).

## Build & Test

```bash
# Pure logic libraries (no Xcode/simulator needed):
swift test                         # all core/geo/data tests
swift test -c release --filter ResolverScaleBenchmarkTests   # locked <10ms p95 lookup gate

# iOS app:
brew install xcodegen              # one-time
make bootstrap                     # xcodegen generate → Patchwork.xcodeproj
make build-app                     # xcodebuild for the simulator
```

`make sample` regenerates the bundled sample geodata; `make icon` regenerates the app icon.

## Build Status

- Swift package tests: **passing** (`swift test`).
- iOS app: **builds for the iOS 17+ simulator** (`xcodebuild`, Xcode 26).
- Lookup scale benchmark: **passing** the locked release-mode gate (synthetic 10k-polygon set; see `Docs/RISK_LOG.md`). Full 33k-ZCTA real-data validation is a deliberate later step.
