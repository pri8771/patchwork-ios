# Patchwork iOS

_Updated 2026-06-30 to match the shipped product and launch scope. See [LAUNCH_READINESS.md](LAUNCH_READINESS.md)._

Patchwork is a private, local-first iOS map-completion game.

> "Color the map you actually live."

**Implementation status: pre-build / docs-only.** This repo currently contains documentation plus empty placeholder folders — no `Package.swift`, no Xcode project, no Swift source, no geodata, and no tests yet. `LAUNCH_READINESS.md` is the authoritative build-to spec (PRD, MVP feature list with acceptance criteria, user flows, bug/risk triage, and the ordered build path).

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

## Build Notes

No Xcode project, Swift package manifest, app target, or tests exist yet. Until those are added, Swift package tests are unavailable and Xcode build status is `UNVERIFIED_XCODE_ENVIRONMENT`.

When Xcode is unavailable in automation, run all possible Swift package tests and report the Xcode build status as `UNVERIFIED_XCODE_ENVIRONMENT`, never as passed.
