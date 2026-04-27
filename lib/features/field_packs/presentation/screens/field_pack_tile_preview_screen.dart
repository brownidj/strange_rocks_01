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

enum _GridQuadrant { one, two, three, four }

class _GridTrailEntry {
  const _GridTrailEntry({
    required this.zoom,
    required this.nextZoom,
    required this.bounds,
    required this.quadrant,
  });

  final int zoom;
  final int nextZoom;
  final TileBounds bounds;
  final _GridQuadrant quadrant;
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
  bool _gridMode = false;
  int? _gridZoom;
  TileBounds? _gridBounds;
  List<_GridTrailEntry> _gridTrail = const <_GridTrailEntry>[];

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
      final current = _loader.load(
        packRootPath: widget.pack.localRootPath,
        zoom: _selectedZoom,
        indexInZoom: _indexInZoom,
      );
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

  void _toggleGridMode() {
    if (_gridMode) {
      setState(() {
        _gridMode = false;
        _gridZoom = null;
        _gridBounds = null;
        _gridTrail = const <_GridTrailEntry>[];
      });
      return;
    }
    _enterGridMode();
  }

  void _enterGridMode() {
    try {
      final zooms = _loader.availableZooms(packRootPath: widget.pack.localRootPath);
      if (zooms.isEmpty) {
        throw StateError('No zoom levels available for grid navigation');
      }
      final startZoom = zooms.first;
      final startBounds = _loader.boundsForZoom(
        packRootPath: widget.pack.localRootPath,
        zoom: startZoom,
      );
      if (startBounds == null) {
        throw StateError('No tiles found for grid navigation');
      }
      final startTile = _loader.firstTileInBounds(
        packRootPath: widget.pack.localRootPath,
        zoom: startZoom,
        bounds: startBounds,
      );
      if (startTile == null) {
        throw StateError('Could not resolve starting tile for grid navigation');
      }
      final current = _loader.loadByTile(
        packRootPath: widget.pack.localRootPath,
        zoom: startTile.zoom,
        tileColumn: startTile.tileColumn,
        tileRow: startTile.tileRow,
      );
      setState(() {
        _preview = current;
        _selectedZoom = current.zoom;
        _indexInZoom = current.indexInZoom;
        _gridMode = true;
        _gridZoom = startZoom;
        _gridBounds = startBounds;
        _gridTrail = const <_GridTrailEntry>[];
        _error = null;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    }
  }

  void _gridBack() {
    if (!_gridMode) {
      return;
    }
    if (_gridTrail.isEmpty) {
      setState(() {
        _gridMode = false;
        _gridZoom = null;
        _gridBounds = null;
      });
      return;
    }
    final updatedTrail = List<_GridTrailEntry>.from(_gridTrail);
    final previous = updatedTrail.removeLast();
    final tile = _loader.firstTileInBounds(
      packRootPath: widget.pack.localRootPath,
      zoom: previous.zoom,
      bounds: previous.bounds,
    );
    if (tile == null) {
      return;
    }
    final current = _loader.loadByTile(
      packRootPath: widget.pack.localRootPath,
      zoom: tile.zoom,
      tileColumn: tile.tileColumn,
      tileRow: tile.tileRow,
    );
    setState(() {
      _preview = current;
      _selectedZoom = current.zoom;
      _indexInZoom = current.indexInZoom;
      _gridZoom = previous.zoom;
      _gridBounds = previous.bounds;
      _gridTrail = updatedTrail;
    });
  }

  void _gridSelect(_GridQuadrant quadrant) {
    if (!_gridMode || _gridZoom == null || _gridBounds == null) {
      return;
    }
    final currentZoom = _gridZoom!;
    final currentBounds = _gridBounds!;
    final selectedAtCurrent = _quadrantBounds(currentBounds, quadrant);
    final tileAtCurrent = _loader.firstTileInBounds(
      packRootPath: widget.pack.localRootPath,
      zoom: currentZoom,
      bounds: selectedAtCurrent,
    );
    if (tileAtCurrent == null) {
      return;
    }
    final availableZooms =
        _loader.availableZooms(packRootPath: widget.pack.localRootPath);
    final nextZoom = _nextZoomWithTiles(
      currentZoom: currentZoom,
      selectedAtCurrent: selectedAtCurrent,
      availableZooms: availableZooms,
    );
    if (nextZoom == null) {
      final finalPreview = _loader.loadByTile(
        packRootPath: widget.pack.localRootPath,
        zoom: tileAtCurrent.zoom,
        tileColumn: tileAtCurrent.tileColumn,
        tileRow: tileAtCurrent.tileRow,
      );
      setState(() {
        _preview = finalPreview;
        _selectedZoom = finalPreview.zoom;
        _indexInZoom = finalPreview.indexInZoom;
        _gridMode = false;
        _gridZoom = null;
        _gridBounds = null;
      });
      return;
    }

    final projected = _projectBoundsToZoom(
      bounds: selectedAtCurrent,
      fromZoom: currentZoom,
      toZoom: nextZoom,
    );
    final nextBounds = _loader.boundsForZoom(
      packRootPath: widget.pack.localRootPath,
      zoom: nextZoom,
      within: projected,
    );
    if (nextBounds == null) {
      setState(() {
        _error =
            'No tiles available in selected quadrant at z$nextZoom. Choose another square.';
      });
      return;
    }
    final nextTile = _loader.firstTileInBounds(
      packRootPath: widget.pack.localRootPath,
      zoom: nextZoom,
      bounds: nextBounds,
    );
    if (nextTile == null) {
      return;
    }
    final nextPreview = _loader.loadByTile(
      packRootPath: widget.pack.localRootPath,
      zoom: nextTile.zoom,
      tileColumn: nextTile.tileColumn,
      tileRow: nextTile.tileRow,
    );
    setState(() {
      _preview = nextPreview;
      _selectedZoom = nextPreview.zoom;
      _indexInZoom = nextPreview.indexInZoom;
      _gridTrail = <_GridTrailEntry>[
        ..._gridTrail,
        _GridTrailEntry(
          zoom: currentZoom,
          nextZoom: nextZoom,
          bounds: currentBounds,
          quadrant: quadrant,
        ),
      ];
      _gridZoom = nextZoom;
      _gridBounds = nextBounds;
      _error = null;
    });
  }

  TileBounds _quadrantBounds(TileBounds base, _GridQuadrant quadrant) {
    final splitColumn = (base.minColumn + base.maxColumn) ~/ 2;
    final splitRow = (base.minRow + base.maxRow) ~/ 2;
    final leftMin = base.minColumn;
    final leftMax = splitColumn;
    final rightMin = splitColumn + 1;
    final rightMax = base.maxColumn;
    final bottomMin = base.minRow;
    final bottomMax = splitRow;
    final topMin = splitRow + 1;
    final topMax = base.maxRow;

    return switch (quadrant) {
      _GridQuadrant.one => TileBounds(
        minColumn: leftMin,
        maxColumn: leftMax,
        minRow: topMin,
        maxRow: topMax,
        count: 0,
      ),
      _GridQuadrant.two => TileBounds(
        minColumn: rightMin,
        maxColumn: rightMax,
        minRow: topMin,
        maxRow: topMax,
        count: 0,
      ),
      _GridQuadrant.three => TileBounds(
        minColumn: leftMin,
        maxColumn: leftMax,
        minRow: bottomMin,
        maxRow: bottomMax,
        count: 0,
      ),
      _GridQuadrant.four => TileBounds(
        minColumn: rightMin,
        maxColumn: rightMax,
        minRow: bottomMin,
        maxRow: bottomMax,
        count: 0,
      ),
    };
  }

  TileBounds _projectBoundsToZoom({
    required TileBounds bounds,
    required int fromZoom,
    required int toZoom,
  }) {
    final factor = 1 << (toZoom - fromZoom);
    return TileBounds(
      minColumn: bounds.minColumn * factor,
      maxColumn: ((bounds.maxColumn + 1) * factor) - 1,
      minRow: bounds.minRow * factor,
      maxRow: ((bounds.maxRow + 1) * factor) - 1,
      count: 0,
    );
  }

  String _gridBreadcrumb() {
    final zoom = _gridZoom;
    if (zoom == null) {
      return '';
    }
    final parts = <String>['z$zoom'];
    for (final step in _gridTrail) {
      parts.add(_quadrantLabel(step.quadrant));
      parts.add('z${step.nextZoom}');
    }
    return parts.join(' > ');
  }

  String _quadrantLabel(_GridQuadrant quadrant) {
    return switch (quadrant) {
      _GridQuadrant.one => '1',
      _GridQuadrant.two => '2',
      _GridQuadrant.three => '3',
      _GridQuadrant.four => '4',
    };
  }

  bool _quadrantHasTiles(_GridQuadrant quadrant) {
    final zoom = _gridZoom;
    final bounds = _gridBounds;
    if (zoom == null || bounds == null) {
      return false;
    }
    final qBounds = _quadrantBounds(bounds, quadrant);
    return _loader.firstTileInBounds(
          packRootPath: widget.pack.localRootPath,
          zoom: zoom,
          bounds: qBounds,
        ) !=
        null;
  }

  int? _nextZoomWithTiles({
    required int currentZoom,
    required TileBounds selectedAtCurrent,
    required List<int> availableZooms,
  }) {
    final candidates = availableZooms.where((z) => z > currentZoom);
    int? fallbackWithAnyTiles;
    for (final zoom in candidates) {
      final projected = _projectBoundsToZoom(
        bounds: selectedAtCurrent,
        fromZoom: currentZoom,
        toZoom: zoom,
      );
      final nextBounds = _loader.boundsForZoom(
        packRootPath: widget.pack.localRootPath,
        zoom: zoom,
        within: projected,
      );
      if (nextBounds == null || nextBounds.count == 0) {
        continue;
      }
      fallbackWithAnyTiles ??= zoom;
      if (_canShowTwoByTwo(nextBounds)) {
        return zoom;
      }
    }
    return fallbackWithAnyTiles;
  }

  bool _canShowTwoByTwo(TileBounds bounds) {
    final columns = (bounds.maxColumn - bounds.minColumn) + 1;
    final rows = (bounds.maxRow - bounds.minRow) + 1;
    return columns >= 2 && rows >= 2 && bounds.count >= 4;
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
                  onChanged: _gridMode
                      ? null
                      : (value) {
                          if (value != null) _changeZoom(value);
                        },
                ),
                const Spacer(),
                Text('tile_column=${preview.tileColumn}, tile_row=${preview.tileRow}'),
              ],
            ),
            if (_gridMode) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _gridBack,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _gridBreadcrumb(),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
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
                        Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10, top: 8),
                            child: InkWell(
                              onTap: _toggleGridMode,
                              borderRadius: BorderRadius.circular(10),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Text(
                                  '⊞',
                                  style: TextStyle(
                                    color: Color(0xFFFFE066),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedOpacity(
                          opacity: _gridMode ? 1 : 0,
                          duration: const Duration(milliseconds: 170),
                          curve: Curves.easeInOut,
                          child: _gridMode
                              ? _GridOverlay(
                                  isEnabled: _quadrantHasTiles,
                                  onTapQuadrant: _gridSelect,
                                )
                              : const SizedBox.shrink(),
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

class _GridOverlay extends StatelessWidget {
  const _GridOverlay({
    required this.isEnabled,
    required this.onTapQuadrant,
  });

  final bool Function(_GridQuadrant quadrant) isEnabled;
  final void Function(_GridQuadrant quadrant) onTapQuadrant;

  @override
  Widget build(BuildContext context) {
    Widget cell(_GridQuadrant q, String label) {
      final enabled = isEnabled(q);
      return Expanded(
        child: GestureDetector(
          onTap: enabled ? () => onTapQuadrant(q) : null,
          child: Container(
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0x33FFE066)
                  : const Color(0x33000000),
              border: Border.all(color: const Color(0xAAFFE066), width: 1.3),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: enabled ? const Color(0xFFFFE066) : Colors.white54,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      ignoring: false,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                cell(_GridQuadrant.one, '1'),
                cell(_GridQuadrant.two, '2'),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                cell(_GridQuadrant.three, '3'),
                cell(_GridQuadrant.four, '4'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
