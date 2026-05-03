import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

part 'mbtiles_tile_preview_loader_core.dart';
part 'mbtiles_tile_preview_loader_load_methods.dart';
part 'mbtiles_tile_preview_loader_utils.dart';

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
    required this.tileScheme,
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
  final String tileScheme;
  final String detectedTileKind;
  final bool labelsAvailable;
  final bool topographyAvailable;
  final TileStepDirection? previousDirection;
  final TileStepDirection? nextDirection;
}

class MbtilesTilePreviewLoader {
  const MbtilesTilePreviewLoader();

  static const _core = _MbtilesTilePreviewCore();

  String tileScheme({required String packRootPath}) {
    final db = _openBasemapDb(packRootPath: packRootPath);
    try {
      return _core.schemeFromDb(db);
    } finally {
      db.dispose();
    }
  }

  TileCoordinate coordinateForLonLat({
    required String packRootPath,
    required int zoom,
    required double lon,
    required double lat,
  }) {
    final db = _openBasemapDb(packRootPath: packRootPath);
    try {
      final scheme = _core.schemeFromDb(db);
      return _core.coordinateForLonLat(
        zoom: zoom,
        lon: lon,
        lat: lat,
        scheme: scheme,
      );
    } finally {
      db.dispose();
    }
  }

  List<int> availableZooms({required String packRootPath}) {
    final db = _openBasemapDb(packRootPath: packRootPath);
    try {
      return _core.availableZooms(db);
    } finally {
      db.dispose();
    }
  }

  TileBounds? boundsForZoom({
    required String packRootPath,
    required int zoom,
    TileBounds? within,
  }) {
    final db = _openBasemapDb(packRootPath: packRootPath);
    try {
      return _core.boundsForZoom(db: db, zoom: zoom, within: within);
    } finally {
      db.dispose();
    }
  }

  TileCoordinate? firstTileInBounds({
    required String packRootPath,
    required int zoom,
    required TileBounds bounds,
  }) {
    final db = _openBasemapDb(packRootPath: packRootPath);
    try {
      return _core.firstTileInBounds(db: db, zoom: zoom, bounds: bounds);
    } finally {
      db.dispose();
    }
  }

  TileCoordinate? nearestTileToLonLat({
    required String packRootPath,
    required int zoom,
    required double lon,
    required double lat,
  }) {
    final db = _openBasemapDb(packRootPath: packRootPath);
    try {
      final scheme = _core.schemeFromDb(db);
      return _core.nearestTileToLonLat(
        db: db,
        zoom: zoom,
        lon: lon,
        lat: lat,
        scheme: scheme,
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
    final dbPath = _basemapDbPath(packRootPath: packRootPath);
    final db = _openBasemapDb(packRootPath: packRootPath);
    try {
      return _core.loadByTile(
        db: db,
        dbPath: dbPath,
        dbSizeBytes: File(dbPath).lengthSync(),
        packRootPath: packRootPath,
        zoom: zoom,
        tileColumn: tileColumn,
        tileRow: tileRow,
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
    final dbPath = _basemapDbPath(packRootPath: packRootPath);
    final db = _openBasemapDb(packRootPath: packRootPath);
    try {
      return _core.load(
        db: db,
        dbPath: dbPath,
        dbSizeBytes: File(dbPath).lengthSync(),
        packRootPath: packRootPath,
        zoom: zoom,
        indexInZoom: indexInZoom,
      );
    } finally {
      db.dispose();
    }
  }

  Database _openBasemapDb({required String packRootPath}) {
    final dbPath = _basemapDbPath(packRootPath: packRootPath);
    return sqlite3.open(dbPath);
  }

  String _basemapDbPath({required String packRootPath}) {
    final dbPath = p.join(packRootPath, 'basemap.mbtiles');
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) {
      throw StateError('basemap.mbtiles not found at $dbPath');
    }
    return dbPath;
  }
}
