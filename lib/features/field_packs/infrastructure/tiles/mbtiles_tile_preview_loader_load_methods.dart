part of 'mbtiles_tile_preview_loader.dart';

mixin _MbtilesTilePreviewCoreLoadMethods on _MbtilesTilePreviewCoreUtils {
  List<int> availableZooms(Database db);

  MbtilesTilePreview loadByTile({
    required Database db,
    required String dbPath,
    required int dbSizeBytes,
    required String packRootPath,
    required int zoom,
    required int tileColumn,
    required int tileRow,
  }) {
    final totalTiles =
        db.select('SELECT COUNT(*) AS c FROM tiles;').first['c'] as int;
    if (totalTiles <= 0) {
      throw StateError('No tiles found in basemap.mbtiles');
    }
    final zooms = availableZooms(db);
    if (zooms.isEmpty) {
      throw StateError('No zoom levels found in basemap.mbtiles');
    }
    final rows = db.select(
      '''
SELECT tile_data
FROM tiles
WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?
LIMIT 1;
''',
      <Object?>[zoom, tileColumn, tileRow],
    );
    if (rows.isEmpty) {
      throw StateError('Tile not found for z=$zoom x=$tileColumn y=$tileRow');
    }
    final normalized = normalizeTileBytes(rows.first['tile_data']);
    final metadataFormatValue = metadataFormat(db);
    final scheme = schemeFromDb(db);
    final totalInZoom =
        db.select('SELECT COUNT(*) AS c FROM tiles WHERE zoom_level = ?;', [
              zoom,
            ]).first['c']
            as int;
    final beforeInZoom =
        db
                .select(
                  '''
SELECT COUNT(*) AS c
FROM tiles
WHERE zoom_level = ?
  AND (tile_column < ? OR (tile_column = ? AND tile_row < ?));
''',
                  <Object?>[zoom, tileColumn, tileColumn, tileRow],
                )
                .first['c']
            as int;

    final labelsDbPath = p.join(packRootPath, 'labels.mbtiles');
    final topographyDbPath = p.join(packRootPath, 'topography.mbtiles');
    final labelsBytes = loadOverlayTile(
      overlayDbPath: labelsDbPath,
      zoom: zoom,
      tileColumn: tileColumn,
      tileRow: tileRow,
    );
    final topographyBytes = loadOverlayTile(
      overlayDbPath: topographyDbPath,
      zoom: zoom,
      tileColumn: tileColumn,
      tileRow: tileRow,
    );

    return MbtilesTilePreview(
      bytes: normalized.bytes,
      labelsBytes: labelsBytes,
      topographyBytes: topographyBytes,
      zoom: zoom,
      tileColumn: tileColumn,
      tileRow: tileRow,
      indexInZoom: beforeInZoom,
      totalInZoom: totalInZoom,
      totalTiles: totalTiles,
      availableZooms: zooms,
      dbPath: dbPath,
      dbSizeBytes: dbSizeBytes,
      tileHeaderHex: headerHex(normalized.bytes, maxBytes: 16),
      metadataFormat: metadataFormatValue,
      tileScheme: scheme,
      detectedTileKind: detectTileKind(normalized.bytes),
      labelsAvailable: File(labelsDbPath).existsSync(),
      topographyAvailable: File(topographyDbPath).existsSync(),
      previousDirection: null,
      nextDirection: null,
    );
  }

  MbtilesTilePreview load({
    required Database db,
    required String dbPath,
    required int dbSizeBytes,
    required String packRootPath,
    required int zoom,
    required int indexInZoom,
  }) {
    final totalTiles =
        db.select('SELECT COUNT(*) AS c FROM tiles;').first['c'] as int;
    if (totalTiles <= 0) {
      throw StateError('No tiles found in basemap.mbtiles');
    }

    final zooms = availableZooms(db);
    if (zooms.isEmpty) {
      throw StateError('No zoom levels found in basemap.mbtiles');
    }

    final effectiveZoom = zooms.contains(zoom) ? zoom : zooms.first;
    final totalInZoom =
        db.select('SELECT COUNT(*) AS c FROM tiles WHERE zoom_level = ?;', [
              effectiveZoom,
            ]).first['c']
            as int;
    if (totalInZoom <= 0) {
      throw StateError('No tiles found for zoom $effectiveZoom');
    }

    final boundedIndex = indexInZoom < 0
        ? 0
        : (indexInZoom >= totalInZoom ? totalInZoom - 1 : indexInZoom);
    final row = db
        .select(
          '''
SELECT tile_column, tile_row, tile_data
FROM tiles
WHERE zoom_level = ?
ORDER BY tile_column, tile_row
LIMIT 1 OFFSET ?;
''',
          [effectiveZoom, boundedIndex],
        )
        .first;
    final previous = boundedIndex > 0
        ? db
              .select(
                '''
SELECT tile_column, tile_row
FROM tiles
WHERE zoom_level = ?
ORDER BY tile_column, tile_row
LIMIT 1 OFFSET ?;
''',
                [effectiveZoom, boundedIndex - 1],
              )
              .first
        : null;
    final next = boundedIndex < totalInZoom - 1
        ? db
              .select(
                '''
SELECT tile_column, tile_row
FROM tiles
WHERE zoom_level = ?
ORDER BY tile_column, tile_row
LIMIT 1 OFFSET ?;
''',
                [effectiveZoom, boundedIndex + 1],
              )
              .first
        : null;

    final metadataFormatValue = metadataFormat(db);
    final scheme = schemeFromDb(db);
    final normalized = normalizeTileBytes(row['tile_data']);
    final labelsDbPath = p.join(packRootPath, 'labels.mbtiles');
    final topographyDbPath = p.join(packRootPath, 'topography.mbtiles');
    final tileColumn = row['tile_column'] as int;
    final tileRow = row['tile_row'] as int;
    final labelsBytes = loadOverlayTile(
      overlayDbPath: labelsDbPath,
      zoom: effectiveZoom,
      tileColumn: tileColumn,
      tileRow: tileRow,
    );
    final topographyBytes = loadOverlayTile(
      overlayDbPath: topographyDbPath,
      zoom: effectiveZoom,
      tileColumn: tileColumn,
      tileRow: tileRow,
    );

    return MbtilesTilePreview(
      bytes: normalized.bytes,
      labelsBytes: labelsBytes,
      topographyBytes: topographyBytes,
      zoom: effectiveZoom,
      tileColumn: tileColumn,
      tileRow: tileRow,
      indexInZoom: boundedIndex,
      totalInZoom: totalInZoom,
      totalTiles: totalTiles,
      availableZooms: zooms,
      dbPath: dbPath,
      dbSizeBytes: dbSizeBytes,
      tileHeaderHex: headerHex(normalized.bytes, maxBytes: 16),
      metadataFormat: metadataFormatValue,
      tileScheme: scheme,
      detectedTileKind: detectTileKind(normalized.bytes),
      labelsAvailable: File(labelsDbPath).existsSync(),
      topographyAvailable: File(topographyDbPath).existsSync(),
      previousDirection: previous == null
          ? null
          : directionFromDelta(
              deltaCol: (previous['tile_column'] as int) - tileColumn,
              deltaRow: (previous['tile_row'] as int) - tileRow,
            ),
      nextDirection: next == null
          ? null
          : directionFromDelta(
              deltaCol: (next['tile_column'] as int) - tileColumn,
              deltaRow: (next['tile_row'] as int) - tileRow,
            ),
    );
  }
}
