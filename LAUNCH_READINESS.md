# Patchwork — Launch Readiness (v1)

> Patchwork is a private, local-first, US-only iOS map-completion game — "Color the map you actually live." As you physically enter a postal area (a Census ZCTA, ZIP-like, never claimed as official USPS ZIP coverage), that area becomes a translucent colored patch on a MapKit map; ZCTA coverage rolls up into city, county, state, and country completion as you zoom out. It is built for people who like quiet, personal progress and the "places I've been" map genre, minus the social/tracking baggage. All geography, location processing, progress, and rollups stay on device — no backend, accounts, analytics, or ads.
>
> **Implementation maturity: PRE-BUILD / DOCS-ONLY.** The repository today contains canonical documentation (`README.md`, `Docs/*`) plus ten empty `.gitkeep` placeholder folders. There is **no `Package.swift`, no `*.xcodeproj`, no Swift source, no `Info.plist`, no `PrivacyInfo.xcprivacy`, no `*.storekit` config, no geodata assets, and no tests** (verified by file inventory; only `Docs/CURRENT_STATUS.md` candidly records the same). One stale doc (`Docs/PROJECT_DOCUMENTATION.md`) previously described a generic board/canvas piece-placement puzzle — it has been rewritten as part of this launch-readiness pass to match the real map-completion product. **This `LAUNCH_READINESS.md` is the authoritative build-to spec.** Every feature below is therefore "Not built" against code; status reflects whether the design decision is locked, not whether code exists. See `Docs/LOCKED_V1_DECISIONS.md` for the binding constraints this spec is derived from.

---

## 1. PRD / Launch Scope

### Problem & insight
"Places I've been" map apps exist, but they fall into two traps: they either demand a social graph / cloud account and harvest continuous location to a server (a trust problem), or they reward you for *checking in* (effort, gamified vanity) rather than for simply *living somewhere*. The insight: the satisfying part is watching a personal map fill in passively as a byproduct of your real life, and the blocker to that satisfaction is **trust** — users will only grant location access to an app they believe keeps everything on the phone. A game that (a) is honest that it never leaves the device and (b) is honest that its "ZIP-like patches" are Census approximations, not official USPS ZIPs, can own a niche the cloud apps can't.

### Target user
- **Primary:** Privacy-conscious US residents who enjoy quiet "completionist" or map/exploration experiences (the "fill in the map" itch — visited-states maps, Geoguessr-adjacent, frequent travelers, road-trippers) and who will *not* hand continuous location to a cloud service.
- **Secondary:** Casual cozy-game players who like calm, low-pressure progress loops and visual collection mechanics, plus map/geography enthusiasts who appreciate ZCTA-level granularity.

### Value proposition
A private map of everywhere you've actually been that fills itself in as you live your life and never leaves your phone.

### Positioning / category & one-sentence pitch
Category: **Games (casual / exploration / map-completion)**, single-player, offline. Pitch: *"Patchwork quietly colors in the map of the places you actually visit — ZIP-like patch by patch, city by city, state by state — entirely on your device."*

### Platform & tech baseline
- **iOS 17+ native only** (SwiftUI app shell). No iPad-specific, Android, web, React Native, or Flutter.
- **MapKit** rendered through a **UIKit `MKMapView` bridge** (`UIViewRepresentable`), with filled patches as `MKOverlay` / `MKMultiPolygon` / `MKMultiPolygonRenderer`.
- **CoreLocation** for location capture (When-In-Use first; Always behind a later gate).
- **SwiftData** (iOS 17+) for *user state only*; heavy geodata bundled read-only.
- **Census-derived geodata** (ZCTA / county / state / Census-Place) pinned to the **2025 TIGER/Line vintage**, shipped as **compressed SQLite and/or binary** (never giant runtime GeoJSON; GeoJSON only as an intermediate/debug artifact in tooling).
- **StoreKit 2** for monetization (no third-party SDKs).
- Frameworks explicitly **forbidden** in v1: any backend, Firebase, Mapbox, MapLibre, ads SDK, analytics SDK, server receipt validation, iCloud sync, multiplayer.

