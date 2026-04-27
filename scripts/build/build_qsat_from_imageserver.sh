#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/build/build_qsat_from_imageserver.sh \
    --polygon /path/to/area.geojson \
    [--imageserver-url "https://spatial-img.information.qld.gov.au/arcgis/rest/services/Basemaps/LatestSatelliteWOS_AllUsers/ImageServer"] \
    [--output-root build/qsat_townsville] \
    [--source-mbtiles build/qsat_townsville/source_qsat.mbtiles] \
    [--min-zoom 10] \
    [--max-zoom 17] \
    [--max-tiles 6000] \
    [--provider "Queensland Government QSat Mosaic"] \
    [--license "CC BY-SA (verify current terms)"] \
    [--attribution "Contains Queensland Government data. Refer to source licence terms."] \
    [--image-format "png32"] \
    [--compression-quality 95] \
    [--interpolation "RSP_NearestNeighbor"] \
    [--raster-function "None"] \
    [--mosaic-where "product_type = 3 AND res_type = 1"] \
    [--prefer-highest-res] \
    [--name "QSat Townsville Source"] \
    [--build-pack]

Description:
  Fetches 256x256 tiles from an ArcGIS ImageServer exportImage endpoint over the
  polygon bounding box and writes source MBTiles. Optionally invokes T2 pack build.

Notes:
  - Current implementation clips by bbox, not exact polygon mask.
  - Designed as a backend/CI worker step, not on-device generation.
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLY_INFO_PY="$SCRIPT_DIR/lib/geojson_polygon_info.py"
T2_SCRIPT="$SCRIPT_DIR/t2_build_parameterized_basemap.sh"

POLYGON=""
IMAGESERVER_URL="https://spatial-img.information.qld.gov.au/arcgis/rest/services/Basemaps/LatestSatelliteWOS_AllUsers/ImageServer"
OUTPUT_ROOT="build/qsat_townsville"
SOURCE_MBTILES=""
MIN_ZOOM="10"
MAX_ZOOM="17"
MAX_TILES="6000"
PROVIDER="Queensland Government QSat Mosaic"
LICENSE_VALUE="CC BY-SA (verify current terms)"
ATTRIBUTION_VALUE="Contains Queensland Government data. Refer to source licence terms."
NAME_VALUE="QSat Source"
BUILD_PACK="false"
IMAGE_FORMAT="png32"
COMPRESSION_QUALITY="95"
INTERPOLATION="RSP_NearestNeighbor"
RASTER_FUNCTION="None"
MOSAIC_WHERE=""
PREFER_HIGHEST_RES="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --polygon) POLYGON="${2:-}"; shift 2 ;;
    --imageserver-url) IMAGESERVER_URL="${2:-}"; shift 2 ;;
    --output-root) OUTPUT_ROOT="${2:-}"; shift 2 ;;
    --source-mbtiles) SOURCE_MBTILES="${2:-}"; shift 2 ;;
    --min-zoom) MIN_ZOOM="${2:-}"; shift 2 ;;
    --max-zoom) MAX_ZOOM="${2:-}"; shift 2 ;;
    --max-tiles) MAX_TILES="${2:-}"; shift 2 ;;
    --provider) PROVIDER="${2:-}"; shift 2 ;;
    --license) LICENSE_VALUE="${2:-}"; shift 2 ;;
    --attribution) ATTRIBUTION_VALUE="${2:-}"; shift 2 ;;
    --image-format) IMAGE_FORMAT="${2:-}"; shift 2 ;;
    --compression-quality) COMPRESSION_QUALITY="${2:-}"; shift 2 ;;
    --interpolation) INTERPOLATION="${2:-}"; shift 2 ;;
    --raster-function) RASTER_FUNCTION="${2:-}"; shift 2 ;;
    --mosaic-where) MOSAIC_WHERE="${2:-}"; shift 2 ;;
    --prefer-highest-res) PREFER_HIGHEST_RES="true"; shift ;;
    --name) NAME_VALUE="${2:-}"; shift 2 ;;
    --build-pack) BUILD_PACK="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$POLYGON" ]]; then
  usage
  exit 1
fi
if [[ ! -f "$POLYGON" ]]; then
  echo "Polygon not found: $POLYGON" >&2
  exit 1
fi
if (( MIN_ZOOM > MAX_ZOOM )); then
  echo "--min-zoom must be <= --max-zoom" >&2
  exit 1
fi
if [[ ! "$IMAGE_FORMAT" =~ ^(png|png8|png24|png32|jpg|jpgpng)$ ]]; then
  echo "--image-format must be one of: png,png8,png24,png32,jpg,jpgpng" >&2
  exit 1
fi
if ! [[ "$COMPRESSION_QUALITY" =~ ^[0-9]+$ ]] || (( COMPRESSION_QUALITY < 0 || COMPRESSION_QUALITY > 100 )); then
  echo "--compression-quality must be an integer in [0,100]" >&2
  exit 1
