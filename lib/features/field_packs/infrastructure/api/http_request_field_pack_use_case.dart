import 'dart:convert';
import 'dart:io';

import 'package:strange_rocks_01/features/field_packs/domain/entities/field_area.dart';
import 'package:strange_rocks_01/features/field_packs/domain/use_cases/request_field_pack_use_case.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/errors/field_pack_pipeline_error.dart';

class HttpRequestFieldPackUseCase implements RequestFieldPackUseCase {
  HttpRequestFieldPackUseCase({
    required this.baseUri,
    HttpClient? httpClient,
    this.maxPollAttempts = 30,
    this.pollInterval = const Duration(seconds: 1),
  }) : _httpClient = httpClient ?? HttpClient();

  final Uri baseUri;
  final HttpClient _httpClient;
  final int maxPollAttempts;
  final Duration pollInterval;

  @override
  Future<String> call(FieldArea area) async {
    final requestBody = <String, Object?>{
      'name': '${area.name} QSat',
      'field_area': <String, Object?>{
        'name': area.name,
        'geojson': area.geoJson,
      },
      'tile_build': <String, Object?>{
        'source_preset': 'qld_qsat_wos_latestsatellite_allusers',
        'min_zoom': 10,
        'max_zoom': 17,
        'max_area_km2': 50,
        'max_size_mb': 500,
        'max_tiles': 6000,
      },
      'metadata': <String, Object?>{
        'provider': 'Queensland Government QSat Mosaic',
        'license': 'CC BY-SA (verify current terms)',
        'attribution':
            'Contains Queensland Government data. Refer to source licence terms.',
      },
    };

    final jobId = await _createJob(requestBody);
    return _pollForPackId(jobId);
  }

  Future<String> _createJob(Map<String, Object?> body) async {
    final uri = baseUri.resolve('/v1/field-pack-build-jobs');
    try {
      final request = await _httpClient.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close();
      final payload = await _readJsonMap(response);
      if (response.statusCode != HttpStatus.accepted) {
        throw FieldPackNetworkError(
          'Build job request failed with status ${response.statusCode}',
          cause: payload,
        );
      }
      final jobId = payload['job_id'];
      if (jobId is! String || jobId.trim().isEmpty) {
        throw const FieldPackSchemaMismatchError(
          'Build job response missing job_id',
        );
      }
      return jobId;
    } on FieldPackPipelineError {
      rethrow;
    } on SocketException catch (error) {
      throw FieldPackNetworkError(
        'Unable to connect to backend for build job request',
        cause: error,
      );
    } catch (error) {
      throw FieldPackUnexpectedError(
        'Unexpected error while requesting field pack build job',
        cause: error,
      );
    }
  }

  Future<String> _pollForPackId(String jobId) async {
    final uri = baseUri.resolve('/v1/field-pack-build-jobs/$jobId');
    for (var attempt = 0; attempt < maxPollAttempts; attempt++) {
      try {
        final request = await _httpClient.getUrl(uri);
        final response = await request.close();
        final payload = await _readJsonMap(response);
        if (response.statusCode != HttpStatus.ok) {
          throw FieldPackNetworkError(
            'Build job status failed with status ${response.statusCode}',
            cause: payload,
          );
        }

        final status = payload['status'] as String?;
        if (status == 'succeeded') {
          final artifact = payload['artifact'];
          if (artifact is! Map<String, Object?>) {
            throw const FieldPackSchemaMismatchError(
              'Build job succeeded but artifact object missing',
            );
          }
          final packId = artifact['pack_id'];
          if (packId is! String || packId.trim().isEmpty) {
            throw const FieldPackSchemaMismatchError(
              'Build job artifact missing pack_id',
            );
          }
          return packId;
        }

        if (status == 'failed') {
          final error = payload['error'];
          throw FieldPackNetworkError(
            'Backend build job failed',
            cause: error ?? payload,
          );
        }
      } on FieldPackPipelineError {
        rethrow;
      } on SocketException catch (error) {
        throw FieldPackNetworkError(
          'Unable to poll backend build job status',
          cause: error,
        );
      } catch (error) {
        throw FieldPackUnexpectedError(
          'Unexpected error while polling build job status',
          cause: error,
        );
      }

      await Future<void>.delayed(pollInterval);
    }
    throw FieldPackNetworkError(
      'Build job timed out after $maxPollAttempts attempts',
    );
  }

  Future<Map<String, Object?>> _readJsonMap(HttpClientResponse response) async {
    final text = await utf8.decoder.bind(response).join();
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) {
      throw const FieldPackSchemaMismatchError(
        'Backend response must be a JSON object',
      );
    }
    return decoded;
  }

  void close() {
    _httpClient.close(force: true);
  }
}
