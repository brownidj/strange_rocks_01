part of 'adhoc_fossil_finds_controller.dart';

EventCompletionValidationSummary _getCompletionValidationSummary(
  AdhocFossilFindsController c,
) {
  final event = c.currentEvent;
  if (event == null) {
    return const EventCompletionValidationSummary(
      blockingIssues: <String>['No active collection event to finish.'],
      warningMessages: <String>[],
    );
  }

  final blockingIssues = <String>[];
  if (event.name.trim().isEmpty) {
    blockingIssues.add('Collection event name cannot be empty.');
  }
  blockingIssues.addAll(event.validateForCompletion());

  var missingLocationPhotos = 0;
  for (final photoSeries in event.series) {
    for (final photo in photoSeries.photos) {
      if (photo.locationWarning || photo.effectiveLocation == null) {
        missingLocationPhotos += 1;
      }
    }
  }

  final warnings = <String>[];
  if (missingLocationPhotos > 0) {
    warnings.add(
      '$missingLocationPhotos photo(s) have missing GPS location. You can still finish this event.',
    );
  }

  return EventCompletionValidationSummary(
    blockingIssues: blockingIssues,
    warningMessages: warnings,
  );
}

Future<bool> _finishEvent(AdhocFossilFindsController c) async {
  final summary = _getCompletionValidationSummary(c);
  if (summary.hasBlockingIssues) {
    c.errorMessage = summary.blockingIssues.join('\n');
    c.notifyListeners();
    return false;
  }

  final event = c.currentEvent!;

  var finished = false;
  await _runGuarded(c, () async {
    final updatedEvent = AdhocCollectionEvent(
      id: event.id,
      name: event.name,
      createdAtUtc: event.createdAtUtc,
      updatedAtUtc: DateTime.now().toUtc(),
      series: event.series,
    );
    final cleaned = _removeEmptySeries(updatedEvent);
    await c._repository.saveCollectionEvent(cleaned);
    final parsed = _parseEventName(
      rawName: cleaned.name,
      fallbackDateLocal: cleaned.createdAtUtc.toLocal(),
    );
    final existing = await c._repository.listCollectionEvents();
    final nextSequence = _nextSequenceForDate(existing, cleaned.createdAtUtc);
    final nextCreatedAtUtc = _newEventCreatedAtUtcForSameLocalDate(
      referenceDateUtc: cleaned.createdAtUtc,
      nowLocal: c._nowLocal(),
    );
    final nextEvent = AdhocCollectionEvent(
      id: c._idGenerator('event'),
      name: _composeEventName(
        baseName: parsed.baseName,
        sequence: nextSequence,
      ),
      createdAtUtc: nextCreatedAtUtc,
      updatedAtUtc: DateTime.now().toUtc(),
      series: const <AdhocPhotoSeries>[],
    );
    await c._repository.saveCollectionEvent(nextEvent);

    c.currentEvent = nextEvent;
    c._eventNameBaseDraft = parsed.baseName;
    c._eventSequence = nextSequence;
    c.infoMessage = 'Collection event saved. Started ${nextEvent.name}.';
    finished = true;
  });
  return finished;
}

DateTime _newEventCreatedAtUtcForSameLocalDate({
  required DateTime referenceDateUtc,
  required DateTime nowLocal,
}) {
  final referenceLocal = referenceDateUtc.toLocal();
  final local = DateTime(
    referenceLocal.year,
    referenceLocal.month,
    referenceLocal.day,
    nowLocal.hour,
    nowLocal.minute,
    nowLocal.second,
    nowLocal.millisecond,
    nowLocal.microsecond,
  );
  return local.toUtc();
}

Future<void> _runGuarded(
  AdhocFossilFindsController c,
  Future<void> Function() operation,
) async {
  c.isLoading = true;
  c.errorMessage = null;
  c.notifyListeners();
  try {
    await operation();
  } catch (error) {
    c.errorMessage = error.toString();
  } finally {
    c.isLoading = false;
    c.notifyListeners();
  }
}

String? _buildInfoMessage({
  required SeriesSplitReason splitReason,
  required String? locationWarning,
}) {
  final messages = <String>[];

  switch (splitReason) {
    case SeriesSplitReason.distanceExceeded:
      messages.add('New series started (moved > 50 m).');
      break;
    case SeriesSplitReason.maxPhotosReached:
      messages.add('Series limit reached (20). Started a new series.');
      break;
    case SeriesSplitReason.manual:
      messages.add('Started a new series.');
      break;
    case SeriesSplitReason.none:
    case SeriesSplitReason.noActiveSeries:
      break;
  }

  if (locationWarning != null && locationWarning.trim().isNotEmpty) {
    messages.add(locationWarning);
  }

  if (messages.isEmpty) {
    return null;
  }
  return messages.join(' ');
}

AdhocCollectionEvent _removeEmptySeries(AdhocCollectionEvent event) {
  final nonEmptySeries = event.series
      .where((photoSeries) => photoSeries.photos.isNotEmpty)
      .toList(growable: false);
  if (nonEmptySeries.length == event.series.length) {
    return event;
  }
  return AdhocCollectionEvent(
    id: event.id,
    name: event.name,
    createdAtUtc: event.createdAtUtc,
    updatedAtUtc: event.updatedAtUtc,
    series: nonEmptySeries,
  );
}
