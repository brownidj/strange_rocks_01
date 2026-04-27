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

  void _step(int delta) {
    final p = _preview;
    if (p == null) {
      return;
    }
    final nextIndex = (_indexInZoom + delta).clamp(0, p.totalInZoom - 1);
    if (nextIndex == _indexInZoom) {
      return;
    }
    setState(() {
      _indexInZoom = nextIndex;
    });
    _reload();
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
                          const Radio<bool>(
                            value: true,
                            toggleable: true,
                          ),
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
                          const Radio<bool>(
                            value: true,
                            toggleable: true,
                          ),
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
                        (z) => DropdownMenuItem<int>(
                          value: z,
                          child: Text('z$z'),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) _changeZoom(value);
                  },
                ),
                const Spacer(),
                Text(
                  'Tile ${preview.indexInZoom + 1}/${preview.totalInZoom}',
                ),
              ],
            ),
            Text('tile_column=${preview.tileColumn}, tile_row=${preview.tileRow}'),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 90,
                  child: Text('Brightness'),
                ),
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
                const SizedBox(
                  width: 90,
                  child: Text('Contrast'),
                ),
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
                  const SizedBox(
                    width: 90,
                    child: Text('Labels'),
                  ),
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
                  const SizedBox(
                    width: 90,
                    child: Text('Topography'),
                  ),
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
                            errorBuilder: (context, error, stackTrace) => const Center(
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
                        const Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 10, top: 8),
                            child: Text(
                              '⊞',
                              style: TextStyle(
                                color: Color(0xFFFFE066),
                                fontSize: 22,
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
                        Align(
                          alignment: _alignmentForDirection(
                            preview.previousDirection,
                          ),
                          child: _OverlayChevronButton(
                            icon: _iconForDirection(preview.previousDirection),
                            enabled: _indexInZoom > 0,
                            onTap: () => _step(-1),
                          ),
                        ),
                        Align(
                          alignment: _alignmentForDirection(
                            preview.nextDirection,
                          ),
                          child: _OverlayChevronButton(
                            icon: _iconForDirection(preview.nextDirection),
                            enabled: _indexInZoom < preview.totalInZoom - 1,
                            onTap: () => _step(1),
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
            OutlinedButton(
              onPressed: _reload,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

Alignment _alignmentForDirection(TileStepDirection? direction) {
  return switch (direction) {
    TileStepDirection.north => Alignment.topCenter,
    TileStepDirection.south => Alignment.bottomCenter,
    TileStepDirection.east => Alignment.centerRight,
    TileStepDirection.west => Alignment.centerLeft,
    TileStepDirection.northeast => Alignment.topRight,
    TileStepDirection.northwest => Alignment.topLeft,
    TileStepDirection.southeast => Alignment.bottomRight,
    TileStepDirection.southwest => Alignment.bottomLeft,
    null => Alignment.center,
  };
}

IconData _iconForDirection(TileStepDirection? direction) {
  return switch (direction) {
    TileStepDirection.north => Icons.keyboard_arrow_up,
    TileStepDirection.south => Icons.keyboard_arrow_down,
    TileStepDirection.east => Icons.keyboard_arrow_right,
    TileStepDirection.west => Icons.keyboard_arrow_left,
    TileStepDirection.northeast => Icons.north_east,
    TileStepDirection.northwest => Icons.north_west,
    TileStepDirection.southeast => Icons.south_east,
    TileStepDirection.southwest => Icons.south_west,
    null => Icons.chevron_right,
  };
}

class _OverlayChevronButton extends StatelessWidget {
  const _OverlayChevronButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? const Color(0xFFFFE066)
        : const Color(0xFFFFE066).withValues(alpha: 0.35);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              icon,
              size: 56,
              color: color,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
