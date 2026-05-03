part of 'field_pack_tile_preview_screen.dart';

extension _FieldPackTilePreviewScreenWidgets
    on _FieldPackTilePreviewScreenState {
  Widget _buildError(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        _error!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  List<Widget> _buildLoadedPreview(
    BuildContext context,
    MbtilesTilePreview preview,
    Rect? selectedRect,
    String areaDisplayName,
  ) {
    return <Widget>[
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
        _buildLayerToggles(preview),
      const SizedBox(height: 8),
      _buildZoomRow(preview),
      const SizedBox(height: 8),
      _buildBrightnessRow(),
      _buildContrastRow(),
      if (preview.labelsAvailable && _labelsOn) _buildLabelsOpacityRow(),
      if (preview.topographyAvailable && _topographyOn)
        _buildTopographyOpacityRow(),
      const SizedBox(height: 12),
      _buildTilePreview(preview, selectedRect),
    ];
  }

  Widget _buildLayerToggles(MbtilesTilePreview preview) {
    return Row(
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
    );
  }

  Widget _buildZoomRow(MbtilesTilePreview preview) {
    return Row(
      children: [
        const Text('Zoom:'),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: preview.zoom,
          items: preview.availableZooms
              .map((z) => DropdownMenuItem<int>(value: z, child: Text('z$z')))
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) {
              _changeZoom(value);
            }
          },
        ),
        const Spacer(),
        Text('tile_column=${preview.tileColumn}, tile_row=${preview.tileRow}'),
      ],
    );
  }

  Widget _buildBrightnessRow() {
    return Row(
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
    );
  }

  Widget _buildContrastRow() {
    return Row(
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
    );
  }

  Widget _buildLabelsOpacityRow() {
    return Row(
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
    );
  }

  Widget _buildTopographyOpacityRow() {
    return Row(
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
    );
  }

  Widget _buildTilePreview(MbtilesTilePreview preview, Rect? selectedRect) {
    return AspectRatio(
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
                if (selectedRect != null)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _SelectedBboxTilePainter(
                        normalizedRect: selectedRect,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEmptyState() {
    return <Widget>[
      const Text('No preview available.'),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: _reload, child: const Text('Retry')),
    ];
  }
}
