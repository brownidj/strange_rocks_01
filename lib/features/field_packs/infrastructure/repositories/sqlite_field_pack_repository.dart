import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_area.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_asset.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_manifest.dart';
import 'package:strange_rocks_01/features/field_packs/domain/repositories/field_pack_repository.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/database/field_pack_database.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/mappers/field_pack_manifest_mapper.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/mappers/field_pack_status_mapper.dart';

part 'sqlite_field_pack_repository_mapping.dart';

class SqliteFieldPackRepository
    with _SqliteFieldPackRepositoryMapping
    implements FieldPackRepository {
  SqliteFieldPackRepository(this._database);

  final FieldPackDatabase _database;

  @override
  Future<void> saveFieldArea(FieldArea area) {
    return _withDatabase<void>((db) {
      db.execute(
        '''
INSERT INTO field_areas(id, pack_id, name, geojson, bbox_json, created_at_utc)
VALUES (?, NULL, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  name = excluded.name,
  geojson = excluded.geojson,
  bbox_json = excluded.bbox_json
''',
        <Object?>[
          area.id,
          area.name,
          jsonEncode(area.geoJson),
          jsonEncode(area.bbox),
          DateTime.now().toUtc().toIso8601String(),
        ],
      );
    });
  }

  @override
  Future<void> linkFieldAreaToPack(String areaId, String packId) {
    return _withDatabase<void>((db) {
      db.execute('UPDATE field_areas SET pack_id = ? WHERE id = ?', <Object?>[
        packId,
        areaId,
      ]);
    });
  }

  @override
  Future<void> savePackManifest(
    FieldPackManifest manifest, {
    required String localRootPath,
    String? name,
  }) {
    final resolvedName = name ?? manifest.name;
    return _withDatabase<void>((db) {
      db.execute(
        '''
INSERT INTO field_packs(
  id, version, name, status, local_root_path, manifest_json, created_at_utc,
  downloaded_at_utc, is_active
) VALUES (?, ?, ?, ?, ?, ?, ?, NULL, 0)
ON CONFLICT(id) DO UPDATE SET
  version = excluded.version,
  name = excluded.name,
  status = excluded.status,
  local_root_path = excluded.local_root_path,
  manifest_json = excluded.manifest_json,
  created_at_utc = excluded.created_at_utc
''',
        <Object?>[
          manifest.packId,
          manifest.version,
          resolvedName,
          FieldPackStatusMapper.toDb(FieldPackStatus.downloading),
          localRootPath,
          jsonEncode(FieldPackManifestMapper.toJson(manifest)),
          manifest.createdAtUtc,
        ],
      );

      _replaceAssets(db, manifest.packId, manifest.assets);
    });
  }

  @override
  Future<void> updatePackStatus(
    String packId,
    FieldPackStatus status, {
    String? downloadedAtUtc,
    bool? isActive,
  }) {
    return _withDatabase<void>((db) {
      if (isActive == true) {
        db.execute('UPDATE field_packs SET is_active = 0 WHERE is_active = 1');
      }
      db.execute(
        '''
UPDATE field_packs SET
  status = ?,
  downloaded_at_utc = COALESCE(?, downloaded_at_utc),
  is_active = COALESCE(?, is_active)
WHERE id = ?
''',
        <Object?>[
          FieldPackStatusMapper.toDb(status),
          downloadedAtUtc,
          isActive == null ? null : (isActive ? 1 : 0),
          packId,
        ],
      );
    });
  }

  @override
  Future<void> replacePackAssets(String packId, List<FieldPackAsset> assets) {
    return _withDatabase<void>((db) {
      _replaceAssets(db, packId, assets);
    });
  }

  @override
  Future<void> markAssetPresence(
    String packId,
    String assetPath,
    bool isPresent,
  ) {
    return _withDatabase<void>((db) {
      db.execute(
        'UPDATE field_pack_assets SET is_present = ? WHERE pack_id = ? AND path = ?',
        <Object?>[isPresent ? 1 : 0, packId, assetPath],
      );
    });
  }

  @override
  Future<void> deletePack(String packId) {
    return _withDatabase<void>((db) {
      db.execute('DELETE FROM field_packs WHERE id = ?', <Object?>[packId]);
    });
  }

  @override
  Future<FieldPack?> getFieldPackById(String packId) {
    return _withDatabase<FieldPack?>((db) {
      final rows = db.select(
        '''
SELECT fp.*, fa.name AS area_name
,
(
  SELECT fa2.geojson
  FROM field_areas fa2
  WHERE fa2.pack_id = fp.id
  ORDER BY fa2.created_at_utc DESC
  LIMIT 1
) AS area_geojson
,
(
  SELECT fa2.bbox_json
  FROM field_areas fa2
  WHERE fa2.pack_id = fp.id
  ORDER BY fa2.created_at_utc DESC
  LIMIT 1
) AS area_bbox_json
FROM field_packs fp
LEFT JOIN field_areas fa ON fa.pack_id = fp.id
WHERE fp.id = ?
ORDER BY fa.created_at_utc DESC
LIMIT 1
''',
        <Object?>[packId],
      );
      if (rows.isEmpty) {
        return null;
      }
      return _mapPack(rows.first);
    });
  }

  @override
  Future<List<FieldPack>> listFieldPacks() {
    return _withDatabase<List<FieldPack>>((db) {
      final rows = db.select('''
SELECT fp.*, (
  SELECT fa.name
  FROM field_areas fa
  WHERE fa.pack_id = fp.id
  ORDER BY fa.created_at_utc DESC
  LIMIT 1
) AS area_name,
(
  SELECT fa.geojson
  FROM field_areas fa
  WHERE fa.pack_id = fp.id
  ORDER BY fa.created_at_utc DESC
  LIMIT 1
) AS area_geojson
,
(
  SELECT fa.bbox_json
  FROM field_areas fa
  WHERE fa.pack_id = fp.id
  ORDER BY fa.created_at_utc DESC
  LIMIT 1
) AS area_bbox_json
FROM field_packs fp
ORDER BY fp.created_at_utc DESC
''');
      return rows.map(_mapPack).toList(growable: false);
    });
  }

  @override
  Future<FieldPack?> getActiveFieldPack() {
    return _withDatabase<FieldPack?>((db) {
      final rows = db.select('''
SELECT fp.*, fa.name AS area_name
,
(
  SELECT fa2.geojson
  FROM field_areas fa2
  WHERE fa2.pack_id = fp.id
  ORDER BY fa2.created_at_utc DESC
  LIMIT 1
) AS area_geojson
,
(
  SELECT fa2.bbox_json
  FROM field_areas fa2
  WHERE fa2.pack_id = fp.id
  ORDER BY fa2.created_at_utc DESC
  LIMIT 1
) AS area_bbox_json
FROM field_packs fp
LEFT JOIN field_areas fa ON fa.pack_id = fp.id
WHERE fp.is_active = 1
ORDER BY fa.created_at_utc DESC
LIMIT 1
''');
      if (rows.isEmpty) {
        return null;
      }
      return _mapPack(rows.first);
    });
  }

  Future<T> _withDatabase<T>(T Function(Database db) operation) async {
    final db = await _database.open();
    try {
      return operation(db);
    } finally {
      db.dispose();
    }
  }

  void _replaceAssets(Database db, String packId, List<FieldPackAsset> assets) {
    db.execute('DELETE FROM field_pack_assets WHERE pack_id = ?', <Object?>[
      packId,
    ]);
    for (final asset in assets) {
      db.execute(
        '''
INSERT INTO field_pack_assets(pack_id, path, kind, size_bytes, sha256, is_present)
VALUES (?, ?, ?, ?, ?, 0)
''',
        <Object?>[
          packId,
          asset.path,
          asset.kind,
          asset.sizeBytes,
          asset.sha256,
        ],
      );
    }
  }
}
