import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:strange_rocks_01/features/field_packs/infrastructure/api/field_pack_api_client.dart';

class LocalStubFieldPackApiClient implements FieldPackApiClient {
  @override
  Future<Map<String, Object?>> fetchManifest(String packId) async {
    final files = _buildPackFiles(packId);
    final assets = <Map<String, Object?>>[];

    for (final entry in files.entries) {
      if (!_isManifestAsset(entry.key)) {
        continue;
      }
      assets.add(<String, Object?>{
        'path': entry.key,
        'kind': _assetKind(entry.key),
        'size_bytes': entry.value.length,
        'sha256': sha256.convert(entry.value).toString(),
      });
    }

    return <String, Object?>{
      'pack_id': packId,
      'name': 'Stub $packId',
      'version': '1.0.0',
      'created_at_utc': DateTime.now().toUtc().toIso8601String(),
      'crs': 'EPSG:4326',
      'area': <String, Object?>{
        'bbox': <Object>[151.0, -27.0, 151.2, -26.8],
        'area_size_m2': 4500000,
      },
      'assets': assets,
      'data_sources': <Object?>[
        <String, Object?>{
          'provider': 'Queensland Geological Survey (stub)',
          'acquired_at_utc': '2026-04-25T00:00:00Z',
          'license': 'Demo data for development only',
          'attribution': 'Strange Rocks local stub provider',
        },
      ],
      'requires_app_version': '1.0.0',
    };
  }

  @override
  Future<void> downloadPackArchive(
    String packId,
    String destinationPath,
  ) async {
    final files = _buildPackFiles(packId);
    final archive = Archive();

    for (final entry in files.entries) {
      archive.add(ArchiveFile(entry.key, entry.value.length, entry.value));
    }

    final encoded = ZipEncoder().encode(archive);
    final output = Uint8List.fromList(encoded);
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(output, flush: true);
  }

  Map<String, Uint8List> _buildPackFiles(String packId) {
    return <String, Uint8List>{
      'basemap.mbtiles': _textBytes('stub basemap for $packId'),
      'topography.mbtiles': _textBytes('stub topography for $packId'),
      'geology.gpkg': _textBytes('stub geology package for $packId'),
      'gazetteer.sqlite': _textBytes('stub gazetteer for $packId'),
      'instructions.md': _textBytes(
        '# Instructions\n\nThis is a local stub field pack for `$packId`.\nUse this for UI and offline workflow testing.',
      ),
      'safety_notes.md': _textBytes(
        '# Safety Notes\n\nCarry water, PPE, and notify a contact before fieldwork.\nDo not enter restricted areas.',
      ),
      p.join('licenses', 'attribution.txt'): _textBytes(
        'Attribution: Strange Rocks stub dataset provider.',
      ),
      p.join('licenses', 'data_sources.json'): _textBytes(
        jsonEncode(<Map<String, String>>[
          <String, String>{
            'provider': 'Queensland Geological Survey (stub)',
            'license': 'Demo data for development only',
          },
        ]),
      ),
      'field_area.geojson': _textBytes(
        jsonEncode(<String, Object?>{
          'type': 'FeatureCollection',
          'features': <Object?>[],
        }),
      ),
    };
  }

  Uint8List _textBytes(String value) => Uint8List.fromList(utf8.encode(value));

  bool _isManifestAsset(String path) {
    return path == 'basemap.mbtiles' ||
        path == 'topography.mbtiles' ||
        path == 'geology.gpkg' ||
        path == 'gazetteer.sqlite';
  }

  String _assetKind(String path) {
    if (path.endsWith('.mbtiles')) {
      return 'tiles';
    }
    if (path.endsWith('.gpkg')) {
      return 'geology';
    }
    if (path.endsWith('.sqlite')) {
      return 'gazetteer';
    }
    return 'asset';
  }
}
