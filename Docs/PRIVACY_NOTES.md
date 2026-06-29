# Privacy Notes

Patchwork V1 is private, local-first, offline-first, and fully on-device.

## Privacy Commitments

- No backend.
- No accounts.
- No analytics SDK.
- No ads.
- No data sales.
- No Firebase.
- No iCloud sync in V1.
- No server receipt validation in V1.
- Location and geography processing remain on device.
- Heavy geodata assets are bundled read-only.
- User state is stored locally with SwiftData.

## Location Permission Model

V1 starts with While-Using location permission and a user-initiated "Claim Current Patch" action. Always/background location is reserved for a later permission gate and must not be introduced silently.

## Local Data

The visited map state is stored as a compact visited-ZCTA bitset. Completion rollups are computed locally from bundled precomputed weighted-overlap lookup tables.

## User-Facing Geography Language

Because ZCTAs are Census-derived ZIP-like areas rather than official USPS ZIP boundaries, product copy must say "ZIP-like patches" or "postal areas" and must not say "official ZIP coverage."
