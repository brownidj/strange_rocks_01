#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/build/t3_ci_build_pack.sh \
    --source /path/to/source.mbtiles \
    --polygon /path/to/polygon.geojson \
    [--output-root build/field_pack_t3_ci] \
    [--min-zoom 10] [--max-zoom 17] \
    [--max-area-km2 250] [--max-size-mb 500] \
    [--provider "Provider"] [--source-url "https://example.org"] \
    [--license "ODbL-1.0"] [--attribution "(c) contributors"] \
    [--topography-source /path/to/topography_source.mbtiles] \
    [--topography-min-zoom 10] [--topography-max-zoom 15] \
    [--topography-provider "Provider"] [--topography-source-url "https://example.org"] \
    [--topography-license "CC-BY-4.0"] [--topography-attribution "(c) provider"] \
    [--git-sha "abc123..."] [--build-timestamp-utc "2026-04-26T12:00:00Z"]

Non-interactive CI wrapper:
  1) build parameterized basemap pack (T2)
  2) optionally build topography.mbtiles (T4)
  3) write artifact checksum manifest
  4) assert tile invariants
USAGE
}

source_meta_value() {
  local db="$1"
  local key="$2"
  sqlite3 "$db" "SELECT value FROM metadata WHERE name = '$key' LIMIT 1;" || true
}

SOURCE=""
POLYGON=""
OUTPUT_ROOT="build/field_pack_t3_ci"
MIN_ZOOM="10"
MAX_ZOOM="17"
MAX_AREA="250"
MAX_SIZE="500"
PROVIDER="Unknown Provider"
SOURCE_URL=""
LICENSE=""
ATTRIBUTION=""

TOPO_SOURCE=""
TOPO_MIN_ZOOM=""
TOPO_MAX_ZOOM=""
TOPO_PROVIDER=""
TOPO_SOURCE_URL=""
TOPO_LICENSE=""
TOPO_ATTRIBUTION=""
GIT_SHA_OVERRIDE=""
BUILD_TIMESTAMP_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="${2:-}"; shift 2 ;;
    --polygon) POLYGON="${2:-}"; shift 2 ;;
    --output-root) OUTPUT_ROOT="${2:-}"; shift 2 ;;
    --min-zoom) MIN_ZOOM="${2:-}"; shift 2 ;;
    --max-zoom) MAX_ZOOM="${2:-}"; shift 2 ;;
    --max-area-km2) MAX_AREA="${2:-}"; shift 2 ;;
    --max-size-mb) MAX_SIZE="${2:-}"; shift 2 ;;
    --provider) PROVIDER="${2:-}"; shift 2 ;;
    --source-url) SOURCE_URL="${2:-}"; shift 2 ;;
    --license) LICENSE="${2:-}"; shift 2 ;;
    --attribution) ATTRIBUTION="${2:-}"; shift 2 ;;
    --topography-source) TOPO_SOURCE="${2:-}"; shift 2 ;;
    --topography-min-zoom) TOPO_MIN_ZOOM="${2:-}"; shift 2 ;;
    --topography-max-zoom) TOPO_MAX_ZOOM="${2:-}"; shift 2 ;;
    --topography-provider) TOPO_PROVIDER="${2:-}"; shift 2 ;;
    --topography-source-url) TOPO_SOURCE_URL="${2:-}"; shift 2 ;;
    --topography-license) TOPO_LICENSE="${2:-}"; shift 2 ;;
    --topography-attribution) TOPO_ATTRIBUTION="${2:-}"; shift 2 ;;
    --git-sha) GIT_SHA_OVERRIDE="${2:-}"; shift 2 ;;
    --build-timestamp-utc) BUILD_TIMESTAMP_OVERRIDE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$SOURCE" || -z "$POLYGON" ]]; then
  usage
  exit 1
fi

BUILD_TIMESTAMP_UTC="${BUILD_TIMESTAMP_OVERRIDE:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"
if [[ -n "$GIT_SHA_OVERRIDE" ]]; then
  GIT_SHA="$GIT_SHA_OVERRIDE"
elif command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_SHA="$(git rev-parse --short=12 HEAD)"
else
  GIT_SHA="unknown"
fi

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_REF="$(git rev-parse --abbrev-ref HEAD)"
else
  GIT_REF="unknown"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIP_SCRIPT="$SCRIPT_DIR/prebuilt_mbtiles_to_fieldpack.sh"
POLY_INFO_PY="$SCRIPT_DIR/lib/geojson_polygon_info.py"

./scripts/build/t2_build_parameterized_basemap.sh \
  --source "$SOURCE" \
  --polygon "$POLYGON" \
  --output-root "$OUTPUT_ROOT" \
  --min-zoom "$MIN_ZOOM" \
  --max-zoom "$MAX_ZOOM" \
  --max-area-km2 "$MAX_AREA" \
  --max-size-mb "$MAX_SIZE" \
  --provider "$PROVIDER" \
  --source-url "$SOURCE_URL" \
  --license "$LICENSE" \
  --attribution "$ATTRIBUTION"

