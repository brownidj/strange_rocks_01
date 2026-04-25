import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_asset.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_manifest.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/errors/field_pack_pipeline_error.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/storage/field_pack_quota_service.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/storage/field_pack_storage.dart';

void main() {
  test('allows manifest that fits within storage quota', () async {
    final tempDir = await Directory.systemTemp.createTemp('quota-ok');
    final storage = FieldPackStorage(
      appSupportDirProvider: () async => tempDir,
    );
    final service = FieldPackQuotaService(
      storage: storage,
      maxAppStorageBytes: 30 * 1024 * 1024,
      reserveBufferBytes: 1024,
    );

    await service.ensureCanStore(_manifest(assetSizeBytes: 1024));
  });

  test('throws when projected storage exceeds quota', () async {
    final tempDir = await Directory.systemTemp.createTemp('quota-fail');
    final storage = FieldPackStorage(
      appSupportDirProvider: () async => tempDir,
    );
    final service = FieldPackQuotaService(
      storage: storage,
      maxAppStorageBytes: 5 * 1024 * 1024,
      reserveBufferBytes: 1024,
    );

    await expectLater(
      () => service.ensureCanStore(_manifest(assetSizeBytes: 12 * 1024 * 1024)),
      throwsA(isA<FieldPackInsufficientStorageError>()),
    );
  });
}

FieldPackManifest _manifest({required int assetSizeBytes}) {
  return FieldPackManifest(
    packId: 'pack-quota',
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
    assets: <FieldPackAsset>[
      FieldPackAsset(
        path: 'assets/a.bin',
        kind: 'binary',
        sizeBytes: assetSizeBytes,
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
    ],
    dataSources: const [],
    requiresAppVersion: '1.0.0',
  );
}
