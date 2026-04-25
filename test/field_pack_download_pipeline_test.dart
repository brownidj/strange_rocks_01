import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/api/field_pack_api_client.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/compatibility/field_pack_compatibility_service.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/database/field_pack_database.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/errors/field_pack_pipeline_error.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/manifest/field_pack_manifest_validator.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/pipeline/field_pack_download_pipeline.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/repositories/sqlite_field_pack_repository.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/storage/field_pack_quota_service.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/storage/field_pack_storage.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/telemetry/field_pack_telemetry.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/unpack/field_pack_archive_unpacker.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/validation/field_pack_checksum_validator.dart';

void main() {
  test(
    'pipeline marks pack ready on successful download and validation',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('pipeline-ok');
      final assetBytes = Uint8List.fromList('fossil-data'.codeUnits);
      final goodSha = sha256.convert(assetBytes).toString();

      final apiClient = _FakeFieldPackApiClient(
        manifest: _manifest(packId: 'pack-ok', sha: goodSha),
        archiveBuilder: () =>
            _buildZip(<String, Uint8List>{'assets/a.bin': assetBytes}),
      );

      final repository = SqliteFieldPackRepository(
        FieldPackDatabase(appSupportDirProvider: () async => tempDir),
      );
      final telemetry = _MemoryTelemetry();

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

    final apiClient = _FakeFieldPackApiClient(
      manifest: _manifest(
        packId: 'pack-fail',
        sha: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
      archiveBuilder: () =>
          _buildZip(<String, Uint8List>{'assets/a.bin': badBytes}),
    );

    final repository = SqliteFieldPackRepository(
      FieldPackDatabase(appSupportDirProvider: () async => tempDir),
    );
    final telemetry = _MemoryTelemetry();

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

    final apiClient = _FakeFieldPackApiClient(
      manifest: _manifest(
        packId: 'pack-incompat',
        sha: goodSha,
        requiresAppVersion: '2.0.0',
      ),
      archiveBuilder: () =>
          _buildZip(<String, Uint8List>{'assets/a.bin': assetBytes}),
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
      telemetry: _MemoryTelemetry(),
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

    final apiClient = _FakeFieldPackApiClient(
      manifest: _manifest(
        packId: 'pack-quota',
        sha: goodSha,
        assetSizeBytes: 20 * 1024 * 1024,
      ),
      archiveBuilder: () =>
          _buildZip(<String, Uint8List>{'assets/a.bin': assetBytes}),
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
      telemetry: _MemoryTelemetry(),
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

class _FakeFieldPackApiClient implements FieldPackApiClient {
  _FakeFieldPackApiClient({
    required this.manifest,
    required this.archiveBuilder,
  });

  final Map<String, Object?> manifest;
  final Uint8List Function() archiveBuilder;

  @override
  Future<Map<String, Object?>> fetchManifest(String packId) async {
    return manifest;
  }

  @override
  Future<void> downloadPackArchive(
    String packId,
    String destinationPath,
  ) async {
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(archiveBuilder(), flush: true);
  }
}

class _MemoryTelemetry implements FieldPackTelemetry {
  int successCount = 0;
  int failureCount = 0;

  @override
  void recordFailure(
    String packId,
    String stage,
    Object error,
    Duration duration,
  ) {
    failureCount += 1;
  }

  @override
  void recordStage(
    String packId,
    String stage, {
    Map<String, Object?>? metadata,
  }) {}

  @override
  void recordStart(String packId) {}

  @override
  void recordSuccess(String packId, Duration duration) {
    successCount += 1;
  }
}

Uint8List _buildZip(Map<String, Uint8List> files) {
  final archive = Archive();
  files.forEach((path, bytes) {
    archive.add(ArchiveFile(path, bytes.length, bytes));
  });

  final encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded);
}

Map<String, Object?> _manifest({
  required String packId,
  required String sha,
  String requiresAppVersion = '1.0.0',
  int assetSizeBytes = 10,
}) {
  return <String, Object?>{
    'pack_id': packId,
    'version': '1.0.0',
    'created_at_utc': '2026-04-25T00:00:00Z',
    'crs': 'EPSG:4326',
    'area': <String, Object?>{
      'bbox': <Object>[152.0, -26.0, 153.0, -25.0],
      'area_size_m2': 1000000,
    },
    'assets': <Object?>[
      <String, Object?>{
        'path': 'assets/a.bin',
        'kind': 'binary',
        'size_bytes': assetSizeBytes,
        'sha256': sha,
      },
    ],
    'data_sources': <Object?>[
      <String, Object?>{
        'provider': 'Example Provider',
        'acquired_at_utc': '2026-04-01T00:00:00Z',
        'license': 'CC-BY 4.0',
        'attribution': 'Example Attribution',
      },
    ],
    'requires_app_version': requiresAppVersion,
  };
}
