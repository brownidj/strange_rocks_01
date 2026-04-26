import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'field_pack_backend_models.dart';
import 'field_pack_backend_geojson.dart';
import 'field_pack_backend_synthetic_pack.dart';

Future<void> main() async {
  final host = InternetAddress.loopbackIPv4;
  final port = int.tryParse(Platform.environment['FIELD_PACK_BACKEND_PORT'] ?? '') ?? 8080;
  final sourcePackRoot =
      Platform.environment['FIELD_PACK_SOURCE_ROOT'] ??
      _defaultSourcePackRootFromScript();
  final service = _FieldPackBackendService(sourcePackRoot: sourcePackRoot);
  final server = await HttpServer.bind(host, port);
  stdout.writeln('Field-pack backend listening on http://${host.address}:$port');
  stdout.writeln('Source pack root: $sourcePackRoot');
  await for (final request in server) {
    await service.handle(request, baseUrl: Uri.parse('http://${host.address}:$port'));
  }
}

String _defaultSourcePackRootFromScript() {
  final scriptDir = Directory.fromUri(Platform.script).parent.path;
  final candidates = <String>[
    p.normalize(p.join(scriptDir, '..', '..', 'build', 'jcu_qsat', 'field_pack')),
    p.normalize(p.join(scriptDir, '..', '..', 'build', 'jcu_qsat', 'field_pack_t3')),
    p.normalize(p.join(scriptDir, '..', '..', 'build', 'jcu_qsat', 'field_pack_t4')),
  ];
  for (final candidate in candidates) {
    if (Directory(candidate).existsSync()) {
      return candidate;
    }
  }
  return candidates.first;
}

class _FieldPackBackendService {
  _FieldPackBackendService({required this.sourcePackRoot});

  final String sourcePackRoot;
  final Map<String, BuildJob> _jobs = <String, BuildJob>{};
  final Map<String, PublishedPack> _packs = <String, PublishedPack>{};
  final Random _random = Random.secure();
  final _syntheticFactory = const FieldPackBackendSyntheticPackFactory();

