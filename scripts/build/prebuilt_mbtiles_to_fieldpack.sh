#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/build/prebuilt_mbtiles_to_fieldpack.sh \
    --source /path/to/source.mbtiles \
    --output /path/to/basemap.mbtiles \
    --bbox minLon,minLat,maxLon,maxLat \
    --min-zoom 10 \
    --max-zoom 15 \
    [--name "Field Pack Basemap"]

Description:
  Clips a prebuilt MBTiles file to a bounding box and zoom range, producing
  a pack-ready basemap.mbtiles. Assumes MBTiles uses TMS tile_row storage.
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

SOURCE=""
OUTPUT=""
BBOX=""
MIN_ZOOM=""
MAX_ZOOM=""
NAME="Field Pack Basemap"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SOURCE="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT="${2:-}"
      shift 2
      ;;
    --bbox)
      BBOX="${2:-}"
      shift 2
      ;;
    --min-zoom)
      MIN_ZOOM="${2:-}"
      shift 2
      ;;
    --max-zoom)
      MAX_ZOOM="${2:-}"
      shift 2
      ;;
    --name)
      NAME="${2:-}"
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

if [[ -z "$SOURCE" || -z "$OUTPUT" || -z "$BBOX" || -z "$MIN_ZOOM" || -z "$MAX_ZOOM" ]]; then
  usage
  exit 1
fi

require_cmd sqlite3
require_cmd python3

if [[ ! -f "$SOURCE" ]]; then
  echo "Source MBTiles not found: $SOURCE" >&2
  exit 1
fi

IFS=',' read -r MIN_LON MIN_LAT MAX_LON MAX_LAT <<< "$BBOX"
if [[ -z "${MIN_LON:-}" || -z "${MIN_LAT:-}" || -z "${MAX_LON:-}" || -z "${MAX_LAT:-}" ]]; then
  echo "Invalid --bbox. Expected: minLon,minLat,maxLon,maxLat" >&2
  exit 1
fi

if (( MIN_ZOOM > MAX_ZOOM )); then
  echo "--min-zoom must be <= --max-zoom" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"
rm -f "$OUTPUT"

sqlite3 "$SOURCE" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='tiles';" >/dev/null
if [[ $? -ne 0 ]]; then
  echo "Source MBTiles must contain a 'tiles' table" >&2
  exit 1
fi

sqlite3 "$OUTPUT" <<SQL
PRAGMA journal_mode=OFF;
PRAGMA synchronous=OFF;
PRAGMA temp_store=MEMORY;

CREATE TABLE IF NOT EXISTS metadata (name TEXT, value TEXT);
CREATE TABLE IF NOT EXISTS tiles (
  zoom_level INTEGER,
  tile_column INTEGER,
  tile_row INTEGER,
  tile_data BLOB
);
CREATE UNIQUE INDEX IF NOT EXISTS tile_index ON tiles (zoom_level, tile_column, tile_row);
SQL

# Copy metadata best-effort from source.
sqlite3 "$OUTPUT" <<SQL
ATTACH DATABASE '$SOURCE' AS src;
INSERT INTO metadata(name, value)
SELECT name, value FROM src.metadata
WHERE name IN ('attribution', 'description', 'format', 'type', 'version');
DETACH DATABASE src;
SQL

RANGE_SQL=$(python3 - "$MIN_LON" "$MIN_LAT" "$MAX_LON" "$MAX_LAT" "$MIN_ZOOM" "$MAX_ZOOM" <<'PY'
import math
import sys

min_lon, min_lat, max_lon, max_lat = map(float, sys.argv[1:5])
min_zoom = int(sys.argv[5])
max_zoom = int(sys.argv[6])

# Clamp to web mercator limits.
min_lat = max(min_lat, -85.05112878)
max_lat = min(max_lat, 85.05112878)

def lon_to_xtile(lon, z):
    n = 2 ** z
    x = int(math.floor((lon + 180.0) / 360.0 * n))
    return max(0, min(n - 1, x))

def lat_to_ytile(lat, z):
    n = 2 ** z
    lat_rad = math.radians(lat)
    y = int(math.floor((1.0 - math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi) / 2.0 * n))
    return max(0, min(n - 1, y))

for z in range(min_zoom, max_zoom + 1):
    n = 2 ** z
    x_min = lon_to_xtile(min_lon, z)
    x_max = lon_to_xtile(max_lon, z)

    y_min_xyz = lat_to_ytile(max_lat, z)  # north
    y_max_xyz = lat_to_ytile(min_lat, z)  # south

    # MBTiles tile_row is TMS.
    y_min_tms = (n - 1) - y_max_xyz
    y_max_tms = (n - 1) - y_min_xyz

    if x_min > x_max:
        x_min, x_max = x_max, x_min
    if y_min_tms > y_max_tms:
        y_min_tms, y_max_tms = y_max_tms, y_min_tms

    print(f"INSERT OR IGNORE INTO tiles(zoom_level, tile_column, tile_row, tile_data) ")
    print(f"SELECT zoom_level, tile_column, tile_row, tile_data FROM src.tiles ")
    print(f"WHERE zoom_level = {z} ")
    print(f"  AND tile_column BETWEEN {x_min} AND {x_max} ")
    print(f"  AND tile_row BETWEEN {y_min_tms} AND {y_max_tms};")
PY
)

sqlite3 "$OUTPUT" <<SQL
ATTACH DATABASE '$SOURCE' AS src;
$RANGE_SQL
DETACH DATABASE src;

DELETE FROM metadata WHERE name IN ('name','bounds','minzoom','maxzoom','center','tile_schema_version');
INSERT INTO metadata(name, value) VALUES
  ('name', '$NAME'),
  ('bounds', '$MIN_LON,$MIN_LAT,$MAX_LON,$MAX_LAT'),
  ('minzoom', '$MIN_ZOOM'),
  ('maxzoom', '$MAX_ZOOM'),
  ('tile_schema_version', '1');

VACUUM;
SQL

TILE_COUNT=$(sqlite3 "$OUTPUT" "SELECT COUNT(*) FROM tiles;")
SIZE_BYTES=$(wc -c < "$OUTPUT" | tr -d ' ')

echo "Created: $OUTPUT"
echo "Tile count: $TILE_COUNT"
echo "Size bytes: $SIZE_BYTES"
