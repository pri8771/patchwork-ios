#!/usr/bin/env python3
"""Generate Patchwork's bundled *sample* geodata SQLite.

This produces a small, deterministic, license-free dataset shaped exactly like the production
bundle (identical schema + geometry encoding) so the whole app — map, claiming, rollups, share
card — runs end to end without the multi-gigabyte national TIGER/Line download.

It is SAMPLE data: ZCTA-like cells tiling a real coordinate window over the San Francisco Bay
Area. Codes/areas are synthetic. The real national bundle is produced by `build_real.py` from
the pinned 2025 TIGER/Line vintage. Per the locked product rules these are "ZIP-like patches" /
"postal areas", never "official ZIP coverage".

Pure standard library (sqlite3, struct, math, random) so it runs anywhere with no deps.
Run:  python3 Tools/geo_build/build_sample.py
"""

import math
import os
import random
import sqlite3
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from geo_format import SCHEMA, encode_geometry, decode_geometry, shoelace_area  # noqa: E402

OUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "..", "Sources", "PatchworkData", "Resources", "patchwork-sample.sqlite",
)

# Real coordinate window over the SF Bay Area so the map renders a recognizable place.
LON_MIN, LON_MAX = -122.55, -121.75
LAT_MIN, LAT_MAX = 37.25, 38.05
ROWS, COLS = 20, 20                  # 400 ZCTA cells
SEED = 20250101                      # 2025 TIGER/Line vintage marker, used as RNG seed

# Counties: map a 3x3 super-grid of the metro to real Bay Area county names.
COUNTY_BY_SUPERCELL = {
    (0, 0): ("06041", "Marin County"),
    (1, 0): ("06075", "San Francisco County"),
    (2, 0): ("06081", "San Mateo County"),
    (0, 1): ("06095", "Solano County"),
    (1, 1): ("06001", "Alameda County"),
    (2, 1): ("06085", "Santa Clara County"),
    (0, 2): ("06013", "Contra Costa County"),
    (1, 2): ("06013", "Contra Costa County"),
    (2, 2): ("06085", "Santa Clara County"),
}

# Cities: each spans a block of cells. (name, row range, col range)
PLACES = [
    ("San Francisco", range(6, 10), range(0, 4)),
    ("Oakland", range(8, 12), range(8, 12)),
    ("Berkeley", range(4, 7), range(8, 11)),
    ("San Jose", range(14, 19), range(14, 20)),
    ("Palo Alto", range(12, 15), range(4, 7)),
    ("Fremont", range(11, 15), range(11, 15)),
    ("Daly City", range(10, 13), range(0, 3)),
    ("San Rafael", range(1, 4), range(2, 5)),
    ("Walnut Creek", range(7, 10), range(15, 18)),
    ("Sunnyvale", range(13, 16), range(8, 11)),
]


def lerp(a, b, t):
    return a + (b - a) * t


def build_grid_vertices(rng):
    """Perturbed grid vertices shared by adjacent cells (guarantees a gap/overlap-free tiling)."""
    cell_w = (LON_MAX - LON_MIN) / COLS
    cell_h = (LAT_MAX - LAT_MIN) / ROWS
    verts = {}
    for r in range(ROWS + 1):
        for c in range(COLS + 1):
            x = lerp(LON_MIN, LON_MAX, c / COLS)
            y = lerp(LAT_MIN, LAT_MAX, r / ROWS)
            # Jitter interior vertices only, so the metro outline stays a clean rectangle.
            if 0 < r < ROWS and 0 < c < COLS:
                x += rng.uniform(-0.22, 0.22) * cell_w
                y += rng.uniform(-0.22, 0.22) * cell_h
            verts[(r, c)] = (x, y)
    return verts, cell_w, cell_h


def edge_midpoint(p, q, cell_diag, rng_cache):
    """Deterministic displaced midpoint for a shared edge, identical for both neighbor cells.

    Keyed by the unordered endpoint pair so the two cells that share the edge produce the exact
    same boundary point (a valid, watertight tiling). Displacement is perpendicular to the edge.
    """
    key = frozenset((p, q))
    if key in rng_cache:
        return rng_cache[key]
    mx, my = (p[0] + q[0]) / 2, (p[1] + q[1]) / 2
    dx, dy = q[0] - p[0], q[1] - p[1]
    length = math.hypot(dx, dy) or 1e-9
    nx, ny = -dy / length, dx / length          # unit normal
    # Deterministic signed magnitude from a hash of the endpoints.
    h = hash((round(p[0], 6), round(p[1], 6), round(q[0], 6), round(q[1], 6)))
    mag = ((h % 1000) / 1000.0 - 0.5) * 0.30 * cell_diag
    point = (mx + nx * mag, my + ny * mag)
    rng_cache[key] = point
    return point


