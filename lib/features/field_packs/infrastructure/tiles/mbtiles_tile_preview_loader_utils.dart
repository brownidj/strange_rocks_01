part of 'mbtiles_tile_preview_loader.dart';

mixin _MbtilesTilePreviewCoreUtils {
  String schemeFromDb(Database db) {
    final schemeRows = db.select(
      "SELECT value FROM metadata WHERE name = 'scheme' LIMIT 1;",
    );
    final scheme = schemeRows.isEmpty
        ? 'tms'
        : ((schemeRows.first['value'] as String?) ?? 'tms').toLowerCase();
    return scheme == 'xyz' ? 'xyz' : 'tms';
  }

  TileCoordinate coordinateForLonLat({
    required int zoom,
    required double lon,
    required double lat,
    required String scheme,
  }) {
    final world = 1 << zoom;
    final clampedLon = lon.clamp(-180.0, 180.0);
    final clampedLat = lat.clamp(-85.05112878, 85.05112878);
    final normalizedX = (clampedLon + 180.0) / 360.0;
    final tileColumn = (normalizedX * world).floor().clamp(0, world - 1);
    final latRad = clampedLat * math.pi / 180.0;
    final mercatorY =
        (1 - math.log(math.tan(latRad) + (1 / math.cos(latRad))) / math.pi) / 2;
    final yXyz = (mercatorY * world).floor().clamp(0, world - 1);
    final tileRow = scheme == 'xyz' ? yXyz : (world - 1 - yXyz);
    final boundedRow = tileRow < 0
        ? 0
        : (tileRow >= world ? world - 1 : tileRow);
    return TileCoordinate(
      zoom: zoom,
      tileColumn: tileColumn,
      tileRow: boundedRow,
    );
  }

  _NormalizedBytes normalizeTileBytes(Object? raw) {
    final bytes = switch (raw) {
      // Deep-copy tile blobs out of sqlite memory before db.dispose().
      final Uint8List u8 => Uint8List.fromList(u8),
      final List<int> list => Uint8List.fromList(list),
      _ => throw StateError('Unexpected tile_data type: ${raw.runtimeType}'),
    };

    final lookedGzip =
        bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
    if (!lookedGzip) {
      return _NormalizedBytes(
        bytes: bytes,
        lookedGzip: false,
        wasGzipDecoded: false,
      );
    }

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

  String headerHex(Uint8List bytes, {required int maxBytes}) {
    final len = bytes.length < maxBytes ? bytes.length : maxBytes;
    final b = bytes.sublist(0, len);
    return b.map((v) => v.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  String detectTileKind(Uint8List bytes) {
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

  TileStepDirection? directionFromDelta({
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

  String? metadataFormat(Database db) {
    final metadataFormatRow = db.select(
      "SELECT value FROM metadata WHERE name = 'format' LIMIT 1;",
    );
    if (metadataFormatRow.isEmpty) {
      return null;
    }
    return metadataFormatRow.first['value'] as String?;
  }

  Uint8List? loadOverlayTile({
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
      return normalizeTileBytes(rows.first['tile_data']).bytes;
    } finally {
      db.dispose();
    }
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
