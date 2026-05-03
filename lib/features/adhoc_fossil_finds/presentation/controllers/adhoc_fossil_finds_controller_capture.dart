part of 'adhoc_fossil_finds_controller.dart';

Future<void> _addPhoto(
  AdhocFossilFindsController c, {
  required PhotoCaptureSource source,
}) async {
  await _runGuarded(c, () async {
    var event = c.currentEvent;
    if (event == null) {
      await _ensureActiveEvent(c);
      event = c.currentEvent;
    }
    if (event == null) {
      throw StateError('Unable to initialize collection event.');
    }

    final captureResult = await c._photoCaptureService.captureAndStore(
      eventId: event.id,
      source: source,
    );
    if (captureResult == null) {
      c.infoMessage = 'Photo capture cancelled.';
      return;
    }

    final metadata = await c._photoMetadataService.extractFromFilePath(
      captureResult.storedPath,
    );
    final capturedAtUtc = metadata.capturedAtUtc ?? captureResult.storedAtUtc;
    final targetEvent = await _resolveEventForCapturedDate(c, capturedAtUtc);
    final locationResult = await c._locationFallbackService.resolveForPhoto(
      metadataLocation: metadata.metadataLocation,
    );

    final workingSeries = targetEvent.series.toList(growable: true);
    final provisionalSeriesId = workingSeries.isEmpty
        ? c._idGenerator('series')
        : workingSeries.last.id;

    final incomingPhoto = AdhocSeriesPhoto(
      id: c._idGenerator('photo'),
      seriesId: provisionalSeriesId,
      filePath: captureResult.storedPath,
      capturedAtUtc: capturedAtUtc,
      metadataLocation: metadata.metadataLocation,
      fallbackLocation: locationResult.fallbackLocation,
      exifExtracted: metadata.exifExtracted,
      locationWarning: locationResult.locationWarning,
    );

    final assignment = c._seriesAssignmentService.assignPhoto(
      eventId: targetEvent.id,
      existingSeries: workingSeries,
      photo: incomingPhoto,
      createSeriesId: () => c._idGenerator('series'),
      nowLocal: c._nowLocal(),
      forceNewSeries: c._manualSplitRequested,
    );
    c._manualSplitRequested = false;

    if (assignment.createdNewSeries) {
      workingSeries.add(assignment.updatedSeries);
    } else {
      final index = workingSeries.indexWhere(
        (candidate) => candidate.id == assignment.updatedSeries.id,
      );
      if (index == -1) {
        throw StateError(
          'Active series ${assignment.updatedSeries.id} not found for append.',
        );
      }
      workingSeries[index] = assignment.updatedSeries;
    }

    final updatedEvent = AdhocCollectionEvent(
      id: targetEvent.id,
      name: targetEvent.name,
      createdAtUtc: targetEvent.createdAtUtc,
      updatedAtUtc: DateTime.now().toUtc(),
      series: workingSeries,
    );
    c.currentEvent = _removeEmptySeries(updatedEvent);
    final currentParsed = _parseEventName(
      rawName: c.currentEvent!.name,
      fallbackDateLocal: c.currentEvent!.createdAtUtc.toLocal(),
    );
    c._eventNameBaseDraft = currentParsed.baseName;
    c._eventSequence = currentParsed.sequence;

    final persistedPhoto = c.currentEvent!.series
        .firstWhere(
          (photoSeries) => photoSeries.id == assignment.updatedSeries.id,
        )
        .photos
        .last;
    await c._repository.saveCapturedPhotoTransaction(
      event: c.currentEvent!,
      series: c.currentEvent!.series.firstWhere(
        (photoSeries) => photoSeries.id == assignment.updatedSeries.id,
      ),
      photo: persistedPhoto,
    );

    c.infoMessage = _buildInfoMessage(
      splitReason: assignment.splitReason,
      locationWarning: locationResult.warningMessage,
    );
  });
}

Future<AdhocCollectionEvent> _resolveEventForCapturedDate(
  AdhocFossilFindsController c,
  DateTime capturedAtUtc,
) async {
  final active = c.currentEvent;
  if (active != null && _isSameLocalDate(active.createdAtUtc, capturedAtUtc)) {
    return active;
  }

  final existing = await c._repository.listCollectionEvents();
  for (final candidate in existing) {
    if (_isSameLocalDate(candidate.createdAtUtc, capturedAtUtc)) {
      final cleaned = _removeEmptySeries(candidate);
      c.currentEvent = cleaned;
      final parsed = _parseEventName(
        rawName: cleaned.name,
        fallbackDateLocal: cleaned.createdAtUtc.toLocal(),
      );
      c._eventNameBaseDraft = parsed.baseName;
      c._eventSequence = parsed.sequence;
      if (cleaned.series.length != candidate.series.length) {
        await c._repository.saveCollectionEvent(cleaned);
      }
      return cleaned;
    }
  }

  final sequence = _nextSequenceForDate(existing, capturedAtUtc);
  final defaultBase = _defaultEventBaseName(capturedAtUtc.toLocal());
  final created = AdhocCollectionEvent(
    id: c._idGenerator('event'),
    name: _composeEventName(baseName: defaultBase, sequence: sequence),
    createdAtUtc: capturedAtUtc,
    updatedAtUtc: DateTime.now().toUtc(),
    series: const <AdhocPhotoSeries>[],
  );
  await c._repository.saveCollectionEvent(created);
  c.currentEvent = created;
  c._eventNameBaseDraft = defaultBase;
  c._eventSequence = sequence;
  return created;
}
