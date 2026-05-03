part of 'adhoc_fossil_finds_screen.dart';

extension _AdhocFossilFindsScreenActions on _AdhocFossilFindsScreenState {
  Future<void> _openCollectionEventsList() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _CollectionEventsListScreen(controller: widget.controller),
      ),
    );
    await _refreshCompletedEventsAvailability();
  }

  void _showFinishTooltip() {
    _finishTooltipKey.currentState?.ensureTooltipVisible();
  }

  Future<void> _handleFinishPressed() async {
    final controller = widget.controller;
    final summary = controller.getCompletionValidationSummary();
    if (summary.hasBlockingIssues) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Cannot finish event'),
            content: Text(summary.blockingIssues.join('\n')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    if (summary.hasWarnings) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Finish with warnings?'),
            content: Text(summary.warningMessages.join('\n')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Finish event'),
              ),
            ],
          );
        },
      );
      if (proceed != true) {
        return;
      }
    }

    await controller.finishEvent();
  }

  Future<void> _showNameHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: const Text('Take a photo to start a Collection event'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showExifModal(AdhocSeriesPhoto photo) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _ExifDataDialog(photo: photo),
    );
  }
}
