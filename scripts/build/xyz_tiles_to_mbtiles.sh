#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/build/xyz_tiles_to_mbtiles.sh \
    --url-template "https://example.com/{z}/{x}/{y}.png" \
    --output /path/to/labels.mbtiles \
    --bbox minLon,minLat,maxLon,maxLat \
    --min-zoom 10 \
    --max-zoom 17 \
    [--max-tiles 12000] \
    [--name "Labels Overlay"] \
    [--attribution "Attribution text"]

Description:
  Downloads XYZ raster tiles and writes an MBTiles file (TMS tile_row) for
  offline label/overlay use.
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

URL_TEMPLATE=""
OUTPUT=""
BBOX=""
MIN_ZOOM=""
MAX_ZOOM=""
MAX_TILES="12000"
NAME="Labels Overlay"
ATTRIBUTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url-template) URL_TEMPLATE="${2:-}"; shift 2 ;;
    --output) OUTPUT="${2:-}"; shift 2 ;;
    --bbox) BBOX="${2:-}"; shift 2 ;;
    --min-zoom) MIN_ZOOM="${2:-}"; shift 2 ;;
    --max-zoom) MAX_ZOOM="${2:-}"; shift 2 ;;
    --max-tiles) MAX_TILES="${2:-}"; shift 2 ;;
    --name) NAME="${2:-}"; shift 2 ;;
    --attribution) ATTRIBUTION="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$URL_TEMPLATE" || -z "$OUTPUT" || -z "$BBOX" || -z "$MIN_ZOOM" || -z "$MAX_ZOOM" ]]; then
  usage
  exit 1
fi
if (( MIN_ZOOM > MAX_ZOOM )); then
  echo "--min-zoom must be <= --max-zoom" >&2
  exit 1
fi

require_cmd curl
require_cmd sqlite3
require_cmd python3

IFS=',' read -r MIN_LON MIN_LAT MAX_LON MAX_LAT <<< "$BBOX"
if [[ -z "${MIN_LON:-}" || -z "${MIN_LAT:-}" || -z "${MAX_LON:-}" || -z "${MAX_LAT:-}" ]]; then
  echo "Invalid --bbox. Expected: minLon,minLat,maxLon,maxLat" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/xyz_tiles.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

TILE_PLAN="$TMP_DIR/tile_plan.csv"
python3 - "$MIN_LON" "$MIN_LAT" "$MAX_LON" "$MAX_LAT" "$MIN_ZOOM" "$MAX_ZOOM" "$TILE_PLAN" "$MAX_TILES" <<'PY'
import math
import sys

min_lon, min_lat, max_lon, max_lat = map(float, sys.argv[1:5])
min_zoom = int(sys.argv[5])
max_zoom = int(sys.argv[6])
out_path = sys.argv[7]
max_tiles = int(sys.argv[8])

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
            tms_y = (2 ** z - 1) - y_xyz
            rows.append((z, x, y_xyz, tms_y))

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

rm -f "$OUTPUT"
sqlite3 "$OUTPUT" <<SQL
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
while IFS=',' read -r Z X Y_XYZ Y_TMS; do
  INDEX=$((INDEX + 1))
  TILE_FILE="$TMP_DIR/tile_${Z}_${X}_${Y_XYZ}.png"
  URL="${URL_TEMPLATE//\{z\}/$Z}"
  URL="${URL//\{x\}/$X}"
  URL="${URL//\{y\}/$Y_XYZ}"

  curl --fail --silent --show-error --location \
    --retry 2 --retry-all-errors --connect-timeout 20 --max-time 120 \
    "$URL" -o "$TILE_FILE"

  if [[ ! -s "$TILE_FILE" ]]; then
    echo "Downloaded tile is empty: z=$Z x=$X y=$Y_XYZ" >&2
    exit 1
  fi

  sqlite3 "$OUTPUT" \
    "INSERT OR REPLACE INTO tiles(zoom_level,tile_column,tile_row,tile_data) VALUES ($Z,$X,$Y_TMS,readfile('$TILE_FILE'));"

  if (( INDEX % 200 == 0 )); then
    echo "Fetched $INDEX/$PLANNED_COUNT tiles..."
  fi
done < "$TILE_PLAN"

GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
sqlite3 "$OUTPUT" <<SQL
INSERT INTO metadata(name,value) VALUES
  ('name', '$NAME'),
  ('type', 'overlay'),
  ('format', 'png'),
  ('bounds', '$BBOX'),
  ('minzoom', '$MIN_ZOOM'),
  ('maxzoom', '$MAX_ZOOM'),
  ('generated_at_utc', '$GENERATED_AT'),
  ('tile_schema_version', '1');
SQL
if [[ -n "$ATTRIBUTION" ]]; then
  sqlite3 "$OUTPUT" "INSERT INTO metadata(name,value) VALUES ('attribution', '$ATTRIBUTION');"
fi

COUNT="$(sqlite3 "$OUTPUT" "SELECT COUNT(*) FROM tiles;")"
if [[ "$COUNT" == "0" ]]; then
  echo "Generated labels MBTiles contains zero tiles." >&2
  exit 1
fi

echo "XYZ MBTiles generated:"
echo "  output=$OUTPUT"
echo "  bbox=$BBOX"
echo "  min_zoom=$MIN_ZOOM"
echo "  max_zoom=$MAX_ZOOM"
echo "  tile_count=$COUNT"
