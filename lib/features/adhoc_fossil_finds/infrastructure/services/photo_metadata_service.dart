import 'dart:io';

import 'package:exif/exif.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/domain/entities/lat_lng.dart';

class PhotoMetadata {
  const PhotoMetadata({
    required this.exifExtracted,
    this.capturedAtUtc,
    this.metadataLocation,
  });

  final bool exifExtracted;
  final DateTime? capturedAtUtc;
  final LatLng? metadataLocation;
}

class PhotoMetadataService {
  Future<PhotoMetadata> extractFromFilePath(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final exif = await readExifFromBytes(bytes);

    if (exif.isEmpty) {
      return const PhotoMetadata(exifExtracted: false);
    }

    final capturedAtUtc = _parseCapturedAt(exif);
    final metadataLocation = _parseMetadataLocation(exif);

    return PhotoMetadata(
      exifExtracted: true,
      capturedAtUtc: capturedAtUtc,
      metadataLocation: metadataLocation,
    );
  }

  DateTime? _parseCapturedAt(Map<String, IfdTag> exif) {
    final candidates = <String?>[
      _tagPrintable(exif, 'EXIF DateTimeOriginal'),
      _tagPrintable(exif, 'Image DateTime'),
    ];

    for (final raw in candidates) {
      if (raw == null || raw.trim().isEmpty) {
        continue;
      }
      final normalized = raw.trim().replaceAll(':', '-');
      final parts = normalized.split(' ');
      if (parts.length != 2) {
        continue;
      }
      final date = parts.first;
      final time = parts.last;
      final dateParts = date.split('-');
      if (dateParts.length < 3) {
        continue;
      }

      final reparsed = '${dateParts[0]}-${dateParts[1]}-${dateParts[2]} $time';
      final parsed = DateTime.tryParse(reparsed.replaceFirst(' ', 'T'));
      if (parsed != null) {
        return parsed.toUtc();
      }
    }

    return null;
  }

  LatLng? _parseMetadataLocation(Map<String, IfdTag> exif) {
    final latRaw = _tagPrintable(exif, 'GPS GPSLatitude');
    final latRef = _tagPrintable(exif, 'GPS GPSLatitudeRef');
    final lngRaw = _tagPrintable(exif, 'GPS GPSLongitude');
    final lngRef = _tagPrintable(exif, 'GPS GPSLongitudeRef');

    final lat = _parseCoordinate(latRaw, latRef);
    final lng = _parseCoordinate(lngRaw, lngRef);
    if (lat == null || lng == null) {
      return null;
    }

    return LatLng(latitude: lat, longitude: lng);
  }

  String? _tagPrintable(Map<String, IfdTag> exif, String key) {
    final tag = exif[key];
    if (tag == null) {
      return null;
    }
    final printable = tag.printable;
    if (printable.trim().isEmpty) {
      return null;
    }
    return printable;
  }

  double? _parseCoordinate(String? rawValue, String? reference) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }

    final components = rawValue
        .replaceAll('[', '')
        .replaceAll(']', '')
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    if (components.isEmpty) {
      return null;
    }

    final values = components
        .map(_parseRationalOrDouble)
        .whereType<double>()
        .toList(growable: false);

    if (values.isEmpty) {
      return null;
    }

    final degrees = values[0];
    final minutes = values.length > 1 ? values[1] : 0;
    final seconds = values.length > 2 ? values[2] : 0;

    var decimal = degrees + (minutes / 60.0) + (seconds / 3600.0);
    final ref = (reference ?? '').trim().toUpperCase();
    if (ref == 'S' || ref == 'W') {
      decimal *= -1;
    }
    return decimal;
  }

  double? _parseRationalOrDouble(String rawValue) {
    final value = rawValue.trim();
    if (value.contains('/')) {
      final parts = value.split('/');
      if (parts.length != 2) {
        return null;
      }
      final numerator = double.tryParse(parts[0]);
      final denominator = double.tryParse(parts[1]);
      if (numerator == null || denominator == null || denominator == 0) {
        return null;
      }
      return numerator / denominator;
    }
    return double.tryParse(value);
  }
}
