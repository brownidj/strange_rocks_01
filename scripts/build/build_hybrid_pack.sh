#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/build/build_hybrid_pack.sh \
    --polygon /path/to/area.geojson \
    [--output-root build/jcu_hybrid] \
    [--min-zoom 9] \
    [--max-zoom 17] \
    [--max-tiles 12000]

Description:
  Builds a "hybrid-style" offline pack with:
    1) aerial basemap.mbtiles (QImagery/State Program source)
    2) labels.mbtiles transparent-ish label overlay (XYZ labels tiles)
    3) topography.mbtiles hillshade (Qld DEM raster function)
    4) T3/T4 CI metadata + invariants
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
IMG_BUILDER="$SCRIPT_DIR/build_qsat_from_imageserver.sh"
XYZ_BUILDER="$SCRIPT_DIR/xyz_tiles_to_mbtiles.sh"
T3_SCRIPT="$SCRIPT_DIR/t3_ci_build_pack.sh"

POLYGON=""
OUTPUT_ROOT="build/jcu_hybrid"
MIN_ZOOM="9"
MAX_ZOOM="17"
MAX_TILES="12000"

AERIAL_IMAGESERVER_URL="https://spatial-img.information.qld.gov.au/arcgis/rest/services/Basemaps/LatestStateProgram_AllUsers/ImageServer"
TOPO_IMAGESERVER_URL="https://spatial-img.information.qld.gov.au/arcgis/rest/services/Elevation/QldDem/ImageServer"
LABELS_URL_TEMPLATE="https://basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}.png"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --polygon) POLYGON="${2:-}"; shift 2 ;;
    --output-root) OUTPUT_ROOT="${2:-}"; shift 2 ;;
    --min-zoom) MIN_ZOOM="${2:-}"; shift 2 ;;
    --max-zoom) MAX_ZOOM="${2:-}"; shift 2 ;;
    --max-tiles) MAX_TILES="${2:-}"; shift 2 ;;
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

require_cmd python3
require_cmd sqlite3

if [[ ! -x "$IMG_BUILDER" || ! -x "$XYZ_BUILDER" || ! -x "$T3_SCRIPT" ]]; then
  echo "Required build script missing execute permission" >&2
  exit 1
fi

mkdir -p "$OUTPUT_ROOT"

AERIAL_ROOT="$OUTPUT_ROOT/aerial"
TOPO_ROOT="$OUTPUT_ROOT/topography"
PACK_ROOT="$OUTPUT_ROOT/field_pack"
AERIAL_SOURCE="$AERIAL_ROOT/source_aerial.mbtiles"
TOPO_SOURCE="$TOPO_ROOT/source_topography.mbtiles"
LABELS_OUTPUT="$PACK_ROOT/labels.mbtiles"

echo "Step 1/4: Build aerial source + pack skeleton"
"$IMG_BUILDER" \
  --imageserver-url "$AERIAL_IMAGESERVER_URL" \
  --polygon "$POLYGON" \
  --output-root "$AERIAL_ROOT" \
  --source-mbtiles "$AERIAL_SOURCE" \
  --min-zoom "$MIN_ZOOM" \
  --max-zoom "$MAX_ZOOM" \
  --max-tiles "$MAX_TILES" \
  --image-format png32 \
  --compression-quality 95 \
  --interpolation RSP_NearestNeighbor \
  --provider "Queensland Government State Program Aerial Imagery" \
  --license "Queensland Government terms (verify current terms)" \
  --attribution "Contains Queensland Government aerial imagery. Refer to source licence terms." \
  --name "QImagery State Program Aerial" \
  --build-pack

echo "Step 2/4: Build topography hillshade source"
"$IMG_BUILDER" \
  --imageserver-url "$TOPO_IMAGESERVER_URL" \
  --polygon "$POLYGON" \
  --output-root "$TOPO_ROOT" \
  --source-mbtiles "$TOPO_SOURCE" \
  --min-zoom "$MIN_ZOOM" \
  --max-zoom "$MAX_ZOOM" \
  --max-tiles "$MAX_TILES" \
  --image-format png32 \
  --compression-quality 95 \
  --interpolation RSP_BilinearInterpolation \
  --raster-function Hillshade \
  --provider "Queensland Government DEM Hillshade" \
  --license "Queensland Government terms (verify current terms)" \
  --attribution "Contains Queensland Government elevation data (QldDem). Refer to source licence terms." \
  --name "Qld DEM Hillshade"

echo "Step 3/4: Finalize field pack with topography metadata"
"$T3_SCRIPT" \
  --source "$AERIAL_SOURCE" \
  --polygon "$POLYGON" \
  --output-root "$PACK_ROOT" \
  --min-zoom "$MIN_ZOOM" \
  --max-zoom "$MAX_ZOOM" \
  --provider "Queensland Government State Program Aerial Imagery" \
  --source-url "$AERIAL_IMAGESERVER_URL" \
  --license "Queensland Government terms (verify current terms)" \
  --attribution "Contains Queensland Government aerial imagery. Refer to source licence terms." \
  --topography-source "$TOPO_SOURCE" \
  --topography-min-zoom "$MIN_ZOOM" \
  --topography-max-zoom "$MAX_ZOOM" \
  --topography-provider "Queensland Government DEM Hillshade" \
  --topography-source-url "$TOPO_IMAGESERVER_URL" \
  --topography-license "Queensland Government terms (verify current terms)" \
  --topography-attribution "Contains Queensland Government elevation data (QldDem). Refer to source licence terms."

echo "Step 4/4: Build labels overlay MBTiles"
BBOX="$("$POLY_INFO_PY" "$POLYGON" | sed -n '1p')"
"$XYZ_BUILDER" \
  --url-template "$LABELS_URL_TEMPLATE" \
  --output "$LABELS_OUTPUT" \
  --bbox "$BBOX" \
  --min-zoom "$MIN_ZOOM" \
  --max-zoom "$MAX_ZOOM" \
  --max-tiles "$MAX_TILES" \
  --name "Labels Overlay" \
  --attribution "© OpenStreetMap contributors © CARTO"

python3 scripts/build/lib/t3_write_artifact_manifest.py \
  --pack-root "$PACK_ROOT" \
  --output artifact_manifest.json

echo "Hybrid pack generated:"
echo "  pack_root=$PACK_ROOT"
echo "  basemap=$PACK_ROOT/basemap.mbtiles"
echo "  labels=$PACK_ROOT/labels.mbtiles"
echo "  topography=$PACK_ROOT/topography.mbtiles"
