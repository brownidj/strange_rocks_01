import 'package:flutter/material.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/tiles/mbtiles_tile_preview_loader.dart';

class FieldPackTilePreviewScreen extends StatefulWidget {
  const FieldPackTilePreviewScreen({super.key, required this.pack});

  final FieldPack pack;

  @override
  State<FieldPackTilePreviewScreen> createState() =>
      _FieldPackTilePreviewScreenState();
}

class _FieldPackTilePreviewScreenState extends State<FieldPackTilePreviewScreen> {
  final _loader = const MbtilesTilePreviewLoader();
  MbtilesTilePreview? _preview;
  bool _loading = false;
  String? _error;
  int _selectedZoom = -1;
  int _indexInZoom = 0;
  double _brightness = 0.12;
  double _contrast = 1.08;
  double _labelsOpacity = 0.9;
  double _topographyOpacity = 0.35;
  bool _labelsOn = true;
  bool _topographyOn = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final current = _loadCenteredOrDefault();
      if (!mounted) {
        return;
      }
      setState(() {
        _preview = current;
        _selectedZoom = current.zoom;
        _indexInZoom = current.indexInZoom;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _preview = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  MbtilesTilePreview _loadCenteredOrDefault() {
    final center = _loadSavedAreaCenter() ?? _loadAreaBboxCenter();
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

  (double, double)? _loadSavedAreaCenter() {
    final lon = widget.pack.areaCenterLon;
    final lat = widget.pack.areaCenterLat;
    if (lon == null || lat == null) {
      return null;
    }
    return (lon, lat);
  }

  (double, double)? _loadAreaBboxCenter() {
    final minLon = widget.pack.manifest.area['min_lon'];
    final minLat = widget.pack.manifest.area['min_lat'];
    final maxLon = widget.pack.manifest.area['max_lon'];
    final maxLat = widget.pack.manifest.area['max_lat'];
    if (minLon == null || minLat == null || maxLon == null || maxLat == null) {
      return null;
    }
    return (
      (minLon.toDouble() + maxLon.toDouble()) / 2,
      (minLat.toDouble() + maxLat.toDouble()) / 2,
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
    return <double>[
      c, 0, 0, 0, b,
      0, c, 0, 0, b,
      0, 0, c, 0, b,
      0, 0, 0, 1, 0,
    ];
  }


  String _selectedAreaBoundsText() {
    final minLon = widget.pack.areaMinLon;
    final minLat = widget.pack.areaMinLat;
    final maxLon = widget.pack.areaMaxLon;
    final maxLat = widget.pack.areaMaxLat;
    if (minLon != null && minLat != null && maxLon != null && maxLat != null) {
      return '${minLon.toStringAsFixed(4)}, ${minLat.toStringAsFixed(4)} '
          'to ${maxLon.toStringAsFixed(4)}, ${maxLat.toStringAsFixed(4)}';
    }
    final m = widget.pack.manifest.area;
    final fbMinLon = m['min_lon'];
    final fbMinLat = m['min_lat'];
    final fbMaxLon = m['max_lon'];
    final fbMaxLat = m['max_lat'];
    if (fbMinLon == null || fbMinLat == null || fbMaxLon == null || fbMaxLat == null) {
      return 'Unavailable';
    }
    final minLonText = fbMinLon.toDouble().toStringAsFixed(4);
    final minLatText = fbMinLat.toDouble().toStringAsFixed(4);
    final maxLonText = fbMaxLon.toDouble().toStringAsFixed(4);
    final maxLatText = fbMaxLat.toDouble().toStringAsFixed(4);
    return '$minLonText, $minLatText to $maxLonText, $maxLatText';
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final areaDisplayName =
        widget.pack.areaName ?? widget.pack.name ?? widget.pack.id;
    return Scaffold(
      appBar: AppBar(title: Text('Tile Preview - $areaDisplayName')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          if (preview != null) ...[
            Row(
              children: [
                Expanded(child: Text('Area: $areaDisplayName')),
                Text('Total tiles: ${preview.totalTiles}'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Selected bbox: ${_selectedAreaBoundsText()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (preview.labelsAvailable || preview.topographyAvailable)
              Row(
                children: [
                  if (preview.topographyAvailable) ...[
                    const Text('Topography'),
                    const SizedBox(width: 4),
                    RadioGroup<bool>(
                      groupValue: _topographyOn ? true : null,
                      onChanged: (value) {
                        setState(() {
                          _topographyOn = value == true;
                        });
                      },
                      child: Row(
                        children: [
                          const Radio<bool>(value: true, toggleable: true),
                          Text(_topographyOn ? 'On' : 'Off'),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (preview.labelsAvailable) ...[
                    const Text('Labels'),
                    const SizedBox(width: 4),
                    RadioGroup<bool>(
                      groupValue: _labelsOn ? true : null,
                      onChanged: (value) {
                        setState(() {
                          _labelsOn = value == true;
                        });
                      },
                      child: Row(
                        children: [
                          const Radio<bool>(value: true, toggleable: true),
                          Text(_labelsOn ? 'On' : 'Off'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Zoom:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: preview.zoom,
                  items: preview.availableZooms
                      .map(
                        (z) =>
                            DropdownMenuItem<int>(value: z, child: Text('z$z')),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) _changeZoom(value);
                  },
                ),
                const Spacer(),
                Text('tile_column=${preview.tileColumn}, tile_row=${preview.tileRow}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 90, child: Text('Brightness')),
                Expanded(
                  child: Slider(
                    value: _brightness,
                    min: 0,
                    max: 0.35,
                    divisions: 35,
                    label: _brightness.toStringAsFixed(2),
                    onChanged: (value) {
                      setState(() {
                        _brightness = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 90, child: Text('Contrast')),
                Expanded(
                  child: Slider(
                    value: _contrast,
                    min: 1.0,
                    max: 1.5,
                    divisions: 25,
                    label: _contrast.toStringAsFixed(2),
                    onChanged: (value) {
                      setState(() {
                        _contrast = value;
                      });
                    },
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _brightness = 0.12;
                      _contrast = 1.08;
                      _labelsOpacity = 0.9;
                      _topographyOpacity = 0.35;
                    });
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
            if (preview.labelsAvailable && _labelsOn)
              Row(
                children: [
                  const SizedBox(width: 90, child: Text('Labels')),
                  Expanded(
                    child: Slider(
                      value: _labelsOpacity,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      label: _labelsOpacity.toStringAsFixed(2),
                      onChanged: (value) {
                        setState(() {
                          _labelsOpacity = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            if (preview.topographyAvailable && _topographyOn)
              Row(
                children: [
                  const SizedBox(width: 90, child: Text('Topography')),
                  Expanded(
                    child: Slider(
                      value: _topographyOpacity,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      label: _topographyOpacity.toStringAsFixed(2),
                      onChanged: (value) {
                        setState(() {
                          _topographyOpacity = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Colors.black12),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 8,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColorFiltered(
                          colorFilter: ColorFilter.matrix(_colorMatrix()),
                          child: Image.memory(
                            preview.bytes,
                            gaplessPlayback: true,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: Text('Tile bytes are not a decodable image'),
                                ),
                          ),
                        ),
                        if (_topographyOn &&
                            preview.topographyBytes != null &&
                            _topographyOpacity > 0)
                          Opacity(
                            opacity: _topographyOpacity,
                            child: Image.memory(
                              preview.topographyBytes!,
                              gaplessPlayback: true,
                              fit: BoxFit.contain,
                            ),
                          ),
                        if (_labelsOn &&
                            preview.labelsBytes != null &&
                            _labelsOpacity > 0)
                          Opacity(
                            opacity: _labelsOpacity,
                            child: Image.memory(
                              preview.labelsBytes!,
                              gaplessPlayback: true,
                              fit: BoxFit.contain,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ] else if (!_loading) ...[
            const Text('No preview available.'),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _reload, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
