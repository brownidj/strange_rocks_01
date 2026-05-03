part of 'sqlite_adhoc_event_repository.dart';

extension _SqliteAdhocEventRepositoryHelpers on SqliteAdhocEventRepository {
  void _upsertEvent(Database db, AdhocCollectionEvent event) {
    db.execute(
      '''
INSERT INTO adhoc_collection_events(id, name, created_at_utc, updated_at_utc)
VALUES (?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  name = excluded.name,
  updated_at_utc = excluded.updated_at_utc
''',
      <Object?>[
        event.id,
        event.name,
        event.createdAtUtc.toUtc().toIso8601String(),
        event.updatedAtUtc.toUtc().toIso8601String(),
      ],
    );
  }

  void _upsertSeries(Database db, AdhocPhotoSeries series) {
    final anchor = series.anchorLocation;
    db.execute(
      '''
INSERT INTO adhoc_photo_series(
  id, event_id, title, started_at_utc, ended_at_utc,
  anchor_latitude, anchor_longitude, max_radius_meters, location_incomplete
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  title = excluded.title,
  started_at_utc = excluded.started_at_utc,
  ended_at_utc = excluded.ended_at_utc,
  anchor_latitude = excluded.anchor_latitude,
  anchor_longitude = excluded.anchor_longitude,
  max_radius_meters = excluded.max_radius_meters,
  location_incomplete = excluded.location_incomplete
''',
      <Object?>[
        series.id,
        series.eventId,
        series.title,
        series.startedAtUtc.toUtc().toIso8601String(),
        series.endedAtUtc?.toUtc().toIso8601String(),
        anchor?.latitude,
        anchor?.longitude,
        series.maxRadiusMeters,
        _seriesIsLocationIncomplete(series) ? 1 : 0,
      ],
    );
    _touchEventByEventId(db, series.eventId);
  }

