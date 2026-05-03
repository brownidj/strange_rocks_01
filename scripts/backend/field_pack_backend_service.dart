import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'field_pack_backend_models.dart';
import 'field_pack_backend_pack_builder.dart';

class FieldPackBackendService {
  FieldPackBackendService({
    required String sourcePackRootDefault,
    required String sourcePackRootQsat,
    required String sourcePackRootQimagery,
    required String sourcePackRootTopography,
  }) : _packBuilder = FieldPackBackendPackBuilder(
         sourcePackRootDefault: sourcePackRootDefault,
         sourcePackRootQsat: sourcePackRootQsat,
         sourcePackRootQimagery: sourcePackRootQimagery,
         sourcePackRootTopography: sourcePackRootTopography,
       );

  final FieldPackBackendPackBuilder _packBuilder;
  final Map<String, BuildJob> _jobs = <String, BuildJob>{};
  final Map<String, PublishedPack> _packs = <String, PublishedPack>{};
  final Random _random = Random.secure();

  Future<void> handle(HttpRequest request, {required Uri baseUrl}) async {
    try {
      final segments = request.uri.pathSegments;
      if (request.method == 'POST' &&
          _match(segments, <String>['v1', 'field-pack-build-jobs'])) {
        await _createJob(request);
        return;
      }
      if (request.method == 'GET' &&
          segments.length == 3 &&
          segments[0] == 'v1' &&
          segments[1] == 'field-pack-build-jobs') {
        await _getJob(request, segments[2], baseUrl: baseUrl);
        return;
      }
      if (request.method == 'GET' &&
          segments.length == 3 &&
          segments[0] == 'field-packs' &&
          segments[2] == 'manifest') {
        await _getManifest(request, segments[1]);
        return;
      }
      if (request.method == 'GET' &&
          segments.length == 3 &&
          segments[0] == 'field-packs' &&
          segments[2] == 'download') {
        await _downloadPack(request, segments[1]);
        return;
      }
      _json(request, HttpStatus.notFound, <String, Object?>{
        'error': 'Not found',
      });
    } catch (error, stack) {
      stderr.writeln('Unhandled backend error: $error\n$stack');
      _json(request, HttpStatus.internalServerError, <String, Object?>{
        'error': 'Internal error',
        'details': error.toString(),
      });
    }
  }

  Future<void> _createJob(HttpRequest request) async {
    final payload = await _readJson(request);
    final now = DateTime.now().toUtc();
    final jobId = _nextId('fpbj');
    final job = BuildJob(
      jobId: jobId,
      status: 'queued',
      stage: 'queued',
      createdAtUtc: now,
      updatedAtUtc: now,
    );
    _jobs[jobId] = job;
    unawaited(_runBuildJob(jobId, payload));
    _json(request, HttpStatus.accepted, <String, Object?>{
      'job_id': jobId,
      'status': 'queued',
      'created_at_utc': _iso(now),
    });
  }

  Future<void> _runBuildJob(String jobId, Map<String, Object?> payload) async {
    final job = _jobs[jobId];
    if (job == null) {
      return;
    }
    try {
      job
        ..status = 'running'
        ..stage = 'build_field_pack'
        ..updatedAtUtc = DateTime.now().toUtc();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final pack = await _packBuilder.publishPack(
        packId: _nextId('pack'),
        payload: payload,
        isoUtc: _iso,
      );
      _packs[pack.packId] = pack;
      job
        ..status = 'succeeded'
        ..stage = 'complete'
        ..packId = pack.packId
        ..updatedAtUtc = DateTime.now().toUtc();
    } catch (error) {
      job
        ..status = 'failed'
        ..stage = 'failed'
        ..errorCode = 'INTERNAL_ERROR'
        ..errorMessage = error.toString()
        ..updatedAtUtc = DateTime.now().toUtc();
    }
  }

  Future<void> _getJob(
    HttpRequest request,
    String jobId, {
    required Uri baseUrl,
  }) async {
    final job = _jobs[jobId];
    if (job == null) {
      _json(request, HttpStatus.notFound, <String, Object?>{
        'error': 'Unknown job_id',
      });
      return;
    }
    final body = <String, Object?>{
      'job_id': job.jobId,
      'status': job.status,
      'stage': job.stage,
      'created_at_utc': _iso(job.createdAtUtc),
      'updated_at_utc': _iso(job.updatedAtUtc),
    };
    if (job.status == 'succeeded' && job.packId != null) {
      final pack = _packs[job.packId!]!;
      body['artifact'] = <String, Object?>{
        'pack_id': pack.packId,
        'manifest_url': baseUrl
            .resolve('/field-packs/${pack.packId}/manifest')
            .toString(),
        'download_url': baseUrl
            .resolve('/field-packs/${pack.packId}/download')
            .toString(),
        'size_bytes': pack.zipBytes.length,
        'sha256': sha256.convert(pack.zipBytes).toString(),
      };
    }
    if (job.status == 'failed') {
      body['error'] = <String, Object?>{
        'code': job.errorCode ?? 'INTERNAL_ERROR',
        'message': job.errorMessage ?? 'Build failed',
      };
    }
    _json(request, HttpStatus.ok, body);
  }

  Future<void> _getManifest(HttpRequest request, String packId) async {
    final pack = _packs[packId];
    if (pack == null) {
      _json(request, HttpStatus.notFound, <String, Object?>{
        'error': 'Unknown pack_id',
      });
      return;
    }
    _json(request, HttpStatus.ok, pack.manifest);
  }

  Future<void> _downloadPack(HttpRequest request, String packId) async {
    final pack = _packs[packId];
    if (pack == null) {
      _json(request, HttpStatus.notFound, <String, Object?>{
        'error': 'Unknown pack_id',
      });
      return;
    }
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType('application', 'zip');
    request.response.headers.set(
      'content-disposition',
      'attachment; filename="$packId.zip"',
    );
    request.response.add(pack.zipBytes);
    await request.response.close();
  }

  Future<Map<String, Object?>> _readJson(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.trim().isEmpty) {
      return <String, Object?>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Body must be a JSON object');
    }
    return decoded;
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

  void _json(HttpRequest request, int status, Map<String, Object?> body) {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    request.response.close();
  }

  String _nextId(String prefix) {
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1 << 20)}';
  }

  String _iso(DateTime dt) => dt.toUtc().toIso8601String();
}
