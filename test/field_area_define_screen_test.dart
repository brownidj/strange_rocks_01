import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_area.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_asset.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_manifest.dart';
import 'package:strange_rocks_01/features/field_packs/domain/repositories/field_pack_repository.dart';
import 'package:strange_rocks_01/features/field_packs/domain/use_cases/download_field_pack_use_case.dart';
import 'package:strange_rocks_01/features/field_packs/domain/use_cases/request_field_pack_use_case.dart';
import 'package:strange_rocks_01/features/field_packs/presentation/controllers/field_pack_controller.dart';
import 'package:strange_rocks_01/features/field_packs/presentation/screens/field_area_define_screen.dart';

void main() {
  group('FieldAreaDefineScreen', () {
    testWidgets('region mode descends level when map is tapped', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(_testApp());

      expect(find.text('Level: z7'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('define-region-map')));
      await tester.pump();

      expect(find.text('Level: z8'), findsOneWidget);
    });

    testWidgets('pins mode adds pin without changing level', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(_testApp());

      await tester.tap(
        find.byKey(const ValueKey<String>('define-pins-mode-button')),
      );
      await tester.pump();

      expect(find.text('Level: z7'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('define-region-map')));
      await tester.pump();

      expect(find.textContaining('Pins: 1'), findsOneWidget);
      expect(find.text('Level: z7'), findsOneWidget);
    });
  });
}

Widget _testApp() {
  final controller = FieldPackController(
    repository: _FakeFieldPackRepository(),
    downloadFieldPack: _NoopDownloadFieldPackUseCase(),
    requestFieldPack: _NoopRequestFieldPackUseCase(),
  );
  return MaterialApp(home: FieldAreaDefineScreen(controller: controller));
}

class _NoopDownloadFieldPackUseCase implements DownloadFieldPackUseCase {
  @override
  Future<void> call(String packId) async {}
}

class _NoopRequestFieldPackUseCase implements RequestFieldPackUseCase {
  @override
  Future<String> call(FieldArea area) async => 'pack-id';
}

class _FakeFieldPackRepository implements FieldPackRepository {
  @override
  Future<void> deletePack(String packId) async {}

  @override
  Future<FieldPack?> getActiveFieldPack() async => null;

  @override
  Future<FieldPack?> getFieldPackById(String packId) async => null;

  @override
  Future<void> linkFieldAreaToPack(String areaId, String packId) async {}

  @override
  Future<List<FieldPack>> listFieldPacks() async => const <FieldPack>[];

  @override
  Future<void> markAssetPresence(
    String packId,
    String assetPath,
    bool isPresent,
  ) async {}

  @override
  Future<void> replacePackAssets(
    String packId,
    List<FieldPackAsset> assets,
  ) async {}

  @override
  Future<void> saveFieldArea(FieldArea area) async {}

  @override
  Future<void> savePackManifest(
    FieldPackManifest manifest, {
    required String localRootPath,
    String? name,
  }) async {}

  @override
  Future<void> updatePackStatus(
    String packId,
    FieldPackStatus status, {
    String? downloadedAtUtc,
    bool? isActive,
  }) async {}
}