  void _upsertPhoto(Database db, AdhocSeriesPhoto photo) {
    final existingRows = db.select(
      'SELECT series_id FROM adhoc_series_photos WHERE id = ? LIMIT 1',
      <Object?>[photo.id],
    );
    if (existingRows.isNotEmpty) {
      final existingSeriesId = existingRows.first['series_id'] as String;
      if (existingSeriesId != photo.seriesId) {
        throw StateError(
          'Photo ${photo.id} already belongs to series $existingSeriesId and cannot be moved.',
        );
      }
    }

    final metadata = photo.metadataLocation;
    final fallback = photo.fallbackLocation;
    final effective = photo.effectiveLocation;
    db.execute(
      '''
INSERT INTO adhoc_series_photos(
  id, series_id, file_path, captured_at_utc,
  metadata_latitude, metadata_longitude,
  fallback_latitude, fallback_longitude,
  effective_latitude, effective_longitude,
  exif_extracted, location_warning, created_at_utc
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  file_path = excluded.file_path,
  captured_at_utc = excluded.captured_at_utc,
  metadata_latitude = excluded.metadata_latitude,
  metadata_longitude = excluded.metadata_longitude,
  fallback_latitude = excluded.fallback_latitude,
  fallback_longitude = excluded.fallback_longitude,
  effective_latitude = excluded.effective_latitude,
  effective_longitude = excluded.effective_longitude,
  exif_extracted = excluded.exif_extracted,
  location_warning = excluded.location_warning
''',
      <Object?>[
        photo.id,
        photo.seriesId,
        photo.filePath,
        photo.capturedAtUtc?.toUtc().toIso8601String(),
        metadata?.latitude,
        metadata?.longitude,
        fallback?.latitude,
        fallback?.longitude,
        effective?.latitude,
        effective?.longitude,
        photo.exifExtracted ? 1 : 0,
        photo.locationWarning ? 1 : 0,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  List<AdhocPhotoSeries> _loadSeriesForEvent(Database db, String eventId) {
    final seriesRows = db.select(
      '''
SELECT
  id, event_id, title, started_at_utc, ended_at_utc,
  anchor_latitude, anchor_longitude, max_radius_meters
FROM adhoc_photo_series
WHERE event_id = ?
ORDER BY started_at_utc ASC
''',
      <Object?>[eventId],
    );

    return seriesRows
        .map((row) {
          final seriesId = row['id'] as String;
          return _mapSeries(row, _loadPhotosForSeries(db, seriesId));
        })
        .toList(growable: false);
  }

  List<AdhocSeriesPhoto> _loadPhotosForSeries(Database db, String seriesId) {
    final photoRows = db.select(
      '''
SELECT
  id, series_id, file_path, captured_at_utc,
  metadata_latitude, metadata_longitude,
  fallback_latitude, fallback_longitude,
  exif_extracted, location_warning
FROM adhoc_series_photos
WHERE series_id = ?
ORDER BY created_at_utc ASC
''',
      <Object?>[seriesId],
    );
    return photoRows.map(_mapPhoto).toList(growable: false);
  }

  AdhocCollectionEvent _mapEvent(Row row, List<AdhocPhotoSeries> series) {
    return AdhocCollectionEvent(
      id: row['id'] as String,
      name: row['name'] as String,
      createdAtUtc: DateTime.parse(row['created_at_utc'] as String).toUtc(),
      updatedAtUtc: DateTime.parse(row['updated_at_utc'] as String).toUtc(),
      series: series,
    );
  }

  AdhocPhotoSeries _mapSeries(Row row, List<AdhocSeriesPhoto> photos) {
    final anchorLat = row['anchor_latitude'] as double?;
    final anchorLng = row['anchor_longitude'] as double?;
    return AdhocPhotoSeries(
      id: row['id'] as String,
      eventId: row['event_id'] as String,
      title: row['title'] as String,
      startedAtUtc: DateTime.parse(row['started_at_utc'] as String).toUtc(),
      endedAtUtc: row['ended_at_utc'] == null
          ? null
          : DateTime.parse(row['ended_at_utc'] as String).toUtc(),
      anchorLocation: (anchorLat != null && anchorLng != null)
          ? LatLng(latitude: anchorLat, longitude: anchorLng)
          : null,
      maxRadiusMeters: (row['max_radius_meters'] as num).toDouble(),
      photos: photos,
    );
  }

  AdhocSeriesPhoto _mapPhoto(Row row) {
    final metadataLat = row['metadata_latitude'] as double?;
    final metadataLng = row['metadata_longitude'] as double?;
    final fallbackLat = row['fallback_latitude'] as double?;
    final fallbackLng = row['fallback_longitude'] as double?;
    return AdhocSeriesPhoto(
      id: row['id'] as String,
      seriesId: row['series_id'] as String,
      filePath: row['file_path'] as String,
      capturedAtUtc: row['captured_at_utc'] == null
          ? null
          : DateTime.parse(row['captured_at_utc'] as String).toUtc(),
      metadataLocation: (metadataLat != null && metadataLng != null)
          ? LatLng(latitude: metadataLat, longitude: metadataLng)
          : null,
      fallbackLocation: (fallbackLat != null && fallbackLng != null)
          ? LatLng(latitude: fallbackLat, longitude: fallbackLng)
          : null,
      exifExtracted: (row['exif_extracted'] as int) == 1,
      locationWarning: (row['location_warning'] as int) == 1,
    );
  }

  void _touchEventBySeriesId(Database db, String seriesId) {
    final rows = db.select(
      'SELECT event_id FROM adhoc_photo_series WHERE id = ? LIMIT 1',
      <Object?>[seriesId],
    );
    if (rows.isEmpty) {
      return;
    }
    _touchEventByEventId(db, rows.first['event_id'] as String);
  }

  void _touchEventByEventId(Database db, String eventId) {
    db.execute(
      'UPDATE adhoc_collection_events SET updated_at_utc = ? WHERE id = ?',
      <Object?>[DateTime.now().toUtc().toIso8601String(), eventId],
    );
  }

  bool _seriesIsLocationIncomplete(AdhocPhotoSeries series) {
    if (series.photos.isEmpty) {
      return false;
    }
    return series.photos.every((photo) => photo.effectiveLocation == null);
  }
}
