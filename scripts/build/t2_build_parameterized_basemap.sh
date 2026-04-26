#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/build/t2_build_parameterized_basemap.sh \
    --source /path/to/source.mbtiles \
    --polygon /path/to/area.geojson \
    [--output-root build/field_pack_t2] \
    [--min-zoom 10] \
    [--max-zoom 15] \
    [--max-area-km2 250] \
    [--max-size-mb 500] \
    [--provider "Provider"] \
    [--source-url "https://example.org"] \
    [--license "ODbL-1.0"] \
    [--attribution "(c) contributors"]
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

source_meta_value() {
  local db="$1"
  local key="$2"
  sqlite3 "$db" "SELECT value FROM metadata WHERE name = '$key' LIMIT 1;" || true
}

SOURCE=""
POLYGON_PATH=""
OUTPUT_ROOT="build/field_pack_t2"
MIN_ZOOM="10"
MAX_ZOOM="15"
MAX_AREA_KM2="250"
MAX_SIZE_MB="500"
PROVIDER="Unknown Provider"
SOURCE_URL=""
LICENSE_OVERRIDE=""
ATTRIBUTION_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="${2:-}"; shift 2 ;;
    --polygon) POLYGON_PATH="${2:-}"; shift 2 ;;
    --output-root) OUTPUT_ROOT="${2:-}"; shift 2 ;;
    --min-zoom) MIN_ZOOM="${2:-}"; shift 2 ;;
    --max-zoom) MAX_ZOOM="${2:-}"; shift 2 ;;
    --max-area-km2) MAX_AREA_KM2="${2:-}"; shift 2 ;;
    --max-size-mb) MAX_SIZE_MB="${2:-}"; shift 2 ;;
    --provider) PROVIDER="${2:-}"; shift 2 ;;
    --source-url) SOURCE_URL="${2:-}"; shift 2 ;;
    --license) LICENSE_OVERRIDE="${2:-}"; shift 2 ;;
    --attribution) ATTRIBUTION_OVERRIDE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$SOURCE" || -z "$POLYGON_PATH" ]]; then
  usage
  exit 1
fi
if [[ ! -f "$SOURCE" ]]; then
  echo "Source MBTiles not found: $SOURCE" >&2
  exit 1
fi
if [[ ! -f "$POLYGON_PATH" ]]; then
  echo "Polygon file not found: $POLYGON_PATH" >&2
  exit 1
fi
if (( MIN_ZOOM > MAX_ZOOM )); then
  echo "Zoom policy breach: --min-zoom must be <= --max-zoom" >&2
  exit 1
fi

require_cmd sqlite3
require_cmd python3

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
CLIP_SCRIPT="$SCRIPT_DIR/prebuilt_mbtiles_to_fieldpack.sh"
POLY_INFO_PY="$LIB_DIR/geojson_polygon_info.py"
SIZE_PREDICT_PY="$LIB_DIR/mbtiles_size_predict.py"

for dep in "$CLIP_SCRIPT" "$POLY_INFO_PY" "$SIZE_PREDICT_PY"; do
  if [[ ! -x "$dep" ]]; then
    echo "Required executable missing: $dep" >&2
    exit 1
  fi
done

LICENSE_VALUE="${LICENSE_OVERRIDE}"
ATTRIBUTION_VALUE="${ATTRIBUTION_OVERRIDE}"
if [[ -z "$LICENSE_VALUE" ]]; then
  LICENSE_VALUE="$(source_meta_value "$SOURCE" license)"
fi
if [[ -z "$ATTRIBUTION_VALUE" ]]; then
  ATTRIBUTION_VALUE="$(source_meta_value "$SOURCE" attribution)"
fi
if [[ -z "$LICENSE_VALUE" ]]; then
  echo "License check failed: provide --license or source metadata.license" >&2
  exit 1
fi
if [[ -z "$ATTRIBUTION_VALUE" ]]; then
  echo "Attribution check failed: provide --attribution or source metadata.attribution" >&2
  exit 1
fi

POLY_INFO_OUTPUT="$($POLY_INFO_PY "$POLYGON_PATH")"
BBOX="$(printf '%s\n' "$POLY_INFO_OUTPUT" | sed -n '1p')"
AREA_KM2="$(printf '%s\n' "$POLY_INFO_OUTPUT" | sed -n '2p')"

