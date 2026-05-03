import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'field_pack_backend_geojson.dart';
import 'field_pack_backend_models.dart';
import 'field_pack_backend_synthetic_pack.dart';

class FieldPackBackendPackBuilder {
  FieldPackBackendPackBuilder({
    required this.sourcePackRootDefault,
    required this.sourcePackRootQsat,
    required this.sourcePackRootQimagery,
    required this.sourcePackRootTopography,
  });

  final String sourcePackRootDefault;
  final String sourcePackRootQsat;
  final String sourcePackRootQimagery;
  final String sourcePackRootTopography;
  final FieldPackBackendSyntheticPackFactory _syntheticFactory =
      const FieldPackBackendSyntheticPackFactory();

  Future<PublishedPack> publishPack({
    required String packId,
    required Map<String, Object?> payload,
    required String Function(DateTime) isoUtc,
  }) async {
    final resolved = _resolveSourceRoot(payload);
    Directory root = Directory(resolved.rootPath);
    if (!_validRoot(root)) {
      final fallback = Directory(sourcePackRootDefault);
      if (_validRoot(fallback)) {
        stderr.writeln(
          'Source pack fallback: preset=${resolved.preset} requested=${resolved.rootPath} '
          'missing/invalid, using default=${fallback.path}',
        );
        root = fallback;
      } else {
        stderr.writeln(
          'Source pack missing for preset=${resolved.preset}; falling back to synthetic pack.',
        );
        return _syntheticFactory.build(
          packId: packId,
          payload: payload,
          isoUtc: isoUtc,
        );
      }
    }

    final zipBytes = await _zipDirectory(root);
    final manifest = await _buildManifest(
      packId: packId,
      sourceRoot: root,
      payload: payload,
      isoUtc: isoUtc,
    );
    return PublishedPack(
      packId: packId,
      manifest: manifest,
      zipBytes: zipBytes,
    );
  }

  ({String preset, String rootPath}) _resolveSourceRoot(
    Map<String, Object?> payload,
  ) {
    final tileBuild =
        (payload['tile_build'] as Map<String, Object?>?) ??
        const <String, Object?>{};
    final presetRaw = (tileBuild['source_preset'] as String?)?.trim();
    final preset = (presetRaw == null || presetRaw.isEmpty)
        ? 'qld_qsat_wos_latestsatellite_allusers'
        : presetRaw;

    final rootPath = switch (preset) {
      'qld_qsat_wos_latestsatellite_allusers' => sourcePackRootQsat,
      'qld_qimagery_aerial' => sourcePackRootQimagery,
      'qld_topographic_hillshade' => sourcePackRootTopography,
      _ => sourcePackRootDefault,
    };

    return (preset: preset, rootPath: rootPath);
  }

  bool _validRoot(Directory dir) {
    return dir.existsSync() &&
        File(p.join(dir.path, 'basemap.mbtiles')).existsSync();
  }

  Future<Map<String, Object?>> _buildManifest({
    required String packId,
    required Directory sourceRoot,
    required Map<String, Object?> payload,
    required String Function(DateTime) isoUtc,
  }) async {
    final now = DateTime.now().toUtc();
    final assets = <Map<String, Object?>>[];
    for (final path in <String>[
      'basemap.mbtiles',
      'labels.mbtiles',
      'topography.mbtiles',
      'geology.gpkg',
      'gazetteer.sqlite',
    ]) {
      final file = File(p.join(sourceRoot.path, path));
      if (!file.existsSync()) {
        continue;
      }
      final bytes = await file.readAsBytes();
      assets.add(<String, Object?>{
        'path': path,
        'kind': path.endsWith('.mbtiles')
            ? 'tiles'
            : (path.endsWith('.gpkg') ? 'geology' : 'gazetteer'),
        'size_bytes': bytes.length,
        'sha256': sha256.convert(bytes).toString(),
      });
    }
    if (assets.isEmpty) {
      throw StateError('No manifest assets found in ${sourceRoot.path}');
    }

    final fieldArea =
        (payload['field_area'] as Map<String, Object?>?) ??
        const <String, Object?>{};
    final geojson =
        (fieldArea['geojson'] as Map<String, Object?>?) ??
        const <String, Object?>{};
    final bbox =
        extractBboxFromGeoJson(geojson) ??
        <double>[146.7406, -19.3379, 146.7798, -19.3078];
    final metadata =
        (payload['metadata'] as Map<String, Object?>?) ??
        const <String, Object?>{};
    final tileBuild =
        (payload['tile_build'] as Map<String, Object?>?) ??
        const <String, Object?>{};
    final sourcePreset = tileBuild['source_preset'] as String?;
    final requestName = payload['name'] as String?;
    final areaName = fieldArea['name'] as String?;
    final displayName = areaName?.trim().isNotEmpty == true
        ? areaName
        : (requestName?.trim().isNotEmpty == true ? requestName : null);
    final provider =
        (metadata['provider'] as String?) ??
        'Queensland Government QSat Mosaic';
    final license =
        (metadata['license'] as String?) ?? 'CC BY-SA (verify current terms)';
    final attribution =
        (metadata['attribution'] as String?) ??
        'Contains Queensland Government data. Refer to source licence terms.';

    return <String, Object?>{
      'pack_id': packId,
      'name': displayName,
      'version': '1.0.0',
      'created_at_utc': isoUtc(now),
      'crs': 'EPSG:4326',
      'area': <String, Object?>{
        'bbox': <Object>[bbox[0], bbox[1], bbox[2], bbox[3]],
        'area_size_m2': max(
          1,
          ((bbox[2] - bbox[0]).abs() * (bbox[3] - bbox[1]).abs() * 12321000000)
              .round(),
        ),
      },
      'assets': assets,
      'data_sources': <Object>[
        <String, Object?>{
          'provider': provider,
          if (sourcePreset != null && sourcePreset.isNotEmpty)
            'source_preset': sourcePreset,
          'acquired_at_utc': isoUtc(now),
          'license': license,
          'attribution': attribution,
        },
      ],
      'requires_app_version': '1.0.0',
    };
  }

  Future<Uint8List> _zipDirectory(Directory dir) async {
    final archive = Archive();
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final relative = p
          .relative(entity.path, from: dir.path)
          .replaceAll('\\', '/');
      final bytes = await entity.readAsBytes();
      archive.add(ArchiveFile(relative, bytes.length, bytes));
    }
    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }
}
