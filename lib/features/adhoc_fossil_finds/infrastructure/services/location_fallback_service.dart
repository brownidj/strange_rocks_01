import 'package:geolocator/geolocator.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/lat_lng.dart';

enum DeviceLocationPermissionStatus {
  denied,
  deniedForever,
  whileInUse,
  always,
}

class DeviceLocationPosition {
  const DeviceLocationPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}

abstract class DeviceLocationProvider {
  Future<bool> isServiceEnabled();
  Future<DeviceLocationPermissionStatus> checkPermission();
  Future<DeviceLocationPermissionStatus> requestPermission();
  Future<DeviceLocationPosition> getCurrentPosition();
}

class GeolocatorDeviceLocationProvider implements DeviceLocationProvider {
  const GeolocatorDeviceLocationProvider();

  @override
  Future<bool> isServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<DeviceLocationPermissionStatus> checkPermission() async {
    final permission = await Geolocator.checkPermission();
    return _mapPermission(permission);
  }

  @override
  Future<DeviceLocationPermissionStatus> requestPermission() async {
    final permission = await Geolocator.requestPermission();
    return _mapPermission(permission);
  }

  @override
  Future<DeviceLocationPosition> getCurrentPosition() async {
    final position = await Geolocator.getCurrentPosition();
    return DeviceLocationPosition(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
    );
  }

  DeviceLocationPermissionStatus _mapPermission(LocationPermission permission) {
    return switch (permission) {
      LocationPermission.denied => DeviceLocationPermissionStatus.denied,
      LocationPermission.deniedForever =>
        DeviceLocationPermissionStatus.deniedForever,
      LocationPermission.whileInUse =>
        DeviceLocationPermissionStatus.whileInUse,
      LocationPermission.always => DeviceLocationPermissionStatus.always,
      LocationPermission.unableToDetermine =>
        DeviceLocationPermissionStatus.denied,
    };
  }
}

class FallbackLocationResult {
  const FallbackLocationResult({
    required this.metadataLocation,
    required this.fallbackLocation,
    required this.fallbackAttempted,
    required this.warningMessage,
  });

  final LatLng? metadataLocation;
  final LatLng? fallbackLocation;
  final bool fallbackAttempted;
  final String? warningMessage;

  LatLng? get effectiveLocation => metadataLocation ?? fallbackLocation;

  bool get locationWarning => effectiveLocation == null;
}

class LocationFallbackService {
  LocationFallbackService({
    DeviceLocationProvider? provider,
    this.maxAcceptedAccuracyMeters = 50,
  }) : _provider = provider ?? const GeolocatorDeviceLocationProvider();

  final DeviceLocationProvider _provider;
  final double maxAcceptedAccuracyMeters;

  Future<FallbackLocationResult> resolveForPhoto({
    required LatLng? metadataLocation,
  }) async {
    if (metadataLocation != null) {
      return FallbackLocationResult(
        metadataLocation: metadataLocation,
        fallbackLocation: null,
        fallbackAttempted: false,
        warningMessage: null,
      );
    }

    final enabled = await _provider.isServiceEnabled();
    if (!enabled) {
      return const FallbackLocationResult(
        metadataLocation: null,
        fallbackLocation: null,
        fallbackAttempted: true,
        warningMessage: 'Location services are disabled.',
      );
    }

    var permission = await _provider.checkPermission();
    if (permission == DeviceLocationPermissionStatus.denied) {
      permission = await _provider.requestPermission();
    }

    if (permission == DeviceLocationPermissionStatus.deniedForever) {
      return const FallbackLocationResult(
        metadataLocation: null,
        fallbackLocation: null,
        fallbackAttempted: true,
        warningMessage: 'Location permission denied permanently.',
      );
    }

    if (permission == DeviceLocationPermissionStatus.denied) {
      return const FallbackLocationResult(
        metadataLocation: null,
        fallbackLocation: null,
        fallbackAttempted: true,
        warningMessage: 'Location permission denied.',
      );
    }

    final position = await _provider.getCurrentPosition();
    if (position.accuracyMeters > maxAcceptedAccuracyMeters) {
      return FallbackLocationResult(
        metadataLocation: null,
        fallbackLocation: null,
        fallbackAttempted: true,
        warningMessage:
            'Location accuracy too low (${position.accuracyMeters.toStringAsFixed(1)} m).',
      );
    }

    return FallbackLocationResult(
      metadataLocation: null,
      fallbackLocation: LatLng(
        latitude: position.latitude,
        longitude: position.longitude,
      ),
      fallbackAttempted: true,
      warningMessage: null,
    );
  }
}
