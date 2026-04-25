import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_asset.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_manifest.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/database/field_pack_database.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/repositories/sqlite_field_pack_repository.dart';

void main() {
  test('savePackManifest and updatePackStatus persist lifecycle', () async {
    final tempDir = await Directory.systemTemp.createTemp('repo-test');
    final database = FieldPackDatabase(
      appSupportDirProvider: () async => tempDir,
    );
    final repository = SqliteFieldPackRepository(database);

    final manifest = _manifest();
    await repository.savePackManifest(
      manifest,
      localRootPath: '${tempDir.path}/field_packs/pack-1',
    );

    await repository.updatePackStatus(
      manifest.packId,
      FieldPackStatus.ready,
      downloadedAtUtc: '2026-04-25T01:00:00Z',
    );

    final pack = await repository.getFieldPackById(manifest.packId);

    expect(pack, isNotNull);
    expect(pack!.status, FieldPackStatus.ready);
    expect(pack.downloadedAtUtc, '2026-04-25T01:00:00Z');
    expect(pack.manifest.assets.length, 1);
  });
}

FieldPackManifest _manifest() {
  return FieldPackManifest(
    packId: 'pack-1',
    version: '1.0.0',
    createdAtUtc: '2026-04-25T00:00:00Z',
    crs: 'EPSG:4326',
    area: <String, num>{
      'min_lon': 150,
      'min_lat': -30,
      'max_lon': 151,
      'max_lat': -29,
      'area_size_m2': 1000,
    },
    assets: const <FieldPackAsset>[
      FieldPackAsset(
        path: 'assets/a.bin',
        kind: 'binary',
        sizeBytes: 4,
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
    ],
    dataSources: const [],
    requiresAppVersion: '1.0.0',
  );
}
