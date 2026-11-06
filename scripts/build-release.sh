#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="$(mktemp -d "${TMPDIR:-/tmp}/streamdeck-osascript.XXXXXX")"
trap 'rm -rf "$build_root"' EXIT
plugin_name="com.gabrielperales.osascript.sdPlugin"

# Build both slices even when Xcode is running on an Apple silicon Mac.
xcodebuild \
  -project "$repo_root/Sources/OSAScript.xcodeproj" \
  -scheme RunOSAScript \
  -configuration Release \
  -derivedDataPath "$build_root/DerivedData" \
  'ARCHS=arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

binary="$build_root/DerivedData/Build/Products/Release/OSAScript"
lipo "$binary" -verify_arch arm64
lipo "$binary" -verify_arch x86_64
codesign --force --sign - --identifier com.gabrielperales.osascript "$binary"
codesign --verify --strict "$binary"

# Keep the existing manifest, action UUID, property inspector, and icons.
mkdir -p "$build_root/package"
cp -R "$repo_root/Sources/$plugin_name" "$build_root/package/$plugin_name"
cp "$binary" "$build_root/package/$plugin_name/OSAScript"
chmod 755 "$build_root/package/$plugin_name/OSAScript"

python3 - "$build_root/package" "$build_root/plugin.streamDeckPlugin" <<'PY'
from pathlib import Path
import sys
from zipfile import ZIP_DEFLATED, ZipFile

root, output = map(Path, sys.argv[1:])
with ZipFile(output, "w", ZIP_DEFLATED) as archive:
    for path in sorted(root.rglob("*")):
        if path.is_file() and not any(part.startswith(".") for part in path.relative_to(root).parts):
            archive.write(path, path.relative_to(root))
with ZipFile(output) as archive:
    if archive.testzip() is not None:
        raise SystemExit("Package integrity check failed")
PY

# Update both checked-in distribution copies only after building and packaging.
cp "$binary" "$repo_root/Sources/$plugin_name/OSAScript"
chmod 755 "$repo_root/Sources/$plugin_name/OSAScript"
mkdir -p "$repo_root/Release"
cp "$build_root/plugin.streamDeckPlugin" "$repo_root/Release/com.gabrielperales.osascript.streamDeckPlugin"
printf 'Built universal plugin: %s\n' "$repo_root/Release/com.gabrielperales.osascript.streamDeckPlugin"
