import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_area.dart';
import 'package:strange_rocks_01/features/field_packs/presentation/controllers/field_pack_controller.dart';

class FieldAreaDefineScreen extends StatefulWidget {
  const FieldAreaDefineScreen({super.key, required this.controller});

  final FieldPackController controller;

  @override
  State<FieldAreaDefineScreen> createState() => _FieldAreaDefineScreenState();
}

enum _AreaSelectionMode { region, pins }

class _RegionBounds {
  const _RegionBounds({
    required this.minLon,
    required this.minLat,
    required this.maxLon,
    required this.maxLat,
  });

  final double minLon;
  final double minLat;
  final double maxLon;
  final double maxLat;

  double get centerLon => (minLon + maxLon) / 2;
  double get centerLat => (minLat + maxLat) / 2;

  _RegionBounds centeredZoomIn({required double centerLon, required double centerLat}) {
    final width = maxLon - minLon;
    final height = maxLat - minLat;
    final nextWidth = width / 2;
    final nextHeight = height / 2;
    return _RegionBounds(
      minLon: centerLon - (nextWidth / 2),
      minLat: centerLat - (nextHeight / 2),
      maxLon: centerLon + (nextWidth / 2),
      maxLat: centerLat + (nextHeight / 2),
    );
  }

  Map<String, Object?> toFeatureCollection() {
    final ring = <List<double>>[
      <double>[minLon, minLat],
      <double>[maxLon, minLat],
      <double>[maxLon, maxLat],
      <double>[minLon, maxLat],
      <double>[minLon, minLat],
    ];
    return <String, Object?>{
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
  }

  String toBBoxText() {
    return '${minLon.toStringAsFixed(4)}, ${minLat.toStringAsFixed(4)} '
        'to ${maxLon.toStringAsFixed(4)}, ${maxLat.toStringAsFixed(4)}';
  }
}

class _GeoPoint {
  const _GeoPoint({required this.lon, required this.lat});

  final double lon;
  final double lat;
}

class _FieldAreaDefineScreenState extends State<FieldAreaDefineScreen> {
  static const _maxTapZoomSteps = 8;
  static const _baseRegionLevel = 7;
  static const _qldBounds = _RegionBounds(
    minLon: 137.95,
    minLat: -29.20,
    maxLon: 153.65,
    maxLat: -9.10,
  );

  static const _previewImageServer =
      'https://spatial-img.information.qld.gov.au/arcgis/rest/services/Basemaps/LatestSatelliteWOS_AllUsers/ImageServer';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _geoJsonController = TextEditingController();

  FieldImagerySource _imagerySource = FieldImagerySource.qimageryAerial;
  _AreaSelectionMode _selectionMode = _AreaSelectionMode.region;
  _RegionBounds _regionBounds = _qldBounds;
  int _regionLevel = _baseRegionLevel;
  List<_RegionBounds> _trail = const <_RegionBounds>[];
  List<_GeoPoint> _pins = const <_GeoPoint>[];
  Offset? _mapPointerDownLocal;
  bool _mapPointerMoved = false;

