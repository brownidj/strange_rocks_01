part of 'adhoc_fossil_finds_screen.dart';

enum _GpsAcquisitionStage {
  acquiring,
  needsServiceEnabled,
  needsPermission,
  needsAppSettings,
  failed,
}

class _GpsAcquisitionDialog extends StatefulWidget {
  const _GpsAcquisitionDialog({required this.onAcquired});

  final VoidCallback onAcquired;

  @override
  State<_GpsAcquisitionDialog> createState() => _GpsAcquisitionDialogState();
}

class _GpsAcquisitionDialogState extends State<_GpsAcquisitionDialog> {
  _GpsAcquisitionStage _stage = _GpsAcquisitionStage.acquiring;
  String _message = 'Please wait. Acquiring GPS signal...';

  @override
  void initState() {
    super.initState();
    _acquireGps();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('GPS status'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_stage == _GpsAcquisitionStage.acquiring) ...[
              const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 12),
            ],
            Text(_message),
          ],
        ),
      ),
      actions: _buildActions(context),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final widgets = <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Abandon'),
      ),
    ];

    switch (_stage) {
      case _GpsAcquisitionStage.needsServiceEnabled:
        widgets.add(
          FilledButton(
            onPressed: () async {
              await Geolocator.openLocationSettings();
              await _acquireGps();
            },
            child: const Text('Turn on GPS'),
          ),
        );
        break;
      case _GpsAcquisitionStage.needsPermission:
        widgets.add(
          FilledButton(onPressed: _acquireGps, child: const Text('Allow GPS')),
        );
        break;
      case _GpsAcquisitionStage.needsAppSettings:
        widgets.add(
          FilledButton(
            onPressed: () async {
              await Geolocator.openAppSettings();
              await _acquireGps();
            },
            child: const Text('Open settings'),
          ),
        );
        break;
      case _GpsAcquisitionStage.failed:
        widgets.add(
          FilledButton(onPressed: _acquireGps, child: const Text('Retry')),
        );
        break;
      case _GpsAcquisitionStage.acquiring:
        break;
    }

    return widgets;
  }

  Future<void> _acquireGps() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _stage = _GpsAcquisitionStage.acquiring;
      _message = 'Please wait. Acquiring GPS signal...';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }
        setState(() {
          _stage = _GpsAcquisitionStage.needsServiceEnabled;
          _message =
              'GPS is off. Please allow location services to be turned on for camera geotagging.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }
        setState(() {
          _stage = _GpsAcquisitionStage.needsAppSettings;
          _message =
              'Location permission is permanently denied. Open settings and allow location access.';
        });
        return;
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) {
          return;
        }
        setState(() {
          _stage = _GpsAcquisitionStage.needsPermission;
          _message = 'Location permission is required to acquire GPS.';
        });
        return;
      }

      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) {
        return;
      }
      widget.onAcquired();
      Navigator.of(context).pop();
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      setState(() {
        _stage = _GpsAcquisitionStage.failed;
        _message = 'GPS signal not available yet. Please wait or retry.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _stage = _GpsAcquisitionStage.failed;
        _message = 'Unable to acquire GPS right now. Please retry or abandon.';
      });
    }
  }
}