  Future<void> handle(HttpRequest request, {required Uri baseUrl}) async {
    try {
      final segments = request.uri.pathSegments;
      if (request.method == 'POST' && _match(segments, <String>['v1', 'field-pack-build-jobs'])) {
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
      _json(request, HttpStatus.notFound, <String, Object?>{'error': 'Not found'});
    } catch (error, stack) {
      stderr.writeln('Unhandled backend error: $error\n$stack');
      _json(
        request,
        HttpStatus.internalServerError,
        <String, Object?>{'error': 'Internal error', 'details': error.toString()},
      );
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
      final pack = await _publishPack(payload);
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

  Future<PublishedPack> _publishPack(Map<String, Object?> payload) async {
    final root = Directory(sourcePackRoot);
    if (!root.existsSync()) {
      return _syntheticFactory.build(
        packId: _nextId('pack'),
        payload: payload,
        isoUtc: _iso,
      );
    }
    final packId = _nextId('pack');
    final zipBytes = await _zipDirectory(root);
    final manifest = await _buildManifest(
      packId: packId,
      sourceRoot: root,
      payload: payload,
    );
    return PublishedPack(packId: packId, manifest: manifest, zipBytes: zipBytes);
  }

  Future<Map<String, Object?>> _buildManifest({
    required String packId,
    required Directory sourceRoot,
    required Map<String, Object?> payload,
  }) async {
    final now = DateTime.now().toUtc();
    final assets = <Map<String, Object?>>[];
    for (final path in <String>['basemap.mbtiles', 'topography.mbtiles', 'geology.gpkg', 'gazetteer.sqlite']) {
      final file = File(p.join(sourceRoot.path, path));
      if (!file.existsSync()) continue;
      final bytes = await file.readAsBytes();
      assets.add(<String, Object?>{
        'path': path,
        'kind': path.endsWith('.mbtiles') ? 'tiles' : (path.endsWith('.gpkg') ? 'geology' : 'gazetteer'),
        'size_bytes': bytes.length,
        'sha256': sha256.convert(bytes).toString(),
      });
    }
    if (assets.isEmpty) throw StateError('No manifest assets found in ${sourceRoot.path}');

    final fieldArea = (payload['field_area'] as Map<String, Object?>?) ?? const <String, Object?>{};
    final geojson = (fieldArea['geojson'] as Map<String, Object?>?) ?? const <String, Object?>{};
    final bbox = extractBboxFromGeoJson(geojson) ??
        <double>[146.7406, -19.3379, 146.7798, -19.3078];
    final metadata = (payload['metadata'] as Map<String, Object?>?) ?? const <String, Object?>{};
    final requestName = payload['name'] as String?;
    final areaName = fieldArea['name'] as String?;
    final displayName = areaName?.trim().isNotEmpty == true
        ? areaName
        : (requestName?.trim().isNotEmpty == true ? requestName : null);
    final provider = (metadata['provider'] as String?) ?? 'Queensland Government QSat Mosaic';
    final license = (metadata['license'] as String?) ?? 'CC BY-SA (verify current terms)';
    final attribution = (metadata['attribution'] as String?) ??
        'Contains Queensland Government data. Refer to source licence terms.';

    return <String, Object?>{
      'pack_id': packId,
      'name': displayName,
      'version': '1.0.0',
      'created_at_utc': _iso(now),
      'crs': 'EPSG:4326',
      'area': <String, Object?>{
        'bbox': <Object>[bbox[0], bbox[1], bbox[2], bbox[3]],
        'area_size_m2': max(1, ((bbox[2] - bbox[0]).abs() * (bbox[3] - bbox[1]).abs() * 12321000000).round()),
      },
      'assets': assets,
      'data_sources': <Object>[
        <String, Object?>{
          'provider': provider,
          'acquired_at_utc': _iso(now),
          'license': license,
          'attribution': attribution,
        }
      ],
      'requires_app_version': '1.0.0',
    };
  }

  Future<void> _getJob(HttpRequest request, String jobId, {required Uri baseUrl}) async {
    final job = _jobs[jobId];
    if (job == null) {
      _json(request, HttpStatus.notFound, <String, Object?>{'error': 'Unknown job_id'});
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
        'manifest_url': baseUrl.resolve('/field-packs/${pack.packId}/manifest').toString(),
        'download_url': baseUrl.resolve('/field-packs/${pack.packId}/download').toString(),
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
    if (pack == null) return _json(request, HttpStatus.notFound, <String, Object?>{'error': 'Unknown pack_id'});
    _json(request, HttpStatus.ok, pack.manifest);
  }

  Future<void> _downloadPack(HttpRequest request, String packId) async {
    final pack = _packs[packId];
    if (pack == null) return _json(request, HttpStatus.notFound, <String, Object?>{'error': 'Unknown pack_id'});
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType('application', 'zip');
    request.response.headers.set('content-disposition', 'attachment; filename="$packId.zip"');
    request.response.add(pack.zipBytes);
    await request.response.close();
  }

  Future<Uint8List> _zipDirectory(Directory dir) async {
    final archive = Archive();
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: dir.path).replaceAll('\\', '/');
      final bytes = await entity.readAsBytes();
      archive.add(ArchiveFile(relative, bytes.length, bytes));
    }
    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  Future<Map<String, Object?>> _readJson(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.trim().isEmpty) return <String, Object?>{};
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) throw const FormatException('Body must be a JSON object');
    return decoded;
  }

  bool _match(List<String> actual, List<String> expected) =>
      actual.length == expected.length && List<int>.generate(actual.length, (i) => i).every((i) => actual[i] == expected[i]);

  void _json(HttpRequest request, int status, Map<String, Object?> body) {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    request.response.close();
  }

  String _nextId(String prefix) =>
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1 << 20)}';

  String _iso(DateTime dt) => dt.toUtc().toIso8601String();
}
