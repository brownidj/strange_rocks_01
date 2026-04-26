# QSat Backend Build Job Contract

Last reviewed: 2026-04-26 (AEST)

## Goal
Define the online app-to-backend contract for building a field pack from Queensland QSat imagery for a selected area (for example JCU Townsville campus), then downloading it to device for offline use.

## End-to-End Flow
1. Mobile app (online) submits a build job with polygon and source preset.
2. Backend worker builds source MBTiles from QSat ImageServer.
3. Backend worker runs existing T2/T3 pack build + validation.
4. Backend stores output archive and manifest.
5. Mobile app polls status and downloads final pack when ready.

## Source Preset
- `source_preset`: `qld_qsat_wos_latestsatellite_allusers`
- `imageserver_url`: `https://spatial-img.information.qld.gov.au/arcgis/rest/services/Basemaps/LatestSatelliteWOS_AllUsers/ImageServer`

## API Contract

### 1) Create Job
`POST /v1/field-pack-build-jobs`

Request body:
```json
{
  "name": "JCU Townsville Campus QSat",
  "field_area": {
    "name": "JCU Townsville Campus",
    "geojson": {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {
            "type": "Polygon",
            "coordinates": [[[146.7406,-19.3379],[146.7798,-19.3379],[146.7798,-19.3078],[146.7406,-19.3078],[146.7406,-19.3379]]]
          },
          "properties": {}
        }
      ]
    }
  },
  "tile_build": {
    "source_preset": "qld_qsat_wos_latestsatellite_allusers",
    "min_zoom": 16,
    "max_zoom": 18,
    "max_area_km2": 50,
    "max_size_mb": 500,
    "max_tiles": 6000
  },
  "metadata": {
    "provider": "Queensland Government QSat Mosaic",
    "license": "CC BY-SA (verify current terms)",
    "attribution": "Contains Queensland Government data. Refer to source licence terms."
  }
}
```

Response `202 Accepted`:
```json
{
  "job_id": "fpbj_01JT...",
  "status": "queued",
  "created_at_utc": "2026-04-26T01:21:03Z"
}
```

### 2) Get Job Status
`GET /v1/field-pack-build-jobs/{job_id}`

Response:
```json
{
  "job_id": "fpbj_01JT...",
  "status": "running",
  "stage": "build_source_mbtiles",
  "progress": {
    "tiles_fetched": 1280,
    "tiles_planned": 4523
  },
  "warnings": [],
  "created_at_utc": "2026-04-26T01:21:03Z",
  "updated_at_utc": "2026-04-26T01:23:48Z"
}
```

Terminal success response:
```json
{
  "job_id": "fpbj_01JT...",
  "status": "succeeded",
  "stage": "complete",
  "artifact": {
    "pack_id": "pack_01JT...",
    "manifest_url": "https://api.example.com/field-packs/pack_01JT.../manifest",
    "download_url": "https://api.example.com/field-packs/pack_01JT.../download",
    "size_bytes": 241882331,
    "sha256": "..."
  }
}
```

### 3) Optional Cancel
`POST /v1/field-pack-build-jobs/{job_id}:cancel`

## Status and Stage Enum
- Status: `queued | running | failed | succeeded | cancelled`
- Stages:
  - `queued`
  - `preflight`
  - `build_source_mbtiles`
  - `build_field_pack`
  - `validate_pack`
  - `persist_artifact`
  - `complete`

## Failure Codes
- `AREA_LIMIT_BREACH`
- `ZOOM_POLICY_BREACH`
- `SIZE_LIMIT_BREACH`
- `TILE_CAP_BREACH`
- `SOURCE_FETCH_FAILED`
- `SOURCE_EMPTY_TILE`
- `PACK_VALIDATION_FAILED`
- `LICENSE_MISSING`
- `ATTRIBUTION_MISSING`
- `INTERNAL_ERROR`

## Backend Worker Mapping (Current Repo Scripts)

Worker step 1: Build source MBTiles from ImageServer.
```bash
./scripts/build/build_qsat_from_imageserver.sh \
  --polygon /tmp/job/field_area.geojson \
  --output-root /tmp/job \
  --source-mbtiles /tmp/job/source_qsat.mbtiles \
  --min-zoom 16 \
  --max-zoom 18 \
  --max-tiles 6000 \
  --provider "Queensland Government QSat Mosaic" \
  --license "CC BY-SA (verify current terms)" \
  --attribution "Contains Queensland Government data. Refer to source licence terms."
```

Worker step 2: Build field pack with existing T2 pipeline.
```bash
./scripts/build/t2_build_parameterized_basemap.sh \
  --source /tmp/job/source_qsat.mbtiles \
  --polygon /tmp/job/field_area.geojson \
  --output-root /tmp/job/field_pack \
  --min-zoom 16 \
  --max-zoom 18 \
  --max-area-km2 50 \
  --max-size-mb 500 \
  --provider "Queensland Government QSat Mosaic" \
  --source-url "https://spatial-img.information.qld.gov.au/arcgis/rest/services/Basemaps/LatestSatelliteWOS_AllUsers/ImageServer" \
  --license "CC BY-SA (verify current terms)" \
  --attribution "Contains Queensland Government data. Refer to source licence terms."
```

Optional worker step 3: CI-style invariant checks and checksums.
```bash
./scripts/build/t3_assert_tile_invariants.sh --pack-root /tmp/job/field_pack
python3 scripts/build/lib/t3_write_artifact_manifest.py \
  --pack-root /tmp/job/field_pack \
  --output /tmp/job/field_pack/artifact_manifest.json
```

## Mobile App Online Behavior
- Submit job in `FieldAreaDefineScreen` after polygon selection.
- Show build queue/progress states via polling every 5-10 seconds.
- On `succeeded`, call existing field pack download/import flow (`manifest_url` then `download_url`).
- On `failed`, show failure code + actionable message:
  - reduce polygon size
  - reduce max zoom
  - retry later if source fetch failed

## JCU Townsville Starter Fixture
Use:
- `scripts/build/fixtures/polygon_jcu_townsville.geojson`

Example local run:
```bash
./scripts/build/build_qsat_from_imageserver.sh \
  --polygon scripts/build/fixtures/polygon_jcu_townsville.geojson \
  --output-root build/jcu_qsat \
  --min-zoom 16 \
  --max-zoom 17 \
  --max-tiles 5000 \
  --build-pack
```

## Local Endpoint Implementation (This Repo)

Run:
```bash
dart run scripts/backend/field_pack_backend_server.dart
```

Environment overrides:
- `FIELD_PACK_BACKEND_PORT` (default `8080`)
- `FIELD_PACK_SOURCE_ROOT` (default `build/jcu_qsat/field_pack_t3`)

Example:
```bash
curl -X POST http://127.0.0.1:8080/v1/field-pack-build-jobs \
  -H 'content-type: application/json' \
  -d @request.json
```
