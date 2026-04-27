import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

enum TileStepDirection {
  north,
  south,
  east,
  west,
  northeast,
  northwest,
  southeast,
  southwest,
}

class TileCoordinate {
  const TileCoordinate({
    required this.zoom,
    required this.tileColumn,
    required this.tileRow,
  });

  final int zoom;
  final int tileColumn;
  final int tileRow;
}

class TileBounds {
  const TileBounds({
    required this.minColumn,
    required this.maxColumn,
    required this.minRow,
    required this.maxRow,
    required this.count,
  });

  final int minColumn;
  final int maxColumn;
  final int minRow;
  final int maxRow;
  final int count;
}

class MbtilesTilePreview {
  const MbtilesTilePreview({
    required this.bytes,
    required this.labelsBytes,
    required this.topographyBytes,
    required this.zoom,
    required this.tileColumn,
    required this.tileRow,
    required this.indexInZoom,
    required this.totalInZoom,
    required this.totalTiles,
    required this.availableZooms,
    required this.dbPath,
    required this.dbSizeBytes,
    required this.tileHeaderHex,
    required this.metadataFormat,
    required this.detectedTileKind,
    required this.labelsAvailable,
    required this.topographyAvailable,
    required this.previousDirection,
    required this.nextDirection,
  });

  final Uint8List bytes;
  final Uint8List? labelsBytes;
  final Uint8List? topographyBytes;
  final int zoom;
  final int tileColumn;
  final int tileRow;
  final int indexInZoom;
  final int totalInZoom;
  final int totalTiles;
  final List<int> availableZooms;
  final String dbPath;
  final int dbSizeBytes;
  final String tileHeaderHex;
  final String? metadataFormat;
  final String detectedTileKind;
  final bool labelsAvailable;
  final bool topographyAvailable;
  final TileStepDirection? previousDirection;
  final TileStepDirection? nextDirection;
}

class MbtilesTilePreviewLoader {
  const MbtilesTilePreviewLoader();

