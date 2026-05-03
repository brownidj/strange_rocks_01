# Adhoc Fossil Finds: On-Device Smoke Test (5-10 min)

## Scope
Validate on a physical device:
- camera capture
- gallery import
- date-based event routing
- GPS icon red/green behavior
- GPS acquisition modal behavior
- GPS position modal behavior
- EXIF modal behavior

## Preconditions
1. App installs and launches on a physical device.
2. Device has camera and location services available.
3. At least one gallery photo exists with EXIF `DateTimeOriginal`.

## Clean Start
1. Uninstall app from device.
2. Reinstall and run fresh build.

Expected:
- No startup crash.
- Adhoc screen loads.
- GPS icon initially red or green depending on device state.

## Test 1: Camera Permission + Capture
1. Tap `Take picture`.
2. If prompted, allow camera permission.
3. Capture a photo and confirm.

Expected:
- App does not crash.
- One thumbnail appears.
- A series title appears.
- `Finish event` becomes enabled.

## Test 2: EXIF Modal (Thumbnail Tap)
1. Tap the thumbnail in the grid.

Expected:
- Modal opens.
- Only one line of data shown: `Taken: <value>`.
- If EXIF timestamp unavailable, shows `Taken: Not available`.

## Test 3: Gallery Import and Event Date Routing
1. Tap `Select photo` and choose a photo with a known date that is different from the current collection event date.

Expected:
- Photo is saved without crash.
- Active collection event changes to `CEyyyy-MM-dd` for the selected photo date.
- Photo appears under that date’s event.

## Test 4: GPS Red Icon Long-Press Flow
(Only if GPS icon is red)
1. Long-press the red GPS icon.

Expected:
- Modal opens and shows `Please wait. Acquiring GPS signal...`.
- If GPS/service/permission missing, modal shows action buttons (enable GPS, allow permission, open settings).
- `Abandon` closes modal.

## Test 5: GPS Acquisition Auto-Close
1. While red GPS modal is open, enable required settings/permission.
2. Wait for GPS lock.

Expected:
- Modal closes automatically when signal is acquired.
- GPS icon changes to green.

## Test 6: GPS Green Icon Long-Press Flow
(Once GPS icon is green)
1. Long-press the green GPS icon.

Expected:
- Modal opens showing current coordinates:
  - `Latitude: ...`
  - `Longitude: ...`

## Test 7: Persistence
1. Add at least one photo.
2. Force-close app (or restart device).
3. Reopen app.

Expected:
- Previously added photo(s) and series remain present.
- No data loss.

## Optional Failure Capture
If any test fails, capture:
1. Device model + OS version.
2. Exact step number above.
3. Flutter logs from `flutter run` around the failure.
4. Screenshot of the failing screen/modal.
