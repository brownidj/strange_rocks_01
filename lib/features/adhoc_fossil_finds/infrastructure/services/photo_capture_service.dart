import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum PhotoCaptureSource { camera, gallery }

class CapturedPhotoFile {
  const CapturedPhotoFile({
    required this.originalPath,
    required this.storedPath,
    required this.storedAtUtc,
  });

  final String originalPath;
  final String storedPath;
  final DateTime storedAtUtc;
}

abstract class PickedImageProvider {
  Future<XFile?> pickImage(ImageSource source);
}

class ImagePickerProvider implements PickedImageProvider {
  ImagePickerProvider({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<XFile?> pickImage(ImageSource source) {
    return _picker.pickImage(source: source);
  }
}

class PhotoCaptureService {
  PhotoCaptureService({
    PickedImageProvider? pickedImageProvider,
    Future<Directory> Function()? appDocumentsDirProvider,
  }) : _pickedImageProvider = pickedImageProvider ?? ImagePickerProvider(),
       _appDocumentsDirProvider =
           appDocumentsDirProvider ?? getApplicationDocumentsDirectory;

  final PickedImageProvider _pickedImageProvider;
  final Future<Directory> Function() _appDocumentsDirProvider;

  Future<CapturedPhotoFile?> captureAndStore({
    required String eventId,
    required PhotoCaptureSource source,
  }) async {
    final picked = await _pickedImageProvider.pickImage(switch (source) {
      PhotoCaptureSource.camera => ImageSource.camera,
      PhotoCaptureSource.gallery => ImageSource.gallery,
    });
    if (picked == null) {
      return null;
    }

    final now = DateTime.now().toUtc();
    final rootDir = await _appDocumentsDirProvider();
    final eventDir = Directory(
      p.join(rootDir.path, 'adhoc_events', _sanitizePathSegment(eventId)),
    );
    await eventDir.create(recursive: true);

    final sourcePath = picked.path;
    final extension = p.extension(sourcePath).toLowerCase();
    final safeExtension = extension.isEmpty ? '.jpg' : extension;
    final destinationName = 'photo_${now.microsecondsSinceEpoch}$safeExtension';
    final destinationPath = p.join(eventDir.path, destinationName);
    await File(sourcePath).copy(destinationPath);

    return CapturedPhotoFile(
      originalPath: sourcePath,
      storedPath: destinationPath,
      storedAtUtc: now,
    );
  }

  String _sanitizePathSegment(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, 'eventId', 'eventId cannot be empty');
    }
    return trimmed.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  }
}