TOPO_ENABLED="false"
TOPO_TILE_COUNT="0"
TOPO_SIZE_BYTES="0"
TOPO_OUTPUT_PATH="$OUTPUT_ROOT/topography.mbtiles"

if [[ -n "$TOPO_SOURCE" ]]; then
  if [[ ! -f "$TOPO_SOURCE" ]]; then
    echo "Topography source not found: $TOPO_SOURCE" >&2
    exit 1
  fi

  TOPO_ENABLED="true"
  TOPO_MIN_ZOOM="${TOPO_MIN_ZOOM:-$MIN_ZOOM}"
  TOPO_MAX_ZOOM="${TOPO_MAX_ZOOM:-$MAX_ZOOM}"
  TOPO_PROVIDER="${TOPO_PROVIDER:-$PROVIDER}"
  TOPO_SOURCE_URL="${TOPO_SOURCE_URL:-$SOURCE_URL}"
  TOPO_LICENSE="${TOPO_LICENSE:-$(source_meta_value "$TOPO_SOURCE" license)}"
  TOPO_ATTRIBUTION="${TOPO_ATTRIBUTION:-$(source_meta_value "$TOPO_SOURCE" attribution)}"

  if [[ -z "$TOPO_LICENSE" ]]; then
    echo "Topography license check failed: provide --topography-license or source metadata.license" >&2
    exit 1
  fi
  if [[ -z "$TOPO_ATTRIBUTION" ]]; then
    echo "Topography attribution check failed: provide --topography-attribution or source metadata.attribution" >&2
    exit 1
  fi

  POLY_INFO_OUTPUT="$($POLY_INFO_PY "$POLYGON")"
  BBOX="$(printf '%s\n' "$POLY_INFO_OUTPUT" | sed -n '1p')"

  "$CLIP_SCRIPT" \
    --source "$TOPO_SOURCE" \
    --output "$TOPO_OUTPUT_PATH" \
    --bbox "$BBOX" \
    --min-zoom "$TOPO_MIN_ZOOM" \
    --max-zoom "$TOPO_MAX_ZOOM" \
    --name "Topography Layer"

  TOPO_TILE_COUNT="$(sqlite3 "$TOPO_OUTPUT_PATH" "SELECT COUNT(*) FROM tiles;")"
  TOPO_SIZE_BYTES="$(wc -c < "$TOPO_OUTPUT_PATH" | tr -d ' ')"

  cat > "$OUTPUT_ROOT/licenses/topography_attribution.txt" <<TXT
$TOPO_ATTRIBUTION
TXT
fi

python3 - "$OUTPUT_ROOT/build_stamp.json" "$BUILD_TIMESTAMP_UTC" "$GIT_SHA" "$GIT_REF" <<'PY'
import json
import sys

path, timestamp, git_sha, git_ref = sys.argv[1:]
payload = {
    "build_stamp_version": 1,
    "build_timestamp_utc": timestamp,
    "git_sha": git_sha,
    "git_ref": git_ref,
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
PY

python3 - "$OUTPUT_ROOT/metadata.json" "$OUTPUT_ROOT/build_stamp.json" "$TOPO_ENABLED" "$TOPO_OUTPUT_PATH" "$TOPO_PROVIDER" "$TOPO_SOURCE_URL" "$TOPO_LICENSE" "$TOPO_ATTRIBUTION" "$TOPO_MIN_ZOOM" "$TOPO_MAX_ZOOM" "$TOPO_TILE_COUNT" "$TOPO_SIZE_BYTES" <<'PY'
import json
import pathlib
import sys

(
    metadata_path,
    build_stamp_path,
    enabled,
    topo_path,
    topo_provider,
    topo_source_url,
    topo_license,
    topo_attr,
    topo_min_zoom,
    topo_max_zoom,
    topo_tile_count,
    topo_size_bytes,
) = sys.argv[1:]

meta_file = pathlib.Path(metadata_path)
build_stamp_file = pathlib.Path(build_stamp_path)
metadata = json.loads(meta_file.read_text(encoding="utf-8"))
build_stamp = json.loads(build_stamp_file.read_text(encoding="utf-8"))

is_enabled = enabled.lower() == "true"
metadata["topography_enabled"] = is_enabled

if is_enabled:
    metadata["topography"] = {
        "path": pathlib.Path(topo_path).name,
        "source_provider": topo_provider,
        "source_url": topo_source_url,
        "license": topo_license,
        "attribution": topo_attr,
        "min_zoom": int(topo_min_zoom),
        "max_zoom": int(topo_max_zoom),
        "tile_count": int(topo_tile_count),
        "size_bytes": int(topo_size_bytes),
    }
else:
    metadata.pop("topography", None)

metadata["build_stamp"] = build_stamp

meta_file.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
PY

python3 scripts/build/lib/t3_write_artifact_manifest.py \
  --pack-root "$OUTPUT_ROOT" \
  --output "artifact_manifest.json"

./scripts/build/t3_assert_tile_invariants.sh --pack-root "$OUTPUT_ROOT"

echo "T3/T4 CI pack build completed: $OUTPUT_ROOT"
