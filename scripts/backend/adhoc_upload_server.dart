import 'dart:io';

import 'package:path/path.dart' as p;

import 'adhoc_upload_db.dart';
import 'adhoc_upload_service.dart';

Future<void> main() async {
  final config = _ServerConfig.fromEnvironment();
  final host = InternetAddress.loopbackIPv4;
  final backendRootDir = _resolveBackendRootFromScript();
  final uploadsRootDir = Directory(p.join(backendRootDir.path, 'uploads'));

  final database = AdhocUploadDb(backendRootDir: backendRootDir);
  await database.ensureInitialized();
  await uploadsRootDir.create(recursive: true);

  final service = AdhocUploadService(
    database: database,
    uploadsRootDir: uploadsRootDir,
  );

  final server = await HttpServer.bind(host, config.port);
  stdout.writeln('Adhoc upload backend listening on http://${host.address}:${config.port}');
  stdout.writeln('Backend root: ${backendRootDir.path}');
  stdout.writeln('Database path: ${database.dbPath}');
  stdout.writeln('Uploads root: ${uploadsRootDir.path}');

  await for (final request in server) {
    await service.handle(
      request,
      baseUrl: Uri.parse('http://${host.address}:${config.port}'),
    );
  }
}

class _ServerConfig {
  _ServerConfig({required this.port});

  final int port;

  factory _ServerConfig.fromEnvironment() {
    final rawPort = Platform.environment['ADHOC_UPLOAD_BACKEND_PORT'];
    if (rawPort == null || rawPort.trim().isEmpty) {
      return _ServerConfig(port: 8090);
    }
    final parsed = int.tryParse(rawPort);
    if (parsed == null || parsed < 1 || parsed > 65535) {
      throw ArgumentError.value(
        rawPort,
        'ADHOC_UPLOAD_BACKEND_PORT',
        'Must be an integer in range 1-65535',
      );
    }
    return _ServerConfig(port: parsed);
  }
}

Directory _resolveBackendRootFromScript() {
  final scriptDir = Directory.fromUri(Platform.script).parent.path;
  return Directory(
    p.normalize(p.join(scriptDir, '..', '..', 'build', 'local_backend')),
  );
}
