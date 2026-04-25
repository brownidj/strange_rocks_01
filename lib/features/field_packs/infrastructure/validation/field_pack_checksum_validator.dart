import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_manifest.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/errors/field_pack_pipeline_error.dart';

class FieldPackChecksumValidator {
  Future<void> validate(FieldPackManifest manifest, String packRootPath) async {
    for (final asset in manifest.assets) {
      final filePath = p.join(packRootPath, asset.path);
      final file = File(filePath);
      if (!await file.exists()) {
        throw FieldPackChecksumError('Missing required asset: ${asset.path}');
      }

      final fileBytes = await file.readAsBytes();
      final digest = sha256.convert(fileBytes).toString();
      if (digest.toLowerCase() != asset.sha256.toLowerCase()) {
        throw FieldPackChecksumError(
          'Checksum mismatch for asset: ${asset.path}',
        );
      }
    }
  }
}
