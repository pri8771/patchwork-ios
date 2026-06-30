# Current Status

_Last updated: 2026-06-30 — V1 implementation build (core libraries + iOS app + geo pipeline)._

## What Exists Now

### Verified Swift package (pure logic, `swift test` green)

- `Package.swift` with three dependency-free library targets and test targets.
- `PatchworkCore`: `ZCTACode`/`ZCTAIndex`, the compact `VisitedBitset` (with versioned binary
  serialization), `Region`/`WeightedRegion`, the `RollupEngine` (weighted sums, never runtime
  spatial intersection), `ProgressSnapshot`, and the deterministic `PatchPalette`.
- `PatchworkGeo`: `Coordinate`/`Point2D`/`BoundingBox`, `GeoPolygon` point-in-polygon (holes,
  concavity, boundary-inclusive), a bulk-loaded STR `SpatialIndex` (R-tree), and `FeatureResolver`
  (broad phase → narrow phase → stable-id boundary tie-break).
- `PatchworkData`: a system-SQLite reader (`SQLiteDatabase`), the `GeometryCodec` (mirrors the
  Python encoder), and `GeoDataStore` (loads the bundle, builds the resolver, serves rollups).
- 40 tests pass, including the locked correctness fixture (inside/outside/shared-edge/concave) and
  the non-degenerate scale benchmark.

### iOS app (builds for the iOS 17+ simulator via xcodegen + xcodebuild)

- SwiftUI shell: `PatchworkApp`, `RootView`, `MainTabView`, onboarding/loading/failed states.
- A Claude-designed design system (`Theme`, `Components`): warm-paper palette, terracotta accent,
  rounded display type, reusable cards/buttons/progress ring/bars/stat tiles.
- UIKit `MKMapView` bridge (`PatchMapView`) rendering `MKMultiPolygon` patch overlays with viewport
  culling and a county-merge LOD fallback at far zoom.
- Features: Onboarding (with the pre-permission trust/education + ZCTA-honesty screens), Map (Claim
  Current Patch + outcome card), Progress (ring, level breakdowns, non-punitive "this month"
  counter, recent timeline), Settings (export/import/reset, privacy, about), Paywall, and a
  privacy-safe Share card.
- Infrastructure: `LocationService` (While-Using-first, single-fix), SwiftData `PersistenceController`
  (user state only, no iCloud), `StoreManager` (StoreKit 2, on-device entitlements), and
  `ShareCardView`/renderer.

### Geodata pipeline + bundled sample

- `Tools/geo_build`: shared `geo_format.py`/`schema.sql`, a runnable stdlib `build_sample.py`, and
  the documented production `build_real.py` skeleton (pinned 2025 TIGER/Line).
- A shipped `patchwork-sample.sqlite` (~200 KB, 400 ZCTAs, 19 regions over the SF Bay Area) so the
  app runs end to end offline.

## Build and Verification Status

- Swift package tests: **passing** (`swift test`, 40 tests).
- iOS app build: **succeeds** for the iOS 17+ simulator (`xcodebuild`, Xcode 26). Launched and
  screenshot-verified (onboarding, map with patches, progress, settings, paywall).
- Lookup scale benchmark: **passing** the locked release-mode <10 ms p95 gate (see RISK_LOG).

## What Is Intentionally Deferred

- Full 33k-ZCTA national bundle + real-data lookup validation (separate data-bundle step).
- Always/background location (behind a later in-app permission gate, per locked decision #10).
- Real StoreKit product review/pricing finalization and App Store metadata/screenshots.
- App Store signing/distribution (the project builds unsigned for the simulator here).
