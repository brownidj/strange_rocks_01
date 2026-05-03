import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/lat_lng.dart';

enum AdhocPhotoLocationSource { exif, fallback, missing }

class AdhocSeriesPhoto {
  AdhocSeriesPhoto({
    required this.id,
    required this.seriesId,
    required this.filePath,
    this.capturedAtUtc,
    this.metadataLocation,
    this.fallbackLocation,
    this.exifExtracted = false,
    this.locationWarning = false,
  }) : assert(id.trim().isNotEmpty, 'Photo id cannot be empty.'),
       assert(seriesId.trim().isNotEmpty, 'Series id cannot be empty.'),
       assert(filePath.trim().isNotEmpty, 'File path cannot be empty.');

  final String id;
  final String seriesId;
  final String filePath;
  final DateTime? capturedAtUtc;
  final LatLng? metadataLocation;
  final LatLng? fallbackLocation;
  final bool exifExtracted;
  final bool locationWarning;

  LatLng? get effectiveLocation => metadataLocation ?? fallbackLocation;

  AdhocPhotoLocationSource get locationSource {
    if (metadataLocation != null) return AdhocPhotoLocationSource.exif;
    if (fallbackLocation != null) return AdhocPhotoLocationSource.fallback;
    return AdhocPhotoLocationSource.missing;
  }
}
