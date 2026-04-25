# Before Fieldwork: Online Preparation - Implementation Plan

## Goal
Implement the first end-to-end capability where a user or project organizer defines a field area online and downloads an offline `field pack` that the app can validate, store, and activate for field use.

## Scope For This Phase
- In scope:
  - Field area definition (polygon-based area selection workflow).
  - Field pack manifest/schema design.
  - Field pack download, integrity validation, local storage, and activation.
  - Metadata and provenance tracking (source, version, created date, CRS, attribution/licensing notes).
  - Basic pack management UI (list packs, pack details, activate/deactivate, delete).
- Out of scope for this phase:
  - Full offline map rendering and geology query UX.
  - Review/admin backend workflows.
  - Sync/export of fossil find records.

## Functional Requirements
1. User can create/select a field area polygon.
2. App requests a field pack for that area from a pack service endpoint.
3. App downloads pack assets with resumable progress.
4. App validates pack integrity before activation.
5. App stores pack metadata and local paths in SQLite.
6. App supports multiple packs with one active pack at a time.
7. App surfaces licensing and safety notes before pack activation.

## Proposed Pack Contract
Use a packaged directory or zip with this minimum contract:

```text
field_pack/
  manifest.json
  field_area.geojson
  basemap.mbtiles
  topography.mbtiles
  geology.gpkg
  gazetteer.sqlite
  instructions.md
  safety_notes.md
  licenses/
    data_sources.json
    attribution.txt
```

`manifest.json` (minimum keys):
- `pack_id` (stable UUID)
- `version` (semver)
- `created_at_utc`
- `area` (bbox + area size)
- `crs` (EPSG code)
- `assets[]` with `path`, `kind`, `size_bytes`, `sha256`
- `data_sources[]` with provider, date, license, attribution
- `requires_app_version`

## App Architecture (Flutter)
Follow a layered approach aligned with `docs/CURRENT_STATE.md`:
- UI layer:
  - `lib/features/field_packs/presentation/`
  - Screens: `field_pack_list_screen`, `field_pack_detail_screen`, `field_area_define_screen`.
- Domain layer:
  - `lib/features/field_packs/domain/`
  - Entities: `FieldPack`, `FieldPackAsset`, `FieldArea`, `DataSourceAttribution`.
  - Use cases: `RequestFieldPack`, `DownloadFieldPack`, `ValidateFieldPack`, `ActivateFieldPack`, `DeleteFieldPack`.
- Infrastructure layer:
  - `lib/features/field_packs/infrastructure/`
  - `FieldPackApiClient`, `FieldPackStorage`, `FieldPackValidator`, `FieldPackRepositoryImpl`.
  - SQLite DAOs for metadata.

## Data Model (SQLite)
Add initial tables:
- `field_packs`
  - `id TEXT PRIMARY KEY`
  - `version TEXT NOT NULL`
  - `name TEXT`
  - `status TEXT NOT NULL` (`downloading|ready|active|invalid`)
  - `local_root_path TEXT NOT NULL`
  - `manifest_json TEXT NOT NULL`
  - `created_at_utc TEXT NOT NULL`
  - `downloaded_at_utc TEXT`
  - `is_active INTEGER NOT NULL DEFAULT 0`
- `field_pack_assets`
  - `id INTEGER PRIMARY KEY AUTOINCREMENT`
  - `pack_id TEXT NOT NULL REFERENCES field_packs(id) ON DELETE CASCADE`
  - `path TEXT NOT NULL`
  - `kind TEXT NOT NULL`
  - `size_bytes INTEGER NOT NULL`
  - `sha256 TEXT NOT NULL`
  - `is_present INTEGER NOT NULL DEFAULT 0`
- `field_areas`
  - `id TEXT PRIMARY KEY`
  - `pack_id TEXT REFERENCES field_packs(id) ON DELETE SET NULL`
  - `name TEXT`
  - `geojson TEXT NOT NULL`
  - `bbox_json TEXT NOT NULL`
  - `created_at_utc TEXT NOT NULL`

Indexes:
- `idx_field_packs_active` on (`is_active`)
- `idx_field_pack_assets_pack_id` on (`pack_id`)
- `idx_field_areas_pack_id` on (`pack_id`)

## API & Integration Strategy
Two deployment options:
1. Temporary stub service for early app integration.
2. Real pack-builder service (preferred after contract stabilizes).

Endpoint sketch:
- `POST /field-packs/request` -> returns `job_id` or direct URL.
- `GET /field-packs/{id}/manifest` -> returns manifest.
- `GET /field-packs/{id}/download` -> pack archive.

Client behavior:
- Retry with backoff for transient errors.
- Resume interrupted downloads where supported.
- Verify `sha256` per asset before marking `ready`.

## UX Flow (MVP)
1. User opens `Field Packs`.
2. Tap `Create Field Area` and draw/import polygon.
3. App estimates area size and warns if too large.
4. User taps `Generate/Download Pack`.
5. Progress view shows download and validation stages.
6. On success, show `instructions` + `safety notes` + license summary.
7. User taps `Activate`.

## Delivery Phases

### Phase 1 - Contract & Foundations
- Define manifest JSON schema and validation rules.
- Add domain entities/use-case interfaces.
- Add SQLite schema + migrations for pack metadata.
- Build local storage structure (`/field_packs/<pack_id>/...`).

### Phase 2 - Download & Validation Pipeline
- Implement API client + download manager.
- Implement unpacking and checksum validation.
- Persist lifecycle state transitions (`downloading -> ready/invalid`).
- Add error mapping (network, storage, checksum, schema mismatch).

### Phase 3 - UI Workflow
- Build pack list/detail screens.
- Build area definition screen (start with import GeoJSON; add draw tools later).
- Add activation/deletion actions with confirmations.
- Show license and safety notes before activation.

### Phase 4 - Hardening
- Add telemetry for failures and pack lifecycle timing.
- Add storage quota checks and low-disk handling.
- Add compatibility checks with `requires_app_version`.
- Add regression and integration tests.

## Test Plan
- Unit tests:
  - Manifest parser/validator.
  - Checksum validator.
  - Pack lifecycle reducer/state logic.
  - SQLite repository CRUD for `field_packs` and assets.
- Integration tests:
  - Download + validate + activate happy path.
  - Corrupt asset checksum failure path.
  - Interrupted download resume path.
- Manual tests:
  - Airplane mode after pack activation.
  - Activate/deactivate across multiple packs.
  - Delete active pack and verify fallback behavior.

## Risks & Mitigations
- Large area requests produce oversized packs.
  - Mitigation: enforce max area and estimated size warnings.
- Data licensing constraints (satellite/orthophoto).
  - Mitigation: explicit license metadata and optional asset toggles.
- Device storage limitations.
  - Mitigation: pre-download size checks and cleanup tools.
- Schema drift between app and builder service.
  - Mitigation: semver in manifest + compatibility gate.

## Definition of Done (for this feature slice)
- User can define/import a field area.
- User can request and download a field pack.
- App validates manifest + all required assets.
- Pack appears in list with `ready` status and can be activated.
- Activation persists across app restarts.
- Errors are visible and actionable (retry/delete/report).
- Tests exist for validator, repository, and primary lifecycle path.

## Suggested Next Step After This Plan
Implement Phase 1 first with a local stub manifest and fixture pack so the domain, repository, and validation pipeline can be tested before backend service integration.
