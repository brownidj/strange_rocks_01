# Map Tile Generation Implementation Plan

## Goal
Create a repeatable field-pack tile generation pipeline that produces offline `basemap.mbtiles` (and optional `topography.mbtiles`) for selected field areas, ready for Phase 5 map rendering.

## Why Now
Phase 5 depends on real offline map assets. The map UI can be built in parallel, but it cannot be validated end-to-end without generated MBTiles for at least one MVP test area.

## Scope
- In scope:
  - Generate `basemap.mbtiles` for one predefined MVP area.
  - Define tile schema/version metadata in pack manifest.
  - Validate tile package quality and size before pack publish.
  - Integrate generated tile artifacts into field pack outputs.
- Out of scope (first cut):
  - Full-state coverage generation.
  - On-device tile generation.
  - Dynamic server-side rendering at request time.

## Output Contract
Each field pack must include:

```text
basemap.mbtiles
metadata.json (or manifest.json tile section)
```

Required tile metadata fields:
- `tile_schema_version`
- `source_provider`
- `generated_at_utc`
- `min_zoom`
- `max_zoom`
- `bounds` (`minLon,minLat,maxLon,maxLat`)
- `tile_count`
- `size_bytes`
- `attribution`
- `license`

## Data Source and Licensing Gate
1. Select basemap source allowed for offline redistribution/caching.
2. Record license terms and attribution text in pack metadata.
3. Block publish if license requirements are missing.

## Technical Approach
Use an offline precompute pipeline (desktop/server-side):
1. Accept field area polygon (GeoJSON).
2. Compute tile coverage for target zoom levels.
3. Fetch/render map tiles for coverage set.
4. Write tiles into MBTiles (`z/x/y` with metadata table).
5. Run quality checks (missing tiles, corruption, extreme size).
6. Emit `basemap.mbtiles` into field-pack build directory.

## Zoom and Size Policy (MVP)
- Basemap defaults:
  - `min_zoom = 10`
  - `max_zoom = 15`
- Hard limits:
  - max area per request (for example 250 km² initially)
  - max MBTiles size budget (for example 500 MB for MVP)
- If predicted size exceeds limit:
  - fail with actionable message
  - suggest lower max zoom or smaller polygon

## Validation and QA Checks
Pre-publish checks:
- MBTiles file opens and has required tables (`metadata`, `tiles`).
- Tile coverage exists for all required zoom levels.
- No empty/zero-length tile blobs.
- Metadata bounds overlap requested polygon.
- File size within configured budget.

Runtime checks in app import:
- `basemap.mbtiles` exists.
- metadata values parse correctly.
- app compatibility check for `tile_schema_version`.

## Delivery Phases

### Phase T1 - MVP Pipeline for One Test Area
- Build command/script that outputs `basemap.mbtiles` for fixed test polygon.
- Add tile metadata generation.
- Add license + attribution checks.
- Manual validation with sample pack import.

### Phase T2 - Parameterized Builder
- Support arbitrary polygon input.
- Add size prediction before generation.
- Add failure messages for area/zoom limit breaches.

### Phase T3 - CI/Automation Integration
- Add non-interactive build mode for field-pack pipeline.
- Add artifact manifest checksuming.
- Add regression tests for tile output invariants.

### Phase T4 - Optional Topography Layer
- Generate `topography.mbtiles` (hillshade/contours) if licensed.
- Add topography toggle in pack metadata.

## Testing Plan
- Unit tests:
  - tile coverage calculation for polygon+zoom range
  - size estimator behavior
  - metadata generation and validation
- Integration tests:
  - generate MBTiles for fixture polygon and verify schema/tile counts
  - package integration test (MBTiles included + manifest references)
- Manual tests:
  - import generated pack in simulator
  - verify map renders fully in airplane mode

## Risks and Mitigations
- Licensing restriction changes:
  - Mitigation: explicit license gate + attribution checks at build time.
- Oversized tile outputs:
  - Mitigation: size prediction + hard caps + zoom fallback guidance.
- Slow generation times:
  - Mitigation: caching and incremental regeneration by tile diff.
- Visual inconsistency across zooms:
  - Mitigation: lock provider style/version in metadata.

## Definition of Done
- One command produces valid `basemap.mbtiles` for MVP area.
- Output passes schema, size, and coverage checks.
- MBTiles included in field pack and imported successfully by app.
- Offline map renders in simulator/device with network disabled.
- License/attribution info is present in pack metadata.

## Immediate Next Actions
1. Pick the initial licensed basemap source and attribution text.
2. Implement Phase T1 script and produce first MVP MBTiles artifact.
3. Run manual airplane-mode verification in the app.
