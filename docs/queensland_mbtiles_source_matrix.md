# Queensland MBTiles Source Matrix

Last reviewed: 2026-04-26 (AEST)

## Purpose
Provide a practical source-selection matrix for generating offline `basemap.mbtiles` and optional `topography.mbtiles` for Queensland field packs.

This matrix is an engineering decision aid, not legal advice.

## Decision Summary

| Source | Type | Public availability | Redistribution risk | Recommendation |
|---|---|---|---|---|
| OpenStreetMap prebuilt MBTiles (e.g. OpenFreeMap / MapTiler data products) | Basemap (vector/raster, provider-dependent) | Public | Medium (depends on provider terms) | Green for rapid MVP if license+attribution are captured and acceptable |
| Queensland QSat free mosaic (via QImagery path, CC BY-SA noted on QLD page) | Satellite imagery | Public free access for mosaic | Medium (share-alike and attribution obligations) | Green/Yellow: good candidate, but verify downstream app/share obligations |
| QImagery historical frames (JPEG downloads) | Aerial frame imagery | Public download workflow | Medium/High (dataset-specific rights; some imagery purchasable/restricted) | Yellow: usable after per-dataset license check and conversion workflow |
| SISP subscription imagery | High-res aerial/satellite | Subscription | High for public app redistribution | Red for default public pack distribution unless explicit rights are granted |
| Landsat / Sentinel (through cited public programs) | Satellite imagery | Public | Low/Medium (still attribution/terms checks) | Green for open science-style layers if quality/resolution meets use-case |

## Queensland Government Signals Relevant to Licensing

The Queensland "Satellite imagery" page states:
- imagery is available online or by subscription
- some imagery is openly available
- some is restricted under license agreements
- a QSat mosaic is available for free under CC BY-SA

Reference:
- https://www.business.qld.gov.au/running-business/support-services/mapping-data-imagery/imagery/satellite

The QImagery page states:
- users can download high-resolution JPEG frames
- some imagery in Queensland Globe remains under license and must be purchased

Reference:
- https://www.business.qld.gov.au/running-business/support-services/mapping-data-imagery/imagery/qimagery

The SISP page states:
- subscription-based access
- license conditions vary by supplier
- usage is generally framed around internal, non-paid distribution/display contexts

Reference:
- https://www.business.qld.gov.au/running-business/support-services/mapping-data-imagery/imagery/sisp

## What This Means for Our Pipeline

Current scripts expect MBTiles input:
- `scripts/build/t2_build_parameterized_basemap.sh`
- `scripts/build/t3_ci_build_pack.sh`
- `scripts/build/prebuilt_mbtiles_to_fieldpack.sh`

Therefore, any Queensland source must end up as a local MBTiles file with:
- `tiles` table
- `metadata` table (or explicit license/attribution flags at build time)

If source data is not already MBTiles (for example JPEG frames or service-based imagery), add a preprocessing step to tile and package into MBTiles before T2/T3.

## Minimum Compliance Gate Before Use

For each chosen source, record and verify:
1. Explicit permission for offline redistribution inside downloadable field packs.
2. Required attribution wording.
3. License identifier/text (`metadata.license` and `licenses/data_sources.json`).
4. Share-alike or downstream publication obligations (if any).
5. Any prohibited use (commercial, resale, editable delivery, etc.).

If any item is unclear, treat source as "Yellow" and block production use until clarified.

## Recommended Source Strategy (Now)

1. Basemap MVP:
   - Use a known MBTiles provider path with clear redistribution terms.
   - Keep zoom/area conservative and enforce existing T2 gates.
2. Queensland imagery overlay:
   - Pilot with QSat free mosaic only after legal check of CC BY-SA implications for app distribution.
3. Avoid SISP feeds for public pack outputs unless contract explicitly permits redistribution in this app model.

## Proposed Next Step

Create `docs/licensing/source_register.md` with one row per actual dataset used in builds:
- dataset name/version/date
- source URL
- license text
- attribution text
- approval owner/date
- allowed pack scope (internal, client, public)