  @override
  void initState() {
    super.initState();
    _applyRegionToGeoJson();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _geoJsonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await widget.controller.importAreaAndDownload(
      areaName: _nameController.text.trim(),
      geoJsonRaw: _geoJsonController.text.trim(),
      imagerySource: _imagerySource,
    );

    if (!mounted) {
      return;
    }

    if (widget.controller.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.controller.errorMessage!)));
      return;
    }

    Navigator.of(context).pop(true);
  }

  void _zoomInToTap(Offset localPosition, Size size) {
    if (_selectionMode != _AreaSelectionMode.region) {
      return;
    }
    if (_regionLevel >= (_baseRegionLevel + _maxTapZoomSteps)) {
      return;
    }
    final width = size.width <= 0 ? 1.0 : size.width;
    final height = size.height <= 0 ? 1.0 : size.height;
    final nx = (localPosition.dx / width).clamp(0.0, 1.0);
    final ny = (localPosition.dy / height).clamp(0.0, 1.0);
    final lon = _regionBounds.minLon + (_regionBounds.maxLon - _regionBounds.minLon) * nx;
    final lat = _regionBounds.maxLat - (_regionBounds.maxLat - _regionBounds.minLat) * ny;
    setState(() {
      _trail = <_RegionBounds>[..._trail, _regionBounds];
      _regionBounds = _regionBounds.centeredZoomIn(centerLon: lon, centerLat: lat);
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
      _regionBounds = _qldBounds;
      _regionLevel = _baseRegionLevel;
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
    final lon = _regionBounds.minLon + (_regionBounds.maxLon - _regionBounds.minLon) * nx;
    final lat = _regionBounds.maxLat - (_regionBounds.maxLat - _regionBounds.minLat) * ny;
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
    final used = _regionLevel - _baseRegionLevel;
    return '$used/$_maxTapZoomSteps zoom taps';
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
    final uri = Uri.parse('$_previewImageServer/exportImage').replace(
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final bottomInset = MediaQuery.of(context).viewPadding.bottom;
        return Scaffold(
          appBar: AppBar(title: const Text('Define Region')),
          body: AbsorbPointer(
            absorbing: widget.controller.isLoading,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                    Text(
                      'Start on the same initial tile. In Region mode, tap a point to center and zoom in by one level.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          key: const ValueKey('define-region-mode-button'),
                          label: const Text('Region'),
                          selected: _selectionMode == _AreaSelectionMode.region,
                          onSelected: (_) {
                            setState(() {
                              _selectionMode = _AreaSelectionMode.region;
                            });
                          },
                        ),
                        ChoiceChip(
                          key: const ValueKey('define-pins-mode-button'),
                          label: const Text('Pins'),
                          selected: _selectionMode == _AreaSelectionMode.pins,
                          onSelected: (_) {
                            setState(() {
                              _selectionMode = _AreaSelectionMode.pins;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text('Level: z$_regionLevel'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _zoomProgressText(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scale: ${_zoomContextLabel()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bounds: ${_regionBounds.toBBoxText()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final size = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            return Listener(
                              key: const ValueKey('define-region-map'),
                              behavior: HitTestBehavior.translucent,
                              onPointerDown: _onMapPointerDown,
                              onPointerMove: _onMapPointerMove,
                              onPointerUp: (event) => _onMapPointerUp(event, size),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    _previewUrl(),
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) {
                                        return child;
                                      }
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) =>
                                        const DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Colors.black12,
                                          ),
                                          child: Center(
                                            child: Text('Preview unavailable'),
                                          ),
                                        ),
                                  ),
                                  IgnorePointer(
                                    child: CustomPaint(
                                      painter: _PinOverlayPainter(
                                        pins: _pins,
                                        bounds: _regionBounds,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _trail.isEmpty ? null : _backRegion,
                          child: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _resetRegion,
                          child: const Text('Reset'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _applyRegionToGeoJson,
                          icon: const Icon(Icons.check),
                          label: const Text('Use This Region'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Pins: ${_pins.length}'),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _pins.isEmpty ? null : _undoPin,
                          child: const Text('Undo Pin'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _pins.isEmpty ? null : _clearPins,
                          child: const Text('Clear Pins'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _pins.length >= 3 ? _applyPinsToGeoJson : null,
                          icon: const Icon(Icons.polyline),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectionMode == _AreaSelectionMode.region
                          ? 'Tap on the map to zoom in. After 8 taps, switch to Pins mode for polygon detail.'
                          : 'Tap map to drop pins for a detailed polygon inside the selected region.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Area Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Area name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<FieldImagerySource>(
                      initialValue: _imagerySource,
                      decoration: const InputDecoration(
                        labelText: 'Imagery Source',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: FieldImagerySource.qsat,
                          child: Text('QSat Mosaic'),
                        ),
                        DropdownMenuItem(
                          value: FieldImagerySource.qimageryAerial,
                          child: Text('QImagery Aerial (default)'),
                        ),
                        DropdownMenuItem(
                          value: FieldImagerySource.topographicHillshade,
                          child: Text('Topographic / Hillshade'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _imagerySource = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _geoJsonController,
                      maxLines: 8,
                      minLines: 6,
                      decoration: const InputDecoration(
                        alignLabelWithHint: true,
                        labelText: 'GeoJSON (auto-filled from selected region)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'GeoJSON is required';
                        }
                        return null;
                      },
                    ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            minimum: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.controller.isLoading ? null : _submit,
                icon: const Icon(Icons.download),
                label: Text(
                  widget.controller.isLoading
                      ? 'Generating Pack...'
                      : 'Generate and Download Pack',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PinOverlayPainter extends CustomPainter {
  const _PinOverlayPainter({required this.pins, required this.bounds});

  final List<_GeoPoint> pins;
  final _RegionBounds bounds;

  @override
  void paint(Canvas canvas, Size size) {
    if (pins.isEmpty) {
      return;
    }
    final linePaint = Paint()
      ..color = const Color(0xCCFFD54F)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = const Color(0x33FFD54F)
      ..style = PaintingStyle.fill;
    final dotPaint = Paint()
      ..color = const Color(0xFFFFEB3B)
      ..style = PaintingStyle.fill;

    final points = pins
        .map((p) => Offset(_xForLon(p.lon, size), _yForLat(p.lat, size)))
        .toList(growable: false);

    if (points.length >= 3) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      path.close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, linePaint);
    } else if (points.length >= 2) {
      for (var i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], linePaint);
      }
    }

    for (var i = 0; i < points.length; i++) {
      final pt = points[i];
      canvas.drawCircle(pt, 5, dotPaint);
      final textSpan = TextSpan(
        text: '${i + 1}',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pt.dx + 6, pt.dy - 6));
    }
  }

  double _xForLon(double lon, Size size) {
    final w = bounds.maxLon - bounds.minLon;
    if (w <= 0) {
      return 0;
    }
    final nx = (lon - bounds.minLon) / w;
    return nx * size.width;
  }

  double _yForLat(double lat, Size size) {
    final h = bounds.maxLat - bounds.minLat;
    if (h <= 0) {
      return 0;
    }
    final ny = (bounds.maxLat - lat) / h;
    return ny * size.height;
  }

  @override
  bool shouldRepaint(covariant _PinOverlayPainter oldDelegate) {
    if (oldDelegate.pins.length != pins.length) {
      return true;
    }
    if (oldDelegate.bounds.minLon != bounds.minLon ||
        oldDelegate.bounds.minLat != bounds.minLat ||
        oldDelegate.bounds.maxLon != bounds.maxLon ||
        oldDelegate.bounds.maxLat != bounds.maxLat) {
      return true;
    }
    for (var i = 0; i < pins.length; i++) {
      if (pins[i].lon != oldDelegate.pins[i].lon ||
          pins[i].lat != oldDelegate.pins[i].lat) {
        return true;
      }
    }
    return false;
  }
}