def cell_ring(r, c, verts, cell_diag, mid_cache):
    tl, tr = verts[(r, c)], verts[(r, c + 1)]
    br, bl = verts[(r + 1, c + 1)], verts[(r + 1, c)]
    return [
        tl, edge_midpoint(tl, tr, cell_diag, mid_cache), tr,
        edge_midpoint(tr, br, cell_diag, mid_cache), br,
        edge_midpoint(br, bl, cell_diag, mid_cache), bl,
        edge_midpoint(bl, tl, cell_diag, mid_cache),
    ]


def main():
    rng = random.Random(SEED)
    verts, cell_w, cell_h = build_grid_vertices(rng)
    cell_diag = math.hypot(cell_w, cell_h)
    mid_cache = {}

    place_lookup = {}  # (r, c) -> place name
    for name, rrange, crange in PLACES:
        for r in rrange:
            for c in crange:
                place_lookup[(r, c)] = name

    zctas = []   # dict per cell
    idx = 0
    for r in range(ROWS):
        for c in range(COLS):
            ring = cell_ring(r, c, verts, cell_diag, mid_cache)
            xs = [p[0] for p in ring]
            ys = [p[1] for p in ring]
            super_r, super_c = min(2, r * 3 // ROWS), min(2, c * 3 // COLS)
            county_id, county_name = COUNTY_BY_SUPERCELL[(super_r, super_c)]
            code = f"{94000 + idx:05d}"
            zctas.append({
                "idx": idx,
                "code": code,
                "ring": ring,
                "area": shoelace_area(ring),
                "min_x": min(xs), "min_y": min(ys),
                "max_x": max(xs), "max_y": max(ys),
                "county_id": county_id,
                "county_name": county_name,
                "state_id": "06",
                "place_name": place_lookup.get((r, c)),
            })
            idx += 1

    # Assemble regions and weighted memberships (weight = area share of the region).
    regions = {}  # id -> (name, kind, parent_id)
    members = {}  # region_id -> list[(zcta_idx, area)]

    def add_member(region_id, zidx, area):
        members.setdefault(region_id, []).append((zidx, area))

    regions["US"] = ("United States", "country", None)
    regions["06"] = ("California", "state", "US")
    for z in zctas:
        add_member("US", z["idx"], z["area"])
        add_member("06", z["idx"], z["area"])
        regions.setdefault(z["county_id"], (z["county_name"], "county", "06"))
        add_member(z["county_id"], z["idx"], z["area"])
        if z["place_name"]:
            pid = "P_" + z["place_name"].replace(" ", "_")
            regions.setdefault(pid, (z["place_name"], "place", "06"))
            add_member(pid, z["idx"], z["area"])

    # Write SQLite.
    if os.path.exists(OUT):
        os.remove(OUT)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    db = sqlite3.connect(OUT)
    db.executescript(SCHEMA)

    for z in zctas:
        blob = encode_geometry([[z["ring"]]])
        assert decode_geometry(blob) == [[z["ring"]]], "geom round-trip mismatch"
        db.execute(
            "INSERT INTO zcta (idx, code, min_x, min_y, max_x, max_y, county_id, state_id, place_name, geom) "
            "VALUES (?,?,?,?,?,?,?,?,?,?)",
            (z["idx"], z["code"], z["min_x"], z["min_y"], z["max_x"], z["max_y"],
             z["county_id"], z["state_id"], z["place_name"], blob),
        )

    for rid, (name, kind, parent) in regions.items():
        db.execute("INSERT INTO region (id, name, kind, parent_id) VALUES (?,?,?,?)",
                   (rid, name, kind, parent))

    for rid, lst in members.items():
        total = sum(area for _, area in lst) or 1.0
        for zidx, area in lst:
            db.execute("INSERT INTO region_member (region_id, zcta_idx, weight) VALUES (?,?,?)",
                       (rid, zidx, area / total))

    meta = {
        "schema_version": "1",
        "dataset": "sample",
        "dataset_name": "SF Bay Area sample",
        "tiger_vintage": "2025",
        "zcta_count": str(len(zctas)),
        "region_count": str(len(regions)),
        "lon_min": str(LON_MIN), "lon_max": str(LON_MAX),
        "lat_min": str(LAT_MIN), "lat_max": str(LAT_MAX),
        "note": "Sample ZIP-like patches (Census ZCTA-style). Not official USPS ZIP coverage.",
    }
    for k, v in meta.items():
        db.execute("INSERT INTO meta (key, value) VALUES (?,?)", (k, v))

    db.commit()
    # Validate weight sums.
    for rid, lst in members.items():
        s = db.execute("SELECT SUM(weight) FROM region_member WHERE region_id=?", (rid,)).fetchone()[0]
        assert abs(s - 1.0) < 1e-6, f"region {rid} weights sum to {s}"
    db.execute("VACUUM")
    db.commit()
    db.close()

    size_kb = os.path.getsize(OUT) / 1024
    print(f"Wrote {OUT} ({size_kb:.1f} KB): {len(zctas)} ZCTAs, {len(regions)} regions.")


if __name__ == "__main__":
    main()
