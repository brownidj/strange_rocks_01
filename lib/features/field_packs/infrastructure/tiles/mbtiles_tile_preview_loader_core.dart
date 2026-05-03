part of 'mbtiles_tile_preview_loader.dart';

class _MbtilesTilePreviewCore
    with _MbtilesTilePreviewCoreUtils, _MbtilesTilePreviewCoreLoadMethods {
  const _MbtilesTilePreviewCore();

  @override
  List<int> availableZooms(Database db) {
    return db
        .select(
          'SELECT DISTINCT zoom_level FROM tiles ORDER BY zoom_level ASC;',
        )
        .map((r) => r['zoom_level'] as int)
        .toList(growable: false);
  }

  TileBounds? boundsForZoom({
    required Database db,
    required int zoom,
    required TileBounds? within,
  }) {
    final where = within == null
        ? 'zoom_level = ?'
        : '''
zoom_level = ?
AND tile_column BETWEEN ? AND ?
AND tile_row BETWEEN ? AND ?
''';
    final args = within == null
        ? <Object?>[zoom]
        : <Object?>[
            zoom,
            within.minColumn,
            within.maxColumn,
            within.minRow,
            within.maxRow,
          ];
    final rows = db.select('''
SELECT
  MIN(tile_column) AS min_column,
  MAX(tile_column) AS max_column,
  MIN(tile_row) AS min_row,
  MAX(tile_row) AS max_row,
  COUNT(*) AS c
FROM tiles
WHERE $where;
''', args);
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    final count = row['c'] as int;
    if (count <= 0) {
      return null;
    }
    return TileBounds(
      minColumn: row['min_column'] as int,
      maxColumn: row['max_column'] as int,
      minRow: row['min_row'] as int,
      maxRow: row['max_row'] as int,
      count: count,
    );
  }

  TileCoordinate? firstTileInBounds({
    required Database db,
    required int zoom,
    required TileBounds bounds,
  }) {
    final rows = db.select(
      '''
SELECT tile_column, tile_row
FROM tiles
WHERE zoom_level = ?
  AND tile_column BETWEEN ? AND ?
  AND tile_row BETWEEN ? AND ?
ORDER BY tile_column, tile_row
LIMIT 1;
''',
      <Object?>[
        zoom,
        bounds.minColumn,
        bounds.maxColumn,
        bounds.minRow,
        bounds.maxRow,
      ],
    );
    if (rows.isEmpty) {
      return null;
    }
    return TileCoordinate(
      zoom: zoom,
      tileColumn: rows.first['tile_column'] as int,
      tileRow: rows.first['tile_row'] as int,
    );
  }

  TileCoordinate? nearestTileToLonLat({
    required Database db,
    required int zoom,
    required double lon,
    required double lat,
    required String scheme,
  }) {
    final world = 1 << zoom;
    final clampedLon = lon.clamp(-180.0, 180.0);
    final clampedLat = lat.clamp(-85.05112878, 85.05112878);
    final normalizedX = (clampedLon + 180.0) / 360.0;
    final x = (normalizedX * world).floor().clamp(0, world - 1);

    final latRad = clampedLat * math.pi / 180.0;
    final mercatorY =
        (1 - math.log(math.tan(latRad) + (1 / math.cos(latRad))) / math.pi) / 2;
    final yXyz = (mercatorY * world).floor().clamp(0, world - 1);
    final yTms = (world - 1 - yXyz).clamp(0, world - 1);

    final targetRow = scheme == 'xyz' ? yXyz : yTms;
    final rows = db.select(
      '''
SELECT tile_column, tile_row
FROM tiles
WHERE zoom_level = ?
ORDER BY (ABS(tile_column - ?) + ABS(tile_row - ?)), tile_column, tile_row
LIMIT 1;
''',
      <Object?>[zoom, x, targetRow],
    );
    if (rows.isEmpty) {
      return null;
    }
    return TileCoordinate(
      zoom: zoom,
      tileColumn: rows.first['tile_column'] as int,
      tileRow: rows.first['tile_row'] as int,
    );
  }
}
