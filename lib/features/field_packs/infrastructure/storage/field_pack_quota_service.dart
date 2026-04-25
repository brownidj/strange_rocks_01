import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_manifest.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/errors/field_pack_pipeline_error.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/storage/field_pack_storage.dart';

class FieldPackQuotaService {
  FieldPackQuotaService({
    required FieldPackStorage storage,
    this.maxAppStorageBytes = 2 * 1024 * 1024 * 1024,
    this.reserveBufferBytes = 100 * 1024 * 1024,
  }) : _storage = storage;

  final FieldPackStorage _storage;
  final int maxAppStorageBytes;
  final int reserveBufferBytes;

  Future<void> ensureCanStore(FieldPackManifest manifest) async {
    final root = await _storage.ensureRootDirectory();
    final currentUsage = await _directorySize(root);
    final incomingSize = _estimatePackSize(manifest);
    final projectedUsage = currentUsage + incomingSize;

    if (projectedUsage > maxAppStorageBytes) {
      throw FieldPackInsufficientStorageError(
        'Projected field-pack storage exceeds app quota. Current=$currentUsage bytes, incoming=$incomingSize bytes, quota=$maxAppStorageBytes bytes.',
      );
    }

    final remaining = maxAppStorageBytes - projectedUsage;
    if (remaining < reserveBufferBytes) {
      throw FieldPackInsufficientStorageError(
        'Insufficient remaining storage buffer after download. Remaining=$remaining bytes, required buffer=$reserveBufferBytes bytes.',
      );
    }
  }

  int _estimatePackSize(FieldPackManifest manifest) {
    final assetsSize = manifest.assets.fold<int>(
      0,
      (sum, asset) => sum + asset.sizeBytes,
    );

    // Include archive and metadata overhead in the preflight estimate.
    const int metadataOverhead = 5 * 1024 * 1024;
    return assetsSize + metadataOverhead;
  }

  Future<int> _directorySize(Directory root) async {
    if (!await root.exists()) {
      return 0;
    }

    var total = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      if (p.basename(entity.path).startsWith('.')) {
        continue;
      }
      total += await entity.length();
    }
    return total;
  }
}
