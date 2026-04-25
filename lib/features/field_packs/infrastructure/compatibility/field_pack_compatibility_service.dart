import 'package:pub_semver/pub_semver.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/errors/field_pack_pipeline_error.dart';

class FieldPackCompatibilityService {
  FieldPackCompatibilityService({required String appVersion})
    : _appVersion = Version.parse(appVersion);

  final Version _appVersion;

  void ensureSupported(String requiredAppVersion) {
    final required = Version.parse(requiredAppVersion);
    if (_appVersion < required) {
      throw FieldPackCompatibilityError(
        'Field pack requires app version $requiredAppVersion but current app version is $_appVersion',
      );
    }
  }
}
