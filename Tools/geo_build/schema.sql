-- Canonical Patchwork geodata schema (reference copy).
-- The authoritative definition lives in `geo_format.py` (SCHEMA); this file is a readable
-- reference for the same tables. Both the sample builder and the real pipeline emit this shape,
-- and the Swift data layer (Sources/PatchworkData) reads it.

PRAGMA user_version = 1;

-- Key/value metadata: dataset name, pinned TIGER/Line vintage, ZCTA count, bounds, honesty note.
CREATE TABLE meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- One row per ZCTA. `idx` is the stable, contiguous ZCTAIndex stored in the visited bitset.
-- `geom` is the compact binary polygon blob (see geo_format.py for the byte layout).
CREATE TABLE zcta (
    idx        INTEGER PRIMARY KEY,
    code       TEXT NOT NULL,
    min_x      REAL NOT NULL,   -- bounding box, planar (x = lon, y = lat)
    min_y      REAL NOT NULL,
    max_x      REAL NOT NULL,
    max_y      REAL NOT NULL,
    county_id  TEXT,            -- primary (max-overlap) county GEOID
    state_id   TEXT,            -- state FIPS
    place_name TEXT,            -- primary Census Place name, if any
    geom       BLOB NOT NULL
);
CREATE INDEX zcta_code_idx ON zcta(code);

-- Administrative regions: country / state / county / place.
CREATE TABLE region (
    id        TEXT PRIMARY KEY, -- "US" | state FIPS | county GEOID | place GEOID
    name      TEXT NOT NULL,
    kind      TEXT NOT NULL,    -- country | state | county | place
    parent_id TEXT
);
CREATE INDEX region_kind_idx ON region(kind);

-- Precomputed weighted-overlap table. For a region, member weights sum to ~1.0, so runtime
-- completion is a plain weighted sum of visited members (no runtime spatial intersection).
CREATE TABLE region_member (
    region_id TEXT NOT NULL,
    zcta_idx  INTEGER NOT NULL,
    weight    REAL NOT NULL,    -- area(zcta ∩ region) / area(region)
    PRIMARY KEY (region_id, zcta_idx)
);
CREATE INDEX region_member_region_idx ON region_member(region_id);