fi
if [[ ! "$INTERPOLATION" =~ ^(RSP_NearestNeighbor|RSP_BilinearInterpolation|RSP_CubicConvolution)$ ]]; then
  echo "--interpolation must be one of: RSP_NearestNeighbor,RSP_BilinearInterpolation,RSP_CubicConvolution" >&2
  exit 1
fi
if [[ ! "$RASTER_FUNCTION" =~ ^(None|Hillshade|Aspect|Slope_degrees|Slope_percent_rise)$ ]]; then
  echo "--raster-function must be one of: None,Hillshade,Aspect,Slope_degrees,Slope_percent_rise" >&2
  exit 1
fi
if (( MAX_ZOOM > 16 )); then
  echo "Warning: max zoom $MAX_ZOOM exceeds native QSat detail (~z16), so higher zooms may appear soft." >&2
fi

require_cmd curl
require_cmd sqlite3
require_cmd python3
if [[ ! -x "$POLY_INFO_PY" ]]; then
  echo "Missing executable: $POLY_INFO_PY" >&2
  exit 1
fi

mkdir -p "$OUTPUT_ROOT"
SOURCE_MBTILES="${SOURCE_MBTILES:-$OUTPUT_ROOT/source_qsat.mbtiles}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/qsat_tiles.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

POLY_INFO_OUTPUT="$("$POLY_INFO_PY" "$POLYGON")"
BBOX="$(printf '%s\n' "$POLY_INFO_OUTPUT" | sed -n '1p')"
IFS=',' read -r MIN_LON MIN_LAT MAX_LON MAX_LAT <<< "$BBOX"

TILE_PLAN="$TMP_DIR/tile_plan.csv"
python3 - "$MIN_LON" "$MIN_LAT" "$MAX_LON" "$MAX_LAT" "$MIN_ZOOM" "$MAX_ZOOM" "$TILE_PLAN" "$MAX_TILES" <<'PY'
import math
import sys

min_lon, min_lat, max_lon, max_lat = map(float, sys.argv[1:5])
min_zoom = int(sys.argv[5])
max_zoom = int(sys.argv[6])
out_path = sys.argv[7]
max_tiles = int(sys.argv[8])

origin_shift = 20037508.342789244

def clamp_lat(v: float) -> float:
    return max(min(v, 85.05112878), -85.05112878)

def lon_to_xtile(lon: float, z: int) -> int:
    n = 2 ** z
    x = int(math.floor((lon + 180.0) / 360.0 * n))
    return max(0, min(n - 1, x))

def lat_to_y_xyz(lat: float, z: int) -> int:
    n = 2 ** z
    lat_rad = math.radians(clamp_lat(lat))
    y = int(math.floor((1 - math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi) / 2 * n))
    return max(0, min(n - 1, y))

def xyz_to_mercator_bbox(x: int, y: int, z: int):
    n = 2 ** z
    tile_size = (2 * origin_shift) / n
    minx = -origin_shift + (x * tile_size)
    maxx = minx + tile_size
    maxy = origin_shift - (y * tile_size)
    miny = maxy - tile_size
    return minx, miny, maxx, maxy

rows = []
for z in range(min_zoom, max_zoom + 1):
    x_min = lon_to_xtile(min_lon, z)
    x_max = lon_to_xtile(max_lon, z)
    y_min = lat_to_y_xyz(max_lat, z)
    y_max = lat_to_y_xyz(min_lat, z)
    if x_min > x_max:
        x_min, x_max = x_max, x_min
    if y_min > y_max:
        y_min, y_max = y_max, y_min

    for x in range(x_min, x_max + 1):
        for y_xyz in range(y_min, y_max + 1):
            minx, miny, maxx, maxy = xyz_to_mercator_bbox(x, y_xyz, z)
            tms_y = (2 ** z - 1) - y_xyz
            rows.append((z, x, y_xyz, tms_y, minx, miny, maxx, maxy))

if len(rows) > max_tiles:
    raise SystemExit(
        f"Tile cap breach: {len(rows)} planned tiles exceeds --max-tiles {max_tiles}. "
        "Use smaller polygon or lower max zoom."
    )

with open(out_path, "w", encoding="utf-8") as handle:
    for r in rows:
        handle.write(",".join(str(v) for v in r) + "\n")

print(len(rows))
PY

PLANNED_COUNT="$(wc -l < "$TILE_PLAN" | tr -d ' ')"
if [[ "$PLANNED_COUNT" == "0" ]]; then
  echo "No tiles planned for bbox=$BBOX and zooms $MIN_ZOOM-$MAX_ZOOM" >&2
  exit 1
fi

mkdir -p "$(dirname "$SOURCE_MBTILES")"
rm -f "$SOURCE_MBTILES"

sqlite3 "$SOURCE_MBTILES" <<SQL
PRAGMA journal_mode=OFF;
PRAGMA synchronous=OFF;
PRAGMA temp_store=MEMORY;
CREATE TABLE metadata (name TEXT, value TEXT);
CREATE TABLE tiles (
  zoom_level INTEGER,
  tile_column INTEGER,
  tile_row INTEGER,
  tile_data BLOB
);
CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row);
SQL

