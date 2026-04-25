import 'package:flutter/material.dart';
import 'package:strange_rocks_01/features/field_packs/presentation/controllers/field_pack_controller.dart';

class FieldAreaDefineScreen extends StatefulWidget {
  const FieldAreaDefineScreen({super.key, required this.controller});

  final FieldPackController controller;

  @override
  State<FieldAreaDefineScreen> createState() => _FieldAreaDefineScreenState();
}

class _FieldAreaDefineScreenState extends State<FieldAreaDefineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _geoJsonController = TextEditingController(
    text: '{"type":"FeatureCollection","features":[]}',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _geoJsonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await widget.controller.importAreaAndDownload(
      areaName: _nameController.text.trim(),
      geoJsonRaw: _geoJsonController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (widget.controller.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.controller.errorMessage!)));
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Define Field Area')),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          return AbsorbPointer(
            absorbing: widget.controller.isLoading,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
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
                    Expanded(
                      child: TextFormField(
                        controller: _geoJsonController,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        decoration: const InputDecoration(
                          alignLabelWithHint: true,
                          labelText: 'GeoJSON',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'GeoJSON is required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.download),
                        label: Text(
                          widget.controller.isLoading
                              ? 'Generating Pack...'
                              : 'Generate and Download Pack',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
