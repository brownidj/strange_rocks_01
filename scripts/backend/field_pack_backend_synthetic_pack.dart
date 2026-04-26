import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'field_pack_backend_geojson.dart';
import 'field_pack_backend_models.dart';

class FieldPackBackendSyntheticPackFactory {
  const FieldPackBackendSyntheticPackFactory();

  Future<PublishedPack> build({
    required String packId,
    required Map<String, Object?> payload,
    required String Function(DateTime) isoUtc,
  }) async {
    final basemapBytes = await _buildSyntheticMbtiles();
    final files = <String, List<int>>{
      'basemap.mbtiles': basemapBytes,
      'instructions.md': utf8.encode('# Instructions\nSynthetic backend pack.'),
      'safety_notes.md': utf8.encode('# Safety Notes\nSynthetic backend pack.'),
      'licenses/attribution.txt': utf8.encode(
        'Contains Queensland Government data. Refer to source licence terms.',
      ),
      'licenses/data_sources.json': utf8.encode(
        '[{"provider":"Queensland Government QSat Mosaic","license":"CC BY-SA (verify current terms)"}]',
      ),
      'field_area.geojson': utf8.encode('{"type":"FeatureCollection","features":[]}'),
    };

    final archive = Archive();
    for (final entry in files.entries) {
      archive.add(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
    final manifest = _buildManifest(
      packId: packId,
      payload: payload,
      basemapBytes: basemapBytes,
      isoUtc: isoUtc,
    );
    return PublishedPack(packId: packId, manifest: manifest, zipBytes: zipBytes);
  }

  Map<String, Object?> _buildManifest({
    required String packId,
    required Map<String, Object?> payload,
    required List<int> basemapBytes,
    required String Function(DateTime) isoUtc,
  }) {
    final now = DateTime.now().toUtc();
    final fieldArea = (payload['field_area'] as Map<String, Object?>?) ?? const <String, Object?>{};
    final geojson = (fieldArea['geojson'] as Map<String, Object?>?) ?? const <String, Object?>{};
    final requestName = payload['name'] as String?;
    final areaName = fieldArea['name'] as String?;
    final displayName = areaName?.trim().isNotEmpty == true
        ? areaName
        : (requestName?.trim().isNotEmpty == true ? requestName : null);
    final bbox = extractBboxFromGeoJson(geojson) ??
        <double>[146.7406, -19.3379, 146.7798, -19.3078];
    final areaSize = _deriveAreaSizeM2(bbox);
    return <String, Object?>{
      'pack_id': packId,
      'name': displayName,
      'version': '1.0.0',
      'created_at_utc': isoUtc(now),
      'crs': 'EPSG:4326',
      'area': <String, Object?>{
        'bbox': <Object>[bbox[0], bbox[1], bbox[2], bbox[3]],
        'area_size_m2': areaSize,
      },
      'assets': <Object>[
        <String, Object?>{
          'path': 'basemap.mbtiles',
          'kind': 'tiles',
          'size_bytes': basemapBytes.length,
          'sha256': sha256.convert(basemapBytes).toString(),
        }
      ],
      'data_sources': <Object>[
        <String, Object?>{
          'provider': 'Queensland Government QSat Mosaic',
          'acquired_at_utc': isoUtc(now),
          'license': 'CC BY-SA (verify current terms)',
          'attribution': 'Contains Queensland Government data. Refer to source licence terms.',
        }
      ],
      'requires_app_version': '1.0.0',
    };
  }

  Future<List<int>> _buildSyntheticMbtiles() async {
    final tmpDir = await Directory.systemTemp.createTemp('synthetic-mbtiles');
    final dbPath = p.join(tmpDir.path, 'basemap.mbtiles');
    final db = sqlite3.open(dbPath);
    try {
      db.execute('''
CREATE TABLE metadata (name TEXT, value TEXT);
CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);
CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row);
''');

      final pngBytes = await _loadSyntheticPngBytes();
      final stmt = db.prepare(
        'INSERT INTO tiles(zoom_level, tile_column, tile_row, tile_data) VALUES (?, ?, ?, ?);',
      );
      stmt.execute(<Object?>[0, 0, 0, pngBytes]);
      stmt.dispose();
      db.execute('''
INSERT INTO metadata(name, value) VALUES
 ('name', 'Synthetic Basemap'),
 ('type', 'baselayer'),
 ('format', 'png'),
 ('minzoom', '0'),
 ('maxzoom', '0'),
 ('bounds', '-180,-85,180,85'),
 ('tile_schema_version', '1');
''');
    } finally {
      db.dispose();
    }

    try {
      return await File(dbPath).readAsBytes();
    } finally {
      await tmpDir.delete(recursive: true);
    }
  }

  int _deriveAreaSizeM2(List<double> bbox) {
    final area = ((bbox[2] - bbox[0]).abs() * (bbox[3] - bbox[1]).abs() * 12321000000).round();
    return area <= 0 ? 1 : area;
  }

  Future<Uint8List> _loadSyntheticPngBytes() async {
    final scriptDir = Directory.fromUri(Platform.script).parent.path;
    final candidatePaths = <String>[
      p.normalize(p.join(scriptDir, '..', '..', 'assets', 'images', 'fish.png')),
      p.normalize(p.join(scriptDir, '..', '..', 'assets', 'images', 'fish_02.png')),
      p.normalize(p.join(scriptDir, '..', '..', 'assets', 'images', 'fish_01.png')),
      p.normalize(p.join(scriptDir, '..', '..', 'assets', 'images', 'fish.jpeg')),
    ];
    for (final candidatePath in candidatePaths) {
      final candidate = File(candidatePath);
      if (candidate.existsSync()) {
        return candidate.readAsBytes();
      }
    }

    // Final fallback valid PNG (1x1 solid color).
    return Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNg2FIBAAHkAS09OXj+AAAAAElFTkSuQmCC',
      ),
    );
  }
}
