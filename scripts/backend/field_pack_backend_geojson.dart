import 'dart:math';

List<double>? extractBboxFromGeoJson(Map<String, Object?> geojson) {
  final coords = <List<double>>[];
  void scan(Object? node) {
    if (node is List && node.length >= 2 && node[0] is num && node[1] is num) {
      coords.add(<double>[(node[0] as num).toDouble(), (node[1] as num).toDouble()]);
      return;
    }
    if (node is List) {
      for (final child in node) {
        scan(child);
      }
    }
    if (node is Map<String, Object?>) {
      for (final value in node.values) {
        scan(value);
      }
    }
  }

  scan(geojson);
  if (coords.isEmpty) return null;
  final minLon = coords.map((c) => c[0]).reduce(min);
  final minLat = coords.map((c) => c[1]).reduce(min);
  final maxLon = coords.map((c) => c[0]).reduce(max);
  final maxLat = coords.map((c) => c[1]).reduce(max);
  return <double>[minLon, minLat, maxLon, maxLat];
}
