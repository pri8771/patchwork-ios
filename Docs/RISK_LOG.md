# Risk Log

_Last updated: 2026-06-29 after Build Task 1 of 18._

## Active Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Large ZCTA geometry can exceed memory or rendering budgets. | Map interaction may stutter or crash on older devices. | Use viewport culling, LOD simplification, bundled binary/SQLite assets, and county/state fallback. |
| Census ZCTAs are ZIP-like approximations, not official USPS ZIP coverage. | User confusion or inaccurate marketing claims. | Require copy to say "ZIP-like patches" or "postal areas" and never "official ZIP coverage." |
| Full 2025 TIGER/Line processing may require substantial offline tooling work. | Geodata integration could become a schedule bottleneck. | Build `Tools/geo_build` incrementally and add sample datasets before full integration. |
| Point-in-polygon and rollup correctness can be difficult to validate at national scale. | Incorrect patch claiming or progress percentages. | Add deterministic unit tests, sample fixtures, and precomputed lookup validation. |
| Local-only privacy promises can be undermined by accidental SDK additions. | Loss of user trust and violation of V1 constraints. | Keep hard exclusions documented and review dependency changes in every task. |
| Xcode may be unavailable in agent environments. | iOS app build status may be unverifiable during automated tasks. | Run all possible Swift package tests and mark Xcode status as UNVERIFIED_XCODE_ENVIRONMENT when necessary. |

## Lookup Performance Benchmark (locked PR2 scale-sanity gate)

Per the Patchwork planning thread, the indexed coordinate→ZCTA lookup must hit single-lookup
**p95 < 10 ms** on a realistic synthetic stress set, in release mode, on a named target — or this
log must record the named target, measured p95, and the gap to 10 ms.

| Field | Value |
| --- | --- |
| Status | **PASS (synthetic scale)** |
| Target | Apple M5 Pro, macOS 26.5, Swift 6.3.3 |
| Command | `swift test -c release --filter ResolverScaleBenchmarkTests` |
| Stress set | 10,000 synthetic polygons, ~50–200 vertices each, deliberately overlapping bboxes |
| Queries | 5,000 fixed-seed random points across the full bounds |
| Measured | p50 ≈ 0.0032 ms, **p95 ≈ 0.0049 ms**, p99 ≈ 0.0063 ms |
| Gap to 10 ms | ~2000× under budget |

**Honesty note:** this validates the *architecture* (indexed, deterministic, fast) at a meaningful
synthetic scale. It is **not** a full-US readiness claim. Real ~33k-ZCTA TIGER/Line validation —
including a measured p95 on real geometry and on target iPhone hardware — remains a deliberate
later data-bundle step (`build_real.py`), and its result will be recorded here when produced.

## Closed Risks

- _Point-in-polygon + spatial-index correctness:_ mitigated by the deterministic correctness
  fixture (inside/outside/shared-edge/concave/holes/multipart) and index-vs-brute-force equivalence
  tests; all green. Reopens if real-data resolution surfaces discrepancies.
