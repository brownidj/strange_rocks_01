# Phase T2 Parameterized Builder Runbook

## Status
Implemented.

## Script
- `scripts/build/t2_build_parameterized_basemap.sh`

## What T2 Adds
- Arbitrary polygon input (`Polygon` or `MultiPolygon` GeoJSON).
- Size prediction before generation.
- Clear failure messages for:
  - area limit breach
  - predicted size limit breach
  - zoom policy breach
  - missing license/attribution

## Core Inputs
- `--source`: prebuilt source MBTiles
- `--polygon`: GeoJSON polygon/feature/feature collection path
- `--min-zoom`, `--max-zoom`
- `--max-area-km2` (default `250`)
- `--max-size-mb` (default `500`)

## Example Command

```bash
./scripts/build/t2_build_parameterized_basemap.sh \
  --source /path/to/source.mbtiles \
  --polygon /path/to/field_area.geojson \
  --output-root build/field_pack_t2 \
  --min-zoom 10 \
  --max-zoom 15 \
  --provider "Open dataset provider" \
  --source-url "https://example.org/source" \
  --license "ODbL-1.0" \
  --attribution "(c) OpenStreetMap contributors"
```

## Output
- `build/field_pack_t2/basemap.mbtiles`
- `build/field_pack_t2/metadata.json`
- `build/field_pack_t2/field_area.geojson`
- `build/field_pack_t2/licenses/attribution.txt`
- `build/field_pack_t2/licenses/data_sources.json`

## Prediction Model (Current)
- Predicts tile count from bbox coverage across zoom range.
- Estimates average tile bytes from source MBTiles.
- Predicted size = `(predicted_tile_count * avg_tile_bytes) + 5MB overhead`.

This is intentionally conservative and intended for preflight gating.

## Failure Messages
Examples produced by script:
- `Area limit breach: polygon area X km^2 exceeds max Y km^2.`
- `Size limit breach: predicted output X MB exceeds max Y MB.`
- `Zoom policy breach: --min-zoom must be <= --max-zoom`
- `License check failed ...`
- `Attribution check failed ...`

## Notes
- Clipping is bbox-based (not exact polygon mask yet).
- Designed for practical MVP control of pack size and policy.
