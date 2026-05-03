part of 'field_pack_tile_preview_screen.dart';

extension _FieldPackTilePreviewScreenLogic on _FieldPackTilePreviewScreenState {
  MbtilesTilePreview _loadCenteredOrDefault() {
    final selectedBbox = _selectedAreaBbox() ?? _manifestBbox();
    final center = selectedBbox == null
        ? null
        : (
            (selectedBbox.$1 + selectedBbox.$3) / 2,
            (selectedBbox.$2 + selectedBbox.$4) / 2,
          );
    if (center == null) {
      return _loader.load(
        packRootPath: widget.pack.localRootPath,
        zoom: _selectedZoom,
        indexInZoom: _indexInZoom,
      );
    }

    final availableZooms = _loader.availableZooms(
      packRootPath: widget.pack.localRootPath,
    );
    if (availableZooms.isEmpty) {
      return _loader.load(
        packRootPath: widget.pack.localRootPath,
        zoom: _selectedZoom,
        indexInZoom: _indexInZoom,
      );
    }

    final targetZoom = availableZooms.contains(_selectedZoom)
        ? _selectedZoom
        : (availableZooms.contains(9) ? 9 : availableZooms.first);
    final exact = _loader.coordinateForLonLat(
      packRootPath: widget.pack.localRootPath,
      zoom: targetZoom,
      lon: center.$1,
      lat: center.$2,
    );

    try {
      return _loader.loadByTile(
        packRootPath: widget.pack.localRootPath,
        zoom: exact.zoom,
        tileColumn: exact.tileColumn,
        tileRow: exact.tileRow,
      );
    } catch (_) {}

    final nearest = _loader.nearestTileToLonLat(
      packRootPath: widget.pack.localRootPath,
      zoom: targetZoom,
      lon: center.$1,
      lat: center.$2,
    );
    if (nearest == null) {
      return _loader.load(
        packRootPath: widget.pack.localRootPath,
        zoom: _selectedZoom,
        indexInZoom: _indexInZoom,
      );
    }
    return _loader.loadByTile(
      packRootPath: widget.pack.localRootPath,
      zoom: nearest.zoom,
      tileColumn: nearest.tileColumn,
      tileRow: nearest.tileRow,
    );
  }

  (double, double, double, double)? _selectedAreaBbox() {
    final minLon = widget.pack.areaMinLon;
    final minLat = widget.pack.areaMinLat;
    final maxLon = widget.pack.areaMaxLon;
    final maxLat = widget.pack.areaMaxLat;
    if (minLon == null || minLat == null || maxLon == null || maxLat == null) {
      return null;
    }
    return (minLon, minLat, maxLon, maxLat);
  }

  (double, double, double, double)? _manifestBbox() {
    final minLon = widget.pack.manifest.area['min_lon'];
    final minLat = widget.pack.manifest.area['min_lat'];
    final maxLon = widget.pack.manifest.area['max_lon'];
    final maxLat = widget.pack.manifest.area['max_lat'];
    if (minLon == null || minLat == null || maxLon == null || maxLat == null) {
      return null;
    }
    return (
      minLon.toDouble(),
      minLat.toDouble(),
      maxLon.toDouble(),
      maxLat.toDouble(),
    );
  }

  void _changeZoom(int zoom) {
    _selectedZoom = zoom;
    _indexInZoom = 0;
    _reload();
  }

  List<double> _colorMatrix() {
    final b = _brightness * 255.0;
    final c = _contrast;
    return <double>[c, 0, 0, 0, b, 0, c, 0, 0, b, 0, 0, c, 0, b, 0, 0, 0, 1, 0];
  }

  String _selectedAreaBoundsText() {
    final bbox = _selectedAreaBbox();
    if (bbox != null) {
      final minLon = bbox.$1;
      final minLat = bbox.$2;
      final maxLon = bbox.$3;
      final maxLat = bbox.$4;
      return '${minLon.toStringAsFixed(4)}, ${minLat.toStringAsFixed(4)} '
          'to ${maxLon.toStringAsFixed(4)}, ${maxLat.toStringAsFixed(4)}';
    }

    final fallback = _manifestBbox();
    if (fallback == null) {
      return 'Unavailable';
    }
    final minLonText = fallback.$1.toStringAsFixed(4);
    final minLatText = fallback.$2.toStringAsFixed(4);
    final maxLonText = fallback.$3.toStringAsFixed(4);
    final maxLatText = fallback.$4.toStringAsFixed(4);
    return '$minLonText, $minLatText to $maxLonText, $maxLatText';
  }

  Rect? _selectedBboxRectOnCurrentTile(MbtilesTilePreview preview) {
    final bbox = _selectedAreaBbox() ?? _manifestBbox();
    if (bbox == null) {
      return null;
    }

    final z = preview.zoom;
    final n = 1 << z;
    final x = preview.tileColumn;
    final yStored = preview.tileRow;
    final scheme = preview.tileScheme;
    final yXyz = scheme == 'xyz' ? yStored : (n - 1 - yStored);

    final tileMinLon = (x / n) * 360.0 - 180.0;
    final tileMaxLon = ((x + 1) / n) * 360.0 - 180.0;
    final tileMaxLat = _latFromTileY(yXyz, z);
    final tileMinLat = _latFromTileY(yXyz + 1, z);

    final interMinLon = math.max(tileMinLon, bbox.$1);
    final interMinLat = math.max(tileMinLat, bbox.$2);
    final interMaxLon = math.min(tileMaxLon, bbox.$3);
    final interMaxLat = math.min(tileMaxLat, bbox.$4);
    if (interMinLon >= interMaxLon || interMinLat >= interMaxLat) {
      return null;
    }

    final dx = tileMaxLon - tileMinLon;
    final dy = tileMaxLat - tileMinLat;
    if (dx <= 0 || dy <= 0) {
      return null;
    }

    final left = ((interMinLon - tileMinLon) / dx).clamp(0.0, 1.0);
    final right = ((interMaxLon - tileMinLon) / dx).clamp(0.0, 1.0);
    final top = ((tileMaxLat - interMaxLat) / dy).clamp(0.0, 1.0);
    final bottom = ((tileMaxLat - interMinLat) / dy).clamp(0.0, 1.0);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  double _latFromTileY(int y, int z) {
    final n = math.pi - (2 * math.pi * y) / (1 << z);
    return math.atan(math.exp(n) / 2 - math.exp(-n) / 2) * 180 / math.pi;
  }
}
