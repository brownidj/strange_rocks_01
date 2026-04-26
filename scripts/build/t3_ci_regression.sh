#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: scripts/build/t3_ci_regression.sh [--output-root build/t3_regression_pack]"
}

OUTPUT_ROOT="build/t3_regression_pack"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-root) OUTPUT_ROOT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

TMP_DIR="$(mktemp -d)"
BASE_SOURCE="$TMP_DIR/source_basemap.mbtiles"
TOPO_SOURCE="$TMP_DIR/source_topography.mbtiles"
POLYGON="scripts/build/fixtures/polygon_townsville.geojson"

create_source() {
  local db="$1"
  local marker="$2"

  sqlite3 "$db" <<SQL
CREATE TABLE metadata (name TEXT, value TEXT);
CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);
CREATE UNIQUE INDEX tile_index ON tiles (zoom_level,tile_column,tile_row);
INSERT INTO metadata(name,value) VALUES ('format','png');
INSERT INTO metadata(name,value) VALUES ('license','CC-BY 4.0');
INSERT INTO metadata(name,value) VALUES ('attribution','Synthetic CI attribution $marker');
SQL

  python3 - "$db" "$marker" <<'PY'
import math
import sqlite3
import sys

db, marker = sys.argv[1], int(sys.argv[2])
conn = sqlite3.connect(db)
cur = conn.cursor()

min_lon, min_lat, max_lon, max_lat = 146.7, -19.45, 147.2, -18.95

def lon_to_xtile(lon, z):
    n = 2 ** z
    return max(0, min(n - 1, int((lon + 180.0) / 360.0 * n)))

def lat_to_ytile(lat, z):
    n = 2 ** z
    lat = max(-85.05112878, min(85.05112878, lat))
    rad = math.radians(lat)
    y = int((1.0 - math.log(math.tan(rad) + (1 / math.cos(rad))) / math.pi) / 2.0 * n)
    return max(0, min(n - 1, y))

for z in range(10, 16):
    n = 2 ** z
    x_min = lon_to_xtile(min_lon, z)
    x_max = lon_to_xtile(max_lon, z)
    y_min = lat_to_ytile(max_lat, z)
    y_max = lat_to_ytile(min_lat, z)
    for x in range(x_min, x_max + 1):
        for y_xyz in range(y_min, y_max + 1):
            y_tms = (n - 1) - y_xyz
            blob = bytes([z % 256, x % 256, y_tms % 256, marker])
            cur.execute(
                "INSERT OR REPLACE INTO tiles(zoom_level,tile_column,tile_row,tile_data) VALUES (?,?,?,?)",
                (z, x, y_tms, blob),
            )

conn.commit()
conn.close()
PY
}

create_source "$BASE_SOURCE" 99
create_source "$TOPO_SOURCE" 77

rm -rf "$OUTPUT_ROOT"

./scripts/build/t3_ci_build_pack.sh \
  --source "$BASE_SOURCE" \
  --polygon "$POLYGON" \
  --output-root "$OUTPUT_ROOT" \
  --min-zoom 10 \
  --max-zoom 15 \
  --max-area-km2 1000 \
  --max-size-mb 100 \
  --provider "Synthetic CI Provider" \
  --source-url "https://example.org/ci" \
  --license "CC-BY 4.0" \
  --attribution "Synthetic CI attribution basemap" \
  --topography-source "$TOPO_SOURCE" \
  --topography-provider "Synthetic CI Topography Provider" \
  --topography-source-url "https://example.org/ci-topography" \
  --topography-license "CC-BY 4.0" \
  --topography-attribution "Synthetic CI attribution topography"

echo "Regression pass: artifacts in $OUTPUT_ROOT"
