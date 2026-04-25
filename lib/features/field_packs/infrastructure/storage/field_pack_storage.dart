import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FieldPackStorage {
  FieldPackStorage({Future<Directory> Function()? appSupportDirProvider})
    : _appSupportDirProvider =
          appSupportDirProvider ?? getApplicationSupportDirectory;

  static const String _rootFolderName = 'field_packs';
  final Future<Directory> Function() _appSupportDirProvider;

  Future<Directory> ensureRootDirectory() async {
    final supportDirectory = await _appSupportDirProvider();
    final rootDirectory = Directory(
      p.join(supportDirectory.path, _rootFolderName),
    );
    return rootDirectory.create(recursive: true);
  }

  Future<Directory> ensurePackDirectory(String packId) async {
    final safePackId = _sanitizePackId(packId);
    final root = await ensureRootDirectory();
    final packDirectory = Directory(p.join(root.path, safePackId));

    await packDirectory.create(recursive: true);
    await Directory(
      p.join(packDirectory.path, 'assets'),
    ).create(recursive: true);
    await Directory(
      p.join(packDirectory.path, 'licenses'),
    ).create(recursive: true);

    return packDirectory;
  }

  Future<String> buildPackPath(String packId) async {
    final directory = await ensurePackDirectory(packId);
    return directory.path;
  }

  Future<String> buildArchivePath(String packId) async {
    final directory = await ensurePackDirectory(packId);
    return p.join(directory.path, 'download.zip');
  }

  String _sanitizePackId(String packId) {
    final trimmed = packId.trim();
    final isValid = RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(trimmed);
    if (!isValid) {
      throw ArgumentError.value(
        packId,
        'packId',
        'must only contain A-Z, a-z, 0-9, _, ., -',
      );
    }
    return trimmed;
  }
}
