import 'package:flutter_test/flutter_test.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/compatibility/field_pack_compatibility_service.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/errors/field_pack_pipeline_error.dart';

void main() {
  test('accepts required version that is lower or equal to app version', () {
    final service = FieldPackCompatibilityService(appVersion: '1.2.0');

    service.ensureSupported('1.2.0');
    service.ensureSupported('1.1.9');
  });

  test('throws when required version is higher than app version', () {
    final service = FieldPackCompatibilityService(appVersion: '1.2.0');

    expect(
      () => service.ensureSupported('1.3.0'),
      throwsA(isA<FieldPackCompatibilityError>()),
    );
  });
}
