import 'package:flutter_test/flutter_test.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_series_photo.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/lat_lng.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/location_fallback_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/photo_capture_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/photo_metadata_service.dart';

import 'support/adhoc_test_support.dart';

void main() {
  test('startEvent creates an active event', () async {
    final controller = buildAdhocController();

    await controller.startEvent('Riverbank Event');

    expect(controller.currentEvent, isNotNull);
    expect(controller.currentEvent!.name, 'Riverbank Event/1');
    expect(controller.series, isEmpty);
    expect(controller.errorMessage, isNull);
  });

  test(
    'addPhoto creates first series and stores location warning when unresolved',
    () async {
      final controller = buildAdhocController(
        captureService: FakePhotoCaptureService(
          result: CapturedPhotoFile(
            originalPath: '/tmp/original.jpg',
            storedPath: '/tmp/stored.jpg',
            storedAtUtc: DateTime.utc(2026, 5, 1, 10, 0, 0),
          ),
        ),
        metadataService: FakePhotoMetadataService(
          metadata: PhotoMetadata(exifExtracted: false),
        ),
        locationService: FakeLocationFallbackService(
          result: FallbackLocationResult(
            metadataLocation: null,
            fallbackLocation: null,
            fallbackAttempted: true,
            warningMessage: 'Location permission denied.',
          ),
        ),
      );

      await controller.startEvent('Missing GPS Event');
      await controller.addPhoto(source: PhotoCaptureSource.camera);

      expect(controller.series.length, 1);
      expect(controller.series.first.photos.length, 1);
      expect(controller.series.first.photos.first.locationWarning, isTrue);
      expect(controller.infoMessage, contains('Location permission denied.'));
    },
  );

  test(
    'location precedence uses EXIF over fallback when both are present',
    () async {
      final controller = buildAdhocController(
        captureService: FakePhotoCaptureService(
          result: CapturedPhotoFile(
            originalPath: '/tmp/exif.jpg',
            storedPath: '/tmp/exif-stored.jpg',
            storedAtUtc: DateTime.utc(2026, 5, 1, 10, 0, 0),
          ),
        ),
        metadataService: FakePhotoMetadataService(
          metadata: const PhotoMetadata(
            exifExtracted: true,
            metadataLocation: LatLng(latitude: -19.100, longitude: 146.100),
          ),
        ),
        locationService: FakeLocationFallbackService(
          result: const FallbackLocationResult(
            metadataLocation: null,
            fallbackLocation: LatLng(latitude: -19.200, longitude: 146.200),
            fallbackAttempted: true,
            warningMessage: null,
          ),
        ),
      );

      await controller.startEvent('Exif Precedence');
      await controller.addPhoto(source: PhotoCaptureSource.camera);

      final photo = controller.series.first.photos.first;
      expect(photo.locationSource, AdhocPhotoLocationSource.exif);
      expect(photo.effectiveLocation, isNotNull);
      expect(photo.effectiveLocation!.latitude, closeTo(-19.100, 0.000001));
      expect(photo.effectiveLocation!.longitude, closeTo(146.100, 0.000001));
      expect(photo.locationWarning, isFalse);
    },
  );

  test('location precedence uses fallback when EXIF is missing', () async {
    final controller = buildAdhocController(
      captureService: FakePhotoCaptureService(
        result: CapturedPhotoFile(
          originalPath: '/tmp/fallback.jpg',
          storedPath: '/tmp/fallback-stored.jpg',
          storedAtUtc: DateTime.utc(2026, 5, 1, 10, 0, 0),
        ),
      ),
      metadataService: FakePhotoMetadataService(
        metadata: const PhotoMetadata(exifExtracted: false),
      ),
      locationService: FakeLocationFallbackService(
        result: const FallbackLocationResult(
          metadataLocation: null,
          fallbackLocation: LatLng(latitude: -19.300, longitude: 146.300),
          fallbackAttempted: true,
          warningMessage: null,
        ),
      ),
    );

    await controller.startEvent('Fallback Precedence');
    await controller.addPhoto(source: PhotoCaptureSource.camera);

    final photo = controller.series.first.photos.first;
    expect(photo.locationSource, AdhocPhotoLocationSource.fallback);
    expect(photo.effectiveLocation, isNotNull);
    expect(photo.effectiveLocation!.latitude, closeTo(-19.300, 0.000001));
    expect(photo.effectiveLocation!.longitude, closeTo(146.300, 0.000001));
    expect(photo.locationWarning, isFalse);
  });

  test('startNewSeries causes next addPhoto to create a new series', () async {
    final controller = buildAdhocController(
      captureService: SequentialFakePhotoCaptureService(
        results: <CapturedPhotoFile?>[
          CapturedPhotoFile(
            originalPath: '/tmp/one.jpg',
            storedPath: '/tmp/one-stored.jpg',
            storedAtUtc: DateTime.utc(2026, 5, 1, 10, 0, 0),
          ),
          CapturedPhotoFile(
            originalPath: '/tmp/two.jpg',
            storedPath: '/tmp/two-stored.jpg',
            storedAtUtc: DateTime.utc(2026, 5, 1, 10, 1, 0),
          ),
        ],
      ),
      metadataService: FakePhotoMetadataService(
        metadata: PhotoMetadata(
          exifExtracted: true,
          metadataLocation: LatLng(latitude: -19.258, longitude: 146.816),
        ),
      ),
      locationService: FakeLocationFallbackService(
        result: FallbackLocationResult(
          metadataLocation: LatLng(latitude: -19.258, longitude: 146.816),
          fallbackLocation: null,
          fallbackAttempted: false,
          warningMessage: null,
        ),
      ),
    );

    await controller.startEvent('Split Event');
    await controller.addPhoto(source: PhotoCaptureSource.camera);
    await controller.startNewSeries();
    await controller.addPhoto(source: PhotoCaptureSource.camera);

    expect(controller.series.length, 2);
    expect(controller.series.first.photos.length, 1);
    expect(controller.series.last.photos.length, 1);
    expect(controller.infoMessage, contains('Started a new series.'));
  });

  test('first gallery photo sets event name from photo date', () async {
    final controller = buildAdhocController(
      captureService: FakePhotoCaptureService(
        result: CapturedPhotoFile(
          originalPath: '/tmp/gallery.jpg',
          storedPath: '/tmp/gallery-stored.jpg',
          storedAtUtc: DateTime.utc(2026, 5, 1, 12, 0, 0),
        ),
      ),
      metadataService: FakePhotoMetadataService(
        metadata: PhotoMetadata(
          capturedAtUtc: DateTime.utc(2025, 12, 31, 8, 30, 0),
          exifExtracted: true,
        ),
      ),
    );

    await controller.ensureActiveEvent();
    await controller.addPhoto(source: PhotoCaptureSource.gallery);

    expect(controller.currentEvent, isNotNull);
    expect(controller.currentEvent!.name, 'CE2025-12-31/1');
    expect(controller.collectionEventName, 'CE2025-12-31/1');
  });

  test('photo with different date is added to date-matching event', () async {
    final repository = InMemoryAdhocEventRepository();
    final controller = buildAdhocController(
      repository: repository,
      captureService: FakePhotoCaptureService(
        result: CapturedPhotoFile(
          originalPath: '/tmp/old.jpg',
          storedPath: '/tmp/old-stored.jpg',
          storedAtUtc: DateTime.utc(2026, 5, 1, 12, 0, 0),
        ),
      ),
      metadataService: FakePhotoMetadataService(
        metadata: PhotoMetadata(
          capturedAtUtc: DateTime.utc(2026, 4, 20, 7, 15, 0),
          exifExtracted: true,
        ),
      ),
    );

    await controller.ensureActiveEvent();
    final initialEventId = controller.currentEvent!.id;
    expect(controller.currentEvent!.name, 'CE2026-05-01/1');

    await controller.addPhoto(source: PhotoCaptureSource.gallery);

    expect(controller.currentEvent!.name, 'CE2026-04-20/1');
    expect(controller.series.length, 1);
    expect(controller.series.single.photos.length, 1);
    expect(repository.events.length, 2);
    expect(repository.events[initialEventId]!.series, isEmpty);
  });
}