### Business model
StoreKit 2 only (per `Docs/LOCKED_V1_DECISIONS.md` #9): **Free** tier + **Pro (annual, default)** + **Lifetime** unlock. No ads, no data sales, no server receipt validation in v1. The free/paid feature split is not yet specified in the repo and is a launch-scope decision (see §6 Known Limitations and §7 NB-7).

### North-star / success signals
Because the app is fully on-device with **no analytics SDK**, success cannot be measured by server telemetry. Launch success is defined by **locally observable** and **beta-observable** signals only:
- **Activation (local):** user reaches "first patch colored" within the first session (the designed first-delight moment).
- **Core-loop habit (local):** number of distinct patches colored and city/county/state rollups unlocked over time, surfaced to the user as their own progress.
- **Trust (beta-observable):** TestFlight feedback shows users grant location permission after the pre-prompt education screen (low permission-denial / uninstall rate).
- **Correctness (beta-observable):** near-zero reports of "wrong patch colored" — a wrong patch erodes trust faster than a missing one.

---

## 2. MVP Feature List (with acceptance criteria)

> Status legend reflects code reality. Because the repo is pre-build, **every feature is "Not built (spec locked)"** — i.e., the design decision is locked in `Docs/LOCKED_V1_DECISIONS.md` but no Swift implements it. Acceptance criteria are written so that, once built, a reviewer can verify each one. Features are ordered by the smallest-risk-first build path from §8.

### F1. Swift package + project foundation — Not built (spec locked)
Establish a compilable foundation: a Swift package (`Package.swift`) wiring `PatchworkCore`, `PatchworkGeo`, `PatchworkData` with a test target, plus an Xcode app target for the SwiftUI shell.
- **Given** a clean checkout, **when** `swift build` and `swift test` run, **then** they succeed (no manifest-missing error) and at least one test executes.
- **Given** the Xcode workspace, **when** opened, **then** an iOS 17+ app target builds against the SwiftUI shell (Xcode status moves off `UNVERIFIED_XCODE_ENVIRONMENT`).
- The three library targets (`PatchworkCore`, `PatchworkGeo`, `PatchworkData`) exist and have no dependency on UI frameworks in `Core`/`Geo`.
- CI (or a documented local command) reports Swift package test pass/fail; Xcode build status is never reported as "passed" when unverified.

### F2. Core domain models + visited-ZCTA bitset — Not built (spec locked)
Pure-Swift domain models in `PatchworkCore`: `ZCTA`, geographic identifiers (county/state/place), and a **compact visited-ZCTA bitset** representing coverage (per `LOCKED_V1_DECISIONS.md` #5).
- **Given** a ZCTA index, **when** a ZCTA is marked visited, **then** the corresponding bit is set and `isVisited(zcta)` returns true; setting twice is idempotent.
- **Given** a bitset, **when** serialized and deserialized, **then** the round trip is lossless and stable across app launches.
- The bitset memory footprint for the full national ZCTA set (~33k ZCTAs) is documented and bounded (well under 100 KB).
- Models are `Codable`/value types with deterministic equality; unit tests cover set/clear/contains/count.

### F3. Point-in-polygon geometry engine — Not built (spec locked)
`PatchworkGeo` containment: given a coordinate and a candidate ZCTA polygon (including multi-polygons and holes), decide membership (per `LOCKED_V1_DECISIONS.md` #7, step "candidate polygons then point-in-polygon").
- **Given** a set of known coordinates with known ZCTAs (fixtures), **when** resolved, **then** each maps to the correct ZCTA (100% on the fixture set).
- **Given** a point inside a polygon **hole** (e.g., an enclave), **when** tested, **then** it is reported *outside* that polygon.
- **Given** a point exactly on an edge/vertex, **when** tested, **then** behavior is deterministic and documented (consistent tie-breaking).
- Multi-polygon ZCTAs (non-contiguous areas) are handled correctly.
- Algorithm correctness is covered by deterministic unit tests with hand-checked fixtures.

### F4. Spatial index for candidate lookup — Not built (spec locked)
`PatchworkGeo` spatial index (e.g., R-tree / grid) to narrow ~33k ZCTA polygons to a small candidate set before point-in-polygon (per `LOCKED_V1_DECISIONS.md` #7, "spatial index then candidate polygons").
- **Given** a coordinate, **when** queried, **then** the index returns a small superset of candidate ZCTAs that always contains the true ZCTA (no false negatives on the fixture set).
- **Given** a coordinate-to-ZCTA resolution, **when** measured on-device, **then** median resolution time is within an interactive budget (target < ~50 ms) and is documented.
- Resolution is **fully local** — no network reverse-geocoding call is made (verifiable by absence of any networking code in the path).

### F5. Weighted rollup engine — Not built (spec locked)
`PatchworkCore`/`PatchworkGeo` computes city/county/state/country completion from the visited bitset using **precomputed weighted-overlap lookup tables** (runtime = weighted sums, **not** spatial intersections; per `LOCKED_V1_DECISIONS.md` #6).
- **Given** a visited bitset and a county's weighted-overlap table, **when** rolled up, **then** county completion % is a weighted sum of visited ZCTAs' contributions and lands in [0, 100].
- **Given** all ZCTAs in a county visited, **when** rolled up, **then** that county reports 100% (within documented rounding tolerance).
- **Given** no ZCTAs visited, **when** rolled up, **then** every rollup is 0%.
- Rollups perform **no runtime spatial intersection** (verifiable: the runtime path reads lookup tables only).
- Rollup math is covered by unit tests with hand-computed expected values.

### F6. Offline Census geodata pipeline (`Tools/geo_build`) — Not built (spec locked)
A documented offline pipeline that ingests 2025 TIGER/Line, produces the compressed SQLite/binary runtime bundle, and generates weighted-overlap lookup tables (per `LOCKED_V1_DECISIONS.md` #4, #6; build plan steps 7 & 17).
- **Given** the pipeline run with the pinned **2025 TIGER/Line** vintage, **when** executed, **then** it emits the runtime geodata bundle and lookup tables deterministically (same inputs → same outputs).
- The runtime bundle is **compressed SQLite and/or binary**, not giant runtime GeoJSON (GeoJSON only as intermediate/debug).
- The pipeline emits a **small sample dataset** (a handful of ZCTAs) usable for DEBUG/tests so app correctness can be validated without the full national bundle (mirrors Roam's sample-vs-production split).
- The TIGER/Line vintage is pinned and recorded; rebuilds are reproducible.

### F7. Runtime geodata repository + sample dataset — Not built (spec locked)
`PatchworkData` loads the read-only bundled geodata (full or sample) and exposes ZCTA polygons, the spatial index source, and rollup tables to the app.
- **Given** the bundled DEBUG sample dataset, **when** the app loads it, **then** ZCTA polygons and rollup tables are available and the end-to-end coordinate→ZCTA→rollup path runs.
- **Given** a release build, **when** it loads, **then** it uses the production bundle (or a clearly labeled limited geography if production isn't ready — see §7 LB-3).
- Geodata is opened **read-only**; no write path mutates bundled assets.
- Bundle load time and memory are within documented budgets on a baseline device.

### F8. SwiftData local persistence — Not built (spec locked)
`SwiftData` (iOS 17+) stores **user state only** (visited bitset, per-patch claim timestamps/metadata, settings); heavy geodata is never stored in SwiftData (per `LOCKED_V1_DECISIONS.md` #8).
- **Given** a user colors patches, **when** the app is killed and relaunched, **then** all previously colored patches and rollups are restored.
- **Given** a fresh install, **when** first launched, **then** the store initializes empty with zero coverage.
- SwiftData holds **no geodata** (verifiable: schema contains user-state entities only).
- A schema migration story is documented for future versions (additive).

### F9. MapKit bridge + patch overlay rendering — Not built (spec locked)
SwiftUI shell hosting an `MKMapView` (UIKit bridge) that renders visited ZCTAs as **translucent colored overlays** via `MKMultiPolygon`/`MKMultiPolygonRenderer`, with performance guardrails (viewport culling, LOD simplification, county/state fallback at broad zoom) (per `LOCKED_V1_DECISIONS.md` #3).
- **Given** a visited ZCTA, **when** the map renders, **then** that area shows as a translucent colored patch distinguishable from unvisited areas.
- **Given** a broad zoom level, **when** rendering, **then** the app shows county/state-level fallback rollup fill instead of all high-detail ZCTA polygons (no attempt to draw all ~33k polygons at once).
- **Given** panning/zooming on a baseline device, **when** interacting, **then** the map sustains an interactive frame rate (target ~60fps, no crash) — viewport culling + LOD are active.
- Overlay colors meet contrast/accessibility guidance and are colorblind-considerate.

### F10. Location capture + "Claim Current Patch" — Not built (spec locked)
CoreLocation capture with a user-initiated **"Claim Current Patch"** action; **When-In-Use** permission first (per `LOCKED_V1_DECISIONS.md` #10). Always/background is **deferred behind a later gate** and must not be requested silently in v1.
- **Given** When-In-Use permission granted, **when** the user taps "Claim Current Patch," **then** the current coordinate resolves to a ZCTA and that patch is colored.
- **Given** a **low-confidence / low-accuracy** fix, **when** claiming, **then** the app declines to color (bias toward not-coloring) and tells the user why — preventing wrong-patch trust damage.
- **Given** the user has not granted permission, **when** they tap claim, **then** the pre-prompt education screen (F11) is shown before any system dialog.
- v1 makes **no Always/background location request** (verifiable: no `requestAlwaysAuthorization`, no background location modes in `Info.plist`).

### F11. Permission education (pre-prompt) — Not built (spec locked)
A pre-permission onboarding screen shown **before** the system location dialog, explaining what's collected (areas entered, on-device only), why location is needed (to color patches), and that nothing leaves the phone (mirrors Roam's highest-leverage surface).
- **Given** first run, **when** the user reaches the location ask, **then** the education screen appears **before** the iOS system permission dialog.
- The screen states plainly: data stays on device, no account, no server, export/delete available.
- The screen uses honest geography language — "ZIP Code Areas (Census ZCTA boundaries)" / "ZIP-like patches," never "official ZIP coverage."
- **Given** the user dismisses education without granting, **when** they return, **then** the app remains usable (browse map) and re-offers education on the next claim attempt.

### F12. First-delight moment: first patch colored — Not built (spec locked)
The designed activation beat: the immediate "I filled one in" feedback when the user's first patch is colored (per the conversation, the hook over rollups/timeline).
- **Given** a brand-new user grants permission and claims, **when** the first patch colors, **then** a distinct, celebratory-but-calm feedback moment plays (animation/haptic) and the map visibly changes.
- **Given** the first patch, **when** colored, **then** the user is shown how it ladders up (this patch → city/state progress) to motivate the loop.
- The first-delight moment fires exactly once for the first-ever patch (subsequent patches use standard feedback).

### F13. Rollup progress UI (city / county / state / country) — Not built (spec locked)
Surfaces the F5 rollups as user-facing progress — completion percentages and counts that increase as zoom changes / as patches accrue.
- **Given** colored patches, **when** the user zooms out, **then** city → county → state → country completion is shown and matches the engine's computed values.
- **Given** a newly completed region (e.g., a county reaches 100%), **when** it completes, **then** the user gets clear progress feedback.
- Percentages displayed match F5 outputs exactly (no separate/ divergent calculation in the UI).

### F14. StoreKit 2 monetization (Free / Pro annual / Lifetime) — Not built (spec locked)
StoreKit 2 purchase flow for **Free** + **Pro (annual, default)** + **Lifetime**, with on-device entitlement checking (no server receipt validation) (per `LOCKED_V1_DECISIONS.md` #9).
- **Given** the paywall, **when** shown, **then** it presents Pro annual (default) and Lifetime with clear pricing and a restore-purchases path.
- **Given** a completed purchase, **when** finished, **then** entitlement unlocks the paid surface locally via StoreKit 2 `Transaction` verification (no network receipt server).
- **Given** "Restore Purchases," **when** tapped, **then** prior entitlements restore.
- No ads SDK and no data-sale code path exist.
- The exact free-vs-paid feature gate is specified before launch (currently unspecified — see §6 / NB-7).

### F15. Privacy controls: export / import / reset — Not built (spec locked)
On-device data controls (build plan step 15): export user progress, import it back, and reset/delete all local data.
- **Given** progress, **when** the user exports, **then** a local file containing only their user state (no geodata) is produced and re-importable.
- **Given** "Reset," **when** confirmed, **then** all visited state and SwiftData user records are deleted and coverage returns to 0%.
- Export/import never contacts a server; all operations are local.
- A clear in-app privacy explanation describes what is stored and that it stays on device.

---

## 3. Out of Scope (v1 non-goals)

Explicitly **not** in v1. The first block is hard-forbidden by `README.md` and `Docs/LOCKED_V1_DECISIONS.md` (V1 Hard Exclusions) — these are trust-spine constraints, not just deferrals:

- **No backend / server of any kind.** All geography, location, progress, and rollups are on device.
- **No accounts / login / identity.**
- **No analytics SDK** and **no ads SDK.**
- **No Firebase, Mapbox, or MapLibre** (MapKit only).
- **No leaderboard, social graph, or multiplayer.**
- **No iCloud sync** (v1 progress does not sync across devices; export/import is the only portability).
- **No server receipt validation** (StoreKit 2 on-device verification only).
- **No Android, web, React Native, or Flutter.**
- **No data sales.**

Additional product non-goals for v1 (deferred by scope, not forbidden):

- **No Always/background passive patch-filling.** v1 is **When-In-Use + manual "Claim Current Patch"** only. Automatic/passive filling via Always location is reserved behind a later permission gate (`LOCKED_V1_DECISIONS.md` #10) — this is the single biggest deferred capability and must not be added silently.
- **No international geography.** US-only is a deliberate strength that keeps the geodata scope real and shippable; non-US is a separate data project.
- **No "official ZIP" claims.** Copy must say "ZIP-like patches" / "ZIP Code Areas (Census ZCTA boundaries)," never "official ZIP coverage."
- **No history/timeline feature, daily challenges, themes/skins, or remote level/content packs** in v1 (possible post-launch retention layers; the first-delight hook is "first patch colored," not a timeline).
- **No iPad-optimized or landscape-first layouts** committed for v1.

---

## 4. User Flows

> Screen names are proposed (no UI code exists yet); they become the `Patchwork/Features` targets. Build them to these flows.

### 4.1 First run / onboarding (the trust gate)
1. App launches to a **Welcome** screen: one-line value prop ("Color the map you actually live") and a calm preview of a partially filled map.
2. User taps **Continue** → **Permission Education** screen (F11): what's collected (areas you enter), where it lives (on device only — no account, no server), why location is needed (to color patches), and the honest geography note ("ZIP-like patches / Census ZCTA boundaries, not official ZIP coverage"). Export/delete is mentioned here.
3. User taps **Enable Location** → iOS shows the **When-In-Use** system dialog (never shown cold — always after education).
4. On grant → land on the **Map** screen centered near the user, ready to claim. On deny → land on the Map screen in browse-only mode; claiming later re-offers education.

### 4.2 Core loop — claim a patch (first-delight)
1. On the **Map** screen, user taps **"Claim Current Patch"** (F10).
2. App takes a CoreLocation fix → resolves coordinate to ZCTA locally: spatial index (F4) → candidate polygons → point-in-polygon (F3).
3. If the fix is **low-confidence**, the app declines to color and explains (bias toward not coloring — avoids wrong-patch trust damage).
4. If resolved, the ZCTA bit is set (F2), persisted (F8), and the patch renders as a translucent colored overlay (F9).
5. **First-ever patch only:** the **first-delight** moment fires (F12) — calm celebratory feedback + a "here's how this ladders up to your city/state" hint.
6. Rollups recompute (F5) and update the progress UI (F13).

### 4.3 Watch progress roll up
1. On the **Map** screen, the user zooms out.
2. At broader zoom, the map switches to county/state fallback fill (F9 performance path) and the **Progress** surface (F13) shows city → county → state → country completion %.
3. When a region crosses a milestone (e.g., a county hits 100%), the user gets clear completion feedback.

### 4.4 Settings / privacy
1. From the **Map** screen, user opens **Settings**.
2. **Export** writes a local user-state file (no geodata); **Import** restores it; **Reset** deletes all local progress after confirmation (F15).
3. An **About / Privacy** section restates: on-device only, no account/server, and the ZCTA-vs-USPS geography honesty note.
4. A future **Always location** explanation lives here behind its own gate (not requested in v1).

### 4.5 Monetization (paywall)
1. User encounters the **Paywall** (F14) at the designated gate (gate TBD — see §6 / NB-7).
2. Paywall shows **Pro annual (default)** and **Lifetime** with clear pricing and **Restore Purchases**.
3. On purchase, StoreKit 2 verifies the transaction on device and unlocks the paid surface locally; no server is contacted.

---

## 5. Acceptance Criteria Summary

Index of MVP features → their launch pass/fail gate. Full criteria are inline in §2.

| ID | Feature | Status | Launch gate (must be true to ship) |
| --- | --- | --- | --- |
| F1 | Swift package + project foundation | Not built (spec locked) | `swift build`/`swift test` pass; iOS 17+ app target builds (Xcode status verified) |
| F2 | Core models + visited bitset | Not built (spec locked) | Set/clear/contains correct; lossless persistence round-trip; footprint bounded |
| F3 | Point-in-polygon engine | Not built (spec locked) | 100% correct on coordinate→ZCTA fixtures incl. holes & multi-polygons; deterministic edges |
| F4 | Spatial index | Not built (spec locked) | Candidate set always contains true ZCTA; local-only; resolution within interactive budget |
| F5 | Weighted rollup engine | Not built (spec locked) | Rollups in [0,100], 100%/0% boundary cases correct; no runtime spatial intersection |
| F6 | Census geodata pipeline | Not built (spec locked) | Deterministic build from pinned 2025 TIGER/Line; compressed SQLite/binary; sample dataset emitted |
| F7 | Runtime geodata repository | Not built (spec locked) | E2E path runs on sample dataset; read-only; load time/memory within budget |
| F8 | SwiftData persistence | Not built (spec locked) | Progress survives relaunch; fresh install empty; geodata not in SwiftData |
| F9 | MapKit bridge + overlays | Not built (spec locked) | Patches render translucent; county/state fallback at broad zoom; interactive frame rate, no crash |
| F10 | Location + Claim Current Patch | Not built (spec locked) | Claim colors correct ZCTA; declines low-confidence fixes; no Always request in v1 |
| F11 | Permission education | Not built (spec locked) | Education shown *before* system dialog; honest copy; app usable on deny |
| F12 | First-delight (first patch) | Not built (spec locked) | First-ever patch triggers calm celebratory feedback + laddering hint, once |
| F13 | Rollup progress UI | Not built (spec locked) | Displayed % matches F5 exactly; milestone feedback |
| F14 | StoreKit 2 monetization | Not built (spec locked) | Pro annual + Lifetime purchasable + restore; on-device verification; no ads/data-sale |
| F15 | Export / import / reset | Not built (spec locked) | Export/import lossless local file; reset zeroes coverage; no network |

**Overall launch gate:** none of F1–F15 is currently built; the entire list is the build-to backlog. Launch requires at minimum the end-to-end core loop (F1–F13) running on a real or clearly-labeled-limited geodata bundle, plus F15 privacy controls and F14 monetization, with the launch-blocking items in §7 resolved.

---

## 6. Known Limitations

- **Nothing is implemented.** This is a pre-build repo (docs + empty `.gitkeep` folders). All "criteria" are build-to targets, not verified behavior.
- **ZCTA ≠ USPS ZIP.** Patches are Census ZCTA approximations of ZIP geographies — not official USPS ZIP boundaries. This is a permanent, by-design accuracy limitation that must be disclosed in copy ("ZIP Code Areas (Census ZCTA boundaries)," "ZIP-like patches"), not hidden.
- **Manual claiming only in v1.** Without Always/background location, the map only fills when the user opens the app and taps "Claim Current Patch." The "passive, fills itself in as you live" fantasy is partially deferred; v1 is a manual approximation of it.
- **Geodata production is unbuilt and is the heaviest single task.** The 2025 TIGER/Line → compressed SQLite/binary pipeline plus weighted-overlap lookup tables (F6) is substantial; the full national bundle may not be ready at first ship (sample/limited geography is the fallback).
- **Performance is device-dependent.** Rendering ~33k ZCTA polygons demands viewport culling + LOD + county/state fallback; behavior on older devices is unverified until F9 exists and is profiled.
- **Location accuracy is device/environment-dependent.** Urban canyons, poor GPS, and ZCTA boundary ambiguity can produce wrong-patch risk; the mitigation (decline low-confidence fixes) is specified but unimplemented.
- **Free-vs-paid split is unspecified.** `LOCKED_V1_DECISIONS.md` names Free/Pro/Lifetime tiers but not which features are gated; this must be decided before the paywall is final.
- **Stale doc corrected this pass.** `Docs/PROJECT_DOCUMENTATION.md` previously described a generic board/canvas piece-placement puzzle (wrong product); it has been rewritten to the map-completion product. Any cached/external copy may still be stale.
- **No tests, no CI yet.** Correctness claims (point-in-polygon, rollups) are unproven until F1–F5 tests exist.

---

## 7. Bug & Risk Triage

> No code exists, so these are not runtime bugs — they are the **gaps, decisions, and risks** that must be resolved for a safe, correct, store-acceptable launch. "Where (file)" points at the doc/intended location since there is no source yet.

### Launch-blocking (must fix before TestFlight / App Store)

| ID | Description | Where | Why blocking |
| --- | --- | --- | --- |
| **LB-1** | **No app exists.** No `Package.swift`, no `*.xcodeproj`, no Swift source, no `Info.plist`, no app target. The entire core loop (F1–F13) is unbuilt. | repo root; `Patchwork/*`, `Sources/*` (empty `.gitkeep`) | There is literally nothing to ship; this is the master blocker. |
| **LB-2** | **No `PrivacyInfo.xcprivacy` and no `Info.plist` location-usage strings.** A location app cannot pass App Review without an `NSLocationWhenInUseUsageDescription` and a privacy manifest. | (to be created) `Patchwork/App/Info.plist`, `PrivacyInfo.xcprivacy` | App Review rejection; permission dialog cannot even be shown without the usage string. |
| **LB-3** | **No geodata bundle.** No ZCTA polygons, spatial index, or rollup tables (F6/F7). Without at least a labeled, working geography, the app cannot color any patch. | `Tools/geo_build/`, `Patchwork/Resources/` (empty) | Core loop is non-functional; must ship full or clearly-labeled-limited geography. |
| **LB-4** | **Permission asked cold = trust failure + likely rejection.** The system location dialog must be preceded by the education screen (F11); shipping the raw prompt is the primary trust blocker called out in the conversation. | F11 (unbuilt) | Permission-denial spike kills the core loop; App Review scrutinizes location justification. |
| **LB-5** | **Wrong-patch risk unmitigated.** No low-confidence-fix rejection (F10) and no validated point-in-polygon/rollup correctness (F3/F5). A wrong patch erodes trust faster than a missing one. | F3, F5, F10 (unbuilt) | Incorrect coloring/percentages directly break the product's one promise (your real map). |
| **LB-6** | **Geography over-claim copy.** Any UI string that says "official ZIP" / "ZIP coverage" instead of "ZIP-like patches / ZIP Code Areas (Census ZCTA boundaries)" violates the locked guardrail. | `LOCKED_V1_DECISIONS.md` #4; all future UI copy | Misleading-claims risk (App Review + user trust); explicitly forbidden by locked decisions. |
| **LB-7** | **StoreKit products + entitlement gate undefined.** No `*.storekit` config, no products configured, and the free-vs-paid split is unspecified (F14). | `LOCKED_V1_DECISIONS.md` #9; (to be created) `Patchwork.storekit` | Cannot ship/validate purchases; a half-defined paywall risks rejection and broken revenue. |

### Non-blocking (ship-with, fix later)

| ID | Description | Rationale for deferral |
| --- | --- | --- |
| **NB-1** | Full national ZCTA bundle not ready at first ship | Acceptable to launch beta on a clearly-labeled limited/sample geography (Roam precedent); expand to full national post-launch. |
| **NB-2** | Always/background passive patch-filling absent | Intentionally deferred behind a later permission gate (`LOCKED_V1_DECISIONS.md` #10); v1 ships manual claim. |
| **NB-3** | History/timeline, daily challenges, themes, content packs missing | Post-launch retention layers; first-delight hook is "first patch colored," not these. |
| **NB-4** | No iCloud sync / cross-device portability | Forbidden in v1; export/import covers basic portability. |
| **NB-5** | Map performance not yet profiled on old devices | Can be tuned post-build once F9 exists; county/state fallback gives a safety margin. |
| **NB-6** | `Docs/CURRENT_STATUS.md`, `ASSUMPTIONS_LOG.md`, `RISK_LOG.md` dated "after Build Task 1" | Doc-freshness only; update alongside each build task, not a launch gate. |
| **NB-7** | Exact free-vs-paid feature gate undecided | Needs a product decision before the paywall finalizes, but doesn't block earlier core-loop build (F1–F13). Promote to LB before shipping F14. |
| **NB-8** | Accessibility (colorblind-safe patch palette, VoiceOver on map/progress) unspecified in detail | Define during F9/F13 build; refine post-beta. |

---

## 8. Production-Readiness Assessment

### Current estimated readiness: **8%**
Justification: the product is **well-specified and the architecture is locked** — `LOCKED_V1_DECISIONS.md`, `ARCHITECTURE.md`, a coherent 18-step build plan, privacy posture, and risk log are all in place, and the stale product doc has now been corrected. That planning maturity is real and de-risks the build. But **zero implementation exists**: no manifest, no Swift, no tests, no geodata, no app target. Against a shippable v1, the credit is for scope/architecture clarity only; everything executable is ahead. 8% reflects "strong build-to spec, nothing built."

### Ordered remaining work to reach 80–90% production-ready
This is the smallest-risk-first path (matches the conversation's "Package.swift + ZCTA point-in-polygon + tests, not MapKit first" and `CODEX_BUILD_PLAN.md`):

1. **Correct the stale product doc** (done this pass) and confirm README + locked decisions win across all docs. *(Cheap insurance — keeps future agents from building the wrong app.)*
2. **F1 — Swift package foundation + first tests.** `Package.swift` wiring `PatchworkCore`/`PatchworkGeo`/`PatchworkData` + test target; `swift build`/`swift test` green.
3. **F2 — Core models + visited bitset**, with persistence round-trip tests.
4. **F3 — Point-in-polygon engine** with hand-checked coordinate→ZCTA fixtures (holes, multi-polygons, edges). *Highest-risk correctness; prove it before any UI.*
5. **F4 — Spatial index**; verify candidate set always contains the true ZCTA and resolution is fast + local.
6. **F5 — Weighted rollup engine** with hand-computed expected values.
7. **F6 — `Tools/geo_build` pipeline** (pinned 2025 TIGER/Line) emitting compressed SQLite/binary + a small DEBUG **sample dataset** + lookup tables.
8. **F7 — Runtime geodata repository**; run the full coordinate→ZCTA→rollup path on the sample dataset.
9. **F8 — SwiftData persistence** for user state; relaunch-survival test.
10. **F11 — Permission education screen** *before* any location request (build before F10's system prompt is wired).
11. **F10 — Location capture + "Claim Current Patch,"** including low-confidence-fix rejection. When-In-Use only; assert no Always request.
12. **F9 — MapKit bridge + translucent overlays** + performance guardrails (viewport culling, LOD, county/state fallback); profile on a baseline device.
13. **F12 + F13 — First-delight moment and rollup progress UI.**
14. **Add `Info.plist` location usage strings + `PrivacyInfo.xcprivacy`** (resolve LB-2) and a colorblind-safe palette + VoiceOver pass (NB-8).
15. **Decide the free-vs-paid gate (NB-7→LB-7), then F14 — StoreKit 2** Free/Pro-annual/Lifetime with `Patchwork.storekit` config and restore.
16. **F15 — Export / import / reset** privacy controls.
17. **Full geodata integration** (national bundle) replacing/augmenting the sample; re-validate correctness and performance.
18. **Release hardening:** dependency review (confirm no forbidden SDKs), copy audit for "ZIP-like" language (LB-6), App Review/privacy package, TestFlight beta. Add CI to run `swift test` on every change.

Reaching the **end of step ~13** with the sample geography puts the core loop end-to-end and would justify roughly **MVP-Ready (~80%)**; steps 14–18 carry it to store-ready 85–90%.

### Test coverage summary
- **What's tested today:** nothing — no test target, no tests, no CI (verified: only empty `Tests/.gitkeep`; `swift test` is unavailable because `Package.swift` does not exist; Xcode status is `UNVERIFIED_XCODE_ENVIRONMENT`).
- **What must be tested (in build order):** bitset set/clear/contains + persistence round-trip (F2); point-in-polygon on hand-checked fixtures incl. holes/multi-polygons/edges (F3); spatial-index no-false-negative + latency (F4); rollup math with hand-computed values + 0%/100% boundaries (F5); pipeline determinism + sample-dataset E2E (F6/F7); persistence relaunch survival (F8); StoreKit purchase/restore via StoreKit testing (F14); export/import lossless round-trip (F15).
- **Verification policy (from README):** when Xcode is unavailable in automation, run all possible Swift package tests and report Xcode build status as `UNVERIFIED_XCODE_ENVIRONMENT`, never as "passed."

---

## 9. Launch Checklist

App Store / privacy / safety / content items specific to Patchwork. (Most are unchecked — pre-build.)

**Foundation & build**
- [ ] `Package.swift` + Xcode app target exist; `swift build`/`swift test` pass.
- [ ] iOS 17+ deployment target configured.
- [ ] Xcode build verified in an Xcode-capable environment (status no longer `UNVERIFIED_XCODE_ENVIRONMENT`).
- [ ] CI runs `swift test` on every change.

**Privacy & permissions (location app — high scrutiny)**
- [ ] `Info.plist` includes `NSLocationWhenInUseUsageDescription` with honest, specific copy. **(LB-2)**
- [ ] **No** `NSLocationAlwaysAndWhenInUseUsageDescription` / background-location modes in v1 (Always deferred). **(NB-2)**
- [ ] `PrivacyInfo.xcprivacy` present and accurate (location collected, on-device, not linked to identity, not used for tracking; no required-reason API gaps). **(LB-2)**
- [ ] Permission **education screen shown before** the system dialog. **(LB-4, F11)**
- [ ] App Store privacy "nutrition label" reflects local-only handling (no data collected off device).
- [ ] Export / import / reset controls function and never contact a network. **(F15)**

**Content & claims (accuracy honesty)**
- [ ] All copy says "ZIP-like patches" / "ZIP Code Areas (Census ZCTA boundaries)"; **no** "official ZIP coverage." **(LB-6)**
- [ ] About/Privacy screen discloses ZCTA-vs-USPS approximation and on-device posture.
- [ ] Census/TIGER attribution included where appropriate; 2025 TIGER/Line vintage recorded.

**Geodata & correctness**
- [ ] Runtime geodata is compressed SQLite/binary (not giant runtime GeoJSON); shipped read-only. **(LB-3)**
- [ ] Coordinate→ZCTA is fully local (no network reverse-geocoding).
- [ ] Point-in-polygon + rollups validated by tests; low-confidence fixes decline to color. **(LB-5)**
- [ ] Full or clearly-labeled-limited geography shipped (sample-geography labeling if national bundle not ready). **(NB-1)**

**Monetization**
- [ ] `Patchwork.storekit` config with Free / Pro annual (default) / Lifetime. **(LB-7)**
- [ ] Free-vs-paid feature gate decided and implemented. **(NB-7)**
- [ ] StoreKit 2 on-device verification + Restore Purchases work; **no** server receipt validation, ads, or data sales.

**Quality, safety & store**
- [ ] Map sustains interactive performance with viewport culling + LOD + county/state fallback; profiled on a baseline device. **(NB-5)**
- [ ] Colorblind-safe patch palette; VoiceOver labels on map/progress. **(NB-8)**
- [ ] Dependency review confirms **no** backend, Firebase, Mapbox, MapLibre, analytics SDK, ads SDK, accounts, web, React Native, or Flutter.
- [ ] Age rating set (expected 4+; no objectionable content, no UGC, no ads).
- [ ] TestFlight beta validates permission-grant rate and absence of wrong-patch reports.
- [ ] App Review notes explain the on-device location use and the ZCTA-approximation positioning.
