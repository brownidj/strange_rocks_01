import 'dart:io';

import 'package:path/path.dart' as p;

import 'field_pack_backend_service.dart';

Future<void> main() async {
  final host = InternetAddress.loopbackIPv4;
  final port =
      int.tryParse(Platform.environment['FIELD_PACK_BACKEND_PORT'] ?? '') ??
      8080;
  final sourceRoots = _defaultSourcePackRootsFromScript();
  final sourcePackRootDefault =
      Platform.environment['FIELD_PACK_SOURCE_ROOT'] ?? sourceRoots.defaultRoot;
  final sourcePackRootQsat =
      Platform.environment['FIELD_PACK_SOURCE_ROOT_QSAT'] ??
      sourceRoots.qsatRoot;
  final sourcePackRootQimagery =
      Platform.environment['FIELD_PACK_SOURCE_ROOT_QIMAGERY'] ??
      sourceRoots.qimageryRoot;
  final sourcePackRootTopography =
      Platform.environment['FIELD_PACK_SOURCE_ROOT_TOPO'] ??
      sourceRoots.topographyRoot;

  final service = FieldPackBackendService(
    sourcePackRootDefault: sourcePackRootDefault,
    sourcePackRootQsat: sourcePackRootQsat,
    sourcePackRootQimagery: sourcePackRootQimagery,
    sourcePackRootTopography: sourcePackRootTopography,
  );

  final server = await HttpServer.bind(host, port);
  stdout.writeln(
    'Field-pack backend listening on http://${host.address}:$port',
  );
  stdout.writeln('Source pack roots:');
  stdout.writeln('  default: $sourcePackRootDefault');
  stdout.writeln('  qsat:    $sourcePackRootQsat');
  stdout.writeln('  qimagery:$sourcePackRootQimagery');
  stdout.writeln('  topo:    $sourcePackRootTopography');

  await for (final request in server) {
    await service.handle(
      request,
      baseUrl: Uri.parse('http://${host.address}:$port'),
    );
  }
}

({
  String defaultRoot,
  String qsatRoot,
  String qimageryRoot,
  String topographyRoot,
})
_defaultSourcePackRootsFromScript() {
  final scriptDir = Directory.fromUri(Platform.script).parent.path;
  final qsatCandidates = <String>[
    p.normalize(
      p.join(scriptDir, '..', '..', 'build', 'jcu_qsat', 'field_pack'),
    ),
    p.normalize(
      p.join(scriptDir, '..', '..', 'build', 'jcu_qsat', 'field_pack_t3'),
    ),
    p.normalize(
      p.join(scriptDir, '..', '..', 'build', 'jcu_qsat', 'field_pack_t4'),
    ),
  ];
  final qimageryCandidates = <String>[
    p.normalize(
      p.join(scriptDir, '..', '..', 'build', 'jcu_qimagery', 'field_pack'),
    ),
    p.normalize(
      p.join(scriptDir, '..', '..', 'build', 'jcu_qimagery', 'field_pack_t3'),
    ),
    p.normalize(
      p.join(scriptDir, '..', '..', 'build', 'qimagery', 'field_pack'),
    ),
  ];
  final topoCandidates = <String>[
    p.normalize(
      p.join(scriptDir, '..', '..', 'build', 'jcu_topography', 'field_pack'),
    ),
    p.normalize(
      p.join(scriptDir, '..', '..', 'build', 'jcu_qtopo', 'field_pack'),
    ),
    p.normalize(
      p.join(scriptDir, '..', '..', 'build', 'topography', 'field_pack'),
    ),
  ];

  String pick(List<String> candidates) {
    for (final candidate in candidates) {
      if (Directory(candidate).existsSync()) {
        return candidate;
      }
    }
    return candidates.first;
  }

  return (
    defaultRoot: pick(qsatCandidates),
    qsatRoot: pick(qsatCandidates),
    qimageryRoot: pick(qimageryCandidates),
    topographyRoot: pick(topoCandidates),
  );
}
