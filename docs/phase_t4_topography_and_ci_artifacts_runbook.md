# Phase T4 Topography + CI Artifact Handling Runbook

## Status
Implemented.

## What T4 Adds
- Optional topography tile generation (`topography.mbtiles`) in the CI build wrapper.
- Metadata toggle and details:
  - `topography_enabled` (bool)
  - `topography` object (path, provider, license, attribution, zooms, tile_count, size_bytes) when enabled.
- Build/version stamping:
  - `build_stamp.json` with `build_timestamp_utc`, `git_sha`, and `git_ref`
  - `metadata.json.build_stamp` mirrors stamp values for downstream consumers
- Topography license + attribution checks.
- CI artifact upload and downstream download/verify workflow.

## Updated Scripts
- `scripts/build/t3_ci_build_pack.sh`
  - supports optional topography flags
  - writes topography metadata into `metadata.json`
- `scripts/build/t3_assert_tile_invariants.sh`
  - validates optional topography invariants when enabled
- `scripts/build/t3_ci_regression.sh`
  - now exercises topography generation path

## New Workflow Behavior
Workflow file:
- `.github/workflows/tile-pack-ci.yml`

Jobs:
1. `build-tile-pack`
   - runs T3/T4 regression build
   - computes artifact name using UTC timestamp + short git SHA
   - uploads generated artifact with retention policy (`retention-days: 14`)
2. `download-and-verify-artifact`
   - downloads uploaded artifact
   - runs invariant verification on downloaded pack

## Optional Topography Flags (CI Wrapper)
Use with `scripts/build/t3_ci_build_pack.sh`:
- `--topography-source /path/to/source.mbtiles`
- `--topography-min-zoom N`
- `--topography-max-zoom N`
- `--topography-provider "..."`
- `--topography-source-url "..."`
- `--topography-license "..."`
- `--topography-attribution "..."`
- `--git-sha "..."` (optional stamp override)
- `--build-timestamp-utc "..."` (optional stamp override)

If `--topography-source` is omitted:
- `topography_enabled` is set to `false`.

## Example Command

```bash
./scripts/build/t3_ci_build_pack.sh \
  --source /path/to/basemap_source.mbtiles \
  --polygon /path/to/polygon.geojson \
  --output-root build/field_pack_t3_ci \
  --provider "Basemap Provider" \
  --license "ODbL-1.0" \
  --attribution "(c) contributors" \
  --topography-source /path/to/topography_source.mbtiles \
  --topography-provider "Topography Provider" \
  --topography-license "CC-BY 4.0" \
  --topography-attribution "(c) Topography Provider"
```

## Output Expectations
Pack folder contains:
- `basemap.mbtiles`
- `topography.mbtiles` (when enabled)
- `metadata.json`
- `build_stamp.json`
- `artifact_manifest.json`
- `field_area.geojson`
- `licenses/*`

## Regression
Run locally:

```bash
./scripts/build/t3_ci_regression.sh --output-root build/t3_regression_pack
```

This verifies:
- basemap generation
- topography generation
- metadata toggle/details
- build stamp generation
- artifact manifest generation
- invariant checks
