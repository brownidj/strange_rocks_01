import 'package:flutter/material.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/repositories/sqlite_adhoc_event_repository.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/location_fallback_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/photo_capture_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/photo_metadata_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/infrastructure/services/series_assignment_service.dart';
import 'package:strange_rocks_01/features/adhoc_fossil_finds/presentation/controllers/adhoc_fossil_finds_controller.dart';
import 'package:strange_rocks_01/features/app_entry/presentation/screens/adhoc_fossil_finds_screen.dart';
import 'package:strange_rocks_01/features/app_entry/presentation/screens/app_permissions_screen.dart';
import 'package:strange_rocks_01/features/app_entry/presentation/screens/app_entry_splash_screen.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/api/http_field_pack_api_client.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/api/http_request_field_pack_use_case.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/compatibility/field_pack_compatibility_service.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/database/field_pack_database.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/download/resumable_download_service.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/manifest/field_pack_manifest_validator.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/pipeline/field_pack_download_pipeline.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/repositories/sqlite_field_pack_repository.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/storage/field_pack_storage.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/storage/field_pack_quota_service.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/telemetry/field_pack_telemetry.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/unpack/field_pack_archive_unpacker.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/validation/field_pack_checksum_validator.dart';
import 'package:strange_rocks_01/features/field_packs/presentation/controllers/field_pack_controller.dart';
import 'package:strange_rocks_01/features/field_packs/presentation/screens/field_pack_list_screen.dart';

class StrangeRocksApp extends StatefulWidget {
  const StrangeRocksApp({super.key});

  @override
  State<StrangeRocksApp> createState() => _StrangeRocksAppState();
}

class _StrangeRocksAppState extends State<StrangeRocksApp> {
  static const String _appVersion = '1.0.0';
  static const String _backendBaseUrl = String.fromEnvironment(
    'FIELD_PACK_BACKEND_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );

  late final FieldPackController _controller;
  late final AdhocFossilFindsController _adhocController;
  late final ResumableDownloadService _downloadService;
  late final HttpRequestFieldPackUseCase _requestFieldPackUseCase;

  @override
  void initState() {
    super.initState();

    final repository = SqliteFieldPackRepository(FieldPackDatabase());
    _downloadService = ResumableDownloadService();
    _requestFieldPackUseCase = HttpRequestFieldPackUseCase(
      baseUri: Uri.parse(_backendBaseUrl),
    );
    final pipeline = FieldPackDownloadPipeline(
      apiClient: HttpFieldPackApiClient(
        baseUri: Uri.parse(_backendBaseUrl),
        downloadService: _downloadService,
      ),
      repository: repository,
      storage: FieldPackStorage(),
      manifestValidator: FieldPackManifestValidator(),
      archiveUnpacker: FieldPackArchiveUnpacker(),
      checksumValidator: FieldPackChecksumValidator(),
      compatibilityService: FieldPackCompatibilityService(
        appVersion: _appVersion,
      ),
      quotaService: FieldPackQuotaService(storage: FieldPackStorage()),
      telemetry: const FieldPackDebugTelemetry(),
    );

    _controller = FieldPackController(
      repository: repository,
      downloadFieldPack: pipeline,
      requestFieldPack: _requestFieldPackUseCase,
    );
    _adhocController = AdhocFossilFindsController(
      repository: SqliteAdhocEventRepository(FieldPackDatabase()),
      photoCaptureService: PhotoCaptureService(),
      photoMetadataService: PhotoMetadataService(),
      locationFallbackService: LocationFallbackService(),
      seriesAssignmentService: const SeriesAssignmentService(),
    );
  }

  @override
  void dispose() {
    _downloadService.close();
    _requestFieldPackUseCase.close();
    _adhocController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Strange Rocks',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF446B4F)),
      ),
      home: Builder(
        builder: (navigatorContext) {
          return AppEntrySplashScreen(
            onAdhocFossilFinds: () {
              Navigator.of(navigatorContext).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      AdhocFossilFindsScreen(controller: _adhocController),
                ),
              );
            },
            onFossilHuntingAdventure: () {
              Navigator.of(navigatorContext).push(
                MaterialPageRoute<void>(
                  builder: (_) => FieldPackListScreen(controller: _controller),
                ),
              );
            },
            onPermissionsSettings: () {
              Navigator.of(navigatorContext).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AppPermissionsScreen(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
