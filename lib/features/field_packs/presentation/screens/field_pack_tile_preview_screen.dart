import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/tiles/mbtiles_tile_preview_loader.dart';

part 'field_pack_tile_preview_screen_logic.dart';
part 'field_pack_tile_preview_screen_widgets.dart';
part 'field_pack_tile_preview_screen_painter.dart';

class FieldPackTilePreviewScreen extends StatefulWidget {
  const FieldPackTilePreviewScreen({super.key, required this.pack});

  final FieldPack pack;

  @override
  State<FieldPackTilePreviewScreen> createState() =>
      _FieldPackTilePreviewScreenState();
}

class _FieldPackTilePreviewScreenState
    extends State<FieldPackTilePreviewScreen> {
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

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final selectedRect = preview == null
        ? null
        : _selectedBboxRectOnCurrentTile(preview);
    final areaDisplayName =
        widget.pack.areaName ?? widget.pack.name ?? widget.pack.id;

    return Scaffold(
      appBar: AppBar(title: Text('Tile Preview - $areaDisplayName')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null) _buildError(context),
          const SizedBox(height: 12),
          if (preview != null)
            ..._buildLoadedPreview(
              context,
              preview,
              selectedRect,
              areaDisplayName,
            )
          else if (!_loading)
            ..._buildEmptyState(),
        ],
      ),
    );
  }
}
