# Patchwork geodata pipeline

Offline tooling that produces the on-device geodata bundle. Per the locked V1 decisions, runtime
geodata ships as **compressed SQLite**, never giant runtime GeoJSON, and is pinned to the **2025
TIGER/Line** vintage. GeoJSON may appear only as an intermediate/debug artifact.

## Files

| File | Purpose |
| --- | --- |
| `geo_format.py` | Canonical SQLite schema + the compact binary polygon encoding. The Swift decoder (`Sources/PatchworkData/GeometryCodec.swift`) mirrors `encode_geometry` byte-for-byte. |
| `schema.sql` | Human-readable reference copy of the schema. |
| `build_sample.py` | **Runnable, stdlib-only.** Generates the bundled SF Bay Area *sample* dataset (`patchwork-sample.sqlite`). Deterministic, license-free, watertight tiling over real coordinates. |
| `build_real.py` | Documented **production** skeleton: real 2025 TIGER/Line ZCTA/county/state/place → the same schema. Needs `requirements.txt` deps + the real files; run on a workstation/CI. |
| `requirements.txt` | Deps for `build_real.py` only. |

## Build the sample bundle

```bash
python3 Tools/geo_build/build_sample.py
# → Sources/PatchworkData/Resources/patchwork-sample.sqlite (~200 KB, 400 ZCTAs, 19 regions)
```

The Swift package test suite reads this bundle, so regenerating it should keep
`swift test` green.

## Build the production bundle (workstation)

```bash
pip install -r Tools/geo_build/requirements.txt
python3 Tools/geo_build/build_real.py --out Sources/PatchworkData/Resources/patchwork-national.sqlite
```

See the step-by-step pipeline documented at the top of `build_real.py`. Full-US (~33k ZCTA)
validation — including a measured lookup p95 recorded in `Docs/RISK_LOG.md` — is a deliberate
separate step from the synthetic correctness/scale work already in the test suite.

## Schema contract

Every dataset (sample or national) emits the identical schema (`meta`, `zcta`, `region`,
`region_member`) and the identical geometry blob format. That is the single contract between this
pipeline and the app; keep `geo_format.py` and `GeometryCodec.swift` in lockstep.

## Honesty rule

These are Census **ZCTA** areas — close approximations of USPS ZIP Codes, not official ZIP
delivery boundaries. The `meta.note` row and all user-facing copy say "ZIP-like patches" /
"postal areas", never "official ZIP coverage".
