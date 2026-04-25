import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_asset.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_manifest.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/errors/field_pack_pipeline_error.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/validation/field_pack_checksum_validator.dart';

void main() {
  test('validate succeeds when hashes match', () async {
    final root = await Directory.systemTemp.createTemp('checksum-ok');
    final assetFile = File('${root.path}/assets/test.bin');
    await assetFile.parent.create(recursive: true);
    await assetFile.writeAsString('hello-rocks');

    final digest = sha256.convert(await assetFile.readAsBytes()).toString();
    final manifest = _manifest(sha: digest, path: 'assets/test.bin');

    final validator = FieldPackChecksumValidator();
    await validator.validate(manifest, root.path);
  });

  test('validate throws on hash mismatch', () async {
    final root = await Directory.systemTemp.createTemp('checksum-fail');
    final assetFile = File('${root.path}/assets/test.bin');
    await assetFile.parent.create(recursive: true);
    await assetFile.writeAsString('hello-rocks');

    final manifest = _manifest(
      sha: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      path: 'assets/test.bin',
    );

    final validator = FieldPackChecksumValidator();
    await expectLater(
      () => validator.validate(manifest, root.path),
      throwsA(isA<FieldPackChecksumError>()),
    );
  });
}

FieldPackManifest _manifest({required String sha, required String path}) {
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
    assets: <FieldPackAsset>[
      FieldPackAsset(path: path, kind: 'binary', sizeBytes: 11, sha256: sha),
    ],
    dataSources: const [],
    requiresAppVersion: '1.0.0',
  );
}
