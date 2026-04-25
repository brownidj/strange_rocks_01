import 'dart:io';

import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_manifest.dart';
import 'package:strange_rocks_01/features/field_packs/domain/repositories/field_pack_repository.dart';
import 'package:strange_rocks_01/features/field_packs/domain/use_cases/download_field_pack_use_case.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/api/field_pack_api_client.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/compatibility/field_pack_compatibility_service.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/errors/field_pack_pipeline_error.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/manifest/field_pack_manifest_validation_error.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/manifest/field_pack_manifest_validator.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/storage/field_pack_storage.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/storage/field_pack_quota_service.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/telemetry/field_pack_telemetry.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/unpack/field_pack_archive_unpacker.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/validation/field_pack_checksum_validator.dart';

class FieldPackDownloadPipeline implements DownloadFieldPackUseCase {
  FieldPackDownloadPipeline({
    required FieldPackApiClient apiClient,
    required FieldPackRepository repository,
    required FieldPackStorage storage,
    required FieldPackManifestValidator manifestValidator,
    required FieldPackArchiveUnpacker archiveUnpacker,
    required FieldPackChecksumValidator checksumValidator,
    required FieldPackCompatibilityService compatibilityService,
    required FieldPackQuotaService quotaService,
    required FieldPackTelemetry telemetry,
    DateTime Function()? nowUtc,
  }) : _apiClient = apiClient,
       _repository = repository,
       _storage = storage,
       _manifestValidator = manifestValidator,
       _archiveUnpacker = archiveUnpacker,
       _checksumValidator = checksumValidator,
       _compatibilityService = compatibilityService,
       _quotaService = quotaService,
       _telemetry = telemetry,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final FieldPackApiClient _apiClient;
  final FieldPackRepository _repository;
  final FieldPackStorage _storage;
  final FieldPackManifestValidator _manifestValidator;
  final FieldPackArchiveUnpacker _archiveUnpacker;
  final FieldPackChecksumValidator _checksumValidator;
  final FieldPackCompatibilityService _compatibilityService;
  final FieldPackQuotaService _quotaService;
  final FieldPackTelemetry _telemetry;
  final DateTime Function() _nowUtc;

  @override
  Future<void> call(String packId) async {
    final startedAt = _nowUtc();
    _telemetry.recordStart(packId);
    FieldPackManifest? manifest;
    var stage = 'prepare';

    try {
      stage = 'manifest_fetch';
      _telemetry.recordStage(packId, stage);
      final packPath = await _storage.buildPackPath(packId);
      final manifestJson = await _apiClient.fetchManifest(packId);

      stage = 'manifest_validate';
      _telemetry.recordStage(packId, stage);
      manifest = _manifestValidator.validate(manifestJson);

      stage = 'compatibility_check';
      _telemetry.recordStage(
        packId,
        stage,
        metadata: <String, Object?>{
          'requires_app_version': manifest.requiresAppVersion,
        },
      );
      _compatibilityService.ensureSupported(manifest.requiresAppVersion);

      stage = 'quota_check';
      _telemetry.recordStage(packId, stage);
      await _quotaService.ensureCanStore(manifest);

      stage = 'persist_downloading';
      _telemetry.recordStage(packId, stage);
      await _repository.savePackManifest(manifest, localRootPath: packPath);
      await _repository.updatePackStatus(packId, FieldPackStatus.downloading);

      stage = 'archive_download';
      _telemetry.recordStage(packId, stage);
      final archivePath = await _storage.buildArchivePath(packId);
      await _apiClient.downloadPackArchive(packId, archivePath);

      stage = 'archive_unpack';
      _telemetry.recordStage(packId, stage);
      await _archiveUnpacker.unpackZip(
        archivePath: archivePath,
        outputDirectory: packPath,
      );

      stage = 'checksum_validate';
      _telemetry.recordStage(packId, stage);
      await _checksumValidator.validate(manifest, packPath);

      stage = 'persist_ready';
      _telemetry.recordStage(packId, stage);
      await _repository.replacePackAssets(packId, manifest.assets);
      for (final asset in manifest.assets) {
        await _repository.markAssetPresence(packId, asset.path, true);
      }

      await _repository.updatePackStatus(
        packId,
        FieldPackStatus.ready,
        downloadedAtUtc: _nowUtc().toIso8601String(),
      );

      stage = 'cleanup';
      await _tryDeleteArchive(archivePath);
      _telemetry.recordSuccess(packId, _nowUtc().difference(startedAt));
    } on FieldPackManifestValidationError catch (error) {
      await _markInvalid(packId, manifest);
      _telemetry.recordFailure(
        packId,
        stage,
        error,
        _nowUtc().difference(startedAt),
      );
      throw FieldPackSchemaMismatchError(
        'Manifest schema validation failed',
        cause: error,
      );
    } on FieldPackPipelineError catch (error) {
      await _markInvalid(packId, manifest);
      _telemetry.recordFailure(
        packId,
        stage,
        error,
        _nowUtc().difference(startedAt),
      );
      rethrow;
    } on FileSystemException catch (error) {
      await _markInvalid(packId, manifest);
      _telemetry.recordFailure(
        packId,
        stage,
        error,
        _nowUtc().difference(startedAt),
      );
      throw FieldPackStorageError(
        'File storage failure in download pipeline',
        cause: error,
      );
    } on Exception catch (error) {
      await _markInvalid(packId, manifest);
      _telemetry.recordFailure(
        packId,
        stage,
        error,
        _nowUtc().difference(startedAt),
      );
      throw FieldPackUnexpectedError(
        'Unexpected field pack pipeline failure',
        cause: error,
      );
    }
  }

  Future<void> _markInvalid(String packId, FieldPackManifest? manifest) async {
    if (manifest != null) {
      final existing = await _repository.getFieldPackById(packId);
      if (existing == null) {
        final path = await _storage.buildPackPath(packId);
        await _repository.savePackManifest(manifest, localRootPath: path);
      }
    }
    await _repository.updatePackStatus(packId, FieldPackStatus.invalid);
  }

  Future<void> _tryDeleteArchive(String archivePath) async {
    final archive = File(archivePath);
    if (await archive.exists()) {
      await archive.delete();
    }
  }
}
