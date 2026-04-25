import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_manifest.dart';

abstract interface class ValidateFieldPackUseCase {
  FieldPackManifest call(Map<String, Object?> manifestJson);
}
