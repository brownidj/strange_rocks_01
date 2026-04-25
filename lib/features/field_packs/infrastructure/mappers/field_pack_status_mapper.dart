import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack.dart';

class FieldPackStatusMapper {
  static String toDb(FieldPackStatus status) => switch (status) {
    FieldPackStatus.downloading => 'downloading',
    FieldPackStatus.ready => 'ready',
    FieldPackStatus.active => 'active',
    FieldPackStatus.invalid => 'invalid',
  };

  static FieldPackStatus fromDb(String value) => switch (value) {
    'downloading' => FieldPackStatus.downloading,
    'ready' => FieldPackStatus.ready,
    'active' => FieldPackStatus.active,
    'invalid' => FieldPackStatus.invalid,
    _ => throw StateError('Unknown field pack status: $value'),
  };
}
