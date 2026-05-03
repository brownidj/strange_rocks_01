part of 'sqlite_field_pack_repository.dart';

mixin _SqliteFieldPackRepositoryMapping {
  FieldPack _mapPack(Row row) {
    final manifestJson =
        jsonDecode(row['manifest_json'] as String) as Map<String, Object?>;
    final areaCenter = _extractAreaCenter(row['area_geojson'] as String?);
    final areaBbox = _extractAreaBbox(row['area_bbox_json'] as String?);

    return FieldPack(
      id: row['id'] as String,
      version: row['version'] as String,
      name: row['name'] as String?,
      areaName: row['area_name'] as String?,
      areaCenterLon: areaCenter?.$1,
      areaCenterLat: areaCenter?.$2,
      areaMinLon: areaBbox?['minLon'],
      areaMinLat: areaBbox?['minLat'],
      areaMaxLon: areaBbox?['maxLon'],
      areaMaxLat: areaBbox?['maxLat'],
      status: FieldPackStatusMapper.fromDb(row['status'] as String),
      localRootPath: row['local_root_path'] as String,
      createdAtUtc: row['created_at_utc'] as String,
      downloadedAtUtc: row['downloaded_at_utc'] as String?,
      isActive: (row['is_active'] as int) == 1,
      manifest: FieldPackManifestMapper.fromJson(manifestJson),
    );
  }

  Map<String, double>? _extractAreaBbox(String? bboxJsonRaw) {
    if (bboxJsonRaw == null || bboxJsonRaw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(bboxJsonRaw);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final minLon = decoded['minLon'];
      final minLat = decoded['minLat'];
      final maxLon = decoded['maxLon'];
      final maxLat = decoded['maxLat'];
      if (minLon is! num ||
          minLat is! num ||
          maxLon is! num ||
          maxLat is! num) {
        return null;
      }
      return <String, double>{
        'minLon': minLon.toDouble(),
        'minLat': minLat.toDouble(),
        'maxLon': maxLon.toDouble(),
        'maxLat': maxLat.toDouble(),
      };
    } catch (_) {
      return null;
    }
  }

  (double, double)? _extractAreaCenter(String? geoJsonRaw) {
    if (geoJsonRaw == null || geoJsonRaw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(geoJsonRaw);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final features = decoded['features'];
      if (features is! List<Object?>) {
        return null;
      }
      for (final feature in features) {
        if (feature is! Map<String, Object?>) {
          continue;
        }
        final geometry = feature['geometry'];
        if (geometry is! Map<String, Object?>) {
          continue;
        }
        final type = geometry['type'] as String?;
        final coordinates = geometry['coordinates'];
        if (type == 'Polygon') {
          final ring = _extractOuterRing(coordinates);
          final centroid = _ringCentroid(ring);
          if (centroid != null) {
            return centroid;
          }
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  List<(double, double)> _extractOuterRing(Object? coordinates) {
    if (coordinates is! List<Object?> || coordinates.isEmpty) {
      return const <(double, double)>[];
    }
    final ringRaw = coordinates.first;
    if (ringRaw is! List<Object?>) {
      return const <(double, double)>[];
    }
    final points = <(double, double)>[];
    for (final point in ringRaw) {
      if (point is List<Object?> && point.length >= 2) {
        final lon = point[0];
        final lat = point[1];
        if (lon is num && lat is num) {
          points.add((lon.toDouble(), lat.toDouble()));
        }
      }
    }
    return points;
  }

  (double, double)? _ringCentroid(List<(double, double)> ring) {
    if (ring.length < 3) {
      return null;
    }
    var doubledArea = 0.0;
    var centroidXTimes = 0.0;
    var centroidYTimes = 0.0;
    for (var i = 0; i < ring.length - 1; i++) {
      final a = ring[i];
      final b = ring[i + 1];
      final cross = a.$1 * b.$2 - b.$1 * a.$2;
      doubledArea += cross;
      centroidXTimes += (a.$1 + b.$1) * cross;
      centroidYTimes += (a.$2 + b.$2) * cross;
    }
    if (doubledArea.abs() < 1e-12) {
      var sumLon = 0.0;
      var sumLat = 0.0;
      for (final p in ring) {
        sumLon += p.$1;
        sumLat += p.$2;
      }
      return (sumLon / ring.length, sumLat / ring.length);
    }
    return (
      centroidXTimes / (3 * doubledArea),
      centroidYTimes / (3 * doubledArea),
    );
  }
}
