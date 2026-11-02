#!/bin/sh
# Temporary standalone simulator host. This is NOT a keyboard extension.
set -eu
if [ "$#" -ne 1 ]; then echo "Usage: $0 BOOTED_SIMULATOR_UDID" >&2; exit 2; fi
udid=$1
project=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
app_id=app.lekha.simulatorhost
if xcrun simctl get_app_container "$udid" "$app_id" data >/dev/null 2>&1; then
  echo "A test host with this ID already exists; refusing to overwrite it." >&2; exit 1
fi
work=$(mktemp -d "${TMPDIR:-/tmp}/lekha-ios-host.XXXXXX")
app="$work/LekhaHost.app"
mkdir -p "$app" "$work/cache"
cleanup() { xcrun simctl uninstall "$udid" "$app_id" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT HUP INT TERM
xcrun --sdk iphonesimulator swiftc -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -target arm64-apple-ios17.0-simulator -module-cache-path "$work/cache" -parse-as-library "$project/LekhaKeyboard/KeyboardViewController.swift" "$project"/LekhaKeyboard/SharedCore/*.swift "$project/Tests/SimulatorHost/main.swift" -o "$app/LekhaHost"
cp "$project"/LekhaKeyboard/Resources/*.tsv "$app/"
cat > "$app/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>app.lekha.simulatorhost</string><key>CFBundleName</key><string>Lekha Test Host</string><key>CFBundleExecutable</key><string>LekhaHost</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleVersion</key><string>1</string><key>CFBundleShortVersionString</key><string>1.0</string><key>MinimumOSVersion</key><string>17.0</string><key>UILaunchScreen</key><dict/></dict></plist>
PLIST
codesign --force --sign - "$app"
xcrun simctl install "$udid" "$app"
container=$(xcrun simctl get_app_container "$udid" "$app_id" data)
xcrun simctl launch --console "$udid" "$app_id" || true
result="$container/tmp/lekha-simulator-host.json"
test -f "$result" || { echo "Host produced no result" >&2; exit 1; }
cp "$result" "$project/Tests/SimulatorHost/last-results.json"
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); sys.exit(0 if r["passed"] else 1)' "$result"
