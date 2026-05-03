import 'dart:collection';

import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_series_photo.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/lat_lng.dart';

class AdhocPhotoSeries {
  static const int minPhotos = 1;
  static const int maxPhotos = 20;

  AdhocPhotoSeries({
    required this.id,
    required this.eventId,
    required this.title,
    required this.startedAtUtc,
    this.endedAtUtc,
    this.anchorLocation,
    this.maxRadiusMeters = 0,
    List<AdhocSeriesPhoto> photos = const <AdhocSeriesPhoto>[],
  }) : photos = UnmodifiableListView<AdhocSeriesPhoto>(photos),
       assert(id.trim().isNotEmpty, 'Series id cannot be empty.'),
       assert(eventId.trim().isNotEmpty, 'Event id cannot be empty.'),
       assert(title.trim().isNotEmpty, 'Series title cannot be empty.'),
       assert(maxRadiusMeters >= 0, 'Series radius cannot be negative.'),
       assert(
         photos.length <= maxPhotos,
         'A series cannot contain more than $maxPhotos photos.',
       );

  final String id;
  final String eventId;
  final String title;
  final DateTime startedAtUtc;
  final DateTime? endedAtUtc;
  final LatLng? anchorLocation;
  final double maxRadiusMeters;
  final UnmodifiableListView<AdhocSeriesPhoto> photos;

  bool get isEmpty => photos.isEmpty;

  bool get isValidPhotoCount =>
      photos.length >= minPhotos && photos.length <= maxPhotos;

  List<String> validateForCompletion() {
    final issues = <String>[];
    if (photos.length < minPhotos) {
      issues.add('Series "$title" has no photos.');
    }
    if (photos.length > maxPhotos) {
      issues.add('Series "$title" has more than $maxPhotos photos.');
    }
    return issues;
  }
}
