import 'package:flutter_test/flutter_test.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/lat_lng.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/location_fallback_service.dart';

void main() {
  test('does not request fallback when metadata location exists', () async {
    final provider = _FakeDeviceLocationProvider();
    final service = LocationFallbackService(provider: provider);

    final result = await service.resolveForPhoto(
      metadataLocation: const LatLng(latitude: -19.258, longitude: 146.816),
    );

    expect(result.effectiveLocation, isNotNull);
    expect(result.locationWarning, isFalse);
    expect(result.fallbackAttempted, isFalse);
    expect(provider.serviceEnabledCalls, 0);
    expect(provider.checkPermissionCalls, 0);
    expect(provider.requestPermissionCalls, 0);
    expect(provider.getCurrentPositionCalls, 0);
  });

  test('returns warning when location services are disabled', () async {
    final provider = _FakeDeviceLocationProvider(serviceEnabled: false);
    final service = LocationFallbackService(provider: provider);

    final result = await service.resolveForPhoto(metadataLocation: null);

    expect(result.effectiveLocation, isNull);
    expect(result.locationWarning, isTrue);
    expect(result.fallbackAttempted, isTrue);
    expect(result.warningMessage, contains('disabled'));
  });

  test('returns warning when permission denied forever', () async {
    final provider = _FakeDeviceLocationProvider(
      initialPermission: DeviceLocationPermissionStatus.deniedForever,
    );
    final service = LocationFallbackService(provider: provider);

    final result = await service.resolveForPhoto(metadataLocation: null);

    expect(result.effectiveLocation, isNull);
    expect(result.locationWarning, isTrue);
    expect(result.warningMessage, contains('permanently'));
    expect(provider.requestPermissionCalls, 0);
  });

  test(
    'returns fallback location when permission granted and accuracy acceptable',
    () async {
      final provider = _FakeDeviceLocationProvider(
        initialPermission: DeviceLocationPermissionStatus.whileInUse,
        position: const DeviceLocationPosition(
          latitude: -19.258,
          longitude: 146.816,
          accuracyMeters: 12,
        ),
      );
      final service = LocationFallbackService(provider: provider);

      final result = await service.resolveForPhoto(metadataLocation: null);

      expect(result.effectiveLocation, isNotNull);
      expect(result.locationWarning, isFalse);
      expect(result.warningMessage, isNull);
      expect(result.effectiveLocation!.latitude, closeTo(-19.258, 0.000001));
      expect(result.effectiveLocation!.longitude, closeTo(146.816, 0.000001));
    },
  );

  test('returns warning when accuracy is worse than threshold', () async {
    final provider = _FakeDeviceLocationProvider(
      initialPermission: DeviceLocationPermissionStatus.always,
      position: const DeviceLocationPosition(
        latitude: -19.258,
        longitude: 146.816,
        accuracyMeters: 120,
      ),
    );
    final service = LocationFallbackService(
      provider: provider,
      maxAcceptedAccuracyMeters: 50,
    );

    final result = await service.resolveForPhoto(metadataLocation: null);

    expect(result.effectiveLocation, isNull);
    expect(result.locationWarning, isTrue);
    expect(result.warningMessage, contains('accuracy too low'));
  });

  test(
    'requests permission when initially denied and uses granted result',
    () async {
      final provider = _FakeDeviceLocationProvider(
        initialPermission: DeviceLocationPermissionStatus.denied,
        requestPermissionResult: DeviceLocationPermissionStatus.whileInUse,
        position: const DeviceLocationPosition(
          latitude: -19.258,
          longitude: 146.816,
          accuracyMeters: 10,
        ),
      );
      final service = LocationFallbackService(provider: provider);

      final result = await service.resolveForPhoto(metadataLocation: null);

      expect(result.effectiveLocation, isNotNull);
      expect(result.locationWarning, isFalse);
      expect(provider.requestPermissionCalls, 1);
      expect(provider.getCurrentPositionCalls, 1);
    },
  );
}

class _FakeDeviceLocationProvider implements DeviceLocationProvider {
  _FakeDeviceLocationProvider({
    this.serviceEnabled = true,
    this.initialPermission = DeviceLocationPermissionStatus.denied,
    this.requestPermissionResult = DeviceLocationPermissionStatus.denied,
    this.position = const DeviceLocationPosition(
      latitude: 0,
      longitude: 0,
      accuracyMeters: 5,
    ),
  });

  final bool serviceEnabled;
  final DeviceLocationPermissionStatus initialPermission;
  final DeviceLocationPermissionStatus requestPermissionResult;
  final DeviceLocationPosition position;

  int serviceEnabledCalls = 0;
  int checkPermissionCalls = 0;
  int requestPermissionCalls = 0;
  int getCurrentPositionCalls = 0;

  @override
  Future<bool> isServiceEnabled() async {
    serviceEnabledCalls += 1;
    return serviceEnabled;
  }

  @override
  Future<DeviceLocationPermissionStatus> checkPermission() async {
    checkPermissionCalls += 1;
    return initialPermission;
  }

  @override
  Future<DeviceLocationPermissionStatus> requestPermission() async {
    requestPermissionCalls += 1;
    return requestPermissionResult;
  }

  @override
  Future<DeviceLocationPosition> getCurrentPosition() async {
    getCurrentPositionCalls += 1;
    return position;
  }
}
