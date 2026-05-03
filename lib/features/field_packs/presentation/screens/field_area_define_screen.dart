import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_area.dart';
import 'package:strange_rocks_01/features/field_packs/presentation/controllers/field_pack_controller.dart';

part 'field_area_define_screen_models.dart';
part 'field_area_define_screen_interactions.dart';
part 'field_area_define_screen_widgets.dart';
part 'field_area_define_screen_painter.dart';

class FieldAreaDefineScreen extends StatefulWidget {
  const FieldAreaDefineScreen({super.key, required this.controller});

  final FieldPackController controller;

  @override
  State<FieldAreaDefineScreen> createState() => _FieldAreaDefineScreenState();
}

class _FieldAreaDefineScreenState extends State<FieldAreaDefineScreen> {
  static const _maxTapZoomSteps = 8;
  static const _baseRegionLevel = 7;
  static const _qldBounds = _RegionBounds(
    minLon: 137.95,
    minLat: -29.20,
    maxLon: 153.65,
    maxLat: -9.10,
  );

  static const _previewImageServer =
      'https://spatial-img.information.qld.gov.au/arcgis/rest/services/Basemaps/LatestSatelliteWOS_AllUsers/ImageServer';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _geoJsonController = TextEditingController();

  FieldImagerySource _imagerySource = FieldImagerySource.qimageryAerial;
  _AreaSelectionMode _selectionMode = _AreaSelectionMode.region;
  _RegionBounds _regionBounds = _qldBounds;
  int _regionLevel = _baseRegionLevel;
  List<_RegionBounds> _trail = const <_RegionBounds>[];
  List<_GeoPoint> _pins = const <_GeoPoint>[];
  Offset? _mapPointerDownLocal;
  bool _mapPointerMoved = false;

  @override
  void initState() {
    super.initState();
    _applyRegionToGeoJson();
  }

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
      imagerySource: _imagerySource,
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
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final bottomInset = MediaQuery.of(context).viewPadding.bottom;
        return Scaffold(
          appBar: AppBar(title: const Text('Define Region')),
          body: AbsorbPointer(
            absorbing: widget.controller.isLoading,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      _buildIntro(context),
                      const SizedBox(height: 10),
                      _buildSelectionModeChips(),
                      const SizedBox(height: 10),
                      _buildZoomStatus(context),
                      const SizedBox(height: 10),
                      _buildPreviewMap(),
                      const SizedBox(height: 10),
                      _buildRegionActions(),
                      const SizedBox(height: 8),
                      _buildPinsActions(),
                      const SizedBox(height: 6),
                      _buildModeHint(context),
                      const SizedBox(height: 16),
                      _buildFormFields(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            minimum: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.controller.isLoading ? null : _submit,
                icon: const Icon(Icons.download),
                label: Text(
                  widget.controller.isLoading
                      ? 'Generating Pack...'
                      : 'Generate and Download Pack',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
