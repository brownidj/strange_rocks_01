import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/compatibility/field_pack_compatibility_service.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/database/field_pack_database.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/errors/field_pack_pipeline_error.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/manifest/field_pack_manifest_validator.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/pipeline/field_pack_download_pipeline.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/repositories/sqlite_field_pack_repository.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/storage/field_pack_quota_service.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/storage/field_pack_storage.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/unpack/field_pack_archive_unpacker.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/validation/field_pack_checksum_validator.dart';

import 'support/field_pack_download_pipeline_test_support.dart';

void main() {
  test(
    'pipeline marks pack ready on successful download and validation',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('pipeline-ok');
      final assetBytes = Uint8List.fromList('fossil-data'.codeUnits);
      final goodSha = sha256.convert(assetBytes).toString();

      final apiClient = FakeFieldPackApiClient(
        manifest: buildManifest(packId: 'pack-ok', sha: goodSha),
        archiveBuilder: () =>
            buildZip(<String, Uint8List>{'assets/a.bin': assetBytes}),
      );

      final repository = SqliteFieldPackRepository(
        FieldPackDatabase(appSupportDirProvider: () async => tempDir),
      );
      final telemetry = MemoryTelemetry();

      final pipeline = FieldPackDownloadPipeline(
        apiClient: apiClient,
        repository: repository,
        storage: FieldPackStorage(appSupportDirProvider: () async => tempDir),
        manifestValidator: FieldPackManifestValidator(),
        archiveUnpacker: FieldPackArchiveUnpacker(),
        checksumValidator: FieldPackChecksumValidator(),
        compatibilityService: FieldPackCompatibilityService(
          appVersion: '1.0.0',
        ),
        quotaService: FieldPackQuotaService(
          storage: FieldPackStorage(appSupportDirProvider: () async => tempDir),
          maxAppStorageBytes: 100 * 1024 * 1024,
          reserveBufferBytes: 1024,
        ),
        telemetry: telemetry,
      );

      await pipeline('pack-ok');

      final pack = await repository.getFieldPackById('pack-ok');
      expect(pack, isNotNull);
      expect(pack!.status, FieldPackStatus.ready);
      expect(telemetry.successCount, 1);
    },
  );

  test('pipeline marks pack invalid when checksum fails', () async {
    final tempDir = await Directory.systemTemp.createTemp('pipeline-fail');
    final badBytes = Uint8List.fromList('bad-data'.codeUnits);

    final apiClient = FakeFieldPackApiClient(
      manifest: buildManifest(
        packId: 'pack-fail',
        sha: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
      archiveBuilder: () =>
          buildZip(<String, Uint8List>{'assets/a.bin': badBytes}),
    );

    final repository = SqliteFieldPackRepository(
      FieldPackDatabase(appSupportDirProvider: () async => tempDir),
    );
    final telemetry = MemoryTelemetry();

    final pipeline = FieldPackDownloadPipeline(
      apiClient: apiClient,
      repository: repository,
      storage: FieldPackStorage(appSupportDirProvider: () async => tempDir),
      manifestValidator: FieldPackManifestValidator(),
      archiveUnpacker: FieldPackArchiveUnpacker(),
      checksumValidator: FieldPackChecksumValidator(),
      compatibilityService: FieldPackCompatibilityService(appVersion: '1.0.0'),
      quotaService: FieldPackQuotaService(
        storage: FieldPackStorage(appSupportDirProvider: () async => tempDir),
        maxAppStorageBytes: 100 * 1024 * 1024,
        reserveBufferBytes: 1024,
      ),
      telemetry: telemetry,
    );

    await expectLater(
      () => pipeline('pack-fail'),
      throwsA(isA<FieldPackChecksumError>()),
    );

    final pack = await repository.getFieldPackById('pack-fail');
    expect(pack, isNotNull);
    expect(pack!.status, FieldPackStatus.invalid);
    expect(telemetry.failureCount, 1);
  });

  test('pipeline rejects incompatible app versions', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'pipeline-incompatible',
    );
    final assetBytes = Uint8List.fromList('fossil-data'.codeUnits);
    final goodSha = sha256.convert(assetBytes).toString();

    final apiClient = FakeFieldPackApiClient(
      manifest: buildManifest(
        packId: 'pack-incompat',
        sha: goodSha,
        requiresAppVersion: '2.0.0',
      ),
      archiveBuilder: () =>
          buildZip(<String, Uint8List>{'assets/a.bin': assetBytes}),
    );

    final repository = SqliteFieldPackRepository(
      FieldPackDatabase(appSupportDirProvider: () async => tempDir),
    );

    final pipeline = FieldPackDownloadPipeline(
      apiClient: apiClient,
      repository: repository,
      storage: FieldPackStorage(appSupportDirProvider: () async => tempDir),
      manifestValidator: FieldPackManifestValidator(),
      archiveUnpacker: FieldPackArchiveUnpacker(),
      checksumValidator: FieldPackChecksumValidator(),
      compatibilityService: FieldPackCompatibilityService(appVersion: '1.0.0'),
      quotaService: FieldPackQuotaService(
        storage: FieldPackStorage(appSupportDirProvider: () async => tempDir),
        maxAppStorageBytes: 100 * 1024 * 1024,
        reserveBufferBytes: 1024,
      ),
      telemetry: MemoryTelemetry(),
    );

    await expectLater(
      () => pipeline('pack-incompat'),
      throwsA(isA<FieldPackCompatibilityError>()),
    );

    final pack = await repository.getFieldPackById('pack-incompat');
    expect(pack, isNotNull);
    expect(pack!.status, FieldPackStatus.invalid);
  });

  test('pipeline rejects packs when storage quota is exceeded', () async {
    final tempDir = await Directory.systemTemp.createTemp('pipeline-quota');
    final assetBytes = Uint8List.fromList('fossil-data'.codeUnits);
    final goodSha = sha256.convert(assetBytes).toString();

    final apiClient = FakeFieldPackApiClient(
      manifest: buildManifest(
        packId: 'pack-quota',
        sha: goodSha,
        assetSizeBytes: 20 * 1024 * 1024,
      ),
      archiveBuilder: () =>
          buildZip(<String, Uint8List>{'assets/a.bin': assetBytes}),
    );

    final repository = SqliteFieldPackRepository(
      FieldPackDatabase(appSupportDirProvider: () async => tempDir),
    );

    final pipeline = FieldPackDownloadPipeline(
      apiClient: apiClient,
      repository: repository,
      storage: FieldPackStorage(appSupportDirProvider: () async => tempDir),
      manifestValidator: FieldPackManifestValidator(),
      archiveUnpacker: FieldPackArchiveUnpacker(),
      checksumValidator: FieldPackChecksumValidator(),
      compatibilityService: FieldPackCompatibilityService(appVersion: '1.0.0'),
      quotaService: FieldPackQuotaService(
        storage: FieldPackStorage(appSupportDirProvider: () async => tempDir),
        maxAppStorageBytes: 15 * 1024 * 1024,
        reserveBufferBytes: 1024,
      ),
      telemetry: MemoryTelemetry(),
    );

    await expectLater(
      () => pipeline('pack-quota'),
      throwsA(isA<FieldPackInsufficientStorageError>()),
    );

    final pack = await repository.getFieldPackById('pack-quota');
    expect(pack, isNotNull);
    expect(pack!.status, FieldPackStatus.invalid);
  });
}
