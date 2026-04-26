import 'package:flutter/foundation.dart';
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
      if (kDebugMode) {
        debugPrint(
          'Tile preview debug: db=${current.dbPath} size=${current.dbSizeBytes} '
          'format=${current.metadataFormat ?? 'missing'} kind=${current.detectedTileKind} '
          'header=${current.tileHeaderHex}',
        );
      }
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
    _indexInZoom = (p.indexInZoom + delta).clamp(0, p.totalInZoom - 1);
    _reload();
  }

  void _changeZoom(int zoom) {
    _selectedZoom = zoom;
    _indexInZoom = 0;
    _reload();
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
            Text('Area: $areaDisplayName'),
            Text('Total tiles: ${preview.totalTiles}'),
            if (kDebugMode) ...[
              const SizedBox(height: 6),
              SelectableText(
                'Debug: ${preview.detectedTileKind}, '
                'format=${preview.metadataFormat ?? 'missing'}, '
                'header=${preview.tileHeaderHex}, '
                'dbSize=${preview.dbSizeBytes}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
                    child: Image.memory(
                      preview.bytes,
                      gaplessPlayback: true,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Text('Tile bytes are not a decodable image'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: preview.indexInZoom <= 0 ? null : () => _step(-1),
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Prev'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: preview.indexInZoom >= preview.totalInZoom - 1
                        ? null
                        : () => _step(1),
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
                  ),
                ),
              ],
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