  List<int> availableZooms({required String packRootPath}) {
    final dbPath = p.join(packRootPath, 'basemap.mbtiles');
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) {
      throw StateError('basemap.mbtiles not found at $dbPath');
    }
    final db = sqlite3.open(dbPath);
    try {
      return db
          .select(
            'SELECT DISTINCT zoom_level FROM tiles ORDER BY zoom_level ASC;',
          )
          .map((r) => r['zoom_level'] as int)
          .toList(growable: false);
    } finally {
      db.dispose();
    }
  }

  TileBounds? boundsForZoom({
    required String packRootPath,
    required int zoom,
    TileBounds? within,
  }) {
    final dbPath = p.join(packRootPath, 'basemap.mbtiles');
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) {
      throw StateError('basemap.mbtiles not found at $dbPath');
    }
    final db = sqlite3.open(dbPath);
    try {
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
      final rows = db.select(
        '''
SELECT
  MIN(tile_column) AS min_column,
  MAX(tile_column) AS max_column,
  MIN(tile_row) AS min_row,
  MAX(tile_row) AS max_row,
  COUNT(*) AS c
FROM tiles
WHERE $where;
''',
        args,
      );
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
    } finally {
      db.dispose();
    }
  }

  TileCoordinate? firstTileInBounds({
    required String packRootPath,
    required int zoom,
    required TileBounds bounds,
  }) {
    final dbPath = p.join(packRootPath, 'basemap.mbtiles');
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) {
      throw StateError('basemap.mbtiles not found at $dbPath');
    }
    final db = sqlite3.open(dbPath);
    try {
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
    } finally {
      db.dispose();
    }
  }

  MbtilesTilePreview loadByTile({
    required String packRootPath,
    required int zoom,
    required int tileColumn,
    required int tileRow,
  }) {
    final dbPath = p.join(packRootPath, 'basemap.mbtiles');
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) {
      throw StateError('basemap.mbtiles not found at $dbPath');
    }
    final dbSizeBytes = dbFile.lengthSync();
    final db = sqlite3.open(dbPath);
    try {
      final totalTiles =
          db.select('SELECT COUNT(*) AS c FROM tiles;').first['c'] as int;
      if (totalTiles <= 0) {
        throw StateError('No tiles found in basemap.mbtiles');
      }
      final availableZooms = db
          .select(
            'SELECT DISTINCT zoom_level FROM tiles ORDER BY zoom_level ASC;',
          )
          .map((r) => r['zoom_level'] as int)
          .toList(growable: false);
      if (availableZooms.isEmpty) {
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
      final normalized = _normalizeTileBytes(rows.first['tile_data']);
      final metadataFormatRow = db.select(
        "SELECT value FROM metadata WHERE name = 'format' LIMIT 1;",
      );
      final metadataFormat = metadataFormatRow.isEmpty
          ? null
          : metadataFormatRow.first['value'] as String?;
      final totalInZoom = (db.select(
        'SELECT COUNT(*) AS c FROM tiles WHERE zoom_level = ?;',
        [zoom],
      ).first['c'] as int);
      final beforeInZoom = (db.select(
        '''
SELECT COUNT(*) AS c
FROM tiles
WHERE zoom_level = ?
  AND (tile_column < ? OR (tile_column = ? AND tile_row < ?));
''',
        <Object?>[zoom, tileColumn, tileColumn, tileRow],
      ).first['c'] as int);
      final labelsDbPath = p.join(packRootPath, 'labels.mbtiles');
      final topographyDbPath = p.join(packRootPath, 'topography.mbtiles');
      final labelsBytes = _loadOverlayTile(
        overlayDbPath: labelsDbPath,
        zoom: zoom,
        tileColumn: tileColumn,
        tileRow: tileRow,
      );
      final topographyBytes = _loadOverlayTile(
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
        availableZooms: availableZooms,
        dbPath: dbPath,
        dbSizeBytes: dbSizeBytes,
        tileHeaderHex: _headerHex(normalized.bytes, maxBytes: 16),
        metadataFormat: metadataFormat,
        detectedTileKind: _detectTileKind(normalized.bytes),
        labelsAvailable: File(labelsDbPath).existsSync(),
        topographyAvailable: File(topographyDbPath).existsSync(),
        previousDirection: null,
        nextDirection: null,
      );
    } finally {
      db.dispose();
    }
  }

  MbtilesTilePreview load({
    required String packRootPath,
    required int zoom,
    required int indexInZoom,
  }) {
    final dbPath = p.join(packRootPath, 'basemap.mbtiles');
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) {
      throw StateError('basemap.mbtiles not found at $dbPath');
    }
    final dbSizeBytes = dbFile.lengthSync();
    final db = sqlite3.open(dbPath);
    try {
      final totalTiles =
          db.select('SELECT COUNT(*) AS c FROM tiles;').first['c'] as int;
      if (totalTiles <= 0) {
        throw StateError('No tiles found in basemap.mbtiles');
      }

      final availableZooms = db
          .select(
            'SELECT DISTINCT zoom_level FROM tiles ORDER BY zoom_level ASC;',
          )
          .map((r) => r['zoom_level'] as int)
          .toList(growable: false);
      if (availableZooms.isEmpty) {
        throw StateError('No zoom levels found in basemap.mbtiles');
      }

      final effectiveZoom = availableZooms.contains(zoom)
          ? zoom
          : availableZooms.first;
      final totalInZoom = (db.select(
        'SELECT COUNT(*) AS c FROM tiles WHERE zoom_level = ?;',
        [effectiveZoom],
      ).first['c'] as int);
      if (totalInZoom <= 0) {
        throw StateError('No tiles found for zoom $effectiveZoom');
      }

      final boundedIndex = indexInZoom < 0
          ? 0
          : (indexInZoom >= totalInZoom ? totalInZoom - 1 : indexInZoom);
      final row = db.select(
        '''
SELECT tile_column, tile_row, tile_data
FROM tiles
WHERE zoom_level = ?
ORDER BY tile_column, tile_row
LIMIT 1 OFFSET ?;
''',
        [effectiveZoom, boundedIndex],
      ).first;
      final previous = boundedIndex > 0
          ? db.select(
              '''
SELECT tile_column, tile_row
FROM tiles
WHERE zoom_level = ?
ORDER BY tile_column, tile_row
LIMIT 1 OFFSET ?;
''',
              [effectiveZoom, boundedIndex - 1],
            ).first
          : null;
      final next = boundedIndex < totalInZoom - 1
          ? db.select(
              '''
SELECT tile_column, tile_row
FROM tiles
WHERE zoom_level = ?
ORDER BY tile_column, tile_row
LIMIT 1 OFFSET ?;
''',
              [effectiveZoom, boundedIndex + 1],
            ).first
          : null;
      final metadataFormatRow = db.select(
        "SELECT value FROM metadata WHERE name = 'format' LIMIT 1;",
      );
      final metadataFormat = metadataFormatRow.isEmpty
          ? null
          : metadataFormatRow.first['value'] as String?;
      final normalized = _normalizeTileBytes(row['tile_data']);
      final labelsDbPath = p.join(packRootPath, 'labels.mbtiles');
      final topographyDbPath = p.join(packRootPath, 'topography.mbtiles');
      final labelsBytes = _loadOverlayTile(
        overlayDbPath: labelsDbPath,
        zoom: effectiveZoom,
        tileColumn: row['tile_column'] as int,
        tileRow: row['tile_row'] as int,
      );
      final topographyBytes = _loadOverlayTile(
        overlayDbPath: topographyDbPath,
        zoom: effectiveZoom,
        tileColumn: row['tile_column'] as int,
        tileRow: row['tile_row'] as int,
      );

      return MbtilesTilePreview(
        bytes: normalized.bytes,
        labelsBytes: labelsBytes,
        topographyBytes: topographyBytes,
        zoom: effectiveZoom,
        tileColumn: row['tile_column'] as int,
        tileRow: row['tile_row'] as int,
        indexInZoom: boundedIndex,
        totalInZoom: totalInZoom,
        totalTiles: totalTiles,
        availableZooms: availableZooms,
        dbPath: dbPath,
        dbSizeBytes: dbSizeBytes,
        tileHeaderHex: _headerHex(normalized.bytes, maxBytes: 16),
        metadataFormat: metadataFormat,
        detectedTileKind: _detectTileKind(normalized.bytes),
        labelsAvailable: File(labelsDbPath).existsSync(),
        topographyAvailable: File(topographyDbPath).existsSync(),
        previousDirection: previous == null
            ? null
            : _directionFromDelta(
                deltaCol: (previous['tile_column'] as int) -
                    (row['tile_column'] as int),
                deltaRow: (previous['tile_row'] as int) - (row['tile_row'] as int),
              ),
        nextDirection: next == null
            ? null
            : _directionFromDelta(
                deltaCol: (next['tile_column'] as int) - (row['tile_column'] as int),
                deltaRow: (next['tile_row'] as int) - (row['tile_row'] as int),
              ),
      );
    } finally {
      db.dispose();
    }
  }

  Uint8List? _loadOverlayTile({
    required String overlayDbPath,
    required int zoom,
    required int tileColumn,
    required int tileRow,
  }) {
    final file = File(overlayDbPath);
    if (!file.existsSync()) {
      return null;
    }
    final db = sqlite3.open(overlayDbPath);
    try {
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
        return null;
      }
      final normalized = _normalizeTileBytes(rows.first['tile_data']);
      return normalized.bytes;
    } finally {
      db.dispose();
    }
  }

  _NormalizedBytes _normalizeTileBytes(Object? raw) {
    final bytes = switch (raw) {
      // Always deep-copy tile blobs out of sqlite memory before db.dispose().
      final Uint8List u8 => Uint8List.fromList(u8),
      final List<int> list => Uint8List.fromList(list),
      _ => throw StateError('Unexpected tile_data type: ${raw.runtimeType}'),
    };

    final lookedGzip = bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
    if (lookedGzip) {
      try {
        final unzipped = gzip.decode(bytes);
        return _NormalizedBytes(
          bytes: Uint8List.fromList(unzipped),
          lookedGzip: true,
          wasGzipDecoded: true,
        );
      } catch (_) {
        return _NormalizedBytes(
          bytes: bytes,
          lookedGzip: true,
          wasGzipDecoded: false,
        );
      }
    }
    return _NormalizedBytes(
      bytes: bytes,
      lookedGzip: false,
      wasGzipDecoded: false,
    );
  }

  String _headerHex(Uint8List bytes, {required int maxBytes}) {
    final len = bytes.length < maxBytes ? bytes.length : maxBytes;
    final b = bytes.sublist(0, len);
    return b.map((v) => v.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  String _detectTileKind(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'jpeg';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    if (bytes.length >= 2 && bytes[0] == 0x78) {
      return 'zlib-or-deflate';
    }
    return 'unknown';
  }

  TileStepDirection? _directionFromDelta({
    required int deltaCol,
    required int deltaRow,
  }) {
    if (deltaCol == 0 && deltaRow == 0) {
      return null;
    }
    if (deltaCol == 0 && deltaRow > 0) {
      return TileStepDirection.north;
    }
    if (deltaCol == 0 && deltaRow < 0) {
      return TileStepDirection.south;
    }
    if (deltaCol > 0 && deltaRow == 0) {
      return TileStepDirection.east;
    }
    if (deltaCol < 0 && deltaRow == 0) {
      return TileStepDirection.west;
    }
    if (deltaCol > 0 && deltaRow > 0) {
      return TileStepDirection.northeast;
    }
    if (deltaCol < 0 && deltaRow > 0) {
      return TileStepDirection.northwest;
    }
    if (deltaCol > 0 && deltaRow < 0) {
      return TileStepDirection.southeast;
    }
    if (deltaCol < 0 && deltaRow < 0) {
      return TileStepDirection.southwest;
    }
    return null;
  }
}

class _NormalizedBytes {
  const _NormalizedBytes({
    required this.bytes,
    required this.lookedGzip,
    required this.wasGzipDecoded,
  });

  final Uint8List bytes;
  final bool lookedGzip;
  final bool wasGzipDecoded;
}
