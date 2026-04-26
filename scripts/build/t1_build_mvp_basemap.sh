#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/build/t1_build_mvp_basemap.sh \
    --source /path/to/source.mbtiles \
    [--output-root build/field_pack_mvp_t1] \
    [--provider "Open dataset provider"] \
    [--source-url "https://example.org/dataset"] \
    [--license "ODbL-1.0"] \
    [--attribution "(c) Contributors"]

Description:
  Phase T1 MVP pipeline for one fixed test area (Townsville bbox):
  1) clips source MBTiles into basemap.mbtiles
  2) generates metadata.json
  3) enforces license + attribution checks
  4) writes sample pack support files
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

SOURCE=""
OUTPUT_ROOT="build/field_pack_mvp_t1"
PROVIDER="Unknown Provider"
SOURCE_URL=""
LICENSE_OVERRIDE=""
ATTRIBUTION_OVERRIDE=""

# Fixed T1 MVP area and zoom policy.
BBOX="146.70,-19.45,147.20,-18.95"
MIN_ZOOM="10"
MAX_ZOOM="15"
PACK_NAME="Townsville MVP Basemap"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SOURCE="${2:-}"
      shift 2
      ;;
    --output-root)
      OUTPUT_ROOT="${2:-}"
      shift 2
      ;;
    --provider)
      PROVIDER="${2:-}"
      shift 2
      ;;
    --source-url)
      SOURCE_URL="${2:-}"
      shift 2
      ;;
    --license)
      LICENSE_OVERRIDE="${2:-}"
      shift 2
      ;;
    --attribution)
      ATTRIBUTION_OVERRIDE="${2:-}"
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

if [[ -z "$SOURCE" ]]; then
  usage
  exit 1
fi

require_cmd sqlite3
require_cmd python3

if [[ ! -f "$SOURCE" ]]; then
  echo "Source MBTiles not found: $SOURCE" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIP_SCRIPT="$SCRIPT_DIR/prebuilt_mbtiles_to_fieldpack.sh"
if [[ ! -x "$CLIP_SCRIPT" ]]; then
  echo "Required script missing or not executable: $CLIP_SCRIPT" >&2
  exit 1
fi

source_meta_value() {
  local key="$1"
  sqlite3 "$SOURCE" "SELECT value FROM metadata WHERE name = '$key' LIMIT 1;" || true
}

LICENSE_VALUE="${LICENSE_OVERRIDE}"
ATTRIBUTION_VALUE="${ATTRIBUTION_OVERRIDE}"

if [[ -z "$LICENSE_VALUE" ]]; then
  LICENSE_VALUE="$(source_meta_value license)"
fi
if [[ -z "$ATTRIBUTION_VALUE" ]]; then
  ATTRIBUTION_VALUE="$(source_meta_value attribution)"
fi

if [[ -z "$LICENSE_VALUE" ]]; then
  echo "License check failed: provide --license or source metadata.license" >&2
  exit 1
fi
if [[ -z "$ATTRIBUTION_VALUE" ]]; then
  echo "Attribution check failed: provide --attribution or source metadata.attribution" >&2
  exit 1
fi

rm -rf "$OUTPUT_ROOT"
mkdir -p "$OUTPUT_ROOT/licenses"

BASEMAP_PATH="$OUTPUT_ROOT/basemap.mbtiles"

"$CLIP_SCRIPT" \
  --source "$SOURCE" \
  --output "$BASEMAP_PATH" \
  --bbox "$BBOX" \
  --min-zoom "$MIN_ZOOM" \
  --max-zoom "$MAX_ZOOM" \
  --name "$PACK_NAME"

TILE_COUNT="$(sqlite3 "$BASEMAP_PATH" "SELECT COUNT(*) FROM tiles;")"
SIZE_BYTES="$(wc -c < "$BASEMAP_PATH" | tr -d ' ')"
GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat > "$OUTPUT_ROOT/licenses/attribution.txt" <<TXT
$ATTRIBUTION_VALUE
TXT

cat > "$OUTPUT_ROOT/licenses/data_sources.json" <<JSON
[
  {
    "provider": "${PROVIDER}",
    "source_url": "${SOURCE_URL}",
    "license": "${LICENSE_VALUE}",
    "attribution": "${ATTRIBUTION_VALUE}",
    "generated_at_utc": "${GENERATED_AT}"
  }
]
JSON

cat > "$OUTPUT_ROOT/field_area.geojson" <<'GEOJSON'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "name": "Townsville MVP Test Area"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [146.70, -19.45],
            [147.20, -19.45],
            [147.20, -18.95],
            [146.70, -18.95],
            [146.70, -19.45]
          ]
        ]
      }
    }
  ]
}
GEOJSON

python3 - "$OUTPUT_ROOT/metadata.json" "$TILE_COUNT" "$SIZE_BYTES" "$GENERATED_AT" "$MIN_ZOOM" "$MAX_ZOOM" "$BBOX" "$PROVIDER" "$LICENSE_VALUE" "$ATTRIBUTION_VALUE" <<'PY'
import json
import sys

(
    output_path,
    tile_count,
    size_bytes,
    generated_at,
    min_zoom,
    max_zoom,
    bbox,
    provider,
    license_value,
    attribution,
) = sys.argv[1:]

metadata = {
    "tile_schema_version": 1,
    "source_provider": provider,
    "generated_at_utc": generated_at,
    "min_zoom": int(min_zoom),
    "max_zoom": int(max_zoom),
    "bounds": bbox,
    "tile_count": int(tile_count),
    "size_bytes": int(size_bytes),
    "license": license_value,
    "attribution": attribution,
}

with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(metadata, handle, indent=2)
    handle.write("\n")
PY

echo ""
echo "T1 MVP pack assets written to: $OUTPUT_ROOT"
echo "  - basemap.mbtiles"
echo "  - metadata.json"
echo "  - field_area.geojson"
echo "  - licenses/attribution.txt"
echo "  - licenses/data_sources.json"
echo ""
echo "Run validation:"
echo "  ./scripts/build/t1_validate_mvp_pack.sh --pack-root $OUTPUT_ROOT"
