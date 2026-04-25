import 'dart:io';

import 'package:strange_rocks_01/features/field_packs/infrastructure/errors/field_pack_pipeline_error.dart';

class ResumableDownloadService {
  ResumableDownloadService({
    HttpClient? httpClient,
    this.maxRetries = 3,
    this.initialBackoff = const Duration(milliseconds: 400),
  }) : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;
  final int maxRetries;
  final Duration initialBackoff;

  Future<void> download(Uri uri, String destinationPath) async {
    final destinationFile = File(destinationPath);
    if (!await destinationFile.exists()) {
      await destinationFile.create(recursive: true);
    }

    var attempt = 0;
    while (true) {
      try {
        await _downloadAttempt(uri, destinationFile);
        return;
      } on SocketException catch (error) {
        if (attempt >= maxRetries - 1) {
          throw FieldPackNetworkError(
            'Download failed after retries',
            cause: error,
          );
        }
      } on HttpException catch (error) {
        if (attempt >= maxRetries - 1) {
          throw FieldPackNetworkError(
            'Download failed with HTTP error',
            cause: error,
          );
        }
      } on IOException catch (error) {
        throw FieldPackStorageError(
          'Failed to write download to local storage',
          cause: error,
        );
      }

      attempt += 1;
      await Future<void>.delayed(initialBackoff * attempt);
    }
  }

  Future<void> _downloadAttempt(Uri uri, File destinationFile) async {
    final bytesAlreadyWritten = await destinationFile.length();
    final request = await _httpClient.getUrl(uri);
    if (bytesAlreadyWritten > 0) {
      request.headers.add(
        HttpHeaders.rangeHeader,
        'bytes=$bytesAlreadyWritten-',
      );
    }

    final response = await request.close();
    final status = response.statusCode;
    final supportsResume = status == HttpStatus.partialContent;

    if (status != HttpStatus.ok && status != HttpStatus.partialContent) {
      throw HttpException('Unexpected status $status for $uri');
    }

    final ioMode = supportsResume ? FileMode.writeOnlyAppend : FileMode.write;
    final sink = destinationFile.openWrite(mode: ioMode);
    try {
      await response.pipe(sink);
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  void close() {
    _httpClient.close(force: true);
  }
}
