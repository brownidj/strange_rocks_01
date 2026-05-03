part of 'field_area_define_screen.dart';

enum _AreaSelectionMode { region, pins }

class _RegionBounds {
  const _RegionBounds({
    required this.minLon,
    required this.minLat,
    required this.maxLon,
    required this.maxLat,
  });

  final double minLon;
  final double minLat;
  final double maxLon;
  final double maxLat;

  _RegionBounds centeredZoomIn({
    required double centerLon,
    required double centerLat,
  }) {
    final width = maxLon - minLon;
    final height = maxLat - minLat;
    final nextWidth = width / 2;
    final nextHeight = height / 2;
    return _RegionBounds(
      minLon: centerLon - (nextWidth / 2),
      minLat: centerLat - (nextHeight / 2),
      maxLon: centerLon + (nextWidth / 2),
      maxLat: centerLat + (nextHeight / 2),
    );
  }

  Map<String, Object?> toFeatureCollection() {
    final ring = <List<double>>[
      <double>[minLon, minLat],
      <double>[maxLon, minLat],
      <double>[maxLon, maxLat],
      <double>[minLon, maxLat],
      <double>[minLon, minLat],
    ];
    return <String, Object?>{
      'type': 'FeatureCollection',
      'features': <Object?>[
        <String, Object?>{
          'type': 'Feature',
          'properties': <String, Object?>{},
          'geometry': <String, Object?>{
            'type': 'Polygon',
            'coordinates': <Object?>[ring],
          },
        },
      ],
    };
  }

  String toBBoxText() {
    return '${minLon.toStringAsFixed(4)}, ${minLat.toStringAsFixed(4)} '
        'to ${maxLon.toStringAsFixed(4)}, ${maxLat.toStringAsFixed(4)}';
  }
}

class _GeoPoint {
  const _GeoPoint({required this.lon, required this.lat});

  final double lon;
  final double lat;
}
