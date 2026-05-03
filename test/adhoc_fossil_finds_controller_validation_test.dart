import 'package:flutter_test/flutter_test.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_collection_event.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_photo_series.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_series_photo.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/lat_lng.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/location_fallback_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/photo_capture_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/photo_metadata_service.dart';

import 'support/adhoc_test_support.dart';

void main() {
  test('finishEvent fails when no series has photos', () async {
    final controller = buildAdhocController();

    await controller.startEvent('Empty Event');
    final finished = await controller.finishEvent();

    expect(finished, isFalse);
    expect(controller.errorMessage, contains('at least one series'));
  });

  test('finishEvent succeeds after a valid photo capture', () async {
    final repository = InMemoryAdhocEventRepository();
    final controller = buildAdhocController(
      repository: repository,
      captureService: FakePhotoCaptureService(
        result: CapturedPhotoFile(
          originalPath: '/tmp/ok.jpg',
          storedPath: '/tmp/ok-stored.jpg',
          storedAtUtc: DateTime.utc(2026, 5, 1, 10, 0, 0),
        ),
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

    await controller.startEvent('Valid Event');
    await controller.addPhoto(source: PhotoCaptureSource.gallery);
    final finished = await controller.finishEvent();

    expect(finished, isTrue);
    expect(controller.errorMessage, isNull);
    expect(controller.infoMessage, contains('saved'));
    expect(repository.events.length, 2);
    expect(controller.currentEvent, isNotNull);
    expect(controller.currentEvent!.name, 'Valid Event/2');
    expect(controller.currentEvent!.series, isEmpty);
  });

  test(
    'completion summary reports blocking issues when series is missing',
    () async {
      final controller = buildAdhocController();

      await controller.startEvent('Needs Photos');
      final summary = controller.getCompletionValidationSummary();

      expect(summary.hasBlockingIssues, isTrue);
      expect(summary.blockingIssues.join(' '), contains('at least one series'));
    },
  );

  test('completion summary reports warnings for missing GPS photos', () async {
    final controller = buildAdhocController(
      captureService: FakePhotoCaptureService(
        result: CapturedPhotoFile(
          originalPath: '/tmp/warn.jpg',
          storedPath: '/tmp/warn-stored.jpg',
          storedAtUtc: DateTime.utc(2026, 5, 1, 10, 0, 0),
        ),
      ),
      metadataService: FakePhotoMetadataService(
        metadata: const PhotoMetadata(exifExtracted: false),
      ),
      locationService: FakeLocationFallbackService(
        result: const FallbackLocationResult(
          metadataLocation: null,
          fallbackLocation: null,
          fallbackAttempted: true,
          warningMessage: 'Location unavailable.',
        ),
      ),
    );

    await controller.startEvent('GPS Warning Event');
    await controller.addPhoto(source: PhotoCaptureSource.camera);

    final summary = controller.getCompletionValidationSummary();
    expect(summary.hasBlockingIssues, isFalse);
    expect(summary.hasWarnings, isTrue);
    expect(summary.warningMessages.join(' '), contains('missing GPS'));
  });

  test('ensureActiveEvent removes series without photos', () async {
    final repository = InMemoryAdhocEventRepository();
    final populatedSeries = AdhocPhotoSeries(
      id: 'series-keep',
      eventId: 'event-1',
      title: 'S2026-05-01 14:32.08',
      startedAtUtc: DateTime.utc(2026, 5, 1, 4, 32, 8),
      photos: <AdhocSeriesPhoto>[
        AdhocSeriesPhoto(
          id: 'photo-1',
          seriesId: 'series-keep',
          filePath: '/tmp/one.jpg',
          capturedAtUtc: DateTime.utc(2026, 5, 1, 4, 32, 9),
          metadataLocation: const LatLng(latitude: -19.25, longitude: 146.81),
          fallbackLocation: null,
          exifExtracted: true,
          locationWarning: false,
        ),
      ],
    );
    final emptySeries = AdhocPhotoSeries(
      id: 'series-empty',
      eventId: 'event-1',
      title: 'S2026-05-01 14:35.00',
      startedAtUtc: DateTime.utc(2026, 5, 1, 4, 35, 0),
      photos: const <AdhocSeriesPhoto>[],
    );
    final event = AdhocCollectionEvent(
      id: 'event-1',
      name: 'CE2026-05-01',
      createdAtUtc: DateTime.utc(2026, 5, 1, 4, 30, 0),
      updatedAtUtc: DateTime.utc(2026, 5, 1, 4, 40, 0),
      series: <AdhocPhotoSeries>[populatedSeries, emptySeries],
    );
    repository.events[event.id] = event;

    final controller = buildAdhocController(repository: repository);
    await controller.ensureActiveEvent();

    expect(controller.series.length, 1);
    expect(controller.series.single.id, 'series-keep');
    expect(repository.events['event-1']!.series.length, 1);
    expect(repository.events['event-1']!.series.single.id, 'series-keep');
  });
}
