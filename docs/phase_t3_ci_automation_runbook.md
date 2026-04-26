# Phase T3 CI Automation Runbook

## Status
Implemented.

## Deliverables
- Non-interactive CI build wrapper:
  - `scripts/build/t3_ci_build_pack.sh`
- Artifact checksum manifest generation:
  - `scripts/build/lib/t3_write_artifact_manifest.py`
- Tile output invariant checks:
  - `scripts/build/t3_assert_tile_invariants.sh`
- Regression runner:
  - `scripts/build/t3_ci_regression.sh`
- CI workflow:
  - `.github/workflows/tile-pack-ci.yml`

## CI Build (Non-Interactive)
Use `t3_ci_build_pack.sh` in CI to run a full deterministic pack build sequence:
1. Build parameterized pack via T2 script.
2. Generate `artifact_manifest.json` with file checksums.
3. Validate tile and metadata invariants.

Example:

```bash
./scripts/build/t3_ci_build_pack.sh \
  --source /path/to/source.mbtiles \
  --polygon /path/to/polygon.geojson \
  --output-root build/field_pack_t3_ci \
  --min-zoom 10 \
  --max-zoom 15 \
  --max-area-km2 250 \
  --max-size-mb 500 \
  --provider "Provider" \
  --source-url "https://example.org" \
  --license "ODbL-1.0" \
  --attribution "(c) contributors"
```

## Artifact Manifest
`artifact_manifest.json` includes:
- manifest version
- file count
- bundle hash (`bundle_sha256`)
- per-file path, size, sha256

This enables reproducible verification and downstream integrity checks.

## Invariant Checks
`t3_assert_tile_invariants.sh` enforces:
- MBTiles schema: `tiles`, `metadata`, `tile_index`
- `tile_count > 0`
- no zero-length tile blobs
- required `metadata.json` keys present
- `metadata.tile_count` equals actual MBTiles count
- zoom policy validity (`min_zoom <= max_zoom`)
- if present, artifact manifest has valid core fields

## Regression Test
`t3_ci_regression.sh` creates a synthetic source MBTiles fixture, runs the full T3 build, and validates invariants.

Run locally:

```bash
./scripts/build/t3_ci_regression.sh
```

## GitHub Actions
Workflow `.github/workflows/tile-pack-ci.yml` runs on push/PR and executes the regression script on Ubuntu.

## Notes
- Regression is self-contained and does not require network tile downloads.
- This phase focuses on automation and invariants; polygon-mask clipping remains future work.
