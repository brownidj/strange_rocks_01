import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/photo_capture_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/photo_metadata_service.dart';

void main() {
  test(
    'PhotoCaptureService stores picked file under adhoc_events/{eventId}',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'adhoc-capture-test',
      );
      final sourceFile = File('${tempDir.path}/camera-source.jpg');
      await sourceFile.writeAsBytes(<int>[1, 2, 3, 4, 5]);

      final service = PhotoCaptureService(
        pickedImageProvider: _FakePickedImageProvider(XFile(sourceFile.path)),
        appDocumentsDirProvider: () async => tempDir,
      );

      final result = await service.captureAndStore(
        eventId: 'event:01',
        source: PhotoCaptureSource.camera,
      );

      expect(result, isNotNull);
      expect(result!.originalPath, sourceFile.path);
      expect(result.storedPath, contains('/adhoc_events/event_01/'));
      expect(await File(result.storedPath).exists(), isTrue);
      final bytes = await File(result.storedPath).readAsBytes();
      expect(bytes, <int>[1, 2, 3, 4, 5]);
    },
  );

  test(
    'PhotoCaptureService returns null when user cancels selection',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'adhoc-capture-cancel',
      );

      final service = PhotoCaptureService(
        pickedImageProvider: _FakePickedImageProvider(null),
        appDocumentsDirProvider: () async => tempDir,
      );

      final result = await service.captureAndStore(
        eventId: 'event-1',
        source: PhotoCaptureSource.gallery,
      );

      expect(result, isNull);
    },
  );

  test('PhotoMetadataService marks empty EXIF as not extracted', () async {
    final tempDir = await Directory.systemTemp.createTemp('adhoc-meta-test');
    final file = File('${tempDir.path}/plain.jpg');
    await file.writeAsBytes(<int>[0, 1, 2, 3, 4, 5, 6]);

    final service = PhotoMetadataService();
    final metadata = await service.extractFromFilePath(file.path);

    expect(metadata.exifExtracted, isFalse);
    expect(metadata.capturedAtUtc, isNull);
    expect(metadata.metadataLocation, isNull);
  });
}

class _FakePickedImageProvider implements PickedImageProvider {
  _FakePickedImageProvider(this._file);

  final XFile? _file;

  @override
  Future<XFile?> pickImage(ImageSource source) async => _file;
}
