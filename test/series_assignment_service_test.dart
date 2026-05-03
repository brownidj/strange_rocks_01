import 'package:flutter_test/flutter_test.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_photo_series.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_series_photo.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/lat_lng.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/series_assignment_service.dart';

void main() {
  final service = SeriesAssignmentService();

  test('creates first series when no active series exists', () {
    final result = service.assignPhoto(
      eventId: 'event-1',
      existingSeries: const <AdhocPhotoSeries>[],
      photo: _photo(
        id: 'p-1',
        seriesId: 's-1',
        latLng: const LatLng(latitude: 0, longitude: 0),
      ),
      createSeriesId: () => 's-1',
      nowLocal: DateTime(2026, 5, 1, 14, 32, 8),
    );

    expect(result.createdNewSeries, isTrue);
    expect(result.splitReason, SeriesSplitReason.noActiveSeries);
    expect(result.updatedSeries.id, 's-1');
    expect(result.updatedSeries.title, 'S2026-05-01 14:32.08');
    expect(result.updatedSeries.photos.length, 1);
  });

  test('keeps photo in same series at 49.9 m', () {
    final anchor = const LatLng(latitude: 0, longitude: 0);
    final activeSeries = _series(
      id: 's-1',
      eventId: 'event-1',
      anchor: anchor,
      photos: <AdhocSeriesPhoto>[
        _photo(id: 'p-1', seriesId: 's-1', latLng: anchor),
      ],
    );

    final result = service.assignPhoto(
      eventId: 'event-1',
      existingSeries: <AdhocPhotoSeries>[activeSeries],
      photo: _photo(
        id: 'p-2',
        seriesId: 's-1',
        latLng: _northOffset(anchor, 49.9),
      ),
      createSeriesId: () => 's-2',
      nowLocal: DateTime(2026, 5, 1, 14, 40, 0),
    );

    expect(result.createdNewSeries, isFalse);
    expect(result.splitReason, SeriesSplitReason.none);
    expect(result.updatedSeries.id, 's-1');
    expect(result.updatedSeries.photos.length, 2);
    expect(result.updatedSeries.maxRadiusMeters, closeTo(49.9, 0.8));
  });

  test('keeps photo in same series at exactly 50.0 m', () {
    final anchor = const LatLng(latitude: 0, longitude: 0);
    final activeSeries = _series(
      id: 's-1',
      eventId: 'event-1',
      anchor: anchor,
      photos: <AdhocSeriesPhoto>[
        _photo(id: 'p-1', seriesId: 's-1', latLng: anchor),
      ],
    );

    final result = service.assignPhoto(
      eventId: 'event-1',
      existingSeries: <AdhocPhotoSeries>[activeSeries],
      photo: _photo(
        id: 'p-2',
        seriesId: 's-1',
        latLng: _northOffset(anchor, 50.0),
      ),
      createSeriesId: () => 's-2',
      nowLocal: DateTime(2026, 5, 1, 14, 40, 0),
    );

    expect(result.createdNewSeries, isFalse);
    expect(result.splitReason, SeriesSplitReason.none);
    expect(result.updatedSeries.id, 's-1');
  });

  test('starts new series when distance exceeds 50 m (50.1 m)', () {
    final anchor = const LatLng(latitude: 0, longitude: 0);
    final activeSeries = _series(
      id: 's-1',
      eventId: 'event-1',
      anchor: anchor,
      photos: <AdhocSeriesPhoto>[
        _photo(id: 'p-1', seriesId: 's-1', latLng: anchor),
      ],
    );

    final result = service.assignPhoto(
      eventId: 'event-1',
      existingSeries: <AdhocPhotoSeries>[activeSeries],
      photo: _photo(
        id: 'p-2',
        seriesId: 's-2',
        latLng: _northOffset(anchor, 50.1),
      ),
      createSeriesId: () => 's-2',
      nowLocal: DateTime(2026, 5, 1, 14, 45, 0),
    );

    expect(result.createdNewSeries, isTrue);
    expect(result.splitReason, SeriesSplitReason.distanceExceeded);
    expect(result.updatedSeries.id, 's-2');
    expect(result.updatedSeries.photos.length, 1);
  });

  test('starts new series when current series already has 20 photos', () {
    final anchor = const LatLng(latitude: 0, longitude: 0);
    final fullPhotos = List<AdhocSeriesPhoto>.generate(
      20,
      (index) => _photo(
        id: 'p-$index',
        seriesId: 's-1',
        latLng: _northOffset(anchor, index.toDouble()),
      ),
    );
    final activeSeries = _series(
      id: 's-1',
      eventId: 'event-1',
      anchor: anchor,
      photos: fullPhotos,
    );

    final result = service.assignPhoto(
      eventId: 'event-1',
      existingSeries: <AdhocPhotoSeries>[activeSeries],
      photo: _photo(
        id: 'p-21',
        seriesId: 's-2',
        latLng: _northOffset(anchor, 5),
      ),
      createSeriesId: () => 's-2',
      nowLocal: DateTime(2026, 5, 1, 15, 0, 0),
    );

    expect(result.createdNewSeries, isTrue);
    expect(result.splitReason, SeriesSplitReason.maxPhotosReached);
    expect(result.updatedSeries.id, 's-2');
    expect(result.updatedSeries.photos.length, 1);
  });

  test('manual split forces new series even when within threshold', () {
    final anchor = const LatLng(latitude: 0, longitude: 0);
    final activeSeries = _series(
      id: 's-1',
      eventId: 'event-1',
      anchor: anchor,
      photos: <AdhocSeriesPhoto>[
        _photo(id: 'p-1', seriesId: 's-1', latLng: anchor),
      ],
    );

    final result = service.assignPhoto(
      eventId: 'event-1',
      existingSeries: <AdhocPhotoSeries>[activeSeries],
      photo: _photo(
        id: 'p-2',
        seriesId: 's-2',
        latLng: _northOffset(anchor, 2),
      ),
      createSeriesId: () => 's-2',
      nowLocal: DateTime(2026, 5, 1, 15, 5, 0),
      forceNewSeries: true,
    );

    expect(result.createdNewSeries, isTrue);
    expect(result.splitReason, SeriesSplitReason.manual);
    expect(result.updatedSeries.id, 's-2');
  });
}

AdhocPhotoSeries _series({
  required String id,
  required String eventId,
  required LatLng? anchor,
  required List<AdhocSeriesPhoto> photos,
}) {
  return AdhocPhotoSeries(
    id: id,
    eventId: eventId,
    title: '2026-05-01 14:00.00',
    startedAtUtc: DateTime.utc(2026, 5, 1, 4, 0, 0),
    anchorLocation: anchor,
    photos: photos,
  );
}

AdhocSeriesPhoto _photo({
  required String id,
  required String seriesId,
  LatLng? latLng,
}) {
  return AdhocSeriesPhoto(
    id: id,
    seriesId: seriesId,
    filePath: '/tmp/$id.jpg',
    metadataLocation: latLng,
    exifExtracted: latLng != null,
    locationWarning: latLng == null,
  );
}

LatLng _northOffset(LatLng origin, double meters) {
  const metersPerDegreeLat = 111320.0;
  final latOffset = meters / metersPerDegreeLat;
  return LatLng(
    latitude: origin.latitude + latOffset,
    longitude: origin.longitude,
  );
}
