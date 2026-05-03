import 'dart:math' as math;

import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_photo_series.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_series_photo.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/lat_lng.dart';

enum SeriesSplitReason {
  none,
  manual,
  distanceExceeded,
  maxPhotosReached,
  noActiveSeries,
}

class SeriesAssignmentResult {
  const SeriesAssignmentResult({
    required this.updatedSeries,
    required this.createdNewSeries,
    required this.splitReason,
  });

  final AdhocPhotoSeries updatedSeries;
  final bool createdNewSeries;
  final SeriesSplitReason splitReason;
}

class SeriesAssignmentService {
  const SeriesAssignmentService({
    this.distanceThresholdMeters = 50,
    this.maxPhotosPerSeries = AdhocPhotoSeries.maxPhotos,
  });

  final double distanceThresholdMeters;
  final int maxPhotosPerSeries;

  SeriesAssignmentResult assignPhoto({
    required String eventId,
    required List<AdhocPhotoSeries> existingSeries,
    required AdhocSeriesPhoto photo,
    required String Function() createSeriesId,
    required DateTime nowLocal,
    bool forceNewSeries = false,
  }) {
    final activeSeries = existingSeries.isEmpty ? null : existingSeries.last;
    final splitReason = _resolveSplitReason(
      activeSeries: activeSeries,
      incomingPhoto: photo,
      forceNewSeries: forceNewSeries,
    );

    final shouldCreateNew =
        activeSeries == null || splitReason != SeriesSplitReason.none;

    if (shouldCreateNew) {
      final created = _createSeriesWithPhoto(
        eventId: eventId,
        seriesId: createSeriesId(),
        nowLocal: nowLocal,
        photo: photo,
      );
      return SeriesAssignmentResult(
        updatedSeries: created,
        createdNewSeries: true,
        splitReason: splitReason,
      );
    }

    final updated = _appendPhoto(activeSeries, photo);
    return SeriesAssignmentResult(
      updatedSeries: updated,
      createdNewSeries: false,
      splitReason: SeriesSplitReason.none,
    );
  }

  SeriesSplitReason _resolveSplitReason({
    required AdhocPhotoSeries? activeSeries,
    required AdhocSeriesPhoto incomingPhoto,
    required bool forceNewSeries,
  }) {
    if (activeSeries == null) {
      return SeriesSplitReason.noActiveSeries;
    }

    if (forceNewSeries) {
      return SeriesSplitReason.manual;
    }

    if (activeSeries.photos.length >= maxPhotosPerSeries) {
      return SeriesSplitReason.maxPhotosReached;
    }

    final anchor = _resolveAnchor(activeSeries);
    final incoming = incomingPhoto.effectiveLocation;
    if (anchor != null && incoming != null) {
      final distance = distanceMeters(anchor, incoming);
      if (distance > distanceThresholdMeters) {
        return SeriesSplitReason.distanceExceeded;
      }
    }

    return SeriesSplitReason.none;
  }

  AdhocPhotoSeries _createSeriesWithPhoto({
    required String eventId,
    required String seriesId,
    required DateTime nowLocal,
    required AdhocSeriesPhoto photo,
  }) {
    final assignedPhoto = _copyPhotoWithSeriesId(photo, seriesId);
    final location = assignedPhoto.effectiveLocation;
    return AdhocPhotoSeries(
      id: seriesId,
      eventId: eventId,
      title: formatSeriesTitle(nowLocal),
      startedAtUtc: nowLocal.toUtc(),
      anchorLocation: location,
      maxRadiusMeters: 0,
      photos: <AdhocSeriesPhoto>[assignedPhoto],
    );
  }

  AdhocPhotoSeries _appendPhoto(
    AdhocPhotoSeries series,
    AdhocSeriesPhoto photo,
  ) {
    final assignedPhoto = _copyPhotoWithSeriesId(photo, series.id);
    final existingAnchor = _resolveAnchor(series);
    final incomingLocation = assignedPhoto.effectiveLocation;
    final nextAnchor = existingAnchor ?? incomingLocation;

    var nextMaxRadius = series.maxRadiusMeters;
    if (nextAnchor != null && incomingLocation != null) {
      final distance = distanceMeters(nextAnchor, incomingLocation);
      if (distance > nextMaxRadius) {
        nextMaxRadius = distance;
      }
    }

    return AdhocPhotoSeries(
      id: series.id,
      eventId: series.eventId,
      title: series.title,
      startedAtUtc: series.startedAtUtc,
      endedAtUtc: series.endedAtUtc,
      anchorLocation: nextAnchor,
      maxRadiusMeters: nextMaxRadius,
      photos: <AdhocSeriesPhoto>[...series.photos, assignedPhoto],
    );
  }

  AdhocSeriesPhoto _copyPhotoWithSeriesId(
    AdhocSeriesPhoto source,
    String seriesId,
  ) {
    return AdhocSeriesPhoto(
      id: source.id,
      seriesId: seriesId,
      filePath: source.filePath,
      capturedAtUtc: source.capturedAtUtc,
      metadataLocation: source.metadataLocation,
      fallbackLocation: source.fallbackLocation,
      exifExtracted: source.exifExtracted,
      locationWarning: source.locationWarning,
    );
  }

  LatLng? _resolveAnchor(AdhocPhotoSeries series) {
    if (series.anchorLocation != null) {
      return series.anchorLocation;
    }
    for (final photo in series.photos) {
      final location = photo.effectiveLocation;
      if (location != null) {
        return location;
      }
    }
    return null;
  }

  String formatSeriesTitle(DateTime nowLocal) {
    String two(int value) => value.toString().padLeft(2, '0');

    final yyyy = nowLocal.year.toString().padLeft(4, '0');
    final mm = two(nowLocal.month);
    final dd = two(nowLocal.day);
    final hh = two(nowLocal.hour);
    final min = two(nowLocal.minute);
    final sec = two(nowLocal.second);

    return 'S$yyyy-$mm-$dd $hh:$min.$sec';
  }

  double distanceMeters(LatLng a, LatLng b) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _degreesToRadians(b.latitude - a.latitude);
    final dLng = _degreesToRadians(b.longitude - a.longitude);
    final lat1 = _degreesToRadians(a.latitude);
    final lat2 = _degreesToRadians(b.latitude);

    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);

    final h =
        sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLng * sinLng;
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));

    return earthRadiusMeters * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
}
