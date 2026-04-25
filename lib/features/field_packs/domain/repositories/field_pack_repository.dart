import 'package:strange_rocks_01/features/field_packs/domain/entities/field_area.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_asset.dart';
import 'package:strange_rocks_01/features/field_packs/domain/entities/field_pack_manifest.dart';

abstract interface class FieldPackRepository {
  Future<void> saveFieldArea(FieldArea area);
  Future<void> savePackManifest(
    FieldPackManifest manifest, {
    required String localRootPath,
    String? name,
  });
  Future<void> updatePackStatus(
    String packId,
    FieldPackStatus status, {
    String? downloadedAtUtc,
    bool? isActive,
  });
  Future<void> replacePackAssets(String packId, List<FieldPackAsset> assets);
  Future<void> markAssetPresence(
    String packId,
    String assetPath,
    bool isPresent,
  );
  Future<void> deletePack(String packId);
  Future<FieldPack?> getFieldPackById(String packId);
  Future<List<FieldPack>> listFieldPacks();
  Future<FieldPack?> getActiveFieldPack();
}
