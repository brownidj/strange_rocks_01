import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/lat_lng.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/location_fallback_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/photo_capture_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/photo_metadata_service.dart';

import 'support/adhoc_screen_test_support.dart';
import 'support/adhoc_test_support.dart';

void main() {
  testWidgets(
    'default collection event name is CEdate and event is auto-created',
    (tester) async {
      final controller = buildAdhocController(
        captureService: FakePhotoCaptureService(
          result: CapturedPhotoFile(
            originalPath: '/tmp/a.jpg',
            storedPath: '/tmp/a-stored.jpg',
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

      await tester.pumpWidget(testAdhocApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('CE2026-05-01'), findsOneWidget);
      expect(find.text('/1'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'New series'), findsNothing);

      await tester.tap(find.text('Take picture'));
      await tester.pumpAndSettle();
      expect(controller.series.length, 1);
      expect(controller.series.first.photos.length, 1);
      expect(find.text('S2026-05-01 14:32.08'), findsOneWidget);
      expect(find.text('<'), findsOneWidget);
      expect(find.text('>'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'New series'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Finish event'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'New series'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('help icon shows collection event guidance dialog', (
    tester,
  ) async {
    final controller = buildAdhocController();
    await tester.pumpWidget(testAdhocApp(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Collection event help'));
    await tester.pumpAndSettle();

    expect(
      find.text('Take a photo to start a Collection event'),
      findsOneWidget,
    );
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('finish is hidden until first series has at least one photo', (
    tester,
  ) async {
    final controller = buildAdhocController();

    await tester.pumpWidget(testAdhocApp(controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Invalid Event');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Finish event'), findsNothing);
  });

  testWidgets('manual start new series puts second photo into new series', (
    tester,
  ) async {
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
        metadata: const PhotoMetadata(
          exifExtracted: true,
          metadataLocation: LatLng(latitude: -19.258, longitude: 146.816),
        ),
      ),
      locationService: FakeLocationFallbackService(
        result: const FallbackLocationResult(
          metadataLocation: LatLng(latitude: -19.258, longitude: 146.816),
          fallbackLocation: null,
          fallbackAttempted: false,
          warningMessage: null,
        ),
      ),
    );

    await tester.pumpWidget(testAdhocApp(controller));

    await tester.enterText(find.byType(TextField), 'Split Event');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'New series'), findsNothing);

    await tester.tap(find.text('Take picture'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New series'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Take picture'));
    await tester.pumpAndSettle();

    expect(controller.series.length, 2);
    expect(controller.series.first.photos.length, 1);
    expect(controller.series.last.photos.length, 1);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '<'))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '>'))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'missing location warning is rendered in series card and summary',
    (tester) async {
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

      await tester.pumpWidget(testAdhocApp(controller));

      await tester.enterText(find.byType(TextField), 'Warning Event');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Take picture'));
      await tester.pumpAndSettle();

      expect(controller.series.length, 1);
      expect(controller.series.first.photos.length, 1);
      expect(
        find.textContaining(
          'missing GPS location. You can still finish this event.',
        ),
        findsOneWidget,
      );
    },
  );
}
