#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

: "${NEPTYPE_MAC_SIGNING_IDENTITY:?Set an existing Developer ID Application signing identity}"
: "${NEPTYPE_MAC_NOTARY_PROFILE:?Set an existing notarytool Keychain profile}"
neptype_version="${NEPTYPE_MAC_VERSION:-0.1.3}"
neptype_build="${NEPTYPE_MAC_BUILD:-4}"
[[ "$neptype_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Use a numeric major.minor.patch version.' >&2; exit 1; }
[[ "$neptype_build" =~ ^[0-9]+$ ]] || { echo 'Use a numeric build number.' >&2; exit 1; }
neptype_root="$PWD"
neptype_release="$neptype_root/build/releases/mac-$neptype_version"
mkdir -p "$neptype_release"
neptype_temp="${NEPTYPE_MAC_STAGE_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/neptype-mac-release.XXXXXX")}"
mkdir -p "$neptype_temp"
[ -z "$(ls -A "$neptype_temp")" ] || { echo "Release staging must be empty: $neptype_temp" >&2; exit 1; }
export MACOSX_DEPLOYMENT_TARGET=13.0
for neptype_arch in arm64 x86_64; do
    export NEPTYPE_BUILD_SCRATCH_PATH="$neptype_temp/swift-$neptype_arch"
    export NEPTYPE_INPUT_BUILD_SCRATCH_PATH="$neptype_temp/input-$neptype_arch"
    bash scripts/build.sh --triple "$neptype_arch-apple-macosx13.0" --disable-sandbox
    cp "$neptype_root/build/NepType.app/Contents/MacOS/NepType" "$neptype_release/NepType-$neptype_arch"
    cp "$neptype_root/build/NepType Input.app/Contents/MacOS/NepTypeInput" "$neptype_release/NepTypeInput-$neptype_arch"
done
neptype_app="$neptype_temp/NepType.app"
ditto --noextattr --norsrc "$neptype_root/build/NepType.app" "$neptype_app"
neptype_binary="$neptype_app/Contents/MacOS/NepType"
xcrun lipo -create "$neptype_release/NepType-arm64" "$neptype_release/NepType-x86_64" -output "$neptype_binary"
neptype_input="$neptype_app/Contents/Resources/Input Methods/NepType Input.app"
neptype_input_binary="$neptype_input/Contents/MacOS/NepTypeInput"
xcrun lipo -create "$neptype_release/NepTypeInput-arm64" "$neptype_release/NepTypeInput-x86_64" -output "$neptype_input_binary"
python3 - "$neptype_binary" "$neptype_input_binary" <<'PY'
import re,subprocess,sys
for binary in sys.argv[1:]:
    architectures=subprocess.check_output(['xcrun','lipo','-archs',binary],text=True).split()
    if set(architectures) != {'arm64','x86_64'}:
        raise SystemExit('Unexpected app architectures: '+str(architectures))
    for arch in ['arm64','x86_64']:
        result=subprocess.check_output(['xcrun','vtool','-arch',arch,'-show-build',binary],text=True)
        minimum=re.search(r'minos\s+(\d+)\.(\d+)',result)
        if not minimum or tuple(map(int,minimum.groups())) > (13,0):
            raise SystemExit('Unexpected macOS minimum for '+arch+': '+result)
        print(arch+' minimum macOS: '+'.'.join(minimum.groups()))
PY
xcrun strip -x "$neptype_binary"
xcrun strip -x "$neptype_input_binary"
plutil -replace CFBundleIdentifier -string com.neptype.mac "$neptype_app/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$neptype_version" "$neptype_app/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$neptype_build" "$neptype_app/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$neptype_version" "$neptype_input/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$neptype_build" "$neptype_input/Contents/Info.plist"
for attribute in com.apple.FinderInfo com.apple.ResourceFork; do
    xattr -dr "$attribute" "$neptype_app" 2>/dev/null || true
