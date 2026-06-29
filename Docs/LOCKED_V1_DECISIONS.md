# Locked V1 Decisions

This document is the canonical source of truth for Patchwork V1 product and architecture constraints. These decisions are locked for V1 unless a later accepted task explicitly changes this file and the corresponding status, assumptions, risk, privacy, and release documents.

## Locked V1 Decisions (verbatim)

1. iOS native only;
2. SwiftUI shell;
3. MapKit via UIKit MKMapView bridge using MKOverlay/MKMultiPolygon/MKMultiPolygonRenderer, perf via viewport culling + LOD geometry simplification + county/state fallback;
4. Census-derived local ZCTA/county/state/Census-Place data pinned to the 2025 TIGER/Line vintage, shipped as compressed SQLite/binary (NOT a giant runtime GeoJSON; GeoJSON only as an intermediate/debug artifact); product copy must say "ZIP-like patches" or "postal areas", never "official ZIP coverage";
5. coverage stored as a compact visited-ZCTA bitset;
6. city/county/state rollups via precomputed weighted-overlap lookup tables (runtime = weighted sums, not spatial intersections);
7. coordinate to ZCTA resolved locally via spatial index then candidate polygons then point-in-polygon (NO network reverse-geocoding);
8. SwiftData local persistence, iOS 17+, user state only, heavy geo assets bundled read-only;
9. StoreKit 2 monetization: Free + Pro annual (default) + Lifetime, no ads, no data sales;
10. location permission While-Using first plus a "Claim Current Patch" action, with Always/background behind a later permission gate.

## V1 Hard Exclusions

Patchwork V1 must not include:

- backend services;
- Firebase;
- accounts;
- leaderboard;
- social graph;
- Mapbox;
- MapLibre;
- ads;
- analytics SDK;
- server receipt validation;
- iCloud sync;
- Android;
- web;
- multiplayer.

## Product Positioning Guardrail

Patchwork is a private, local-first iOS map-completion game with the tagline: "Color the map you actually live."

User-facing copy must describe areas as "ZIP-like patches" or "postal areas" and must not claim "official ZIP coverage."
