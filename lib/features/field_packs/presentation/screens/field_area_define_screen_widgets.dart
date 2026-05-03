part of 'field_area_define_screen.dart';

extension _FieldAreaDefineScreenWidgets on _FieldAreaDefineScreenState {
  Widget _buildIntro(BuildContext context) {
    return Text(
      'Start on the same initial tile. In Region mode, tap a point to center and zoom in by one level.',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _buildSelectionModeChips() {
    return Wrap(
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
    );
  }

  Widget _buildZoomStatus(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Level: z$_regionLevel'),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_zoomProgressText(), overflow: TextOverflow.ellipsis),
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
      ],
    );
  }

  Widget _buildPreviewMap() {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
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
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        const DecoratedBox(
                          decoration: BoxDecoration(color: Colors.black12),
                          child: Center(child: Text('Preview unavailable')),
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
    );
  }

  Widget _buildRegionActions() {
    return Row(
      children: [
        OutlinedButton(
          onPressed: _trail.isEmpty ? null : _backRegion,
          child: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: _resetRegion, child: const Text('Reset')),
        const Spacer(),
        FilledButton.icon(
          onPressed: _applyRegionToGeoJson,
          icon: const Icon(Icons.check),
          label: const Text('Use This Region'),
        ),
      ],
    );
  }

  Widget _buildPinsActions() {
    return Row(
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
    );
  }

  Widget _buildModeHint(BuildContext context) {
    return Text(
      _selectionMode == _AreaSelectionMode.region
          ? 'Tap on the map to zoom in. After 8 taps, switch to Pins mode for polygon detail.'
          : 'Tap map to drop pins for a detailed polygon inside the selected region.',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    );
  }
}
