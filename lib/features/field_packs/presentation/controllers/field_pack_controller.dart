import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_area.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack.dart';
import 'package:strange_rocks_01/features/field_packs/domain/repositories/field_pack_repository.dart';
import 'package:strange_rocks_01/features/field_packs/domain/use_cases/download_field_pack_use_case.dart';
import 'package:strange_rocks_01/features/field_packs/presentation/models/field_pack_notes.dart';

class FieldPackController extends ChangeNotifier {
  FieldPackController({
    required FieldPackRepository repository,
    required DownloadFieldPackUseCase downloadFieldPack,
  }) : _repository = repository,
       _downloadFieldPack = downloadFieldPack;

  final FieldPackRepository _repository;
  final DownloadFieldPackUseCase _downloadFieldPack;

  List<FieldPack> packs = const <FieldPack>[];
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadPacks() async {
    await _runGuarded(() async {
      packs = await _repository.listFieldPacks();
    });
  }

  Future<void> importAreaAndDownload({
    required String areaName,
    required String geoJsonRaw,
  }) async {
    await _runGuarded(() async {
      final geoJson = jsonDecode(geoJsonRaw);
      if (geoJson is! Map<String, Object?>) {
        throw const FormatException('GeoJSON must decode to an object');
      }

      final now = DateTime.now().toUtc();
      final packId = _buildPackId(areaName, now);
      final area = FieldArea(
        id: 'area-$packId',
        name: areaName,
        geoJson: geoJson,
        bbox: _extractBoundingBox(geoJson),
      );

      await _repository.saveFieldArea(area);
      await _downloadFieldPack(packId);
      packs = await _repository.listFieldPacks();
    });
  }

  Future<void> activatePack(String packId) async {
    await _runGuarded(() async {
      await _repository.updatePackStatus(
        packId,
        FieldPackStatus.active,
        isActive: true,
      );
      packs = await _repository.listFieldPacks();
    });
  }

  Future<void> deletePack(FieldPack pack) async {
    await _runGuarded(() async {
      await _repository.deletePack(pack.id);
      final directory = Directory(pack.localRootPath);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      packs = await _repository.listFieldPacks();
    });
  }

  Future<FieldPackNotes> loadPackNotes(FieldPack pack) async {
    final instructionsPath = p.join(pack.localRootPath, 'instructions.md');
    final safetyPath = p.join(pack.localRootPath, 'safety_notes.md');
    final licensePath = p.join(
      pack.localRootPath,
      'licenses',
      'attribution.txt',
    );

    return FieldPackNotes(
      instructions: await _safeReadText(instructionsPath),
      safetyNotes: await _safeReadText(safetyPath),
      licenseAttribution: await _safeReadText(licensePath),
    );
  }

  Future<String> _safeReadText(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return 'Not available';
    }
    return file.readAsString();
  }

  String _buildPackId(String areaName, DateTime nowUtc) {
    final safe = areaName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return '$safe-${nowUtc.millisecondsSinceEpoch}';
  }

  Map<String, num> _extractBoundingBox(Map<String, Object?> geoJson) {
    final features = geoJson['features'];
    if (features is! List<Object?>) {
      return <String, num>{'minLon': 0, 'minLat': 0, 'maxLon': 0, 'maxLat': 0};
    }

    num? minLon;
    num? minLat;
    num? maxLon;
    num? maxLat;

    for (final feature in features) {
      if (feature is! Map<String, Object?>) {
        continue;
      }
      final geometry = feature['geometry'];
      if (geometry is! Map<String, Object?>) {
        continue;
      }
      final coordinates = geometry['coordinates'];
      _walkCoordinates(coordinates, (lon, lat) {
        minLon = minLon == null ? lon : (lon < minLon! ? lon : minLon);
        minLat = minLat == null ? lat : (lat < minLat! ? lat : minLat);
        maxLon = maxLon == null ? lon : (lon > maxLon! ? lon : maxLon);
        maxLat = maxLat == null ? lat : (lat > maxLat! ? lat : maxLat);
      });
    }

    return <String, num>{
      'minLon': minLon ?? 0,
      'minLat': minLat ?? 0,
      'maxLon': maxLon ?? 0,
      'maxLat': maxLat ?? 0,
    };
  }

  void _walkCoordinates(
    Object? coordinates,
    void Function(num lon, num lat) onPoint,
  ) {
    if (coordinates is List<Object?> &&
        coordinates.length >= 2 &&
        coordinates[0] is num &&
        coordinates[1] is num) {
      onPoint(coordinates[0] as num, coordinates[1] as num);
      return;
    }

    if (coordinates is List<Object?>) {
      for (final entry in coordinates) {
        _walkCoordinates(entry, onPoint);
      }
    }
  }

  Future<void> _runGuarded(Future<void> Function() operation) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await operation();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
