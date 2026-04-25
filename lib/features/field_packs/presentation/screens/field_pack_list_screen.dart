import 'package:flutter/material.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack.dart';
import 'package:strange_rocks_01/features/field_packs/presentation/controllers/field_pack_controller.dart';
import 'package:strange_rocks_01/features/field_packs/presentation/screens/field_area_define_screen.dart';
import 'package:strange_rocks_01/features/field_packs/presentation/screens/field_pack_detail_screen.dart';

class FieldPackListScreen extends StatefulWidget {
  const FieldPackListScreen({super.key, required this.controller});

  final FieldPackController controller;

  @override
  State<FieldPackListScreen> createState() => _FieldPackListScreenState();
}

class _FieldPackListScreenState extends State<FieldPackListScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadPacks();
  }

  Future<void> _openAreaDefinition() async {
    final refreshed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FieldAreaDefineScreen(controller: widget.controller),
      ),
    );

    if (refreshed == true) {
      await widget.controller.loadPacks();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Field pack downloaded successfully.')),
      );
    }
  }

  Future<void> _openPackDetails(FieldPack pack) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            FieldPackDetailScreen(controller: widget.controller, pack: pack),
      ),
    );
    await widget.controller.loadPacks();
  }

  Future<void> _confirmActivate(FieldPack pack) async {
    final notes = await widget.controller.loadPackNotes(pack);
    if (!mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Activate Field Pack'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Review safety and licensing before activation.'),
                  const SizedBox(height: 12),
                  const Text(
                    'Safety Notes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(notes.safetyNotes),
                  const SizedBox(height: 12),
                  const Text(
                    'License Attribution',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(notes.licenseAttribution),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Activate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await widget.controller.activatePack(pack.id);
    if (!mounted) {
      return;
    }

    final error = widget.controller.errorMessage;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Pack activated.')));
  }

  Future<void> _confirmDelete(FieldPack pack) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Field Pack'),
          content: Text('Delete pack "${pack.id}" from local storage?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await widget.controller.deletePack(pack);
    if (!mounted) {
      return;
    }

    final error = widget.controller.errorMessage;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Pack deleted.')));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Field Packs')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: widget.controller.isLoading ? null : _openAreaDefinition,
            icon: const Icon(Icons.add_location_alt),
            label: const Text('Define Area'),
          ),
          body: Column(
            children: [
              if (widget.controller.errorMessage != null)
                MaterialBanner(
                  content: Text(widget.controller.errorMessage!),
                  actions: [
                    TextButton(
                      onPressed: widget.controller.loadPacks,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              Expanded(
                child: widget.controller.packs.isEmpty
                    ? const Center(
                        child: Text(
                          'No field packs yet. Tap "Define Area" to import GeoJSON and download one.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: widget.controller.loadPacks,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: widget.controller.packs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final pack = widget.controller.packs[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            pack.id,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        _statusChip(pack.status),
                                        if (pack.isActive)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 8),
                                            child: Chip(label: Text('Active')),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Created: ${pack.createdAtUtc}'),
                                    if (pack.downloadedAtUtc != null)
                                      Text(
                                        'Downloaded: ${pack.downloadedAtUtc}',
                                      ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        OutlinedButton(
                                          onPressed: () =>
                                              _openPackDetails(pack),
                                          child: const Text('Details'),
                                        ),
                                        if (pack.status ==
                                                FieldPackStatus.ready ||
                                            pack.status ==
                                                FieldPackStatus.active)
                                          FilledButton(
                                            onPressed: pack.isActive
                                                ? null
                                                : () => _confirmActivate(pack),
                                            child: const Text('Activate'),
                                          ),
                                        OutlinedButton(
                                          onPressed: () => _confirmDelete(pack),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              if (widget.controller.isLoading)
                const LinearProgressIndicator(minHeight: 2),
            ],
          ),
        );
      },
    );
  }

  Widget _statusChip(FieldPackStatus status) {
    final color = switch (status) {
      FieldPackStatus.downloading => Colors.orange,
      FieldPackStatus.ready => Colors.green,
      FieldPackStatus.active => Colors.blue,
      FieldPackStatus.invalid => Colors.red,
    };

    return Chip(
      side: BorderSide.none,
      backgroundColor: color.withValues(alpha: 0.16),
      label: Text(status.name),
    );
  }
}
