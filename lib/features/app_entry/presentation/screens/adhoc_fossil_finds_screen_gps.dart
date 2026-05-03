part of 'adhoc_fossil_finds_screen.dart';

extension _AdhocFossilFindsScreenGps on _AdhocFossilFindsScreenState {
  Future<void> _handleGpsPressed() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _GpsAcquisitionDialog(
          onAcquired: () {
            if (!mounted) {
              return;
            }
            setState(() {
              _isGpsReady = true;
            });
          },
        );
      },
    );
    await _refreshConnectionStatus();
  }

  Future<void> _handleGpsLongPressed() async {
    if (_isGpsReady) {
      await showDialog<void>(
        context: context,
        builder: (context) => const _GpsPositionDialog(),
      );
      return;
    }
    await _handleGpsPressed();
  }

  Future<void> _refreshConnectionStatus() async {
    bool gpsReady = false;

    try {
      gpsReady = await _isGpsAvailableForCamera();
    } catch (_) {
      gpsReady = false;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isGpsReady = gpsReady;
    });
  }

  Future<bool> _isGpsAvailableForCamera() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}

class _GpsIconButton extends StatelessWidget {
  const _GpsIconButton({
    required this.isReady,
    required this.onPressed,
    required this.onLongPressed,
  });

  final bool isReady;
  final VoidCallback? onPressed;
  final VoidCallback onLongPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed ?? () {},
      onLongPress: onLongPressed,
      tooltip: isReady ? 'GPS ready' : 'GPS unavailable',
      icon: Image.asset(
        isReady
            ? 'assets/images/icons/GPS-icon_green.png'
            : 'assets/images/icons/GPS-icon_red.png',
        width: 22,
        height: 22,
      ),
    );
  }
}

class _GpsPositionDialog extends StatelessWidget {
  const _GpsPositionDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('GPS position'),
      content: SizedBox(
        width: 320,
        child: FutureBuilder<Position>(
          future: Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Text('Unable to get current GPS position.');
            }
            final position = snapshot.data!;
            return SelectableText(
              'Latitude: ${position.latitude.toStringAsFixed(6)}\n'
              'Longitude: ${position.longitude.toStringAsFixed(6)}',
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
}
