import 'dart:collection';

import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_photo_series.dart';

class AdhocCollectionEvent {
  AdhocCollectionEvent({
    required this.id,
    required this.name,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    List<AdhocPhotoSeries> series = const <AdhocPhotoSeries>[],
  }) : series = UnmodifiableListView<AdhocPhotoSeries>(series),
       assert(id.trim().isNotEmpty, 'Event id cannot be empty.'),
       assert(name.trim().isNotEmpty, 'Event name cannot be empty.');

  final String id;
  final String name;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final UnmodifiableListView<AdhocPhotoSeries> series;

  bool get hasAnySeries => series.isNotEmpty;

  List<String> validateForCompletion() {
    final issues = <String>[];
    if (series.isEmpty) {
      issues.add('Collection event must include at least one series.');
    }
    for (final photoSeries in series) {
      issues.addAll(photoSeries.validateForCompletion());
    }
    return issues;
  }
}
