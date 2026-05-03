part of 'field_area_define_screen.dart';

extension _FieldAreaDefineScreenInteractions on _FieldAreaDefineScreenState {
  void _zoomInToTap(Offset localPosition, Size size) {
    if (_selectionMode != _AreaSelectionMode.region) {
      return;
    }
    if (_regionLevel >=
        (_FieldAreaDefineScreenState._baseRegionLevel +
            _FieldAreaDefineScreenState._maxTapZoomSteps)) {
      return;
    }
    final width = size.width <= 0 ? 1.0 : size.width;
    final height = size.height <= 0 ? 1.0 : size.height;
    final nx = (localPosition.dx / width).clamp(0.0, 1.0);
    final ny = (localPosition.dy / height).clamp(0.0, 1.0);
    final lon =
        _regionBounds.minLon +
        (_regionBounds.maxLon - _regionBounds.minLon) * nx;
    final lat =
        _regionBounds.maxLat -
        (_regionBounds.maxLat - _regionBounds.minLat) * ny;
    setState(() {
      _trail = <_RegionBounds>[..._trail, _regionBounds];
      _regionBounds = _regionBounds.centeredZoomIn(
        centerLon: lon,
        centerLat: lat,
      );
      _regionLevel += 1;
      _pins = const <_GeoPoint>[];
    });
  }

  void _backRegion() {
    if (_trail.isEmpty) {
      return;
    }
    final updated = List<_RegionBounds>.from(_trail);
    final previousBounds = updated.removeLast();
    setState(() {
      _trail = updated;
      _regionBounds = previousBounds;
      _regionLevel -= 1;
      _pins = const <_GeoPoint>[];
    });
  }

  void _resetRegion() {
    setState(() {
      _regionBounds = _FieldAreaDefineScreenState._qldBounds;
      _regionLevel = _FieldAreaDefineScreenState._baseRegionLevel;
      _trail = const <_RegionBounds>[];
      _pins = const <_GeoPoint>[];
    });
  }

  void _applyRegionToGeoJson() {
    final geoJson = _regionBounds.toFeatureCollection();
    _geoJsonController.text = jsonEncode(geoJson);
    if (_nameController.text.trim().isEmpty) {
      _nameController.text = 'Queensland Region';
    }
  }

  void _addPinAtPosition(Offset localPosition, Size size) {
    if (_selectionMode != _AreaSelectionMode.pins) {
      return;
    }
    final width = size.width <= 0 ? 1.0 : size.width;
    final height = size.height <= 0 ? 1.0 : size.height;
    final nx = (localPosition.dx / width).clamp(0.0, 1.0);
    final ny = (localPosition.dy / height).clamp(0.0, 1.0);
    final lon =
        _regionBounds.minLon +
        (_regionBounds.maxLon - _regionBounds.minLon) * nx;
    final lat =
        _regionBounds.maxLat -
        (_regionBounds.maxLat - _regionBounds.minLat) * ny;
    setState(() {
      _pins = <_GeoPoint>[..._pins, _GeoPoint(lon: lon, lat: lat)];
    });
  }

  void _onMapPointerDown(PointerDownEvent event) {
    _mapPointerDownLocal = event.localPosition;
    _mapPointerMoved = false;
  }

  void _onMapPointerMove(PointerMoveEvent event) {
    final down = _mapPointerDownLocal;
    if (down == null) {
      return;
    }
    if ((event.localPosition - down).distance > 10) {
      _mapPointerMoved = true;
    }
  }

  void _onMapPointerUp(PointerUpEvent event, Size size) {
    final down = _mapPointerDownLocal;
    _mapPointerDownLocal = null;
    if (down == null || _mapPointerMoved) {
      return;
    }
    if (_selectionMode == _AreaSelectionMode.pins) {
      _addPinAtPosition(event.localPosition, size);
      return;
    }
    _zoomInToTap(event.localPosition, size);
  }

  void _clearPins() {
    setState(() {
      _pins = const <_GeoPoint>[];
    });
  }

  void _undoPin() {
    if (_pins.isEmpty) {
      return;
    }
    setState(() {
      _pins = _pins.sublist(0, _pins.length - 1);
    });
  }

  void _applyPinsToGeoJson() {
    if (_pins.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 3 pins to form an area')),
      );
      return;
    }
    final ring = <List<double>>[
      ..._pins.map((p) => <double>[p.lon, p.lat]),
      <double>[_pins.first.lon, _pins.first.lat],
    ];
    final geoJson = <String, Object?>{
      'type': 'FeatureCollection',
      'features': <Object?>[
        <String, Object?>{
          'type': 'Feature',
          'properties': <String, Object?>{},
          'geometry': <String, Object?>{
            'type': 'Polygon',
            'coordinates': <Object?>[ring],
          },
        },
      ],
    };
    _geoJsonController.text = jsonEncode(geoJson);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('GeoJSON updated from pins')));
  }

  String _zoomProgressText() {
    final used = _regionLevel - _FieldAreaDefineScreenState._baseRegionLevel;
    return '$used/${_FieldAreaDefineScreenState._maxTapZoomSteps} zoom taps';
  }

  String _zoomContextLabel() {
    return switch (_regionLevel) {
      <= 8 => 'State / City overview',
      <= 10 => 'District scale',
      <= 12 => 'Suburb scale',
      <= 14 => 'Street scale',
      _ => 'Property / site scale',
    };
  }

  String _previewUrl() {
    final bbox =
        '${_regionBounds.minLon},${_regionBounds.minLat},${_regionBounds.maxLon},${_regionBounds.maxLat}';
    final uri =
        Uri.parse(
          '${_FieldAreaDefineScreenState._previewImageServer}/exportImage',
        ).replace(
          queryParameters: <String, String>{
            'bbox': bbox,
            'bboxSR': '4326',
            'imageSR': '4326',
            'size': '1024,1024',
            'format': 'jpgpng',
            'compressionQuality': '70',
            'interpolation': 'RSP_BilinearInterpolation',
            'f': 'image',
          },
        );
    return uri.toString();
  }
}
