import 'package:flutter_test/flutter_test.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/manifest/field_pack_manifest_validation_error.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/manifest/field_pack_manifest_validator.dart';

void main() {
  final validator = FieldPackManifestValidator();

  test('valid manifest parses successfully', () {
    final parsed = validator.validate(_validManifest());

    expect(parsed.packId, 'pack-123');
    expect(parsed.assets.length, 1);
    expect(parsed.dataSources.length, 1);
  });

  test('invalid semver throws validation error', () {
    final invalid = _validManifest()..['version'] = '1.0';

    expect(
      () => validator.validate(invalid),
      throwsA(isA<FieldPackManifestValidationError>()),
    );
  });

  test('missing required key throws validation error', () {
    final invalid = _validManifest()..remove('pack_id');

    expect(
      () => validator.validate(invalid),
      throwsA(isA<FieldPackManifestValidationError>()),
    );
  });
}

Map<String, Object?> _validManifest() {
  return <String, Object?>{
    'pack_id': 'pack-123',
    'version': '1.0.0',
    'created_at_utc': '2026-04-25T00:00:00Z',
    'crs': 'EPSG:4326',
    'area': <String, Object?>{
      'bbox': <Object>[152.0, -26.0, 153.0, -25.0],
      'area_size_m2': 1000000,
    },
    'assets': <Object?>[
      <String, Object?>{
        'path': 'basemap.mbtiles',
        'kind': 'basemap',
        'size_bytes': 1024,
        'sha256':
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
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
    'requires_app_version': '1.0.0',
  };
}