AREA_BREACH=$(python3 - "$AREA_KM2" "$MAX_AREA_KM2" <<'PY'
import sys
print("1" if float(sys.argv[1]) > float(sys.argv[2]) else "0")
PY
)
if [[ "$AREA_BREACH" == "1" ]]; then
  echo "Area limit breach: polygon area ${AREA_KM2} km^2 exceeds max ${MAX_AREA_KM2} km^2." >&2
  echo "Action: reduce polygon size or raise --max-area-km2 intentionally." >&2
  exit 1
fi

PREDICT_OUTPUT="$($SIZE_PREDICT_PY "$BBOX" "$MIN_ZOOM" "$MAX_ZOOM" "$SOURCE")"
PRED_TILE_COUNT="$(printf '%s\n' "$PREDICT_OUTPUT" | sed -n '1p')"
AVG_TILE_BYTES="$(printf '%s\n' "$PREDICT_OUTPUT" | sed -n '2p')"
PRED_SIZE_BYTES="$(printf '%s\n' "$PREDICT_OUTPUT" | sed -n '3p')"

SIZE_BREACH=$(python3 - "$PRED_SIZE_BYTES" "$MAX_SIZE_MB" <<'PY'
import sys
pred = int(sys.argv[1])
limit = int(float(sys.argv[2]) * 1024 * 1024)
print("1" if pred > limit else "0")
PY
)
if [[ "$SIZE_BREACH" == "1" ]]; then
  PRED_MB=$(python3 - "$PRED_SIZE_BYTES" <<'PY'
import sys
print(f"{int(sys.argv[1]) / (1024*1024):.2f}")
PY
)
  echo "Size limit breach: predicted output ${PRED_MB} MB exceeds max ${MAX_SIZE_MB} MB." >&2
  echo "Action: reduce --max-zoom, reduce polygon extent, or increase --max-size-mb intentionally." >&2
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
  --name "Parameterized Field Pack Basemap"

ACTUAL_TILE_COUNT="$(sqlite3 "$BASEMAP_PATH" "SELECT COUNT(*) FROM tiles;")"
ACTUAL_SIZE_BYTES="$(wc -c < "$BASEMAP_PATH" | tr -d ' ')"
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

cp "$POLYGON_PATH" "$OUTPUT_ROOT/field_area.geojson"

python3 - "$OUTPUT_ROOT/metadata.json" "$GENERATED_AT" "$MIN_ZOOM" "$MAX_ZOOM" "$BBOX" "$PROVIDER" "$LICENSE_VALUE" "$ATTRIBUTION_VALUE" "$AREA_KM2" "$PRED_TILE_COUNT" "$AVG_TILE_BYTES" "$PRED_SIZE_BYTES" "$ACTUAL_TILE_COUNT" "$ACTUAL_SIZE_BYTES" <<'PY'
import json
import sys

(
    output_path,
    generated_at,
    min_zoom,
    max_zoom,
    bbox,
    provider,
    license_value,
    attribution,
    area_km2,
    predicted_tiles,
    avg_tile_bytes,
    predicted_bytes,
    actual_tiles,
    actual_bytes,
) = sys.argv[1:]

payload = {
    "tile_schema_version": 1,
    "source_provider": provider,
    "generated_at_utc": generated_at,
    "min_zoom": int(min_zoom),
    "max_zoom": int(max_zoom),
    "bounds": bbox,
    "polygon_area_km2": float(area_km2),
    "predicted_tile_count": int(predicted_tiles),
    "avg_source_tile_bytes": int(avg_tile_bytes),
    "predicted_size_bytes": int(predicted_bytes),
    "tile_count": int(actual_tiles),
    "size_bytes": int(actual_bytes),
    "license": license_value,
    "attribution": attribution,
}

with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
PY

echo "Parameterized pack generated at: $OUTPUT_ROOT"
echo "  bbox=$BBOX"
echo "  polygon_area_km2=$AREA_KM2"
echo "  predicted_size_bytes=$PRED_SIZE_BYTES"
echo "  actual_size_bytes=$ACTUAL_SIZE_BYTES"
