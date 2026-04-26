# Phase T1 MVP Pipeline Runbook

## Status
Implemented.

This runbook covers the exact workflow for:
- fixed test polygon clipping (`Townsville` bbox)
- tile metadata generation
- license + attribution enforcement
- manual validation artifact creation

## Scripts
- Build: `scripts/build/t1_build_mvp_basemap.sh`
- Validate: `scripts/build/t1_validate_mvp_pack.sh`
- Shared clip helper: `scripts/build/prebuilt_mbtiles_to_fieldpack.sh`

## Fixed T1 Configuration
- BBox: `146.70,-19.45,147.20,-18.95`
- Zooms: `10..15`
- Output default: `build/field_pack_mvp_t1/`

## Build Command

```bash
./scripts/build/t1_build_mvp_basemap.sh \
  --source /absolute/path/to/source.mbtiles \
  --provider "Your Provider Name" \
  --source-url "https://provider.example/data" \
  --license "ODbL-1.0" \
  --attribution "(c) OpenStreetMap contributors"
```

Notes:
- `--license` and `--attribution` are optional only when source MBTiles metadata already contains `license` and `attribution`.
- Script fails fast if both sources are missing for either value.

## Output Files
- `basemap.mbtiles`
- `metadata.json`
- `field_area.geojson`
- `licenses/attribution.txt`
- `licenses/data_sources.json`

## Validation Command

```bash
./scripts/build/t1_validate_mvp_pack.sh --pack-root build/field_pack_mvp_t1
```

Validation checks:
- required files exist
- MBTiles has `tiles` + `metadata` tables
- tile count > 0
- metadata has required keys
- metadata tile count > 0

## Manual Validation (Sample Pack Import)
Current app state does not yet include final map import/render (Phase 5). Manual validation for T1 therefore means:
1. Build and validate pack files.
2. Keep output pack as fixture artifact for Phase 5.
3. In Phase 5, import this sample pack and verify map rendering in airplane mode.

## Proof Run (Local Synthetic Source)
Completed in this workspace:
- build succeeded
- validation succeeded
- generated pack had non-zero tile count

