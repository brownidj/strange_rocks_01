#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-.}"
MAX_LINES="${MAX_LINES:-300}"

if ! command -v rg >/dev/null 2>&1; then
  echo "rg (ripgrep) is required." >&2
  exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Target directory not found: $TARGET_DIR" >&2
  exit 1
fi

cd "$TARGET_DIR"

violations=0
while IFS= read -r file_path; do
  line_count="$(wc -l < "$file_path" | tr -d '[:space:]')"
  if [[ "$line_count" -gt "$MAX_LINES" ]]; then
    printf '%s %s\n' "$line_count" "$file_path"
    violations=1
  fi
done < <(
  rg --files . \
    | sed 's#^\./##' \
    | rg '\.(dart|yaml|yml|kt|swift|m|mm|h|cc|cpp|c|js|ts|java|gradle|kts|xml|json|txt|plist|storyboard)$' \
    | rg -v '^assets/' \
    | rg -v '^android/app/src/main/res/' \
    | rg -v '^ios/Runner/Assets.xcassets/' \
    | rg -v '^ios/Runner/Base.lproj/' \
    | rg -v '^macos/Runner/Assets.xcassets/' \
    | rg -v '^macos/Runner/Base.lproj/' \
    | rg -v '^build/' \
    | rg -v '^pubspec\.lock$' \
    | rg -v '^ios/Runner\.xcodeproj/project\.pbxproj$' \
    | rg -v '^macos/Runner\.xcodeproj/project\.pbxproj$'
)

if [[ "$violations" -ne 0 ]]; then
  echo "Found file(s) over ${MAX_LINES} lines." >&2
  exit 1
fi
