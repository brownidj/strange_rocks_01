class AdhocUploadPayloadValidationError implements Exception {
  AdhocUploadPayloadValidationError({
    required this.path,
    required this.message,
  });

  final String path;
  final String message;

  @override
  String toString() => 'AdhocUploadPayloadValidationError($path): $message';
}

class AdhocUploadEventPayload {
  AdhocUploadEventPayload({
    required this.clientEventId,
    required this.eventName,
    required this.eventCreatedAtUtc,
    required this.eventUpdatedAtUtc,
    required this.uploadedAtUtc,
    required this.series,
  });

  final String clientEventId;
  final String eventName;
  final DateTime eventCreatedAtUtc;
  final DateTime eventUpdatedAtUtc;
  final DateTime uploadedAtUtc;
  final List<AdhocUploadSeriesPayload> series;

  factory AdhocUploadEventPayload.fromJson(Object? json) {
    final reader = _JsonReader.root(json);
    final seriesJson = reader.requiredList('series');
    final series = <AdhocUploadSeriesPayload>[];
    for (var i = 0; i < seriesJson.length; i += 1) {
      series.add(
        AdhocUploadSeriesPayload.fromJson(seriesJson[i], path: 'series[$i]'),
      );
    }
    return AdhocUploadEventPayload(
      clientEventId: reader.requiredId('client_event_id'),
      eventName: reader.requiredString('event_name'),
      eventCreatedAtUtc: reader.requiredUtcDateTime('event_created_at_utc'),
      eventUpdatedAtUtc: reader.requiredUtcDateTime('event_updated_at_utc'),
      uploadedAtUtc: reader.requiredUtcDateTime('uploaded_at_utc'),
      series: series,
    );
  }
}

class AdhocUploadSeriesPayload {
  AdhocUploadSeriesPayload({
    required this.clientSeriesId,
    required this.title,
    required this.startedAtUtc,
    required this.endedAtUtc,
    required this.anchorLatitude,
    required this.anchorLongitude,
    required this.maxRadiusMeters,
    required this.locationIncomplete,
    required this.photos,
  });

  final String clientSeriesId;
  final String title;
  final DateTime startedAtUtc;
  final DateTime? endedAtUtc;
  final double? anchorLatitude;
  final double? anchorLongitude;
  final double maxRadiusMeters;
  final bool locationIncomplete;
  final List<AdhocUploadPhotoPayload> photos;

  factory AdhocUploadSeriesPayload.fromJson(
    Object? json, {
    String path = 'series',
  }) {
    final reader = _JsonReader(path: path, json: json);
    final photosJson = reader.requiredList('photos');
    final photos = <AdhocUploadPhotoPayload>[];
    for (var i = 0; i < photosJson.length; i += 1) {
      photos.add(
        AdhocUploadPhotoPayload.fromJson(
          photosJson[i],
          path: '$path.photos[$i]',
        ),
      );
    }
    return AdhocUploadSeriesPayload(
      clientSeriesId: reader.requiredId('client_series_id'),
      title: reader.requiredString('title'),
      startedAtUtc: reader.requiredUtcDateTime('started_at_utc'),
      endedAtUtc: reader.optionalUtcDateTime('ended_at_utc'),
      anchorLatitude: reader.optionalDouble('anchor_latitude'),
      anchorLongitude: reader.optionalDouble('anchor_longitude'),
      maxRadiusMeters: reader.requiredNonNegativeDouble('max_radius_meters'),
      locationIncomplete: reader.requiredBool('location_incomplete'),
      photos: photos,
    );
  }
}

class AdhocUploadPhotoPayload {
  AdhocUploadPhotoPayload({
    required this.clientPhotoId,
    required this.capturedAtUtc,
    required this.createdAtUtc,
    required this.effectiveLatitude,
    required this.effectiveLongitude,
    required this.metadataLatitude,
    required this.metadataLongitude,
    required this.fallbackLatitude,
    required this.fallbackLongitude,
    required this.exifExtracted,
    required this.locationWarning,
    required this.fileName,
    required this.sha256,
    required this.sizeBytes,
  });

  final String clientPhotoId;
  final DateTime? capturedAtUtc;
  final DateTime createdAtUtc;
  final double? effectiveLatitude;
  final double? effectiveLongitude;
  final double? metadataLatitude;
  final double? metadataLongitude;
  final double? fallbackLatitude;
  final double? fallbackLongitude;
  final bool exifExtracted;
  final bool locationWarning;
  final String fileName;
  final String sha256;
  final int sizeBytes;

