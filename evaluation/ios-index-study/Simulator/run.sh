#!/bin/bash
set -euo pipefail
if [ "$#" -ne 3 ]; then echo 'Usage: run.sh BOOTED_SIMULATOR_UDID IOS_PROJECT_ROOT PACKED_MINED_PATH' >&2; exit 2; fi
udid=$1
project=$(CDPATH= cd -- "$2" && pwd)
packed_path=$3
study=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app_id=app.lekha.packedindex.bench
if xcrun simctl get_app_container "$udid" "$app_id" data >/dev/null 2>&1; then echo 'Test host already installed; refusing overwrite' >&2; exit 1; fi
work=$(mktemp -d "${TMPDIR:-/tmp}/lekha-index-ios.XXXXXX")
app="$work/LekhaBench.app";mkdir -p "$app" "$work/cache"
cleanup() { xcrun simctl uninstall "$udid" "$app_id" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT HUP INT TERM
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun --sdk iphonesimulator swiftc -O -sdk "$sdk" -target arm64-apple-ios17.0-simulator -module-cache-path "$work/cache" -parse-as-library "$project/LekhaKeyboard/SharedCore/GeneratedAliasIndex.swift" "$study/PackedIndex.swift" "$study/Simulator/main.swift" -o "$app/LekhaBench"
cp "$project/LekhaKeyboard/Resources/aksharantar-indiccorp-v1.tsv" "$app/"
cp "$packed_path" "$app/aksharantar-indiccorp-v1.lki"
cat > "$app/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>app.lekha.packedindex.bench</string><key>CFBundleName</key><string>Lekha Packed Bench</string><key>CFBundleExecutable</key><string>LekhaBench</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleVersion</key><string>1</string><key>CFBundleShortVersionString</key><string>1.0</string><key>MinimumOSVersion</key><string>17.0</string><key>UILaunchScreen</key><dict/></dict></plist>
PLIST
codesign --force --sign - "$app"
xcrun simctl install "$udid" "$app"
container=$(xcrun simctl get_app_container "$udid" "$app_id" data)
out="$study/Simulator"
for mode in raw packed; do
 for run in 1 2 3; do
  rm -f "$container/tmp/packed-bench.json"
  xcrun simctl launch --console "$udid" "$app_id" "$mode" > "$work/$mode-$run.log" 2>&1
  test -f "$container/tmp/packed-bench.json" || { cat "$work/$mode-$run.log" >&2; exit 1; }
  cp "$container/tmp/packed-bench.json" "$out/$mode-$run.json"
 done
done
