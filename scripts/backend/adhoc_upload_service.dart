import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import 'adhoc_upload_db.dart';
import 'adhoc_upload_models.dart';

class AdhocUploadService {
  AdhocUploadService({
    required AdhocUploadDb database,
    required Directory uploadsRootDir,
  }) : _database = database,
       _uploadsRootDir = uploadsRootDir;

  final AdhocUploadDb _database;
  final Directory _uploadsRootDir;
  final Random _random = Random.secure();
  static const int _maxRequestBytes = 25 * 1024 * 1024;
  static const int _maxFileBytes = 10 * 1024 * 1024;
  static const Set<String> _allowedMimeTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/heic',
  };

  Future<void> handle(HttpRequest request, {required Uri baseUrl}) async {
    try {
      final segments = request.uri.pathSegments;
      if (request.method == 'GET' && _match(segments, <String>['healthz'])) {
        await _healthz(request);
        return;
      }
      if (request.method == 'POST' &&
          _match(segments, <String>['v1', 'adhoc', 'events', 'upload'])) {
        await _uploadEvent(request);
        return;
      }
      if (request.method == 'GET' &&
          segments.length == 5 &&
          segments[0] == 'v1' &&
          segments[1] == 'adhoc' &&
          segments[2] == 'events' &&
          segments[4] == 'status') {
        await _getUploadStatus(request, clientEventId: segments[3]);
        return;
      }
      if (request.method == 'GET' &&
          _match(segments, <String>['v1', 'adhoc', 'events'])) {
        await _listEvents(request);
        return;
      }

      _json(request, HttpStatus.notFound, <String, Object?>{
        'error': 'Not found',
        'base_url': baseUrl.toString(),
        'db_path': _database.dbPath,
        'uploads_root': _uploadsRootDir.path,
      });
    } catch (error, stack) {
      stderr.writeln('Adhoc upload backend error: $error\n$stack');
      _json(request, HttpStatus.internalServerError, <String, Object?>{
        'error': 'Internal server error',
      });
    }
  }

  Future<void> _healthz(HttpRequest request) async {
    _json(request, HttpStatus.ok, <String, Object?>{
      'status': 'ok',
      'service': 'adhoc_upload',
    });
  }

  Future<void> _uploadEvent(HttpRequest request) async {
    try {
      final multipart = await _readUploadMultipart(request);
      _validatePayloadFileCorrespondence(
        payload: multipart.payload,
        filesByPhotoId: multipart.filesByPhotoId,
      );
      _validateUploadFiles(
        payload: multipart.payload,
        filesByPhotoId: multipart.filesByPhotoId,
      );
      final payloadHash = _computePayloadHash(multipart.payload);
      final persisted = await _persistUpload(
        payload: multipart.payload,
        filesByPhotoId: multipart.filesByPhotoId,
        payloadHash: payloadHash,
      );
      _json(
        request,
        persisted.isIdempotentReplay ? HttpStatus.ok : HttpStatus.created,
        <String, Object?>{
        'server_event_id': persisted.serverEventId,
        'uploaded_photo_count': persisted.uploadedPhotoCount,
        'received_at_utc': persisted.receivedAtUtc.toIso8601String(),
        'idempotent_replay': persisted.isIdempotentReplay,
      },
      );
    } on _BadRequest catch (error) {
      _json(request, HttpStatus.badRequest, <String, Object?>{
        'error': 'Invalid upload request',
        'details': error.message,
      });
    } on _Conflict catch (error) {
      _json(request, HttpStatus.conflict, <String, Object?>{
        'error': 'Upload conflict',
        'details': error.message,
      });
    } on AdhocUploadPayloadValidationError catch (error) {
      _json(request, HttpStatus.badRequest, <String, Object?>{
        'error': 'Invalid payload',
        'path': error.path,
        'details': error.message,
      });
    } on FormatException catch (error) {
      _json(request, HttpStatus.badRequest, <String, Object?>{
        'error': 'Invalid JSON payload',
        'details': error.message,
      });
    } catch (error) {
      stderr.writeln('Upload persistence failed: $error');
      _json(request, HttpStatus.internalServerError, <String, Object?>{
        'error': 'Upload persistence failed',
      });
    }
  }

  Future<void> _getUploadStatus(
    HttpRequest request, {
    required String clientEventId,
  }) async {
    if (!_isValidId(clientEventId)) {
      _json(request, HttpStatus.badRequest, <String, Object?>{
        'error': 'Invalid client_event_id',
        'details': 'client_event_id format is invalid',
      });
      return;
    }

    final db = _database.open();
    try {
      final rows = db.select(
        '''
SELECT e.id, e.received_at_utc,
       COUNT(p.id) AS uploaded_photo_count
FROM upload_events e
LEFT JOIN upload_series s ON s.event_id = e.id
LEFT JOIN upload_photos p ON p.series_id = s.id
WHERE e.client_event_id = ?
GROUP BY e.id, e.received_at_utc
LIMIT 1
''',
        <Object?>[clientEventId],
      );
      if (rows.isEmpty) {
        _json(request, HttpStatus.ok, <String, Object?>{
          'exists': false,
          'server_event_id': null,
          'uploaded_photo_count': 0,
        });
        return;
      }
      final row = rows.first;
      _json(request, HttpStatus.ok, <String, Object?>{
        'exists': true,
        'server_event_id': row['id'] as String,
        'uploaded_photo_count': row['uploaded_photo_count'] as int,
        'received_at_utc': row['received_at_utc'] as String,
      });
    } finally {
      db.dispose();
    }
  }

  Future<void> _listEvents(HttpRequest request) async {
    final rawLimit = request.uri.queryParameters['limit'];
    final limit = rawLimit == null ? 50 : int.tryParse(rawLimit);
    if (limit == null || limit < 1 || limit > 500) {
      _json(request, HttpStatus.badRequest, <String, Object?>{
        'error': 'Invalid limit',
        'details': 'Query parameter "limit" must be an integer in range 1-500',
      });
      return;
    }

    final db = _database.open();
    try {
      final rows = db.select(
        '''
SELECT
  e.id,
  e.client_event_id,
  e.event_name,
  e.uploaded_at_utc,
  e.received_at_utc,
  COUNT(DISTINCT s.id) AS series_count,
  COUNT(p.id) AS uploaded_photo_count
FROM upload_events e
LEFT JOIN upload_series s ON s.event_id = e.id
LEFT JOIN upload_photos p ON p.series_id = s.id
GROUP BY e.id, e.client_event_id, e.event_name, e.uploaded_at_utc, e.received_at_utc
ORDER BY e.received_at_utc DESC
LIMIT ?
''',
        <Object?>[limit],
      );
      final events = rows
          .map(
            (row) => <String, Object?>{
              'server_event_id': row['id'] as String,
              'client_event_id': row['client_event_id'] as String,
              'event_name': row['event_name'] as String,
              'uploaded_at_utc': row['uploaded_at_utc'] as String,
              'received_at_utc': row['received_at_utc'] as String,
              'series_count': row['series_count'] as int,
              'uploaded_photo_count': row['uploaded_photo_count'] as int,
            },
          )
          .toList(growable: false);

      _json(request, HttpStatus.ok, <String, Object?>{
        'limit': limit,
        'count': events.length,
        'events': events,
      });
    } finally {
      db.dispose();
    }
  }

  bool _match(List<String> actual, List<String> expected) {
    if (actual.length != expected.length) {
      return false;
    }
    for (var i = 0; i < actual.length; i += 1) {
      if (actual[i] != expected[i]) {
        return false;
      }
    }
    return true;
  }

  Future<_UploadMultipartData> _readUploadMultipart(HttpRequest request) async {
    final requestContentLength = request.headers.contentLength;
    if (requestContentLength > _maxRequestBytes) {
      throw _BadRequest(
        'Request body exceeds maximum allowed size of $_maxRequestBytes bytes',
      );
    }

    final contentType = request.headers.contentType;
    if (contentType == null || contentType.mimeType != 'multipart/form-data') {
      throw _BadRequest('Content-Type must be multipart/form-data');
    }

    final boundary = contentType.parameters['boundary'];
    if (boundary == null || boundary.isEmpty) {
      throw _BadRequest('Multipart boundary is missing');
    }

    String? payloadJson;
    final filesByPhotoId = <String, _UploadedFilePart>{};
    final transformer = MimeMultipartTransformer(boundary);
    var totalBytesRead = 0;

    await for (final part in transformer.bind(request)) {
      final disposition = part.headers['content-disposition'];
      if (disposition == null || disposition.isEmpty) {
        throw _BadRequest('Each multipart part must include content-disposition');
      }
      final parsed = HeaderValue.parse(disposition, parameterSeparator: ';');
      if (parsed.value != 'form-data') {
        throw _BadRequest('Unsupported content-disposition: ${parsed.value}');
      }
      final fieldName = parsed.parameters['name'];
      if (fieldName == null || fieldName.isEmpty) {
        throw _BadRequest('Multipart form-data part is missing "name"');
      }

      if (fieldName == 'payload') {
        if (payloadJson != null) {
          throw _BadRequest('Multipart request must include only one payload part');
        }
        payloadJson = await utf8.decoder.bind(part).join();
        totalBytesRead += payloadJson.length;
        if (totalBytesRead > _maxRequestBytes) {
          throw _BadRequest(
            'Request body exceeds maximum allowed size of $_maxRequestBytes bytes',
          );
        }
        continue;
      }

      if (!fieldName.startsWith('file_')) {
        throw _BadRequest('Unknown multipart field "$fieldName"');
      }

      final photoId = fieldName.substring('file_'.length);
      if (photoId.isEmpty) {
        throw _BadRequest('File field name must be file_<photo_id>');
      }
      if (filesByPhotoId.containsKey(photoId)) {
        throw _BadRequest('Duplicate multipart file part for photo "$photoId"');
      }

      final filename = parsed.parameters['filename'] ?? '';
      final partContentType = _parseContentType(part.headers['content-type']);
      final bytes = await _readPartBytes(part);
      totalBytesRead += bytes.length;
      if (totalBytesRead > _maxRequestBytes) {
        throw _BadRequest(
          'Request body exceeds maximum allowed size of $_maxRequestBytes bytes',
        );
      }
      if (bytes.length > _maxFileBytes) {
        throw _BadRequest(
          'File for photo "$photoId" exceeds maximum allowed size of $_maxFileBytes bytes',
        );
      }
      filesByPhotoId[photoId] = _UploadedFilePart(
        fieldName: fieldName,
        fileName: filename,
        contentType: partContentType,
        bytes: bytes,
      );
    }

    if (payloadJson == null || payloadJson.trim().isEmpty) {
      throw _BadRequest('Missing payload JSON part');
    }

    final decoded = jsonDecode(payloadJson);
    final payload = AdhocUploadEventPayload.fromJson(decoded);
    return _UploadMultipartData(payload: payload, filesByPhotoId: filesByPhotoId);
  }

  void _validatePayloadFileCorrespondence({
    required AdhocUploadEventPayload payload,
    required Map<String, _UploadedFilePart> filesByPhotoId,
  }) {
    final photos = _allPhotos(payload);
    final expectedPhotoIds = <String>{};
    for (final photo in photos) {
      if (!expectedPhotoIds.add(photo.clientPhotoId)) {
        throw _BadRequest(
          'Duplicate client_photo_id in payload: ${photo.clientPhotoId}',
        );
      }
    }
    final receivedPhotoIds = filesByPhotoId.keys.toSet();

    final missingPhotoIds = expectedPhotoIds.difference(receivedPhotoIds);
    if (missingPhotoIds.isNotEmpty) {
      final missingList = missingPhotoIds.toList()..sort();
      throw _BadRequest(
        'Missing multipart file parts for photo IDs: ${missingList.join(', ')}',
      );
    }

    final extraPhotoIds = receivedPhotoIds.difference(expectedPhotoIds);
    if (extraPhotoIds.isNotEmpty) {
      final extraList = extraPhotoIds.toList()..sort();
      throw _BadRequest(
        'Received multipart file parts not present in payload: ${extraList.join(', ')}',
      );
    }
  }

  void _validateUploadFiles({
    required AdhocUploadEventPayload payload,
    required Map<String, _UploadedFilePart> filesByPhotoId,
  }) {
    final photoById = <String, AdhocUploadPhotoPayload>{
      for (final photo in _allPhotos(payload)) photo.clientPhotoId: photo,
    };
    for (final entry in filesByPhotoId.entries) {
      final photoId = entry.key;
      final file = entry.value;
      final photo = photoById[photoId];
      if (photo == null) {
        throw _BadRequest('Received file for unknown photo ID: $photoId');
      }
      final mimeType = file.contentType?.mimeType;
      if (mimeType == null || !_allowedMimeTypes.contains(mimeType)) {
        throw _BadRequest(
          'Unsupported content-type for photo "$photoId": ${mimeType ?? 'missing'}',
        );
      }
      if (file.bytes.length != photo.sizeBytes) {
        throw _BadRequest(
          'File size mismatch for photo "$photoId": payload=${photo.sizeBytes}, actual=${file.bytes.length}',
        );
      }
      final actualSha = sha256.convert(file.bytes).toString();
      if (actualSha != photo.sha256) {
        throw _BadRequest(
          'SHA-256 mismatch for photo "$photoId": payload=${photo.sha256}, actual=$actualSha',
        );
      }
      if (file.fileName.isNotEmpty && file.fileName != photo.fileName) {
        throw _BadRequest(
          'Filename mismatch for photo "$photoId": payload=${photo.fileName}, multipart=${file.fileName}',
        );
      }
    }
  }

  Future<_PersistedUpload> _persistUpload({
    required AdhocUploadEventPayload payload,
    required Map<String, _UploadedFilePart> filesByPhotoId,
    required String payloadHash,
  }) async {
    final existing = _lookupExistingUpload(
      clientEventId: payload.clientEventId,
      payloadHash: payloadHash,
    );
    if (existing != null) {
      return existing;
    }

    final receivedAtUtc = DateTime.now().toUtc();
    final serverEventId = _nextId('evt');
    final eventUploadDir = Directory(p.join(_uploadsRootDir.path, serverEventId));
    final storedPathByPhotoId = <String, String>{};

    await eventUploadDir.create(recursive: true);
    try {
      for (final photo in _allPhotos(payload)) {
        final filePart = filesByPhotoId[photo.clientPhotoId];
        if (filePart == null) {
          throw StateError('Missing multipart file for ${photo.clientPhotoId}');
        }
        final storedFileName =
            '${photo.clientPhotoId}_${_sanitizeFileName(photo.fileName)}';
        final storedPath = p.join(eventUploadDir.path, storedFileName);
        await File(storedPath).writeAsBytes(filePart.bytes, flush: true);
        storedPathByPhotoId[photo.clientPhotoId] = storedPath;
      }

      final db = _database.open();
      try {
        db.execute('BEGIN TRANSACTION');
        try {
          db.execute(
            '''
INSERT INTO upload_events (
  id,
  client_event_id,
  payload_sha256,
  event_name,
  event_created_at_utc,
  event_updated_at_utc,
  uploaded_at_utc,
  received_at_utc
) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
''',
            <Object?>[
              serverEventId,
              payload.clientEventId,
              payloadHash,
              payload.eventName,
              payload.eventCreatedAtUtc.toIso8601String(),
              payload.eventUpdatedAtUtc.toIso8601String(),
              payload.uploadedAtUtc.toIso8601String(),
              receivedAtUtc.toIso8601String(),
            ],
          );

          for (final series in payload.series) {
            final serverSeriesId = _nextId('ser');
            db.execute(
              '''
INSERT INTO upload_series (
  id,
  event_id,
  client_series_id,
  title,
  started_at_utc,
  ended_at_utc,
  anchor_latitude,
  anchor_longitude,
  max_radius_meters,
  location_incomplete
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
              <Object?>[
                serverSeriesId,
                serverEventId,
                series.clientSeriesId,
                series.title,
                series.startedAtUtc.toIso8601String(),
                series.endedAtUtc?.toIso8601String(),
                series.anchorLatitude,
                series.anchorLongitude,
                series.maxRadiusMeters,
                series.locationIncomplete ? 1 : 0,
              ],
            );

            for (final photo in series.photos) {
              final serverPhotoId = _nextId('pho');
              final storedPath = storedPathByPhotoId[photo.clientPhotoId];
              if (storedPath == null) {
                throw StateError(
                  'No stored file path for photo ${photo.clientPhotoId}',
                );
              }
              db.execute(
                '''
INSERT INTO upload_photos (
  id,
  series_id,
  client_photo_id,
  captured_at_utc,
  created_at_utc,
  effective_latitude,
  effective_longitude,
  metadata_latitude,
  metadata_longitude,
  fallback_latitude,
  fallback_longitude,
  exif_extracted,
  location_warning,
  file_name,
  stored_path,
  sha256,
  size_bytes
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
                <Object?>[
                  serverPhotoId,
                  serverSeriesId,
                  photo.clientPhotoId,
                  photo.capturedAtUtc?.toIso8601String(),
                  photo.createdAtUtc.toIso8601String(),
                  photo.effectiveLatitude,
                  photo.effectiveLongitude,
                  photo.metadataLatitude,
                  photo.metadataLongitude,
                  photo.fallbackLatitude,
                  photo.fallbackLongitude,
                  photo.exifExtracted ? 1 : 0,
                  photo.locationWarning ? 1 : 0,
                  photo.fileName,
                  storedPath,
                  photo.sha256,
                  photo.sizeBytes,
                ],
              );
            }
          }
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      } finally {
        db.dispose();
      }
    } catch (_) {
      await _deleteDirectoryIfExists(eventUploadDir);
      rethrow;
    }

    return _PersistedUpload(
      serverEventId: serverEventId,
      uploadedPhotoCount: storedPathByPhotoId.length,
      receivedAtUtc: receivedAtUtc,
      isIdempotentReplay: false,
    );
  }

  _PersistedUpload? _lookupExistingUpload({
    required String clientEventId,
    required String payloadHash,
  }) {
    final db = _database.open();
    try {
      final rows = db.select(
        '''
SELECT id, payload_sha256, received_at_utc
FROM upload_events
WHERE client_event_id = ?
LIMIT 1
''',
        <Object?>[clientEventId],
      );
      if (rows.isEmpty) {
        return null;
      }
      final row = rows.first;
      final serverEventId = row['id'] as String;
      final existingPayloadHash = row['payload_sha256'] as String;
      if (existingPayloadHash != payloadHash) {
        throw _Conflict(
          'client_event_id "$clientEventId" already exists with different payload',
        );
      }
      final photoCountRow = db.select(
        '''
SELECT COUNT(*) AS photo_count
FROM upload_photos p
INNER JOIN upload_series s ON s.id = p.series_id
WHERE s.event_id = ?
''',
        <Object?>[serverEventId],
      );
      final uploadedPhotoCount = photoCountRow.first['photo_count'] as int;
      final receivedRaw = row['received_at_utc'] as String;
      final receivedAtUtc = DateTime.tryParse(receivedRaw)?.toUtc();
      if (receivedAtUtc == null) {
        throw StateError('Invalid received_at_utc for existing event');
      }
      return _PersistedUpload(
        serverEventId: serverEventId,
        uploadedPhotoCount: uploadedPhotoCount,
        receivedAtUtc: receivedAtUtc,
        isIdempotentReplay: true,
      );
    } finally {
      db.dispose();
    }
  }

  String _computePayloadHash(AdhocUploadEventPayload payload) {
    final canonical = <String, Object?>{
      'client_event_id': payload.clientEventId,
      'event_name': payload.eventName,
      'event_created_at_utc': payload.eventCreatedAtUtc.toIso8601String(),
      'event_updated_at_utc': payload.eventUpdatedAtUtc.toIso8601String(),
      'uploaded_at_utc': payload.uploadedAtUtc.toIso8601String(),
      'series': payload.series
          .map(
            (series) => <String, Object?>{
              'client_series_id': series.clientSeriesId,
              'title': series.title,
              'started_at_utc': series.startedAtUtc.toIso8601String(),
              'ended_at_utc': series.endedAtUtc?.toIso8601String(),
              'anchor_latitude': series.anchorLatitude,
              'anchor_longitude': series.anchorLongitude,
              'max_radius_meters': series.maxRadiusMeters,
              'location_incomplete': series.locationIncomplete,
              'photos': series.photos
                  .map(
                    (photo) => <String, Object?>{
                      'client_photo_id': photo.clientPhotoId,
                      'captured_at_utc': photo.capturedAtUtc?.toIso8601String(),
                      'created_at_utc': photo.createdAtUtc.toIso8601String(),
                      'effective_latitude': photo.effectiveLatitude,
                      'effective_longitude': photo.effectiveLongitude,
                      'metadata_latitude': photo.metadataLatitude,
                      'metadata_longitude': photo.metadataLongitude,
                      'fallback_latitude': photo.fallbackLatitude,
                      'fallback_longitude': photo.fallbackLongitude,
                      'exif_extracted': photo.exifExtracted,
                      'location_warning': photo.locationWarning,
                      'file_name': photo.fileName,
                      'sha256': photo.sha256,
                      'size_bytes': photo.sizeBytes,
                    },
                  )
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
    };
    final bytes = utf8.encode(jsonEncode(canonical));
    return sha256.convert(bytes).toString();
  }

  List<AdhocUploadPhotoPayload> _allPhotos(AdhocUploadEventPayload payload) {
    return payload.series
        .expand((series) => series.photos)
        .toList(growable: false);
  }

  ContentType? _parseContentType(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return ContentType.parse(raw);
  }

  Future<Uint8List> _readPartBytes(Stream<List<int>> part) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in part) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<void> _deleteDirectoryIfExists(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  String _sanitizeFileName(String input) {
    final base = p.basename(input.trim());
    if (base.isEmpty) {
      return 'photo.bin';
    }
    final sanitized = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (sanitized.isEmpty) {
      return 'photo.bin';
    }
    if (sanitized.length > 120) {
      return sanitized.substring(sanitized.length - 120);
    }
    return sanitized;
  }

  String _nextId(String prefix) {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final randomBits = _random.nextInt(1 << 30);
    return '$prefix-$millis-$randomBits';
  }

  bool _isValidId(String value) {
    return RegExp(r'^[A-Za-z0-9._:-]{3,128}$').hasMatch(value);
  }

  void _json(HttpRequest request, int status, Map<String, Object?> body) {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    request.response.close();
  }
}

class _BadRequest implements Exception {
  _BadRequest(this.message);

  final String message;
}

class _Conflict implements Exception {
  _Conflict(this.message);

  final String message;
}

class _UploadMultipartData {
  _UploadMultipartData({
    required this.payload,
    required this.filesByPhotoId,
  });

  final AdhocUploadEventPayload payload;
  final Map<String, _UploadedFilePart> filesByPhotoId;
}

class _UploadedFilePart {
  _UploadedFilePart({
    required this.fieldName,
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });

  final String fieldName;
  final String fileName;
  final ContentType? contentType;
  final Uint8List bytes;
}

class _PersistedUpload {
  _PersistedUpload({
    required this.serverEventId,
    required this.uploadedPhotoCount,
    required this.receivedAtUtc,
    required this.isIdempotentReplay,
  });

  final String serverEventId;
  final int uploadedPhotoCount;
  final DateTime receivedAtUtc;
  final bool isIdempotentReplay;
}
