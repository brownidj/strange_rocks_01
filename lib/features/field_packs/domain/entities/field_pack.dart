import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_manifest.dart';

enum FieldPackStatus { downloading, ready, active, invalid }

class FieldPack {
  const FieldPack({
    required this.id,
    required this.version,
    required this.status,
    required this.localRootPath,
    required this.createdAtUtc,
    required this.manifest,
    this.name,
    this.downloadedAtUtc,
    this.isActive = false,
  });

  final String id;
  final String version;
  final String? name;
  final FieldPackStatus status;
  final String localRootPath;
  final String createdAtUtc;
  final String? downloadedAtUtc;
  final bool isActive;
  final FieldPackManifest manifest;
}
