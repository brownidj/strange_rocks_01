import 'dart:io';

import 'package:archive/archive.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/errors/field_pack_pipeline_error.dart';

class FieldPackArchiveUnpacker {
  Future<void> unpackZip({
    required String archivePath,
    required String outputDirectory,
  }) async {
    try {
      final archiveFile = File(archivePath);
      final bytes = await archiveFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final item in archive) {
        final targetPath = '$outputDirectory/${item.name}';
        if (item.isFile) {
          final file = File(targetPath);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(item.content as List<int>, flush: true);
        } else {
          await Directory(targetPath).create(recursive: true);
        }
      }
    } on ArchiveException catch (error) {
      throw FieldPackUnpackError(
        'Unable to unpack field pack zip archive',
        cause: error,
      );
    } on IOException catch (error) {
      throw FieldPackStorageError(
        'Unable to write unpacked field pack files',
        cause: error,
      );
    }
  }
}
