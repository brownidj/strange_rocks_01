import 'package:strange_rocks_01/features/field_packs/domain/entities/data_source_attribution.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_asset.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_manifest.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/manifest/field_pack_manifest_validation_error.dart';

class FieldPackManifestValidator {
  static final RegExp _semVer = RegExp(
    r'^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$',
  );
  static final RegExp _epsg = RegExp(r'^EPSG:\d+$');
  static final RegExp _sha256 = RegExp(r'^[a-fA-F0-9]{64}$');

  FieldPackManifest validate(Map<String, Object?> manifestJson) {
    final packId = _requiredString(manifestJson, 'pack_id');
    final version = _requiredString(manifestJson, 'version');
    final createdAtUtc = _requiredString(manifestJson, 'created_at_utc');
    final crs = _requiredString(manifestJson, 'crs');
    final requiresAppVersion = _requiredString(
      manifestJson,
      'requires_app_version',
    );

    _validateSemVer(version, key: 'version');
    _validateSemVer(requiresAppVersion, key: 'requires_app_version');
    _validateIsoDate(createdAtUtc, key: 'created_at_utc');

    if (!_epsg.hasMatch(crs)) {
      throw const FieldPackManifestValidationError(
        'crs must use format EPSG:<code>',
      );
    }

    final areaMap = _requiredMap(manifestJson, 'area');
    final bbox = _requiredList(areaMap, 'bbox');
    if (bbox.length != 4 || bbox.any((entry) => entry is! num)) {
      throw const FieldPackManifestValidationError(
        'area.bbox must be [minLon, minLat, maxLon, maxLat]',
      );
    }

    final areaSizeM2 = areaMap['area_size_m2'];
    if (areaSizeM2 is! num || areaSizeM2 <= 0) {
      throw const FieldPackManifestValidationError(
        'area.area_size_m2 must be a positive number',
      );
    }

    final assetsJson = _requiredList(manifestJson, 'assets');
    if (assetsJson.isEmpty) {
      throw const FieldPackManifestValidationError('assets must not be empty');
    }
    final assets = assetsJson.map(_parseAsset).toList(growable: false);

    final dataSourcesJson = _requiredList(manifestJson, 'data_sources');
    final dataSources = dataSourcesJson
        .map(_parseDataSource)
        .toList(growable: false);

    return FieldPackManifest(
      packId: packId,
      version: version,
      createdAtUtc: createdAtUtc,
      crs: crs,
      area: <String, num>{
        'min_lon': (bbox[0] as num),
        'min_lat': (bbox[1] as num),
        'max_lon': (bbox[2] as num),
        'max_lat': (bbox[3] as num),
        'area_size_m2': areaSizeM2,
      },
      assets: assets,
      dataSources: dataSources,
      requiresAppVersion: requiresAppVersion,
    );
  }

  FieldPackAsset _parseAsset(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FieldPackManifestValidationError(
        'Each assets item must be an object',
      );
    }

    final path = _requiredString(json, 'path');
    final kind = _requiredString(json, 'kind');
    final sizeBytes = json['size_bytes'];
    final sha256 = _requiredString(json, 'sha256');

    if (path.trim().isEmpty || path.startsWith('/')) {
      throw const FieldPackManifestValidationError(
        'assets.path must be a relative non-empty path',
      );
    }
    if (sizeBytes is! int || sizeBytes <= 0) {
      throw const FieldPackManifestValidationError(
        'assets.size_bytes must be a positive integer',
      );
    }
    if (!_sha256.hasMatch(sha256)) {
      throw const FieldPackManifestValidationError(
        'assets.sha256 must be a 64-char hex string',
      );
    }

    return FieldPackAsset(
      path: path,
      kind: kind,
      sizeBytes: sizeBytes,
      sha256: sha256,
    );
  }

  DataSourceAttribution _parseDataSource(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FieldPackManifestValidationError(
        'Each data_sources item must be an object',
      );
    }

    final acquiredAtUtc = _requiredString(json, 'acquired_at_utc');
    _validateIsoDate(acquiredAtUtc, key: 'data_sources.acquired_at_utc');

    return DataSourceAttribution(
      provider: _requiredString(json, 'provider'),
      acquiredAtUtc: acquiredAtUtc,
      license: _requiredString(json, 'license'),
      attribution: _requiredString(json, 'attribution'),
    );
  }

  Map<String, Object?> _requiredMap(Map<String, Object?> root, String key) {
    final value = root[key];
    if (value is Map<String, Object?>) {
      return value;
    }
    throw FieldPackManifestValidationError(
      '$key is required and must be an object',
    );
  }

  List<Object?> _requiredList(Map<String, Object?> root, String key) {
    final value = root[key];
    if (value is List<Object?>) {
      return value;
    }
    throw FieldPackManifestValidationError(
      '$key is required and must be an array',
    );
  }

  String _requiredString(Map<String, Object?> root, String key) {
    final value = root[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw FieldPackManifestValidationError(
      '$key is required and must be a non-empty string',
    );
  }

  void _validateSemVer(String value, {required String key}) {
    if (!_semVer.hasMatch(value)) {
      throw FieldPackManifestValidationError('$key must be semver formatted');
    }
  }

  void _validateIsoDate(String value, {required String key}) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !value.toUpperCase().endsWith('Z')) {
      throw FieldPackManifestValidationError(
        '$key must be an ISO-8601 UTC timestamp',
      );
    }
  }
}
