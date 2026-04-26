#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: scripts/build/t3_assert_tile_invariants.sh --pack-root /path/to/pack"
}

PACK_ROOT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pack-root) PACK_ROOT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$PACK_ROOT" ]]; then
  usage
  exit 1
fi
if [[ ! -d "$PACK_ROOT" ]]; then
  echo "Pack root not found: $PACK_ROOT" >&2
  exit 1
fi

BASEMAP="$PACK_ROOT/basemap.mbtiles"
METADATA_JSON="$PACK_ROOT/metadata.json"
ARTIFACT_MANIFEST="$PACK_ROOT/artifact_manifest.json"
BUILD_STAMP="$PACK_ROOT/build_stamp.json"

for req in "$BASEMAP" "$METADATA_JSON" "$BUILD_STAMP"; do
  if [[ ! -f "$req" ]]; then
    echo "Missing required file: $req" >&2
    exit 1
  fi
done

check_mbtiles() {
  local file="$1"
  local label="$2"

  local tiles_table meta_table tile_index tile_count zero_blobs
  tiles_table=$(sqlite3 "$file" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='tiles';")
  meta_table=$(sqlite3 "$file" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='metadata';")
  tile_index=$(sqlite3 "$file" "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name='tile_index';")
  tile_count=$(sqlite3 "$file" "SELECT COUNT(*) FROM tiles;")
  zero_blobs=$(sqlite3 "$file" "SELECT COUNT(*) FROM tiles WHERE LENGTH(tile_data) = 0;")

  if [[ "$tiles_table" != "1" || "$meta_table" != "1" ]]; then
    echo "Invariant failed: $label must contain tiles and metadata tables" >&2
    exit 1
  fi
  if [[ "$tile_index" != "1" ]]; then
    echo "Invariant failed: $label must contain tile_index" >&2
    exit 1
  fi
  if [[ "$tile_count" -le 0 ]]; then
    echo "Invariant failed: $label tile_count must be > 0" >&2
    exit 1
  fi
  if [[ "$zero_blobs" -ne 0 ]]; then
    echo "Invariant failed: $label has $zero_blobs empty tile blobs" >&2
    exit 1
  fi

  echo "$tile_count"
}

BASE_TILE_COUNT=$(check_mbtiles "$BASEMAP" "basemap.mbtiles")

python3 - "$METADATA_JSON" "$BASE_TILE_COUNT" "$ARTIFACT_MANIFEST" "$PACK_ROOT" "$BUILD_STAMP" <<'PY'
import json
import pathlib
import sqlite3
import sys

metadata_path = pathlib.Path(sys.argv[1])
actual_tiles = int(sys.argv[2])
manifest_path = pathlib.Path(sys.argv[3])
pack_root = pathlib.Path(sys.argv[4])
build_stamp_path = pathlib.Path(sys.argv[5])

required = {
    "tile_schema_version",
    "source_provider",
    "generated_at_utc",
    "min_zoom",
    "max_zoom",
    "bounds",
    "predicted_size_bytes",
    "tile_count",
    "size_bytes",
    "license",
    "attribution",
    "topography_enabled",
    "build_stamp",
}

metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
missing = sorted(required - set(metadata.keys()))
if missing:
    raise SystemExit(f"Invariant failed: metadata missing keys {missing}")

if int(metadata["tile_count"]) != actual_tiles:
    raise SystemExit(
        f"Invariant failed: metadata tile_count={metadata['tile_count']} does not match MBTiles={actual_tiles}"
    )

if int(metadata["min_zoom"]) > int(metadata["max_zoom"]):
    raise SystemExit("Invariant failed: metadata min_zoom must be <= max_zoom")

if float(metadata["predicted_size_bytes"]) <= 0:
    raise SystemExit("Invariant failed: predicted_size_bytes must be > 0")

build_stamp = json.loads(build_stamp_path.read_text(encoding="utf-8"))
for key in ("build_stamp_version", "build_timestamp_utc", "git_sha", "git_ref"):
    if key not in build_stamp:
        raise SystemExit(f"Invariant failed: build_stamp.json missing key {key}")

if metadata.get("build_stamp") != build_stamp:
    raise SystemExit("Invariant failed: metadata.build_stamp must match build_stamp.json")

if metadata.get("topography_enabled"):
    topo = metadata.get("topography")
    if not isinstance(topo, dict):
        raise SystemExit("Invariant failed: topography_enabled=true but topography object missing")

    topo_path = pack_root / topo.get("path", "")
    if not topo_path.exists():
        raise SystemExit(f"Invariant failed: topography file missing: {topo_path}")

    conn = sqlite3.connect(topo_path)
    try:
        row = conn.execute("SELECT COUNT(*) FROM tiles").fetchone()
        topo_count = int(row[0])
    finally:
        conn.close()

    if topo_count <= 0:
        raise SystemExit("Invariant failed: topography tile_count must be > 0")
    if int(topo.get("tile_count", 0)) != topo_count:
        raise SystemExit(
            f"Invariant failed: topography metadata tile_count={topo.get('tile_count')} does not match MBTiles={topo_count}"
        )

if manifest_path.exists():
    artifact = json.loads(manifest_path.read_text(encoding="utf-8"))
    if int(artifact.get("file_count", 0)) <= 0:
        raise SystemExit("Invariant failed: artifact manifest file_count must be > 0")
    if not artifact.get("bundle_sha256"):
        raise SystemExit("Invariant failed: artifact manifest bundle_sha256 missing")

print("JSON invariants validated")
PY

echo "Tile invariants passed for: $PACK_ROOT"
