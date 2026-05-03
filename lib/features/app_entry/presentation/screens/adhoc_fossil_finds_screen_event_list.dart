part of 'adhoc_fossil_finds_screen.dart';

class _CollectionEventsListScreen extends StatefulWidget {
  const _CollectionEventsListScreen({required this.controller});

  final AdhocFossilFindsController controller;

  @override
  State<_CollectionEventsListScreen> createState() =>
      _CollectionEventsListScreenState();
}

class _CollectionEventsListScreenState
    extends State<_CollectionEventsListScreen> {
  late Future<List<AdhocCollectionEvent>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = widget.controller.listCollectionEvents();
  }

  Future<void> _deleteEvent(String eventId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Are you sure?'),
          content: const Text(
            'This will permanently delete this collection event.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) {
      return;
    }

    await widget.controller.deleteCollectionEvent(eventId);
    if (!mounted) {
      return;
    }
    setState(() {
      _eventsFuture = widget.controller.listCollectionEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Completed collection events')),
      body: FutureBuilder<List<AdhocCollectionEvent>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load events: ${snapshot.error}'),
              ),
            );
          }

          final activeEventId = widget.controller.currentEvent?.id;
          final events = (snapshot.data ?? const <AdhocCollectionEvent>[])
              .where(
                (event) =>
                    event.id != activeEventId &&
                    event.series.any(
                      (photoSeries) => photoSeries.photos.isNotEmpty,
                    ),
              )
              .toList(growable: false);
          if (events.isEmpty) {
            return const Center(
              child: Text('No completed collection events yet.'),
            );
          }

          return ListView.separated(
            itemCount: events.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final event = events[index];
              final createdLocal = event.createdAtUtc.toLocal();
              final photoCount = event.series.fold<int>(
                0,
                (total, photoSeries) => total + photoSeries.photos.length,
              );

              return ListTile(
                title: Text(event.name),
                subtitle: Text(
                  '${createdLocal.year.toString().padLeft(4, '0')}-'
                  '${createdLocal.month.toString().padLeft(2, '0')}-'
                  '${createdLocal.day.toString().padLeft(2, '0')}'
                  ' | ${event.series.length} series | $photoCount photos',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Tooltip(
                      message: 'Not synced with server',
                      child: Icon(Icons.cloud_off, color: Colors.red),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      label: const Text('Delete'),
                      onPressed: () => _deleteEvent(event.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
