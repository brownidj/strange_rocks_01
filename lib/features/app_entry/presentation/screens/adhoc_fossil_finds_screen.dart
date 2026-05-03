import 'dart:async';
import 'dart:io';

import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_collection_event.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_photo_series.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/adhoc_series_photo.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/photo_capture_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/presentation/controllers/adhoc_fossil_finds_controller.dart';

part 'adhoc_fossil_finds_screen_actions.dart';
part 'adhoc_fossil_finds_screen_event_list.dart';
part 'adhoc_fossil_finds_screen_gps.dart';
part 'adhoc_fossil_finds_screen_gps_dialog.dart';
part 'adhoc_fossil_finds_screen_widgets.dart';
part 'adhoc_fossil_finds_screen_series.dart';

const String _noSeriesHelpText =
    'No series for the collection event has been started yet.\n\n'
    'Take a picture or select a photo to start your first series.\n\n'
    'Collection events contain 1 or more series of photos. Each series can '
    'contain up to 20 pictures.\n\n'
    'A new series starts either when you choose to start one, or when the '
    'limit of 20 pictures is reached or when you have moved your position '
    'more than about 50 metres. This happens automatically - you do not need '
    'to do anything unless you specifically want to start a new series.';

class AdhocFossilFindsScreen extends StatefulWidget {
  const AdhocFossilFindsScreen({required this.controller, super.key});

  final AdhocFossilFindsController controller;

  @override
  State<AdhocFossilFindsScreen> createState() => _AdhocFossilFindsScreenState();
}

class _AdhocFossilFindsScreenState extends State<AdhocFossilFindsScreen> {
  late final TextEditingController _eventBaseNameController;
  final GlobalKey<TooltipState> _finishTooltipKey = GlobalKey<TooltipState>();
  Timer? _statusTimer;
  bool _isGpsReady = false;
  bool _hasCompletedCollectionEvents = false;
  int _selectedSeriesIndex = 0;
  int _lastNonEmptySeriesCount = 0;

  @override
  void initState() {
    super.initState();
    _eventBaseNameController = TextEditingController(
      text: widget.controller.collectionEventBaseName,
    );
    widget.controller.addListener(_handleControllerChanged);
    widget.controller.ensureActiveEvent();
    _refreshCompletedEventsAvailability();
    _refreshConnectionStatus();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshConnectionStatus(),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    widget.controller.removeListener(_handleControllerChanged);
    _eventBaseNameController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    unawaited(_refreshCompletedEventsAvailability());
  }

  Future<void> _refreshCompletedEventsAvailability() async {
    final activeEventId = widget.controller.currentEvent?.id;
    final events = await widget.controller.listCollectionEvents();
    final hasCompleted = events.any(
      (event) =>
          event.id != activeEventId &&
          event.series.any((photoSeries) => photoSeries.photos.isNotEmpty),
    );
    if (!mounted || hasCompleted == _hasCompletedCollectionEvents) {
      return;
    }
    setState(() {
      _hasCompletedCollectionEvents = hasCompleted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final series = controller.series;
        final firstSeriesHasPhoto =
            series.isNotEmpty && series.first.photos.isNotEmpty;
        final hasAtLeastOnePhoto = series.any(
          (photoSeries) => photoSeries.photos.isNotEmpty,
        );
        final nonEmptySeries = series
            .where((photoSeries) => photoSeries.photos.isNotEmpty)
            .toList(growable: false);
        if (nonEmptySeries.length > _lastNonEmptySeriesCount) {
          _selectedSeriesIndex = nonEmptySeries.length - 1;
        }
        if (_selectedSeriesIndex >= nonEmptySeries.length) {
          _selectedSeriesIndex = nonEmptySeries.isEmpty
              ? 0
              : nonEmptySeries.length - 1;
        }
        _lastNonEmptySeriesCount = nonEmptySeries.length;

        if (_eventBaseNameController.text !=
            controller.collectionEventBaseName) {
          _eventBaseNameController.text = controller.collectionEventBaseName;
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Expanded(child: Text('Adhoc fossil finds')),
                _GpsIconButton(
                  isReady: _isGpsReady,
                  onPressed: _isGpsReady ? null : _handleGpsPressed,
                  onLongPressed: _handleGpsLongPressed,
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EventHeader(
                    eventNameController: _eventBaseNameController,
                    eventNameSuffix: controller.collectionEventSuffix,
                    isLoading: controller.isLoading,
                    onEventNameChanged: controller.updateCollectionEventName,
                    onHelpPressed: _showNameHelp,
                    onListPressed: _hasCompletedCollectionEvents
                        ? _openCollectionEventsList
                        : null,
                  ),
                  if (controller.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    _MessageBanner(
                      message: controller.errorMessage!,
                      background: const Color(0xFFFDE8E7),
                      foreground: const Color(0xFF9B1C1C),
                    ),
                  ],
                  if (controller.infoMessage != null) ...[
                    const SizedBox(height: 12),
                    _MessageBanner(
                      message: controller.infoMessage!,
                      background: const Color(0xFFEAF6EE),
                      foreground: const Color(0xFF1E4D2B),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ActionRow(
                    canAct: controller.hasActiveEvent && !controller.isLoading,
                    onAddFromCamera: () =>
                        controller.addPhoto(source: PhotoCaptureSource.camera),
                    onAddFromGallery: () =>
                        controller.addPhoto(source: PhotoCaptureSource.gallery),
                  ),
                  const SizedBox(height: 12),
                  _CompletionStatusBanner(
                    summary: controller.getCompletionValidationSummary(),
                    hasActiveEvent: controller.hasActiveEvent,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: hasAtLeastOnePhoto
                        ? _SingleSeriesViewer(
                            series: nonEmptySeries,
                            selectedIndex: _selectedSeriesIndex,
                            onPhotoSelected: _showExifModal,
                            onSelectedIndexChanged: (index) {
                              setState(() {
                                _selectedSeriesIndex = index;
                              });
                            },
                          )
                        : const Center(child: Text(_noSeriesHelpText)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (firstSeriesHasPhoto)
                        OutlinedButton.icon(
                          onPressed:
                              controller.hasActiveEvent && !controller.isLoading
                              ? controller.startNewSeries
                              : null,
                          icon: const Icon(Icons.library_add),
                          label: const Text('New series'),
                        ),
                      const Spacer(),
                      if (firstSeriesHasPhoto)
                        Tooltip(
                          key: _finishTooltipKey,
                          message:
                              'Runs final validation and cleanup, then '
                              'prepares this collection event for server '
                              'upload so fossil identification can begin.',
                          triggerMode: TooltipTriggerMode.manual,
                          child: FilledButton.tonalIcon(
                            onPressed:
                                controller.hasActiveEvent &&
                                    !controller.isLoading &&
                                    hasAtLeastOnePhoto
                                ? _handleFinishPressed
                                : null,
                            onLongPress: _showFinishTooltip,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Finish event'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
