import 'package:strange_rocks_01/features/field_packs/domain/entities/data_source_attribution.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_asset.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_manifest.dart';

class FieldPackManifestMapper {
  static Map<String, Object?> toJson(FieldPackManifest manifest) {
    return <String, Object?>{
      'pack_id': manifest.packId,
      'name': manifest.name,
      'version': manifest.version,
      'created_at_utc': manifest.createdAtUtc,
      'crs': manifest.crs,
      'requires_app_version': manifest.requiresAppVersion,
      'area': <String, Object?>{
        'bbox': <Object?>[
          manifest.area['min_lon'],
          manifest.area['min_lat'],
          manifest.area['max_lon'],
          manifest.area['max_lat'],
        ],
        'area_size_m2': manifest.area['area_size_m2'],
      },
      'assets': manifest.assets.map(_assetToJson).toList(growable: false),
      'data_sources': manifest.dataSources
          .map(_dataSourceToJson)
          .toList(growable: false),
    };
  }

  static FieldPackManifest fromJson(Map<String, Object?> json) {
    final area = (json['area'] as Map<String, Object?>?) ?? <String, Object?>{};
    final bbox = (area['bbox'] as List<Object?>?) ?? <Object?>[];

    return FieldPackManifest(
      packId: json['pack_id'] as String,
      name: json['name'] as String?,
      version: json['version'] as String,
      createdAtUtc: json['created_at_utc'] as String,
      crs: json['crs'] as String,
      area: <String, num>{
        'min_lon': (bbox[0] as num),
        'min_lat': (bbox[1] as num),
        'max_lon': (bbox[2] as num),
        'max_lat': (bbox[3] as num),
        'area_size_m2': area['area_size_m2'] as num,
      },
      assets: ((json['assets'] as List<Object?>?) ?? <Object?>[])
          .whereType<Map<String, Object?>>()
          .map(_assetFromJson)
          .toList(growable: false),
      dataSources: ((json['data_sources'] as List<Object?>?) ?? <Object?>[])
          .whereType<Map<String, Object?>>()
          .map(_dataSourceFromJson)
          .toList(growable: false),
      requiresAppVersion: json['requires_app_version'] as String,
    );
  }

  static Map<String, Object?> _assetToJson(FieldPackAsset asset) =>
      <String, Object?>{
        'path': asset.path,
        'kind': asset.kind,
        'size_bytes': asset.sizeBytes,
        'sha256': asset.sha256,
      };

  static FieldPackAsset _assetFromJson(Map<String, Object?> json) {
    return FieldPackAsset(
      path: json['path'] as String,
      kind: json['kind'] as String,
      sizeBytes: json['size_bytes'] as int,
      sha256: json['sha256'] as String,
    );
  }

  static Map<String, Object?> _dataSourceToJson(DataSourceAttribution source) =>
      <String, Object?>{
        'provider': source.provider,
        'acquired_at_utc': source.acquiredAtUtc,
        'license': source.license,
        'attribution': source.attribution,
      };

  static DataSourceAttribution _dataSourceFromJson(Map<String, Object?> json) {
    return DataSourceAttribution(
      provider: json['provider'] as String,
      acquiredAtUtc: json['acquired_at_utc'] as String,
      license: json['license'] as String,
      attribution: json['attribution'] as String,
    );
  }
}
