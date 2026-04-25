import 'dart:io';
import 'dart:convert';

import 'package:strange_rocks_01/features/field_packs/infrastructure/api/field_pack_api_client.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/download/resumable_download_service.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/errors/field_pack_pipeline_error.dart';

class HttpFieldPackApiClient implements FieldPackApiClient {
  HttpFieldPackApiClient({
    required this.baseUri,
    required this.downloadService,
  });

  final Uri baseUri;
  final ResumableDownloadService downloadService;

  @override
  Future<Map<String, Object?>> fetchManifest(String packId) async {
    final uri = baseUri.resolve('/field-packs/$packId/manifest');
    final tempDirectory = await Directory.systemTemp.createTemp(
      'field-pack-manifest',
    );
    final tempFile = File('${tempDirectory.path}/$packId-manifest.json');
    try {
      await downloadService.download(uri, tempFile.path);
      final jsonString = await tempFile.readAsString();
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, Object?>) {
        throw const FieldPackSchemaMismatchError(
          'Manifest response must be a JSON object',
        );
      }
      return decoded;
    } on FieldPackPipelineError {
      rethrow;
    } on FormatException catch (error) {
      throw FieldPackSchemaMismatchError(
        'Manifest is not valid JSON',
        cause: error,
      );
    } catch (error) {
      throw FieldPackNetworkError('Failed to fetch manifest', cause: error);
    } finally {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  }

  @override
  Future<void> downloadPackArchive(
    String packId,
    String destinationPath,
  ) async {
    final uri = baseUri.resolve('/field-packs/$packId/download');
    await downloadService.download(uri, destinationPath);
  }
}
