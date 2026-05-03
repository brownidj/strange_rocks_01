import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_collection_event.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_photo_series.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_series_photo.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/lat_lng.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/repositories/adhoc_event_repository.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/location_fallback_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/photo_capture_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/photo_metadata_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/series_assignment_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/presentation/controllers/adhoc_fossil_finds_controller.dart';

AdhocFossilFindsController buildAdhocController({
  AdhocEventRepository? repository,
  PhotoCaptureService? captureService,
  PhotoMetadataService? metadataService,
  LocationFallbackService? locationService,
}) {
  var idCounter = 0;
  return AdhocFossilFindsController(
    repository: repository ?? InMemoryAdhocEventRepository(),
    photoCaptureService:
        captureService ?? FakePhotoCaptureService(result: null),
    photoMetadataService:
        metadataService ??
        FakePhotoMetadataService(
          metadata: const PhotoMetadata(exifExtracted: false),
        ),
    locationFallbackService:
        locationService ??
        FakeLocationFallbackService(
          result: const FallbackLocationResult(
            metadataLocation: null,
            fallbackLocation: null,
            fallbackAttempted: true,
            warningMessage: 'Location unavailable.',
          ),
        ),
    seriesAssignmentService: const SeriesAssignmentService(),
    nowLocal: () => DateTime(2026, 5, 1, 14, 32, 8),
    idGenerator: (prefix) {
      idCounter += 1;
      return '$prefix-$idCounter';
    },
  );
}

class InMemoryAdhocEventRepository implements AdhocEventRepository {
  final Map<String, AdhocCollectionEvent> events =
      <String, AdhocCollectionEvent>{};
  final Map<String, AdhocPhotoSeries> seriesById = <String, AdhocPhotoSeries>{};
  final Map<String, AdhocSeriesPhoto> photosById = <String, AdhocSeriesPhoto>{};

  @override
  Future<void> deleteCollectionEvent(String eventId) async {
    events.remove(eventId);
  }

  @override
  Future<void> deletePhotoSeries(String seriesId) async {
    seriesById.remove(seriesId);
  }

  @override
  Future<AdhocCollectionEvent?> getCollectionEventById(String eventId) async {
    return events[eventId];
  }

  @override
  Future<List<AdhocCollectionEvent>> listCollectionEvents() async {
    return events.values.toList(growable: false);
  }

  @override
  Future<List<AdhocSeriesPhoto>> listSeriesPhotos(String seriesId) async {
    return photosById.values
        .where((photo) => photo.seriesId == seriesId)
        .toList(growable: false);
  }

  @override
  Future<List<AdhocPhotoSeries>> listPhotoSeries(String eventId) async {
    return seriesById.values
        .where((series) => series.eventId == eventId)
        .toList(growable: false);
  }

  @override
  Future<void> saveCapturedPhotoTransaction({
    required AdhocCollectionEvent event,
    required AdhocPhotoSeries series,
    required AdhocSeriesPhoto photo,
  }) async {
    events[event.id] = event;
    seriesById[series.id] = series;
    photosById[photo.id] = photo;
  }

  @override
  Future<void> saveCollectionEvent(AdhocCollectionEvent event) async {
    events[event.id] = event;
  }

  @override
  Future<void> savePhotoSeries(AdhocPhotoSeries series) async {
    seriesById[series.id] = series;
  }

  @override
  Future<void> saveSeriesPhoto(AdhocSeriesPhoto photo) async {
    photosById[photo.id] = photo;
  }
}

class FakePhotoCaptureService extends PhotoCaptureService {
  FakePhotoCaptureService({required this.result})
    : super(
        pickedImageProvider: _NoopPickedImageProvider(),
        appDocumentsDirProvider: () async => Directory.systemTemp,
      );

  final CapturedPhotoFile? result;

  @override
  Future<CapturedPhotoFile?> captureAndStore({
    required String eventId,
    required PhotoCaptureSource source,
  }) async {
    return result;
  }
}

class SequentialFakePhotoCaptureService extends PhotoCaptureService {
  SequentialFakePhotoCaptureService({required List<CapturedPhotoFile?> results})
    : _results = results,
      super(
        pickedImageProvider: _NoopPickedImageProvider(),
        appDocumentsDirProvider: () async => Directory.systemTemp,
      );

  final List<CapturedPhotoFile?> _results;
  int _index = 0;

  @override
  Future<CapturedPhotoFile?> captureAndStore({
    required String eventId,
    required PhotoCaptureSource source,
  }) async {
    final current = _results[_index];
    _index += 1;
    return current;
  }
}

class _NoopPickedImageProvider implements PickedImageProvider {
  @override
  Future<XFile?> pickImage(ImageSource source) async => null;
}

class FakePhotoMetadataService extends PhotoMetadataService {
  FakePhotoMetadataService({required this.metadata});

  final PhotoMetadata metadata;

  @override
  Future<PhotoMetadata> extractFromFilePath(String filePath) async {
    return metadata;
  }
}

class FakeLocationFallbackService extends LocationFallbackService {
  FakeLocationFallbackService({required this.result})
    : super(provider: const _NoopDeviceLocationProvider());

  final FallbackLocationResult result;

  @override
  Future<FallbackLocationResult> resolveForPhoto({
    required LatLng? metadataLocation,
  }) async {
    return result;
  }
}

class _NoopDeviceLocationProvider implements DeviceLocationProvider {
  const _NoopDeviceLocationProvider();

  @override
  Future<DeviceLocationPermissionStatus> checkPermission() async {
    return DeviceLocationPermissionStatus.denied;
  }

  @override
  Future<DeviceLocationPosition> getCurrentPosition() async {
    return const DeviceLocationPosition(
      latitude: 0,
      longitude: 0,
      accuracyMeters: 999,
    );
  }

  @override
  Future<bool> isServiceEnabled() async {
    return false;
  }

  @override
  Future<DeviceLocationPermissionStatus> requestPermission() async {
    return DeviceLocationPermissionStatus.denied;
  }
}
