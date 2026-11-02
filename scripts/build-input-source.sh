#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SCRATCH="${TMPDIR:-/tmp}/neptype-input-build-${UID}"
export CLANG_MODULE_CACHE_PATH="$SCRATCH/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$SCRATCH/ModuleCache"
swift build --product NepTypeInput --scratch-path "$SCRATCH" --cache-path "$SCRATCH/cache" --config-path "$SCRATCH/config" --security-path "$SCRATCH/security" "$@"
APP="$SCRATCH/NepType Input.app"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources/Licenses"
cp branding/assets/NepType.icns "$APP/Contents/Resources/NepType.icns"
cp data/sources/CMUDICT-LICENSE.txt "$APP/Contents/Resources/Licenses/CMUDICT-LICENSE.txt"
cp data/compiled/google-ne-aliases.tsv "$APP/Contents/Resources/google-ne-aliases.tsv"
cp data/compiled/aksharantar-indiccorp-v1.tsv "$APP/Contents/Resources/aksharantar-indiccorp-v1.tsv"
cp data/compiled/aksharantar-indiccorp-v1.manifest.json "$APP/Contents/Resources/Licenses/AKSHARANTAR-PROVENANCE.json"
cp data/sources/AKSHARANTAR-ATTRIBUTION.txt "$APP/Contents/Resources/Licenses/AKSHARANTAR-ATTRIBUTION.txt"
cp data/sources/GOOGLE-NE-ATTRIBUTION.txt "$APP/Contents/Resources/Licenses/GOOGLE-NE-ATTRIBUTION.txt"
cp "$SCRATCH/debug/NepTypeInput" "$APP/Contents/MacOS/NepTypeInput"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>NepTypeInput</string>
<key>CFBundleIdentifier</key><string>local.anup.inputmethod.NepType</string>
<key>CFBundleName</key><string>NepType Input</string>
<key>CFBundleDisplayName</key><string>NepType Nepali</string>
<key>CFBundleIconFile</key><string>NepType.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>InputMethodConnectionName</key><string>NepTypeInput_Connection</string>
<key>InputMethodServerControllerClass</key><string>NepTypeInputController</string>
<key>TISIntendedLanguage</key><string>ne</string>
<key>tsInputMethodCharacterRepertoireKey</key><array><string>Devanagari</string></array>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
mkdir -p build
ditto --noextattr --norsrc "$APP" "build/NepType Input.app"
printf '\nBuilt %s\n' "$(pwd)/build/NepType Input.app"