done
codesign --force --options runtime --timestamp --sign "$NEPTYPE_MAC_SIGNING_IDENTITY" "$neptype_input"
codesign --verify --deep --strict "$neptype_input"
# The input source can be copied out independently, so it carries its own ticket.
ditto -c -k --keepParent "$neptype_input" "$neptype_release/notarize-input.zip"
xcrun notarytool submit "$neptype_release/notarize-input.zip" --keychain-profile "$NEPTYPE_MAC_NOTARY_PROFILE" --wait --output-format json > "$neptype_release/notarization-input.json"
python3 - "$neptype_release/notarization-input.json" <<'PY_CHECK'
import json,sys
result=json.load(open(sys.argv[1]))
assert result.get('status') == 'Accepted', result
print('Input source notarization accepted:',result['id'])
PY_CHECK
xcrun stapler staple "$neptype_input"
xcrun stapler validate "$neptype_input"
codesign --force --options runtime --timestamp --sign "$NEPTYPE_MAC_SIGNING_IDENTITY" "$neptype_app"
codesign --verify --deep --strict --verbose=2 "$neptype_app"

# Staple the app before packaging, so the copied app also carries its ticket.
ditto -c -k --keepParent "$neptype_app" "$neptype_release/notarize-app.zip"
xcrun notarytool submit "$neptype_release/notarize-app.zip" --keychain-profile "$NEPTYPE_MAC_NOTARY_PROFILE" --wait --output-format json > "$neptype_release/notarization-app.json"
python3 - "$neptype_release/notarization-app.json" <<'PY'
import json,sys
result=json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    raise SystemExit('App notarization was not accepted; inspect the saved submission result.')
print('App notarization accepted:',result['id'])
PY
xcrun stapler staple "$neptype_app"
xcrun stapler validate "$neptype_app"
spctl --assess --type execute --verbose=2 "$neptype_app"

neptype_stage=$(mktemp -d "$neptype_temp/dmg-stage.XXXXXX")
trap 'rm -rf "$neptype_stage"' EXIT
ditto "$neptype_app" "$neptype_stage/NepType.app"
ln -s /Applications "$neptype_stage/Applications"
neptype_dmg="$neptype_release/NepType-$neptype_version-macos-universal.dmg"
hdiutil create -volname NepType -fs HFS+ -format UDZO -srcfolder "$neptype_stage" -ov "$neptype_dmg"
codesign --force --timestamp --sign "$NEPTYPE_MAC_SIGNING_IDENTITY" "$neptype_dmg"
xcrun notarytool submit "$neptype_dmg" --keychain-profile "$NEPTYPE_MAC_NOTARY_PROFILE" --wait --output-format json > "$neptype_release/notarization-dmg.json"
python3 - "$neptype_release/notarization-dmg.json" <<'PY'
import json,sys
result=json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    raise SystemExit('DMG notarization was not accepted; inspect the saved submission result.')
print('DMG notarization accepted:',result['id'])
PY
xcrun stapler staple "$neptype_dmg"
xcrun stapler validate "$neptype_dmg"
codesign --verify --strict --verbose=2 "$neptype_dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$neptype_dmg"
hdiutil verify "$neptype_dmg"
python3 - "$neptype_dmg" "$neptype_version" "$neptype_build" <<'PY'
import datetime,hashlib,json,pathlib,subprocess,sys
p=pathlib.Path(sys.argv[1])
manifest={'version':sys.argv[2],'build':sys.argv[3],'bundleId':'com.neptype.mac','file':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'architectures':['arm64','x86_64'],'minimumMacOS':'13.0','sourceCommit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'verifiedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'inputSourceNotarization':json.loads((p.parent/'notarization-input.json').read_text()),'appNotarization':json.loads((p.parent/'notarization-app.json').read_text()),'dmgNotarization':json.loads((p.parent/'notarization-dmg.json').read_text())}
(p.parent/'release.json').write_text(json.dumps(manifest,indent=2)+'\n')
(p.parent/(p.name+'.sha256')).write_text(manifest['sha256']+'  '+p.name+'\n')
print('Verified release:',p)
print('SHA-256:',manifest['sha256'])
PY
