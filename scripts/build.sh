#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SCRATCH="${TMPDIR:-/tmp}/neptype-build-${UID}"
export CLANG_MODULE_CACHE_PATH="$SCRATCH/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$SCRATCH/ModuleCache"
swift build -c release --scratch-path "$SCRATCH" --cache-path "$SCRATCH/cache" --config-path "$SCRATCH/config" --security-path "$SCRATCH/security" "$@"
APP="$SCRATCH/NepType.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mkdir -p "$APP/Contents/Resources/Licenses"
cp branding/assets/NepType.icns "$APP/Contents/Resources/NepType.icns"
cp branding/assets/neptype-mark.png "$APP/Contents/Resources/NepTypeMark.png"
cp data/sources/CMUDICT-LICENSE.txt "$APP/Contents/Resources/Licenses/CMUDICT-LICENSE.txt"
cp data/compiled/google-ne-aliases.tsv "$APP/Contents/Resources/google-ne-aliases.tsv"
cp data/compiled/aksharantar-indiccorp-v1.tsv "$APP/Contents/Resources/aksharantar-indiccorp-v1.tsv"
cp data/compiled/aksharantar-indiccorp-v1.manifest.json "$APP/Contents/Resources/Licenses/AKSHARANTAR-PROVENANCE.json"
cp data/sources/AKSHARANTAR-ATTRIBUTION.txt "$APP/Contents/Resources/Licenses/AKSHARANTAR-ATTRIBUTION.txt"
cp data/sources/GOOGLE-NE-ATTRIBUTION.txt "$APP/Contents/Resources/Licenses/GOOGLE-NE-ATTRIBUTION.txt"
cp "$SCRATCH/release/NepType" "$APP/Contents/MacOS/NepType"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>NepType</string>
<key>CFBundleIdentifier</key><string>local.anup.neptype.prototype</string>
<key>CFBundleName</key><string>NepType</string>
<key>CFBundleDisplayName</key><string>NepType</string>
<key>CFBundleIconFile</key><string>NepType.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
mkdir -p build
ditto --noextattr --norsrc "$APP" build/NepType.app
printf '\nBuilt %s\n' "$(pwd)/build/NepType.app"
