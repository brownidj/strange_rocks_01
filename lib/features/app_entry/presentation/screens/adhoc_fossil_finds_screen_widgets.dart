part of 'adhoc_fossil_finds_screen.dart';

class _EventHeader extends StatelessWidget {
  const _EventHeader({
    required this.eventNameController,
    required this.eventNameSuffix,
    required this.isLoading,
    required this.onEventNameChanged,
    required this.onHelpPressed,
    required this.onListPressed,
  });

  final TextEditingController eventNameController;
  final String eventNameSuffix;
  final bool isLoading;
  final ValueChanged<String> onEventNameChanged;
  final VoidCallback onHelpPressed;
  final VoidCallback? onListPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: eventNameController,
            enabled: !isLoading,
            onChanged: onEventNameChanged,
            decoration: InputDecoration(
              labelText: 'Collection event name',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                onPressed: onHelpPressed,
                tooltip: 'Collection event help',
                icon: const Text(
                  '?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            eventNameSuffix,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        if (onListPressed != null) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: onListPressed,
            tooltip: 'Collection event list',
            icon: const Icon(Icons.list),
          ),
        ],
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.canAct,
    required this.onAddFromCamera,
    required this.onAddFromGallery,
  });

  final bool canAct;
  final VoidCallback onAddFromCamera;
  final VoidCallback onAddFromGallery;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: canAct ? onAddFromGallery : null,
              icon: const Icon(Icons.photo_library),
              label: const Text('Select photo'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: canAct ? onAddFromCamera : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF88CC9B),
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Take picture'),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompletionStatusBanner extends StatelessWidget {
  const _CompletionStatusBanner({
    required this.summary,
    required this.hasActiveEvent,
  });

  final EventCompletionValidationSummary summary;
  final bool hasActiveEvent;

  @override
  Widget build(BuildContext context) {
    if (!hasActiveEvent) {
      return const SizedBox.shrink();
    }

    if (summary.hasWarnings) {
      return _MessageBanner(
        message: summary.warningMessages.join(' '),
        background: const Color(0xFFFFF6E8),
        foreground: const Color(0xFF9C5D00),
      );
    }

    return const SizedBox.shrink();
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.message,
    required this.background,
    required this.foreground,
  });

  final String message;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TextStyle(color: foreground)),
    );
  }
}
