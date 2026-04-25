import 'package:strange_rocks_01/features/field_packs/domain/entities/field_area.dart';

abstract interface class RequestFieldPackUseCase {
  Future<String> call(FieldArea area);
}
