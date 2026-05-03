part of 'adhoc_fossil_finds_screen.dart';

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({required this.series, required this.onPhotoSelected});

  final AdhocPhotoSeries series;
  final ValueChanged<AdhocSeriesPhoto> onPhotoSelected;

  @override
  Widget build(BuildContext context) {
    final visiblePhotos = series.photos
        .where((photo) => File(photo.filePath).existsSync())
        .toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (visiblePhotos.isEmpty)
              const Text('No photos yet')
            else
              Expanded(
                child: GridView.builder(
                  itemCount: visiblePhotos.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    return _PhotoThumb(
                      photo: visiblePhotos[index],
                      onTap: () => onPhotoSelected(visiblePhotos[index]),
                      onLongPress: () => onPhotoSelected(visiblePhotos[index]),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SingleSeriesViewer extends StatelessWidget {
  const _SingleSeriesViewer({
    required this.series,
    required this.selectedIndex,
    required this.onSelectedIndexChanged,
    required this.onPhotoSelected,
  });

  final List<AdhocPhotoSeries> series;
  final int selectedIndex;
  final ValueChanged<int> onSelectedIndexChanged;
  final ValueChanged<AdhocSeriesPhoto> onPhotoSelected;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return const Center(child: Text(_noSeriesHelpText));
    }

    final current = series[selectedIndex];
    final canGoPrevious = selectedIndex > 0;
    final canGoNext = selectedIndex < series.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton(
              onPressed: canGoPrevious
                  ? () => onSelectedIndexChanged(selectedIndex - 1)
                  : null,
              child: const Text('<'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                current.title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: canGoNext
                  ? () => onSelectedIndexChanged(selectedIndex + 1)
                  : null,
              child: const Text('>'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _SeriesCard(series: current, onPhotoSelected: onPhotoSelected),
        ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    required this.photo,
    required this.onTap,
    required this.onLongPress,
  });

  final AdhocSeriesPhoto photo;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(photo.filePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _ExifDataDialog extends StatelessWidget {
  const _ExifDataDialog({required this.photo});

  final AdhocSeriesPhoto photo;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: const Text('Photo data'),
      content: SizedBox(
        width: viewport.width * 0.88,
        height: viewport.height * 0.72,
        child: FutureBuilder<String?>(
          future: _readDateTimeOriginal(photo.filePath),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final taken = snapshot.hasError
                ? 'Not available'
                : (snapshot.data ?? 'Not available');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(photo.filePath),
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Text('Preview unavailable'));
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText('Taken: $taken'),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<String?> _readDateTimeOriginal(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final exif = await readExifFromBytes(bytes);
    if (exif.isEmpty) {
      return null;
    }
    final value = exif['EXIF DateTimeOriginal']?.printable;
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }
}
