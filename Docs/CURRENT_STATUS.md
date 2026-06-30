# Current Status

_Last updated: 2026-06-30. The launch-scope build-to spec is `LAUNCH_READINESS.md` at the repo root; the stale `Docs/PROJECT_DOCUMENTATION.md` (which described a generic tile puzzle) has been corrected to the real map-completion product._

## What Exists Now

- The repository has been audited at a baseline level and currently contains documentation plus placeholder folder scaffolding.
- `README.md` describes the Patchwork purpose, local-only rule, hard exclusions, and build notes.
- Canonical documentation now exists in `Docs/`:
  - `LOCKED_V1_DECISIONS.md`
  - `ARCHITECTURE.md`
  - `CODEX_BUILD_PLAN.md`
  - `CURRENT_STATUS.md`
  - `ASSUMPTIONS_LOG.md`
  - `RISK_LOG.md`
  - `PRIVACY_NOTES.md`
  - `RELEASE_CHECKLIST.md`
- Baseline source folders now exist:
  - `Patchwork/App`
  - `Patchwork/DesignSystem`
  - `Patchwork/Features`
  - `Patchwork/Infrastructure`
  - `Patchwork/Resources`
  - `Sources/PatchworkCore`
  - `Sources/PatchworkGeo`
  - `Sources/PatchworkData`
  - `Tests`
  - `Tools/geo_build`

## What Does Not Exist Yet

- No Xcode project or Swift package manifest exists yet.
- No Swift source files exist yet.
- No app target, executable app shell, or MapKit bridge exists yet.
- No geodata assets, generated SQLite files, binary assets, or sample datasets exist yet.
- No SwiftData schema exists yet.
- No StoreKit configuration or products exist yet.
- No tests exist yet beyond the placeholder test folder.

## Build and Verification Status

- Swift package tests: not available yet because `Package.swift` has not been created.
- Xcode build: UNVERIFIED_XCODE_ENVIRONMENT because no Xcode project exists in this baseline scaffold.

## Current Open Work

- Create Swift package foundation and initial tests.
- Define core models and visited bitset.
- Build geospatial algorithms, tooling, persistence, UI, MapKit rendering, monetization, privacy/export flows, performance guardrails, full geodata integration, and release hardening in later tasks.
