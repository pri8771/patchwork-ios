#!/usr/bin/env python3
"""Build the production Patchwork geodata bundle from real Census TIGER/Line data.

PINNED VINTAGE: 2025 TIGER/Line. Do not bump without updating Docs/LOCKED_V1_DECISIONS.md,
Docs/ASSUMPTIONS_LOG.md, and the in-app `meta.tiger_vintage`.

This is the production counterpart to `build_sample.py`. It downloads (or reads local) TIGER/Line
ZCTA, county, state, and place shapefiles, simplifies geometry for on-device rendering, computes
area-weighted overlap tables, and writes the same SQLite schema the app already reads. It is a
structured skeleton: the orchestration, schema wiring, and weighting math are spelled out; the
heavy GIS steps require `shapely` + `pyshp` and a network/local copy of the 2025 files, so this
is run on a workstation/CI box, not on device and not in this repo's lightweight automation.

Per the planning thread, full-US (~33k ZCTA) validation is a deliberate, separate step from the
synthetic correctness/scale work already landed; this file is where that validation is produced.

Usage:
    pip install -r requirements.txt
    python3 build_real.py --states 06,36 --out ../../Sources/PatchworkData/Resources/patchwork-national.sqlite
    # omit --states to process the whole US.

Dependencies (see requirements.txt): shapely>=2.0, pyshp>=2.3, requests>=2.31.
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from geo_format import SCHEMA, encode_geometry, shoelace_area  # noqa: F401,E402

TIGER_VINTAGE = "2025"
TIGER_BASE = f"https://www2.census.gov/geo/tiger/TIGER{TIGER_VINTAGE}"

# Layers we consume. ZCTA is national; county/state/place drive the rollups.
LAYERS = {
    "zcta": f"{TIGER_BASE}/ZCTA520/tl_{TIGER_VINTAGE}_us_zcta520.zip",
    "county": f"{TIGER_BASE}/COUNTY/tl_{TIGER_VINTAGE}_us_county.zip",
    "state": f"{TIGER_BASE}/STATE/tl_{TIGER_VINTAGE}_us_state.zip",
    # place files are per-state: f"{TIGER_BASE}/PLACE/tl_{VINTAGE}_{stfips}_place.zip"
}

# Simplification tolerance (degrees) for on-device rendering. ~1e-4 ≈ ~10 m. Tune against the
# performance budget; the locked perf strategy also adds runtime viewport culling + LOD.
SIMPLIFY_TOLERANCE = 1e-4


def main():
    parser = argparse.ArgumentParser(description="Build the production Patchwork geodata bundle.")
    parser.add_argument("--states", default="", help="comma-separated state FIPS to limit to (default: all US)")
    parser.add_argument("--out", required=True, help="output SQLite path")
    parser.add_argument("--cache", default="./tiger_cache", help="download cache directory")
    args = parser.parse_args()

    try:
        import shapely  # noqa: F401
        import shapefile  # noqa: F401  (pyshp)
    except ImportError:
        print("ERROR: install dependencies first: pip install -r requirements.txt", file=sys.stderr)
        sys.exit(2)

    # The production pipeline, step by step:
    #
    # 1. Fetch + unzip the pinned 2025 TIGER/Line ZCTA, county, state, and (per-state) place
    #    shapefiles into `args.cache` (skip if already present).
    #
    # 2. Load ZCTA polygons. Assign each a stable, contiguous `idx` (sorted by ZCTA code so the
    #    index is reproducible across rebuilds of the same vintage). Reproject to lon/lat if
    #    needed (TIGER ships EPSG:4269 ≈ WGS84). Optionally clip to `--states`.
    #
    # 3. Simplify each ZCTA polygon with shapely `.simplify(SIMPLIFY_TOLERANCE, preserve_topology=True)`
    #    to shrink on-device geometry, then encode with `encode_geometry` (same blob the app reads).
    #
    # 4. For each region level (county, state, place, country=US), compute the area-weighted
    #    overlap of every ZCTA: weight = area(zcta ∩ region) / area(region), using shapely
    #    `.intersection(...).area`. Normalize per region so weights sum to 1.0 (matches the
    #    runtime rollup contract and the sample builder).
    #
    # 5. Record each ZCTA's primary county/state/place (the max-overlap region) into the `zcta`
    #    row for the claim label.
    #
    # 6. Write `meta` (dataset="national", tiger_vintage=TIGER_VINTAGE, zcta_count, bounds, honest
    #    note), then VACUUM. Validate that every region's weights sum to ~1.0 before finishing.
    #
    # 7. Spot-check known coordinates resolve to the expected ZCTA before shipping (parity with the
    #    Swift correctness fixtures), and record measured 33k-scale lookup p95 in Docs/RISK_LOG.md.
    #
    # The geometry/area work above needs shapely + the real files; wire it in on a workstation.
    raise SystemExit(
        "build_real.py is the documented production skeleton. Implement steps 1–7 with shapely + "
        "the pinned 2025 TIGER/Line files on a workstation/CI box. See build_sample.py for a "
        "complete, runnable reference that emits the identical schema."
    )


if __name__ == "__main__":
    main()
