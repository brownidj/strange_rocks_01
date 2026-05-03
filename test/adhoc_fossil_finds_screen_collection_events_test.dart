import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_collection_event.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_photo_series.dart';

import 'support/adhoc_screen_test_support.dart';
import 'support/adhoc_test_support.dart';

void main() {
  testWidgets(
    'collection event list icon is hidden when no completed events exist',
    (tester) async {
      final controller = buildAdhocController();
      await tester.pumpWidget(testAdhocApp(controller));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Collection event list'), findsNothing);
    },
  );

  testWidgets('list icon opens collection events screen', (tester) async {
    final repository = InMemoryAdhocEventRepository();
    await repository.saveCollectionEvent(
      buildCompletedEvent('event-1', 'CE2026-05-01/1'),
    );
    await repository.saveCollectionEvent(
      buildCompletedEvent('event-2', 'CE2026-05-01/2'),
    );
    final controller = buildAdhocController(repository: repository);
    await tester.pumpWidget(testAdhocApp(controller));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Collection event list'), findsOneWidget);
    await tester.tap(find.byTooltip('Collection event list'));
    await tester.pumpAndSettle();

    expect(find.text('Completed collection events'), findsOneWidget);
  });

  testWidgets('unsynced collection event can be deleted from list', (
    tester,
  ) async {
    final repository = InMemoryAdhocEventRepository();
    await repository.saveCollectionEvent(
      buildCompletedEvent('event-1', 'CE2026-05-01/1'),
    );
    await repository.saveCollectionEvent(
      buildCompletedEvent('event-2', 'CE2026-04-30/1'),
    );
    final controller = buildAdhocController(repository: repository);

    await tester.pumpWidget(testAdhocApp(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Collection event list'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Not synced with server'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Delete'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Are you sure?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.events.containsKey('event-2'), isFalse);
  });

  testWidgets(
    'unfinished active event is excluded and completed cartouches keep status icon',
    (tester) async {
      final repository = InMemoryAdhocEventRepository();
      await repository.saveCollectionEvent(
        buildCompletedEvent('event-6', 'CE2026-05-03/6'),
      );
      await repository.saveCollectionEvent(
        AdhocCollectionEvent(
          id: 'event-7',
          name: 'CE2026-05-03/7',
          createdAtUtc: DateTime.utc(2026, 5, 3, 2),
          updatedAtUtc: DateTime.utc(2026, 5, 3, 3),
          series: const <AdhocPhotoSeries>[],
        ),
      );
      final controller = buildAdhocController(repository: repository);

      await tester.pumpWidget(testAdhocApp(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Collection event list'));
      await tester.pumpAndSettle();

      expect(find.text('CE2026-05-03/7'), findsNothing);
      expect(find.text('CE2026-05-03/6'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Delete'), findsOneWidget);
    },
  );
}
