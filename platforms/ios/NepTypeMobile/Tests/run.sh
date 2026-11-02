#!/bin/sh
# Temporary simulator container host; includes no keyboard extension.
set -eu
if [ "$#" -ne 1 ]; then echo "Usage: $0 BOOTED_SIMULATOR_UDID" >&2; exit 2; fi
udid=$1
project=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
app_id=app.neptype.containerhost
if xcrun simctl get_app_container "$udid" "$app_id" data >/dev/null 2>&1; then
  echo "A test host with this ID already exists; refusing to overwrite it." >&2; exit 1
fi
work=$(mktemp -d "${TMPDIR:-/tmp}/neptype-container-host.XXXXXX")
app="$work/ContainerHost.app"
mkdir -p "$app" "$work/cache"
cleanup() { xcrun simctl uninstall "$udid" "$app_id" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT HUP INT TERM
bash "$project/../../scripts/build-apple-engine.sh" iphonesimulator
xcrun --sdk iphonesimulator swiftc -I "$project/../../shared/include" "$project/../../build/rust-apple/iphonesimulator/libneptype_engine.a" -D NEPTYPE_CONTAINER_TEST -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -target arm64-apple-ios17.0-simulator -module-cache-path "$work/cache" -parse-as-library "$project/NepTypeMobile/AppDelegate.swift" "$project/../../Sources/NepaliCore/Composer.swift" "$project/../../Sources/NepaliCore/Transliterator.swift" "$project/../../Sources/NepaliCore/GeneratedIndexes.swift" "$project/../../Sources/NepaliCore/GeneratedAliasIndex.swift" "$project/NepTypeMobile/Tests/ContainerHost.swift" -o "$app/ContainerHost"
python3 "$project/../../scripts/engine-data.py" stage "$app/"
cat > "$app/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>app.neptype.containerhost</string><key>CFBundleName</key><string>NepType Container Test</string><key>CFBundleExecutable</key><string>ContainerHost</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleVersion</key><string>1</string><key>CFBundleShortVersionString</key><string>1.0</string><key>MinimumOSVersion</key><string>17.0</string><key>UILaunchScreen</key><dict/></dict></plist>
PLIST
codesign --force --sign - "$app"
xcrun simctl install "$udid" "$app"
container=$(xcrun simctl get_app_container "$udid" "$app_id" data)
result="$container/tmp/neptype-container-check.json"
xcrun simctl launch --console "$udid" "$app_id" &
host_pid=$!
attempt=0
while [ ! -f "$result" ] && [ "$attempt" -lt 250 ]; do
  sleep 0.1
  attempt=$((attempt + 1))
done
mkdir -p "$project/../../evidence/platforms"
if [ -f "$result" ]; then
  xcrun simctl io "$udid" screenshot "$project/../../evidence/platforms/iphone-keyboard.png"
fi
if [ ! -f "$result" ]; then
  xcrun simctl terminate "$udid" "$app_id" >/dev/null 2>&1 || true
fi
wait "$host_pid" || true
test -f "$result" || { echo "Host produced no result" >&2; exit 1; }
cp "$result" "$project/NepTypeMobile/Tests/last-results.json"
mkdir -p "$project/../../evidence/platforms"
cp "$container/tmp/neptype-iphone-graphite.png" "$project/../../evidence/platforms/iphone.png"
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); sys.exit(0 if r["passed"] else 1)' "$result"
