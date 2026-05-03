import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class AppEntrySplashScreen extends StatefulWidget {
  const AppEntrySplashScreen({
    required this.onAdhocFossilFinds,
    required this.onFossilHuntingAdventure,
    required this.onPermissionsSettings,
    super.key,
  });

  final VoidCallback onAdhocFossilFinds;
  final VoidCallback onFossilHuntingAdventure;
  final VoidCallback onPermissionsSettings;

  @override
  State<AppEntrySplashScreen> createState() => _AppEntrySplashScreenState();
}

class _AppEntrySplashScreenState extends State<AppEntrySplashScreen>
    with WidgetsBindingObserver {
  String _versionBuildLabel = '';
  bool _showPermissionsSettings = true;
  bool _cameraGranted = false;
  bool _locationGranted = false;
  bool _gpsEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshMetadataAndPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshMetadataAndPermissions();
    }
  }

  Future<void> _refreshMetadataAndPermissions() async {
    await Future.wait<void>([
      _refreshVersionBuildLabel(),
      _refreshPermissionsChipVisibility(),
    ]);
  }

  Future<void> _refreshVersionBuildLabel() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) {
        return;
      }
      setState(() {
        _versionBuildLabel =
            'v${packageInfo.version}+${packageInfo.buildNumber}';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _versionBuildLabel = '';
      });
    }
  }

  Future<void> _refreshPermissionsChipVisibility() async {
    final cameraGranted = await Permission.camera.status.isGranted;
    final locationGranted = await Permission.locationWhenInUse.status.isGranted;
    final gpsEnabled = await Geolocator.isLocationServiceEnabled();
    final shouldShow = !(cameraGranted && locationGranted && gpsEnabled);

    if (!mounted) {
      return;
    }
    setState(() {
      _cameraGranted = cameraGranted;
      _locationGranted = locationGranted;
      _gpsEnabled = gpsEnabled;
      _showPermissionsSettings = shouldShow;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = _versionBuildLabel.isEmpty
        ? 'Strange Rocks'
        : 'Strange Rocks $_versionBuildLabel';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/fish_04.png', fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Center(
                    child: _ServiceStatusPanel(
                      cameraGranted: _cameraGranted,
                      locationGranted: _locationGranted,
                      gpsEnabled: _gpsEnabled,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: Tooltip(
                      message: 'Use this to record adhoc fossil finds.',
                      triggerMode: TooltipTriggerMode.longPress,
                      child: ElevatedButton(
                        onPressed: widget.onAdhocFossilFinds,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF88CC9B),
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('I think I found a fossil!'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: Tooltip(
                      message:
                          'Use this to plan and execute a fossil hunting trip.',
                      triggerMode: TooltipTriggerMode.longPress,
                      child: ElevatedButton(
                        onPressed: widget.onFossilHuntingAdventure,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF23402C),
                        ),
                        child: const Text(
                          'Plan and execute a fossil finding trip',
                        ),
                      ),
                    ),
                  ),
                  if (_showPermissionsSettings) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: widget.onPermissionsSettings,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                        child: const Text('Permissions & settings'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceStatusPanel extends StatelessWidget {
  const _ServiceStatusPanel({
    required this.cameraGranted,
    required this.locationGranted,
    required this.gpsEnabled,
  });

  final bool cameraGranted;
  final bool locationGranted;
  final bool gpsEnabled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusRow(
              label: 'Camera',
              ok: cameraGranted,
              okText: 'On',
              failText: 'Off',
            ),
            const SizedBox(height: 6),
            _StatusRow(
              label: 'Location/GPS',
              ok: locationGranted && gpsEnabled,
              okText: 'On',
              failText: 'Off',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.ok,
    required this.okText,
    required this.failText,
  });

  final String label;
  final bool ok;
  final String okText;
  final String failText;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.circle,
          size: 10,
          color: ok ? Colors.greenAccent : Colors.redAccent,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ${ok ? okText : failText}',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }
}
