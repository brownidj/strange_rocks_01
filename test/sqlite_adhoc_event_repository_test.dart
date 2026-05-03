import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_collection_event.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_photo_series.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_series_photo.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/lat_lng.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/repositories/sqlite_adhoc_event_repository.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/database/field_pack_database.dart';

void main() {
  test('save/get/list CRUD persists event with series and photos', () async {
    final tempDir = await Directory.systemTemp.createTemp('adhoc-repo-test');
    final database = FieldPackDatabase(
      appSupportDirProvider: () async => tempDir,
    );
    final repository = SqliteAdhocEventRepository(database);

    final event = _event(
      id: 'event-1',
      name: 'Townsville Sweep',
      createdAt: DateTime.utc(2026, 5, 1, 2, 0, 0),
      updatedAt: DateTime.utc(2026, 5, 1, 2, 0, 0),
    );
    final series = _series(
      id: 'series-1',
      eventId: event.id,
      startedAt: DateTime.utc(2026, 5, 1, 2, 1, 0),
      photos: const <AdhocSeriesPhoto>[],
    );
    final photo = _photo(
      id: 'photo-1',
      seriesId: series.id,
      filePath: '/tmp/photo-1.jpg',
      fallbackLocation: const LatLng(latitude: -19.258, longitude: 146.816),
      locationWarning: false,
    );

    await repository.saveCollectionEvent(event);
    await repository.savePhotoSeries(series);
    await repository.saveSeriesPhoto(photo);

    final loaded = await repository.getCollectionEventById(event.id);
    final listed = await repository.listCollectionEvents();
    final listedSeries = await repository.listPhotoSeries(event.id);
    final listedPhotos = await repository.listSeriesPhotos(series.id);

    expect(loaded, isNotNull);
    expect(loaded!.name, 'Townsville Sweep');
    expect(loaded.series.length, 1);
    expect(loaded.series.first.photos.length, 1);
    expect(
      loaded.series.first.photos.first.locationSource,
      AdhocPhotoLocationSource.fallback,
    );
    expect(listed.length, 1);
    expect(listedSeries.length, 1);
    expect(listedPhotos.length, 1);
  });

  test(
    'saveCapturedPhotoTransaction writes event series and photo together',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('adhoc-repo-tx');
      final database = FieldPackDatabase(
        appSupportDirProvider: () async => tempDir,
      );
      final repository = SqliteAdhocEventRepository(database);

      final event = _event(
        id: 'event-2',
        name: 'Creekline',
        createdAt: DateTime.utc(2026, 5, 1, 3, 0, 0),
        updatedAt: DateTime.utc(2026, 5, 1, 3, 10, 0),
      );
      final series = _series(
        id: 'series-2',
        eventId: event.id,
        startedAt: DateTime.utc(2026, 5, 1, 3, 5, 0),
        photos: const <AdhocSeriesPhoto>[],
      );
      final photo = _photo(
        id: 'photo-2',
        seriesId: series.id,
        filePath: '/tmp/photo-2.jpg',
        metadataLocation: const LatLng(latitude: -19.258, longitude: 146.817),
        locationWarning: false,
      );

      await repository.saveCapturedPhotoTransaction(
        event: event,
        series: series,
        photo: photo,
      );

      final loaded = await repository.getCollectionEventById(event.id);
      expect(loaded, isNotNull);
      expect(loaded!.series.length, 1);
      expect(loaded.series.first.photos.length, 1);
      expect(
        loaded.series.first.photos.first.locationSource,
        AdhocPhotoLocationSource.exif,
      );
    },
  );

  test('photo id cannot be moved between series', () async {
    final tempDir = await Directory.systemTemp.createTemp('adhoc-repo-lock');
    final database = FieldPackDatabase(
      appSupportDirProvider: () async => tempDir,
    );
    final repository = SqliteAdhocEventRepository(database);

    final event = _event(
      id: 'event-3',
      name: 'Ridge',
      createdAt: DateTime.utc(2026, 5, 1, 4, 0, 0),
      updatedAt: DateTime.utc(2026, 5, 1, 4, 0, 0),
    );
    final seriesA = _series(
      id: 'series-a',
      eventId: event.id,
      startedAt: DateTime.utc(2026, 5, 1, 4, 1, 0),
      photos: const <AdhocSeriesPhoto>[],
    );
    final seriesB = _series(
      id: 'series-b',
      eventId: event.id,
      startedAt: DateTime.utc(2026, 5, 1, 4, 2, 0),
      photos: const <AdhocSeriesPhoto>[],
    );

    await repository.saveCollectionEvent(event);
    await repository.savePhotoSeries(seriesA);
    await repository.savePhotoSeries(seriesB);
    await repository.saveSeriesPhoto(
      _photo(id: 'photo-x', seriesId: seriesA.id, filePath: '/tmp/photo-x.jpg'),
    );

    expect(
      () => repository.saveSeriesPhoto(
        _photo(
          id: 'photo-x',
          seriesId: seriesB.id,
          filePath: '/tmp/photo-x.jpg',
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });
}

AdhocCollectionEvent _event({
  required String id,
  required String name,
  required DateTime createdAt,
  required DateTime updatedAt,
}) {
  return AdhocCollectionEvent(
    id: id,
    name: name,
    createdAtUtc: createdAt,
    updatedAtUtc: updatedAt,
  );
}

AdhocPhotoSeries _series({
  required String id,
  required String eventId,
  required DateTime startedAt,
  required List<AdhocSeriesPhoto> photos,
}) {
  return AdhocPhotoSeries(
    id: id,
    eventId: eventId,
    title: 'S2026-05-01 14:32.08',
    startedAtUtc: startedAt,
    photos: photos,
  );
}

AdhocSeriesPhoto _photo({
  required String id,
  required String seriesId,
  required String filePath,
  LatLng? metadataLocation,
  LatLng? fallbackLocation,
  bool locationWarning = true,
}) {
  return AdhocSeriesPhoto(
    id: id,
    seriesId: seriesId,
    filePath: filePath,
    capturedAtUtc: DateTime.utc(2026, 5, 1, 3, 30, 0),
    metadataLocation: metadataLocation,
    fallbackLocation: fallbackLocation,
    exifExtracted: metadataLocation != null,
    locationWarning: locationWarning,
  );
}