  factory AdhocUploadPhotoPayload.fromJson(
    Object? json, {
    String path = 'photo',
  }) {
    final reader = _JsonReader(path: path, json: json);
    final sha256 = reader.requiredString('sha256');
    if (!_isSha256(sha256)) {
      throw AdhocUploadPayloadValidationError(
        path: '$path.sha256',
        message: 'must be a 64-character lowercase hex string',
      );
    }
    final sizeBytes = reader.requiredInt('size_bytes');
    if (sizeBytes <= 0) {
      throw AdhocUploadPayloadValidationError(
        path: '$path.size_bytes',
        message: 'must be greater than zero',
      );
    }
    return AdhocUploadPhotoPayload(
      clientPhotoId: reader.requiredId('client_photo_id'),
      capturedAtUtc: reader.optionalUtcDateTime('captured_at_utc'),
      createdAtUtc: reader.requiredUtcDateTime('created_at_utc'),
      effectiveLatitude: reader.optionalDouble('effective_latitude'),
      effectiveLongitude: reader.optionalDouble('effective_longitude'),
      metadataLatitude: reader.optionalDouble('metadata_latitude'),
      metadataLongitude: reader.optionalDouble('metadata_longitude'),
      fallbackLatitude: reader.optionalDouble('fallback_latitude'),
      fallbackLongitude: reader.optionalDouble('fallback_longitude'),
      exifExtracted: reader.requiredBool('exif_extracted'),
      locationWarning: reader.requiredBool('location_warning'),
      fileName: reader.requiredString('file_name'),
      sha256: sha256,
      sizeBytes: sizeBytes,
    );
  }
}

class _JsonReader {
  _JsonReader({required this.path, required Object? json})
    : _map = _ensureMap(path: path, json: json);

  factory _JsonReader.root(Object? json) => _JsonReader(path: r'$', json: json);

  final String path;
  final Map<String, Object?> _map;

  String requiredString(String key) {
    final value = _required(key);
    if (value is! String) {
      _invalid(key, 'must be a string');
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _invalid(key, 'must not be empty');
    }
    return trimmed;
  }

  String requiredId(String key) {
    final value = requiredString(key);
    if (!_isValidId(value)) {
      _invalid(
        key,
        'must be 3-128 chars and contain only letters, numbers, ".", "_", "-", ":"',
      );
    }
    return value;
  }

  bool requiredBool(String key) {
    final value = _required(key);
    if (value is! bool) {
      _invalid(key, 'must be a boolean');
    }
    return value;
  }

  int requiredInt(String key) {
    final value = _required(key);
    if (value is! int) {
      _invalid(key, 'must be an integer');
    }
    return value;
  }

  double requiredNonNegativeDouble(String key) {
    final value = _required(key);
    final number = _toDouble(key, value);
    if (number.isNaN || number.isInfinite || number < 0) {
      _invalid(key, 'must be a non-negative finite number');
    }
    return number;
  }

  DateTime requiredUtcDateTime(String key) {
    final value = _required(key);
    return _parseUtcDateTime(key, value);
  }

  DateTime? optionalUtcDateTime(String key) {
    final value = _map[key];
    if (value == null) {
      return null;
    }
    return _parseUtcDateTime(key, value);
  }

  double? optionalDouble(String key) {
    final value = _map[key];
    if (value == null) {
      return null;
    }
    final number = _toDouble(key, value);
    if (number.isNaN || number.isInfinite) {
      _invalid(key, 'must be a finite number');
    }
    return number;
  }

  List<Object?> requiredList(String key) {
    final value = _required(key);
    if (value is! List<Object?>) {
      _invalid(key, 'must be a list');
    }
    return value;
  }

  Object? _required(String key) {
    if (!_map.containsKey(key)) {
      throw AdhocUploadPayloadValidationError(
        path: '$path.$key',
        message: 'is required',
      );
    }
    return _map[key];
  }

  DateTime _parseUtcDateTime(String key, Object? value) {
    if (value is! String) {
      _invalid(key, 'must be an ISO-8601 UTC string ending with Z');
    }
    if (!value.endsWith('Z')) {
      _invalid(key, 'must be UTC and end with Z');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      _invalid(key, 'must be a valid ISO-8601 timestamp');
    }
    return parsed.toUtc();
  }

  double _toDouble(String key, Object? value) {
    if (value is! num) {
      _invalid(key, 'must be a number');
    }
    return value.toDouble();
  }

  Never _invalid(String key, String message) {
    throw AdhocUploadPayloadValidationError(path: '$path.$key', message: message);
  }
}

Map<String, Object?> _ensureMap({required String path, required Object? json}) {
  if (json is! Map<String, Object?>) {
    throw AdhocUploadPayloadValidationError(
      path: path,
      message: 'must be a JSON object',
    );
  }
  return json;
}

bool _isSha256(String value) {
  final pattern = RegExp(r'^[a-f0-9]{64}$');
  return pattern.hasMatch(value);
}

bool _isValidId(String value) {
  final pattern = RegExp(r'^[A-Za-z0-9._:-]{3,128}$');
  return pattern.hasMatch(value);
}
