import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissionsScreen extends StatefulWidget {
  const AppPermissionsScreen({super.key});

  @override
  State<AppPermissionsScreen> createState() => _AppPermissionsScreenState();
}

class _AppPermissionsScreenState extends State<AppPermissionsScreen>
    with WidgetsBindingObserver {
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _locationStatus = PermissionStatus.denied;
  bool _locationServiceEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissionState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionState();
    }
  }

  Future<void> _refreshPermissionState() async {
    final cameraStatus = await Permission.camera.status;
    final locationStatus = await Permission.locationWhenInUse.status;
    final locationServiceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!mounted) {
      return;
    }
    setState(() {
      _cameraStatus = cameraStatus;
      _locationStatus = locationStatus;
      _locationServiceEnabled = locationServiceEnabled;
      _isLoading = false;
    });
  }

  Future<void> _requestCameraPermission() async {
    await Permission.camera.request();
    await _refreshPermissionState();
  }

  Future<void> _requestLocationPermission() async {
    await Permission.locationWhenInUse.request();
    await _refreshPermissionState();
  }

  Future<void> _openSystemAppSettings() async {
    await openAppSettings();
    await _refreshPermissionState();
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
    await _refreshPermissionState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Control camera and GPS permissions for this app. '
                  'If a permission is permanently denied, open app settings to change it.',
                ),
                const SizedBox(height: 16),
                _PermissionCard(
                  title: 'Camera',
                  statusText: _describeStatus(_cameraStatus),
                  statusColor: _statusColor(_cameraStatus),
                  primaryActionLabel: 'Request camera permission',
                  onPrimaryAction: _requestCameraPermission,
                ),
                const SizedBox(height: 12),
                _PermissionCard(
                  title: 'Location / GPS',
                  statusText:
                      '${_describeStatus(_locationStatus)}${_locationServiceEnabled ? ' (GPS on)' : ' (GPS off)'}',
                  statusColor: _locationServiceEnabled
                      ? _statusColor(_locationStatus)
                      : Colors.red,
                  primaryActionLabel: 'Request location permission',
                  onPrimaryAction: _requestLocationPermission,
                  secondaryActionLabel: 'Open location settings',
                  onSecondaryAction: _openLocationSettings,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _openSystemAppSettings,
                  child: const Text('Open app settings'),
                ),
              ],
            ),
    );
  }

  Color _statusColor(PermissionStatus status) {
    return switch (status) {
      PermissionStatus.granted => Colors.green,
      PermissionStatus.limited => Colors.green,
      PermissionStatus.provisional => Colors.amber,
      PermissionStatus.denied => Colors.red,
      PermissionStatus.restricted => Colors.red,
      PermissionStatus.permanentlyDenied => Colors.red,
    };
  }

  String _describeStatus(PermissionStatus status) {
    return switch (status) {
      PermissionStatus.granted => 'Granted',
      PermissionStatus.limited => 'Limited',
      PermissionStatus.provisional => 'Provisional',
      PermissionStatus.denied => 'Denied',
      PermissionStatus.restricted => 'Restricted',
      PermissionStatus.permanentlyDenied => 'Permanently denied',
    };
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.title,
    required this.statusText,
    required this.statusColor,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String statusText;
  final Color statusColor;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.circle, size: 12, color: statusColor),
                const SizedBox(width: 8),
                Text(statusText),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: onPrimaryAction,
                  child: Text(primaryActionLabel),
                ),
                if (secondaryActionLabel != null && onSecondaryAction != null)
                  OutlinedButton(
                    onPressed: onSecondaryAction,
                    child: Text(secondaryActionLabel!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
