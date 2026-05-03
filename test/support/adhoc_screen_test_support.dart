import 'package:flutter/material.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_collection_event.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_photo_series.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_series_photo.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/presentation/controllers/adhoc_fossil_finds_controller.dart';
import 'package:strange_rocks_01/features/app_entry/presentation/screens/adhoc_fossil_finds_screen.dart';

Widget testAdhocApp(AdhocFossilFindsController controller) {
  return MaterialApp(home: AdhocFossilFindsScreen(controller: controller));
}

AdhocCollectionEvent buildCompletedEvent(String eventId, String eventName) {
  const seriesId = 'series-1';
  return AdhocCollectionEvent(
    id: eventId,
    name: eventName,
    createdAtUtc: DateTime.utc(2026, 5, 1, 1),
    updatedAtUtc: DateTime.utc(2026, 5, 1, 2),
    series: <AdhocPhotoSeries>[
      AdhocPhotoSeries(
        id: seriesId,
        eventId: eventId,
        title: 'S2026-05-01 10:00.00',
        startedAtUtc: DateTime.utc(2026, 5, 1, 1),
        photos: <AdhocSeriesPhoto>[
          AdhocSeriesPhoto(
            id: 'photo-1',
            seriesId: seriesId,
            filePath: '/tmp/photo-1.jpg',
            capturedAtUtc: DateTime.utc(2026, 5, 1, 1),
          ),
        ],
      ),
    ],
  );
}
