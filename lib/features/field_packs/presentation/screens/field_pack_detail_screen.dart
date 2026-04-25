import 'package:flutter/material.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack.dart';
import 'package:strange_rocks_01/features/field_packs/presentation/controllers/field_pack_controller.dart';
import 'package:strange_rocks_01/features/field_packs/presentation/models/field_pack_notes.dart';

class FieldPackDetailScreen extends StatefulWidget {
  const FieldPackDetailScreen({
    super.key,
    required this.controller,
    required this.pack,
  });

  final FieldPackController controller;
  final FieldPack pack;

  @override
  State<FieldPackDetailScreen> createState() => _FieldPackDetailScreenState();
}

class _FieldPackDetailScreenState extends State<FieldPackDetailScreen> {
  FieldPackNotes? _notes;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await widget.controller.loadPackNotes(widget.pack);
    if (!mounted) {
      return;
    }
    setState(() {
      _notes = notes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.pack;

    return Scaffold(
      appBar: AppBar(title: Text(pack.id)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Status: ${pack.status.name}'),
          const SizedBox(height: 8),
          Text('Version: ${pack.version}'),
          const SizedBox(height: 8),
          Text('Created (UTC): ${pack.createdAtUtc}'),
          const SizedBox(height: 8),
          Text('Active: ${pack.isActive ? 'Yes' : 'No'}'),
          const SizedBox(height: 16),
          const Text('Assets', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...pack.manifest.assets.map(
            (asset) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(asset.path),
              subtitle: Text('${asset.kind} - ${asset.sizeBytes} bytes'),
            ),
          ),
          const Divider(height: 24),
          const Text(
            'Instructions',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SelectableText(_notes?.instructions ?? 'Loading...'),
          const Divider(height: 24),
          const Text(
            'Safety Notes',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SelectableText(_notes?.safetyNotes ?? 'Loading...'),
          const Divider(height: 24),
          const Text(
            'License Attribution',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SelectableText(_notes?.licenseAttribution ?? 'Loading...'),
        ],
      ),
    );
  }
}
