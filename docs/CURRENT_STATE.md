

# CURRENT_STATE

## Code prompt

### Architecture & Separation of Concerns
- Establish an architecture that sets explicit boundaries between UI, domain, and infrastructure layers. This should be reflected in the directory structure.
- Avoid dumping new files in the project root; just keep main.py there.
- `main.py` or `main.dart` must not contain any wiring, domain logic, or infrastructure.
- Keep UI wiring, domain logic, and infrastructure separated. Domain must not import infra or UI.
- Prefer thin orchestrators and small, focused services. Use explicit service helpers for UI side effects.
- Avoid direct dialog/widget mutations across layers; use adapters/services (for example, `CategoryManagerUIService`, `AddEditStateService`).
- Keep init/builders as composition roots; do not leak logic into UI builders.
- Prefer explicit dependencies via small dataclasses/services rather than hidden attribute reach-through.

### Readability & Maintainability
- Use clear, short functions with a single responsibility. Extract helpers when logic grows.
- Avoid `getattr`/duck typing in production flow unless truly necessary; prefer adapters/registries.
- Write defensive UI code (best-effort; never crash), but keep error handling narrow and intentional.
- Keep naming consistent with existing patterns: `*Service`, `*Controller`, `*Coordinator`, `*Effects`, `*Rules`.
- Always add explicit error types in try/catch.

### File Size Constraint
- Keep each file under 300 lines. If a file approaches 300, split it into focused modules.
- Make a script to do this at regular intervals, adjusted for the local project.

Example:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${1:-.}"
if ! command -v rg >/dev/null 2>&1; then
  echo "rg (ripgrep) is required." >&2
  exit 1
fi
rg --files "$ROOT_DIR" \
  | rg -v "^${ROOT_DIR}/assets/" \
  | rg -v "^${ROOT_DIR}/pubspec.lock$" \
  | rg -v "^${ROOT_DIR}/ios/Runner.xcodeproj/project.pbxproj$" \
  | rg -v "^${ROOT_DIR}/macos/Runner.xcodeproj/project.pbxproj$" \
  | xargs wc -l \
  | awk '$2 != "total" && $1 > 300 {print $1, $2; found=1} END{exit found?1:0}'