INDEX=0
while IFS=',' read -r Z X Y_XYZ Y_TMS MINX MINY MAXX MAXY; do
  INDEX=$((INDEX + 1))
  TILE_FILE="$TMP_DIR/tile_${Z}_${X}_${Y_XYZ}.img"
  URL="${IMAGESERVER_URL%/}/exportImage?bbox=${MINX},${MINY},${MAXX},${MAXY}&bboxSR=3857&imageSR=3857&size=256,256&format=${IMAGE_FORMAT}&compressionQuality=${COMPRESSION_QUALITY}&interpolation=${INTERPOLATION}&f=image"
  if [[ -n "$MOSAIC_WHERE" || "$PREFER_HIGHEST_RES" == "true" ]]; then
    MOSAIC_RULE_ENCODED="$(python3 - "$MOSAIC_WHERE" "$PREFER_HIGHEST_RES" <<'PY'
import json
import sys
import urllib.parse

where = sys.argv[1].strip()
prefer_high = sys.argv[2].lower() == "true"

rule = {}
if prefer_high:
    rule["mosaicMethod"] = "esriMosaicAttribute"
    rule["sortField"] = "res_value"
    rule["ascending"] = True
if where:
    rule["where"] = where

print(urllib.parse.quote(json.dumps(rule, separators=(",", ":"))))
PY
)"
    URL="${URL}&mosaicRule=${MOSAIC_RULE_ENCODED}"
  fi
  if [[ "$RASTER_FUNCTION" != "None" ]]; then
    RENDERING_RULE_ENCODED="$(python3 - "$RASTER_FUNCTION" <<'PY'
import json
import sys
import urllib.parse

name = sys.argv[1]
rule = {"rasterFunction": name}
print(urllib.parse.quote(json.dumps(rule, separators=(",", ":"))))
PY
)"
    URL="${URL}&renderingRule=${RENDERING_RULE_ENCODED}"
  fi

  curl --fail --silent --show-error --location \
    --retry 2 --retry-all-errors --connect-timeout 20 --max-time 120 \
    "$URL" -o "$TILE_FILE"

  if [[ ! -s "$TILE_FILE" ]]; then
    echo "Downloaded tile is empty: z=$Z x=$X y=$Y_XYZ" >&2
    exit 1
  fi

  sqlite3 "$SOURCE_MBTILES" \
    "INSERT OR REPLACE INTO tiles(zoom_level,tile_column,tile_row,tile_data) VALUES ($Z,$X,$Y_TMS,readfile('$TILE_FILE'));"

  if (( INDEX % 200 == 0 )); then
    echo "Fetched $INDEX/$PLANNED_COUNT tiles..."
  fi
done < "$TILE_PLAN"

GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
SOURCE_URL="${IMAGESERVER_URL%/}"
sqlite3 "$SOURCE_MBTILES" <<SQL
INSERT INTO metadata(name,value) VALUES
  ('name', '$NAME_VALUE'),
  ('type', 'baselayer'),
  ('format', '$IMAGE_FORMAT'),
  ('bounds', '$BBOX'),
  ('minzoom', '$MIN_ZOOM'),
  ('maxzoom', '$MAX_ZOOM'),
  ('source_provider', '$PROVIDER'),
  ('source_url', '$SOURCE_URL'),
  ('resampling', '$INTERPOLATION'),
  ('raster_function', '$RASTER_FUNCTION'),
  ('mosaic_where', '$MOSAIC_WHERE'),
  ('prefer_highest_res', '$PREFER_HIGHEST_RES'),
  ('license', '$LICENSE_VALUE'),
  ('attribution', '$ATTRIBUTION_VALUE'),
  ('generated_at_utc', '$GENERATED_AT'),
  ('tile_schema_version', '1');
SQL

COUNT="$(sqlite3 "$SOURCE_MBTILES" "SELECT COUNT(*) FROM tiles;")"
if [[ "$COUNT" == "0" ]]; then
  echo "Generated source MBTiles contains zero tiles." >&2
  exit 1
fi

echo "QSat source MBTiles generated:"
echo "  source_mbtiles=$SOURCE_MBTILES"
echo "  bbox=$BBOX"
echo "  min_zoom=$MIN_ZOOM"
echo "  max_zoom=$MAX_ZOOM"
echo "  tile_count=$COUNT"

if [[ "$BUILD_PACK" == "true" ]]; then
  PACK_ROOT="$OUTPUT_ROOT/field_pack"
  "$T2_SCRIPT" \
    --source "$SOURCE_MBTILES" \
    --polygon "$POLYGON" \
    --output-root "$PACK_ROOT" \
    --min-zoom "$MIN_ZOOM" \
    --max-zoom "$MAX_ZOOM" \
    --provider "$PROVIDER" \
    --source-url "$SOURCE_URL" \
    --license "$LICENSE_VALUE" \
    --attribution "$ATTRIBUTION_VALUE"
  echo "Pack output: $PACK_ROOT"
fi
