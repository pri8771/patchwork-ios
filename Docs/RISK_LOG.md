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

## Closed Risks

- None yet.
