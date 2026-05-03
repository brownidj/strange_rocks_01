import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/api/field_pack_api_client.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/telemetry/field_pack_telemetry.dart';

class FakeFieldPackApiClient implements FieldPackApiClient {
  FakeFieldPackApiClient({
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

class MemoryTelemetry implements FieldPackTelemetry {
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

Uint8List buildZip(Map<String, Uint8List> files) {
  final archive = Archive();
  files.forEach((path, bytes) {
    archive.add(ArchiveFile(path, bytes.length, bytes));
  });

  final encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded);
}

Map<String, Object?> buildManifest({
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
