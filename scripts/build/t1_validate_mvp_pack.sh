#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/build/t1_validate_mvp_pack.sh --pack-root /path/to/field_pack_mvp_t1
USAGE
}

PACK_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pack-root)
      PACK_ROOT="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
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

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Missing required file: $path" >&2
    exit 1
  fi
}

require_file "$PACK_ROOT/basemap.mbtiles"
require_file "$PACK_ROOT/metadata.json"
require_file "$PACK_ROOT/licenses/attribution.txt"
require_file "$PACK_ROOT/licenses/data_sources.json"
require_file "$PACK_ROOT/field_area.geojson"

TILES_TABLE=$(sqlite3 "$PACK_ROOT/basemap.mbtiles" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='tiles';")
META_TABLE=$(sqlite3 "$PACK_ROOT/basemap.mbtiles" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='metadata';")
TILE_COUNT=$(sqlite3 "$PACK_ROOT/basemap.mbtiles" "SELECT COUNT(*) FROM tiles;")

if [[ "$TILES_TABLE" != "1" || "$META_TABLE" != "1" ]]; then
  echo "MBTiles schema check failed: missing tiles/metadata tables" >&2
  exit 1
fi

if [[ "$TILE_COUNT" -le 0 ]]; then
  echo "MBTiles content check failed: tile_count is $TILE_COUNT" >&2
  exit 1
fi

python3 - "$PACK_ROOT/metadata.json" <<'PY'
import json
import sys

path = sys.argv[1]
required = [
    "tile_schema_version",
    "source_provider",
    "generated_at_utc",
    "min_zoom",
    "max_zoom",
    "bounds",
    "tile_count",
    "size_bytes",
    "license",
    "attribution",
]

with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

missing = [key for key in required if key not in data]
if missing:
    raise SystemExit(f"metadata.json missing required keys: {missing}")

if int(data["tile_count"]) <= 0:
    raise SystemExit("metadata.json tile_count must be > 0")

print("metadata.json validated")
PY

echo "Validation passed for pack root: $PACK_ROOT"
echo "  tile_count=$TILE_COUNT"

echo "Manual import validation (current app state):"
echo "  1) Keep this pack folder as sample artifact for Phase 5 map integration."
echo "  2) When map import/render is wired, import this pack and verify airplane-mode rendering."
