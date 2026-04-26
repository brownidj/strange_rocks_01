# Option 3 Playbook: Use Prebuilt MBTiles Datasets

## Objective
Use a public prebuilt MBTiles dataset as input, then clip it to a field area and zoom range for your field-pack `basemap.mbtiles`.

## What Is Implemented
Script added:

- `scripts/build/prebuilt_mbtiles_to_fieldpack.sh`

This script:
- reads a source MBTiles (`tiles` + `metadata` tables)
- clips to `--bbox` and `--min-zoom/--max-zoom`
- writes a pack-ready `basemap.mbtiles`
- stamps core metadata (`bounds`, `minzoom`, `maxzoom`, `tile_schema_version`)

## Candidate Prebuilt Sources (Start Here)
1. OpenFreeMap weekly planet MBTiles
   - https://openfreemap.org/
   - Use as source MBTiles, then clip locally.
2. Any licensed MBTiles export your org already holds
   - e.g. prior project MBTiles with redistribution rights.

Important:
- Always confirm license terms for offline redistribution in your app/project context.
- Store attribution/license text in pack metadata/licenses files.

## Usage

```bash
./scripts/build/prebuilt_mbtiles_to_fieldpack.sh \
  --source /path/to/source.mbtiles \
  --output /path/to/field_pack/basemap.mbtiles \
  --bbox 146.70,-19.45,147.20,-18.95 \
  --min-zoom 10 \
  --max-zoom 15 \
  --name "Townsville Basemap"
```

## Recommended First Run (MVP)
- Area: one small Queensland MVP test area (for example Townsville outskirts)
- Zooms: `10-15`
- Validate output size target: `< 500 MB`

## Validation Checklist
1. `basemap.mbtiles` exists and non-zero size.
2. `sqlite3 basemap.mbtiles "SELECT COUNT(*) FROM tiles;"` > 0.
3. Metadata contains `bounds`, `minzoom`, `maxzoom`, `tile_schema_version`.
4. Field pack imports in app and map renders in airplane mode.

## Known Limitations
- Assumes source MBTiles uses standard `tiles` table and TMS `tile_row`.
- No polygon mask yet (bbox clipping only).
- No automatic source download/auth handling yet.

## Next Step After This
- Add a small wrapper script that:
  - accepts a field-pack folder
  - runs this MBTiles clip command
  - updates pack manifest/license metadata in one command.
