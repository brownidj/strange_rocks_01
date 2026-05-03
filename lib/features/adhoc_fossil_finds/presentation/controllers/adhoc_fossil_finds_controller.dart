import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_collection_event.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_photo_series.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_series_photo.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/repositories/adhoc_event_repository.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/location_fallback_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/photo_capture_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/photo_metadata_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/series_assignment_service.dart';

part 'adhoc_fossil_finds_controller_events.dart';
part 'adhoc_fossil_finds_controller_capture.dart';
part 'adhoc_fossil_finds_controller_completion.dart';

class EventCompletionValidationSummary {
  const EventCompletionValidationSummary({
    required this.blockingIssues,
    required this.warningMessages,
  });

  final List<String> blockingIssues;
  final List<String> warningMessages;

  bool get hasBlockingIssues => blockingIssues.isNotEmpty;
  bool get hasWarnings => warningMessages.isNotEmpty;
}

class AdhocFossilFindsController extends ChangeNotifier {
  AdhocFossilFindsController({
    required AdhocEventRepository repository,
    required PhotoCaptureService photoCaptureService,
    required PhotoMetadataService photoMetadataService,
    required LocationFallbackService locationFallbackService,
    required SeriesAssignmentService seriesAssignmentService,
    DateTime Function()? nowLocal,
    String Function(String prefix)? idGenerator,
  }) : _repository = repository,
       _photoCaptureService = photoCaptureService,
       _photoMetadataService = photoMetadataService,
       _locationFallbackService = locationFallbackService,
       _seriesAssignmentService = seriesAssignmentService,
       _nowLocal = nowLocal ?? DateTime.now,
       _idGenerator = idGenerator ?? _defaultIdGenerator {
    _eventNameBaseDraft = _defaultEventBaseName(_nowLocal());
  }

  final AdhocEventRepository _repository;
  final PhotoCaptureService _photoCaptureService;
  final PhotoMetadataService _photoMetadataService;
  final LocationFallbackService _locationFallbackService;
  final SeriesAssignmentService _seriesAssignmentService;
  final DateTime Function() _nowLocal;
  final String Function(String prefix) _idGenerator;

  AdhocCollectionEvent? currentEvent;
  bool isLoading = false;
  String? errorMessage;
  String? infoMessage;

  late String _eventNameBaseDraft;
  int _eventSequence = 1;
  bool _manualSplitRequested = false;

  List<AdhocPhotoSeries> get series =>
      currentEvent?.series ?? const <AdhocPhotoSeries>[];

  bool get hasActiveEvent => currentEvent != null;

  bool get isManualSplitQueued => _manualSplitRequested;

  String get collectionEventBaseName => _eventNameBaseDraft.trim().isEmpty
      ? _defaultEventBaseName(_nowLocal())
      : _eventNameBaseDraft.trim();

  String get collectionEventSuffix => '/$_eventSequence';

  String get collectionEventName => _composeEventName(
    baseName: collectionEventBaseName,
    sequence: _eventSequence,
  );

  void updateCollectionEventName(String value) =>
      _updateCollectionEventName(this, value);

  Future<void> ensureActiveEvent() => _ensureActiveEvent(this);

  Future<void> startEvent(String name) => _startEvent(this, name);

  Future<void> startNewSeries() => _startNewSeries(this);

  Future<void> addPhoto({required PhotoCaptureSource source}) =>
      _addPhoto(this, source: source);

  Future<List<AdhocCollectionEvent>> listCollectionEvents() =>
      _listCollectionEvents(this);

  Future<void> deleteCollectionEvent(String eventId) =>
      _deleteCollectionEvent(this, eventId);

  EventCompletionValidationSummary getCompletionValidationSummary() =>
      _getCompletionValidationSummary(this);

  Future<bool> finishEvent() => _finishEvent(this);

  static String _defaultIdGenerator(String prefix) {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final randomBits = Random().nextInt(1 << 20);
    return '$prefix-$millis-$randomBits';
  }
}

String _defaultEventBaseName(DateTime dateTime) {
  final date = dateTime.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return 'CE${date.year}-${two(date.month)}-${two(date.day)}';
}

String _composeEventName({required String baseName, required int sequence}) {
  return '${baseName.trim()}/$sequence';
}

({String baseName, int sequence}) _parseEventName({
  required String rawName,
  required DateTime fallbackDateLocal,
}) {
  final trimmed = rawName.trim();
  final match = RegExp(r'^(.*?)/([0-9]+)$').firstMatch(trimmed);
  if (match != null) {
    final base = match.group(1)?.trim() ?? '';
    final sequence = int.tryParse(match.group(2) ?? '');
    if (base.isNotEmpty && sequence != null && sequence > 0) {
      return (baseName: base, sequence: sequence);
    }
  }

  final fallbackBase = trimmed.isEmpty
      ? _defaultEventBaseName(fallbackDateLocal)
      : trimmed;
  return (baseName: fallbackBase, sequence: 1);
}

bool _isSameLocalDate(DateTime leftUtc, DateTime rightUtc) {
  final left = leftUtc.toLocal();
  final right = rightUtc.toLocal();
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