```

### Testing & Refactors
- Always consider adding new tests, even small ones, and always make appropriate suggestions.
- Add small pure tests for new services/helpers when behavior might regress.
- Preserve behavior; refactors should be test-driven and avoid hidden side effects.
- Add Flutter integration tests to test the UI, especially for iOS.
- Consider using Patrol for Android UI tests.
- Remind me to run tests when appropriate.
- Remind me to run manual tests when appropriate.
- Avoid leaving brittle wrappers behind when refactoring code.
- Always start major refactoring in a new branch.

### Coding Style
- Prefer explicit imports. Avoid large inline logic inside UI event handlers.
- Keep log noise low; log failures only in hot paths.

### Output
- Make changes in one pass; keep diffs minimal and focused.
- Maintain a `CURRENT_STATE.md` file that contains this prompt at the top of the file, then the state of the code base architecture, then a report of running any tests.

### Debugging
- Add a debugging code system that allows all debug code to be turned off.
- When debug code is added, make sure it complies with this prerequisite.

### Git
- Remind me to commit and push when appropriate.
- Before doing large-scale refactoring, remind me to change to a refactoring branch.

## If a database is required

### Database requirements
- Use the built-in `sqlite3` library unless there is a strong reason otherwise.
- Organize the code clearly, with separation between:
  1. database connection/setup
  2. schema creation
  3. CRUD operations
  4. utility/helper functions
- Include clear comments throughout.
- Use parameterized queries everywhere to prevent SQL injection.
- Use context managers or another safe pattern to ensure connections and transactions are handled correctly.
- Include proper error handling for database operations.
- Design the code so it can be reused in a larger application.

### Database expectations
- Create the database file if it does not already exist.
- Define a schema using `CREATE TABLE IF NOT EXISTS`.
- Include a primary key for each table.
- Add appropriate foreign keys, unique constraints, default values, and indexes where sensible.
- Enable foreign key enforcement.
- Include a function to initialize the database schema.

### Database coding expectations
- Use classes or well-structured functions, whichever is more appropriate for clarity and maintainability.
- Include type hints where reasonable.
- Avoid overly clever abstractions; prefer readable, practical code.
- Make the design easy to extend with additional tables later.
- Return query results in a convenient format, such as tuples, dictionaries, or lightweight objects, and be consistent.

### Database functionality to include
- Connect to the SQLite database.
- Initialize schema.
- Insert records.
- Fetch one record.
- Fetch multiple records.
- Update records.
- Delete records.
- Optionally search/filter records.
- Optionally support soft delete if appropriate.

### Database testing/demo expectations
- Include a short example showing how to initialize the database and perform basic CRUD operations.
- Include sample table definitions and example usage data.

### Database output expectations
- After the code, briefly explain the structure and design decisions.
- Do not omit important implementation details.

## Code base architecture state

### Updated: 2026-04-25

### Architecture summary
- `lib/main.dart` is now a thin composition root only (`WidgetsFlutterBinding` + `runApp`).
- App-level UI wiring moved to `lib/app/app.dart`.
- Field pack feature scaffolded under explicit layers:
  - `lib/features/field_packs/presentation/screens/`
  - `lib/features/field_packs/domain/entities/`
  - `lib/features/field_packs/domain/repositories/`
  - `lib/features/field_packs/domain/use_cases/`
  - `lib/features/field_packs/infrastructure/manifest/`
  - `lib/features/field_packs/infrastructure/database/`
  - `lib/features/field_packs/infrastructure/storage/`

### Phase 1 delivered
- Domain entities created for field packs, assets, field areas, and data source attribution.
- Use-case interfaces added:
  - `RequestFieldPackUseCase`
  - `DownloadFieldPackUseCase`
  - `ValidateFieldPackUseCase`
  - `ActivateFieldPackUseCase`
  - `DeleteFieldPackUseCase`
- Manifest schema validation implemented with explicit typed rules and validation error type.
- SQLite migration foundation implemented:
  - DB versioning
  - migration list
  - V1 tables: `field_packs`, `field_pack_assets`, `field_areas`
  - required indexes and foreign keys enabled.
- Field pack local storage service implemented to create:
  - app support root `/field_packs`
  - per-pack directory `/field_packs/<pack_id>`
  - subfolders `assets/` and `licenses/`

### Phase 2 delivered
- Implemented API + download pipeline infrastructure:
  - `FieldPackApiClient` abstraction
  - `HttpFieldPackApiClient` for `/field-packs/{id}/manifest` and `/field-packs/{id}/download`
  - `ResumableDownloadService` with retry/backoff and HTTP range resume attempt
- Implemented unpack and integrity services:
  - `FieldPackArchiveUnpacker` (zip extraction)
  - `FieldPackChecksumValidator` (SHA-256 verification against manifest)
- Implemented lifecycle orchestration:
  - `FieldPackDownloadPipeline` as `DownloadFieldPackUseCase`
  - status transitions persisted: `downloading -> ready` or `invalid` on failure
- Implemented explicit pipeline error mapping:
  - `FieldPackNetworkError`
  - `FieldPackStorageError`
  - `FieldPackChecksumError`
  - `FieldPackSchemaMismatchError`
  - `FieldPackUnpackError`
  - `FieldPackUnexpectedError`
- Implemented SQLite repository:
  - `SqliteFieldPackRepository`
  - manifest and asset persistence
  - lifecycle status updates and active-pack semantics
- Added mapping helpers:
  - `FieldPackManifestMapper`
  - `FieldPackStatusMapper`

### Phase 3 delivered
- Implemented presentation workflow screens:
  - `FieldPackListScreen` with pack list, status chips, refresh, and action buttons
  - `FieldAreaDefineScreen` for area name + GeoJSON import and pack download trigger
  - `FieldPackDetailScreen` for manifest assets, instructions, safety notes, and license attribution
- Added `FieldPackController` (`ChangeNotifier`) as thin UI orchestrator:
  - load packs
  - import area and trigger download
  - activate pack
  - delete pack and local files
  - load local notes for safety/license/instructions
- Added pre-activation confirmation dialog showing:
  - safety notes
  - license attribution
- Added delete confirmation dialog.
- Added local stub API implementation for simulator-friendly Phase 3 behavior:
  - `LocalStubFieldPackApiClient`
  - generates manifest and downloadable zip archive with deterministic assets/notes
- Updated app composition root:
  - `StrangeRocksApp` now wires repository, pipeline, and controller
  - app home now receives `FieldPackController` dependency
- Extended repository contract and SQLite implementation with pack deletion support.

### Phase 4 delivered
- Implemented compatibility gate for field packs:
  - `FieldPackCompatibilityService` validates `requires_app_version`
  - pipeline fails early with `FieldPackCompatibilityError` when app version is too old
- Implemented storage quota and low-disk buffer checks:
  - `FieldPackQuotaService` estimates incoming pack size from manifest assets
  - checks projected app storage usage against quota and reserve buffer
  - pipeline fails with `FieldPackInsufficientStorageError` when limits are exceeded
- Implemented telemetry for pipeline lifecycle timing and failures:
  - `FieldPackTelemetry` abstraction
  - `FieldPackDebugTelemetry` implementation for debug logging
  - `FieldPackDownloadPipeline` now emits start, stage, success duration, and failure events
- Updated pipeline orchestration:
  - stage tracking across manifest fetch/validate, compatibility check, quota check, download, unpack, checksum, persistence, cleanup
  - consistent failure marking (`invalid`) plus telemetry for all error paths
- Updated app composition to wire Phase 4 services:
  - compatibility service (`appVersion=1.0.0`)
  - quota service
  - debug telemetry
- Added direct dependency on `pub_semver` for version comparison.

### Tests report
- `flutter analyze`: pass (no issues).
- `flutter test`: pass.
- Added tests:
  - `test/field_pack_manifest_validator_test.dart`
  - `test/field_pack_migrations_test.dart`
  - `test/field_pack_checksum_validator_test.dart`
  - `test/sqlite_field_pack_repository_test.dart`
  - `test/field_pack_download_pipeline_test.dart`
  - `test/field_pack_compatibility_service_test.dart`
  - `test/field_pack_quota_service_test.dart`
  - updated `test/widget_test.dart` for new app shell.
