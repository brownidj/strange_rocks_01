import 'package:flutter/material.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/api/local_stub_field_pack_api_client.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/compatibility/field_pack_compatibility_service.dart';
import 'package:strange_rocks_01/features/field_packs/infrastructure/database/field_pack_database.dart';
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

  late final FieldPackController _controller;

  @override
  void initState() {
    super.initState();

    final repository = SqliteFieldPackRepository(FieldPackDatabase());
    final pipeline = FieldPackDownloadPipeline(
      apiClient: LocalStubFieldPackApiClient(),
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
    );
  }

  @override
  void dispose() {
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
      home: FieldPackListScreen(controller: _controller),
    );
  }
}
