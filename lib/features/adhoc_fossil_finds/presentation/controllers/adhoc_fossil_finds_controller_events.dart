part of 'adhoc_fossil_finds_controller.dart';

void _updateCollectionEventName(AdhocFossilFindsController c, String value) {
  c._eventNameBaseDraft = value;
  final event = c.currentEvent;
  if (event != null) {
    final baseName = value.trim().isEmpty
        ? _defaultEventBaseName(event.createdAtUtc.toLocal())
        : value.trim();
    final composedName = _composeEventName(
      baseName: baseName,
      sequence: c._eventSequence,
    );
    if (composedName == event.name) {
      c.notifyListeners();
      return;
    }
    final renamed = AdhocCollectionEvent(
      id: event.id,
      name: composedName,
      createdAtUtc: event.createdAtUtc,
      updatedAtUtc: DateTime.now().toUtc(),
      series: event.series,
    );
    c.currentEvent = renamed;
    unawaited(c._repository.saveCollectionEvent(renamed));
  }
  c.notifyListeners();
}

Future<void> _ensureActiveEvent(AdhocFossilFindsController c) async {
  if (c.currentEvent != null) {
    return;
  }
  await _runGuarded(c, () async {
    final existing = await c._repository.listCollectionEvents();
    if (existing.isNotEmpty) {
      existing.sort((a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc));
      final loaded = _removeEmptySeries(existing.first);
      final parsed = _parseEventName(
        rawName: loaded.name,
        fallbackDateLocal: loaded.createdAtUtc.toLocal(),
      );
      final normalizedName = _composeEventName(
        baseName: parsed.baseName,
        sequence: parsed.sequence,
      );

      if (loaded.name.trim().isEmpty) {
        final repaired = AdhocCollectionEvent(
          id: loaded.id,
          name: normalizedName,
          createdAtUtc: loaded.createdAtUtc,
          updatedAtUtc: DateTime.now().toUtc(),
          series: loaded.series,
        );
        await c._repository.saveCollectionEvent(repaired);
        c.currentEvent = repaired;
        c._eventNameBaseDraft = parsed.baseName;
        c._eventSequence = parsed.sequence;
      } else {
        var normalized = loaded;
        final needsNameNormalization = loaded.name != normalizedName;
        if (needsNameNormalization) {
          normalized = AdhocCollectionEvent(
            id: loaded.id,
            name: normalizedName,
            createdAtUtc: loaded.createdAtUtc,
            updatedAtUtc: DateTime.now().toUtc(),
            series: loaded.series,
          );
          await c._repository.saveCollectionEvent(normalized);
        } else if (loaded.series.length != existing.first.series.length) {
          await c._repository.saveCollectionEvent(loaded);
        }
        c.currentEvent = normalized;
        c._eventNameBaseDraft = parsed.baseName;
        c._eventSequence = parsed.sequence;
      }
      return;
    }

    final nowUtc = c._nowLocal().toUtc();
    final sequence = _nextSequenceForDate(existing, nowUtc);
    final baseName = c._eventNameBaseDraft.trim().isEmpty
        ? _defaultEventBaseName(c._nowLocal())
        : c._eventNameBaseDraft.trim();
    final created = AdhocCollectionEvent(
      id: c._idGenerator('event'),
      name: _composeEventName(baseName: baseName, sequence: sequence),
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
      series: const <AdhocPhotoSeries>[],
    );
    await c._repository.saveCollectionEvent(created);
    c.currentEvent = created;
    c._eventNameBaseDraft = baseName;
    c._eventSequence = sequence;
  });
}

Future<void> _startEvent(AdhocFossilFindsController c, String name) async {
  c._eventNameBaseDraft = name;
  await _ensureActiveEvent(c);
}

Future<void> _startNewSeries(AdhocFossilFindsController c) async {
  if (c.currentEvent == null) {
    c.errorMessage = 'Take a photo to start a Collection event first.';
    c.notifyListeners();
    return;
  }
  c._manualSplitRequested = true;
  c.errorMessage = null;
  c.infoMessage = 'A new series will start on the next photo.';
  c.notifyListeners();
}

Future<List<AdhocCollectionEvent>> _listCollectionEvents(
  AdhocFossilFindsController c,
) async {
  final events = await c._repository.listCollectionEvents();
  events.sort((a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc));
  return events.map(_removeEmptySeries).toList(growable: false);
}

Future<void> _deleteCollectionEvent(
  AdhocFossilFindsController c,
  String eventId,
) async {
  await c._repository.deleteCollectionEvent(eventId);
  if (c.currentEvent?.id == eventId) {
    c.currentEvent = null;
    await _ensureActiveEvent(c);
    return;
  }
  c.notifyListeners();
}

int _nextSequenceForDate(List<AdhocCollectionEvent> events, DateTime dateUtc) {
  var maxSequence = 0;
  for (final event in events) {
    if (!_isSameLocalDate(event.createdAtUtc, dateUtc)) {
      continue;
    }
    final parsed = _parseEventName(
      rawName: event.name,
      fallbackDateLocal: event.createdAtUtc.toLocal(),
    );
    if (parsed.sequence > maxSequence) {
      maxSequence = parsed.sequence;
    }
  }
  return maxSequence + 1;
}
