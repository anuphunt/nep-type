#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SCRATCH="${NEPTYPE_BUILD_SCRATCH_PATH:-${TMPDIR:-/tmp}/neptype-build-${UID}}"
export CLANG_MODULE_CACHE_PATH="$SCRATCH/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$SCRATCH/ModuleCache"
bash scripts/build-apple-engine.sh macosx
export NEPTYPE_RUST_LIBRARY="$PWD/build/rust-apple/macosx/libneptype_engine.a"
swift build -c release --scratch-path "$SCRATCH" --cache-path "$SCRATCH/cache" --config-path "$SCRATCH/config" --security-path "$SCRATCH/security" "$@"
NEPTYPE_BIN_PATH=$(swift build -c release --scratch-path "$SCRATCH" --cache-path "$SCRATCH/cache" --config-path "$SCRATCH/config" --security-path "$SCRATCH/security" "$@" --show-bin-path)
APP="$SCRATCH/NepType.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mkdir -p "$APP/Contents/Resources/Licenses"
cp branding/assets/NepType.icns "$APP/Contents/Resources/NepType.icns"
cp branding/assets/neptype-mark.png "$APP/Contents/Resources/NepTypeMark.png"
python3 scripts/engine-data.py stage "$APP/Contents/Resources"
cp data/sources/CMUDICT-LICENSE.txt "$APP/Contents/Resources/Licenses/CMUDICT-LICENSE.txt"
cp data/compiled/aksharantar-indiccorp-v1.manifest.json "$APP/Contents/Resources/Licenses/AKSHARANTAR-PROVENANCE.json"
cp data/sources/AKSHARANTAR-ATTRIBUTION.txt "$APP/Contents/Resources/Licenses/AKSHARANTAR-ATTRIBUTION.txt"
cp data/sources/GOOGLE-NE-ATTRIBUTION.txt "$APP/Contents/Resources/Licenses/GOOGLE-NE-ATTRIBUTION.txt"
cp "$NEPTYPE_BIN_PATH/NepType" "$APP/Contents/MacOS/NepType"
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
<key>CFBundleShortVersionString</key><string>0.1.2</string>
<key>CFBundleVersion</key><string>3</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
bash scripts/build-input-source.sh "$@"
mkdir -p "$APP/Contents/Resources/Input Methods"
ditto --noextattr --norsrc "build/NepType Input.app" "$APP/Contents/Resources/Input Methods/NepType Input.app"
# Copied source assets can carry Finder metadata that invalidates code signing.
# Remove only that metadata from the generated bundle, not quarantine attributes.
python3 - "$APP" <<'PY'
import os,subprocess,sys
for root,dirs,files in os.walk(sys.argv[1]):
    for item in [root,*[os.path.join(root,name) for name in files]]:
        if os.path.islink(item):
            continue
        for name in subprocess.check_output(['xattr',item],text=True).splitlines():
            if name in ('com.apple.FinderInfo','com.apple.ResourceFork'):
                subprocess.run(['xattr','-d',name,item],check=True)
PY
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
mkdir -p build
ditto --noextattr --norsrc "$APP" build/NepType.app
printf '\nBuilt %s\n' "$(pwd)/build/NepType.app"
