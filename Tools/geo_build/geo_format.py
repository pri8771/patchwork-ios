"""Shared geodata format for Patchwork.

This module defines the canonical SQLite schema and the compact binary polygon encoding used
by both the offline pipeline (this directory) and the on-device Swift data layer
(`Sources/PatchworkData`). The Swift decoder in `GeometryCodec.swift` must mirror
`encode_geometry` byte-for-byte.

Locked V1 decision #4: runtime geodata ships as compressed SQLite / binary, never giant
runtime GeoJSON. GeoJSON may appear only as an intermediate/debug artifact.

Geometry blob format (version 1, little-endian):
    u8  version (1)
    u8  reserved (0)
    u16 polygon_count
    per polygon:
        u16 ring_count            # ring 0 = exterior, rings 1.. = holes
        per ring:
            u32 point_count
            point_count * (float64 x = longitude, float64 y = latitude)
"""

import struct

GEOM_VERSION = 1

SCHEMA = """
PRAGMA user_version = 1;

CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- One row per ZCTA. `idx` is the stable, contiguous ZCTAIndex stored in the visited bitset.
CREATE TABLE IF NOT EXISTS zcta (
    idx        INTEGER PRIMARY KEY,
    code       TEXT NOT NULL,
    min_x      REAL NOT NULL,
    min_y      REAL NOT NULL,
    max_x      REAL NOT NULL,
    max_y      REAL NOT NULL,
    county_id  TEXT,
    state_id   TEXT,
    place_name TEXT,
    geom       BLOB NOT NULL
);
CREATE INDEX IF NOT EXISTS zcta_code_idx ON zcta(code);

-- Administrative regions: country / state / county / place.
CREATE TABLE IF NOT EXISTS region (
    id        TEXT PRIMARY KEY,
    name      TEXT NOT NULL,
    kind      TEXT NOT NULL,        -- country | state | county | place
    parent_id TEXT
);
CREATE INDEX IF NOT EXISTS region_kind_idx ON region(kind);

-- Precomputed weighted-overlap table (locked decision #6). For a given region, the member
-- weights sum to ~1.0, so runtime completion is a plain weighted sum of visited members.
CREATE TABLE IF NOT EXISTS region_member (
    region_id TEXT NOT NULL,
    zcta_idx  INTEGER NOT NULL,
    weight    REAL NOT NULL,
    PRIMARY KEY (region_id, zcta_idx)
);
CREATE INDEX IF NOT EXISTS region_member_region_idx ON region_member(region_id);
"""


def encode_geometry(polygons):
    """Encode a list of polygons to the binary blob format.

    `polygons` is a list of polygons; each polygon is a list of rings; each ring is a list of
    (x, y) = (longitude, latitude) tuples. Ring 0 is the exterior; remaining rings are holes.
    """
    out = bytearray()
    out += struct.pack("<BBH", GEOM_VERSION, 0, len(polygons))
    for rings in polygons:
        out += struct.pack("<H", len(rings))
        for ring in rings:
            out += struct.pack("<I", len(ring))
            for (x, y) in ring:
                out += struct.pack("<dd", x, y)
    return bytes(out)


def decode_geometry(blob):
    """Inverse of `encode_geometry` (used by pipeline self-checks)."""
    version, _reserved, polygon_count = struct.unpack_from("<BBH", blob, 0)
    assert version == GEOM_VERSION, f"unsupported geom version {version}"
    offset = 4
    polygons = []
    for _ in range(polygon_count):
        (ring_count,) = struct.unpack_from("<H", blob, offset)
        offset += 2
        rings = []
        for _ in range(ring_count):
            (point_count,) = struct.unpack_from("<I", blob, offset)
            offset += 4
            pts = []
            for _ in range(point_count):
                x, y = struct.unpack_from("<dd", blob, offset)
                offset += 16
                pts.append((x, y))
            rings.append(pts)
        polygons.append(rings)
    return polygons


def shoelace_area(ring):
    """Absolute polygon area via the shoelace formula (planar, in squared degrees)."""
    n = len(ring)
    s = 0.0
    for i in range(n):
        x1, y1 = ring[i]
        x2, y2 = ring[(i + 1) % n]
        s += x1 * y2 - x2 * y1
    return abs(s) / 2.0
