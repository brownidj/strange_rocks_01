import 'package:strange_rocks_01/features/field_packs/domain/entities/data_source_attribution.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_asset.dart';

class FieldPackManifest {
  const FieldPackManifest({
    required this.packId,
    required this.version,
    required this.createdAtUtc,
    required this.crs,
    required this.area,
    required this.assets,
    required this.dataSources,
    required this.requiresAppVersion,
  });

  final String packId;
  final String version;
  final String createdAtUtc;
  final String crs;
  final Map<String, num> area;
  final List<FieldPackAsset> assets;
  final List<DataSourceAttribution> dataSources;
  final String requiresAppVersion;
}
