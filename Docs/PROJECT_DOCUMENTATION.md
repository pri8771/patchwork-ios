# Patchwork — Project Documentation

_Updated 2026-06-30 to match the shipped product and launch scope. See LAUNCH_READINESS.md._

> **Correction note:** A previous version of this file described a generic board/canvas piece-placement (jigsaw/tile) puzzle. That was stale and wrong. Patchwork is **not** a tile puzzle. It is a private, local-first, US-only iOS **map-completion game**. `README.md` and `Docs/LOCKED_V1_DECISIONS.md` are the binding source of truth; this document has been rewritten to match them.

GitHub is the source of truth for this project documentation. Notion indexes this file in the Priyansh App Factory Command Center.

## 00. Executive Summary
Patchwork is a native iOS, US-only, offline-first **map-completion game** — "Color the map you actually live." When a user physically enters a postal area (a Census ZCTA — ZIP-like, never claimed as official USPS ZIP coverage), that area becomes a translucent colored patch on a MapKit map. ZCTA coverage rolls up into city, county, state, and country completion as the user zooms out. It is for privacy-conscious people who enjoy quiet, personal "places I've been" progress without a social graph, account, or cloud. Everything — geography, location processing, progress, and rollups — stays on device. The end product includes permission education, manual "Claim Current Patch" capture, translucent patch rendering, weighted rollups, local persistence, privacy export/import/reset, and StoreKit 2 monetization. **Implementation status: pre-build / docs-only** (see `Docs/CURRENT_STATUS.md`).

## 01. Product
MVP scope: permission-education onboarding; CoreLocation capture with a user-initiated "Claim Current Patch" action (When-In-Use first, Always deferred); local coordinate→ZCTA resolution (spatial index → candidate polygons → point-in-polygon); a compact visited-ZCTA bitset; translucent patch overlays on a MapKit `MKMapView` bridge; weighted city/county/state/country rollups from precomputed lookup tables; SwiftData local persistence; export/import/reset privacy controls; and StoreKit 2 (Free / Pro annual / Lifetime). First-delight moment = the first patch colored. Acceptance criteria: a new user can grant location after honest education, claim their first patch correctly, and see it color and ladder up into city/state progress; low-confidence location fixes decline to color rather than color the wrong patch. Full per-feature acceptance criteria live in `LAUNCH_READINESS.md` §2.

## 02. Design
Calm, private, completion-oriented visuals. Translucent colored patches over a real map; clear distinction between visited and unvisited areas; colorblind-safe palette; calm-but-satisfying first-patch feedback. Screens: Welcome, Permission Education, Map (with "Claim Current Patch"), Progress/Rollups, Settings (export/import/reset, About/Privacy), Paywall. Geography copy must read "ZIP Code Areas (Census ZCTA boundaries)" / "ZIP-like patches," never "official ZIP coverage."

## 03. Frontend Technical
SwiftUI app shell hosting a UIKit `MKMapView` bridge (`UIViewRepresentable`). Patches render as `MKOverlay` / `MKMultiPolygon` / `MKMultiPolygonRenderer`. Performance via viewport culling, level-of-detail geometry simplification, and county/state fallback at broad zoom. Domain logic is pure Swift in `Sources/PatchworkCore`; geometry, spatial index, point-in-polygon, and rollups in `Sources/PatchworkGeo`; persistence and read-only geodata access in `Sources/PatchworkData`. State: a compact visited-ZCTA bitset, persisted via SwiftData (iOS 17+, user state only).

## 04. Backend Technical
No backend for v1 — this is a hard exclusion, not a deferral. All geography and location processing run on device. Heavy geodata is bundled read-only as compressed SQLite/binary (never giant runtime GeoJSON); coordinate-to-ZCTA resolution is fully local with no network reverse-geocoding. Future possibilities (post-v1, would require new decisions): optional iCloud sync, history/timeline. None are in v1.

## 05. Business
StoreKit 2 only: Free + Pro annual (default) + Lifetime. No ads, no data sales, no server receipt validation (on-device verification only). The exact free-vs-paid feature gate is an open product decision to be settled before the paywall finalizes (see `LAUNCH_READINESS.md` §7 NB-7).

## 06. Marketing
Positioning: a private map of everywhere you've actually been, that fills itself in and never leaves your phone. Honest framing of "ZIP-like patches" (Census ZCTA boundaries) is part of the pitch, not a footnote. Channels: privacy/cozy-game and map/geography communities, App Store feature pitch, road-trip/travel angles.

## 07. User Acquisition
Beta with privacy-conscious and map/exploration testers. Because there is **no analytics SDK**, metrics are local or beta-observable only: first-patch activation (local), patches/rollups over time (local), permission-grant rate after education (beta), and near-zero wrong-patch reports (beta).

## 08. Execution
Plan (smallest-risk-first, per `Docs/CODEX_BUILD_PLAN.md` and the agent conversation): correct stale docs → `Package.swift` + tests → core models/bitset → point-in-polygon → spatial index → weighted rollups → offline Census pipeline + sample dataset → runtime geodata repo → SwiftData → permission education → location capture/Claim → MapKit overlays + performance → first-delight + rollup UI → StoreKit 2 → export/import/reset → full geodata integration → release hardening. Build the data layer and prove correctness before any MapKit UI.

## 09. QA
Test point-in-polygon on hand-checked coordinate→ZCTA fixtures (including holes, multi-polygons, edges); spatial-index no-false-negatives + latency; weighted-rollup math with hand-computed values and 0%/100% boundaries; persistence relaunch survival; pipeline determinism + sample-dataset end-to-end; low-confidence-fix rejection; StoreKit purchase/restore; export/import round-trip; map performance and device sizes; accessibility (colorblind-safe palette, VoiceOver). When Xcode is unavailable in automation, run all possible Swift package tests and report Xcode build status as `UNVERIFIED_XCODE_ENVIRONMENT`, never "passed."

## 10. Legal / Compliance
No account or backend for v1; all data on device. Privacy manifest (`PrivacyInfo.xcprivacy`) and `Info.plist` `NSLocationWhenInUseUsageDescription` are required for App Review. Geography copy must not claim official USPS ZIP coverage. Census/TIGER attribution (2025 TIGER/Line vintage) included where appropriate. No analytics, no ads, no data sales.

## 11. Operations
Release process: internal correctness QA → labeled sample/limited geography beta → full geodata integration → TestFlight → App Store submission. Post-launch candidates (new decisions required): Always/background passive patch-filling behind a permission gate, history/timeline, daily challenges, themes, expanded geography.
