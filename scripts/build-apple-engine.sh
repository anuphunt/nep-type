#!/bin/bash
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export PATH="$HOME/.cargo/bin:$PATH"
cd "$root/engine"
platform="${1:-macosx}"
case "$platform" in
 iphoneos) targets=(aarch64-apple-ios);;
 iphonesimulator) targets=(aarch64-apple-ios-sim x86_64-apple-ios);;
 macosx) targets=(aarch64-apple-darwin x86_64-apple-darwin);;
 *) echo "Unsupported Apple platform: $platform" >&2; exit 1;;
esac
python3 "$root/scripts/engine-data.py" check
out="$root/build/rust-apple/$platform"
mkdir -p "$out"
# App and extension may request the same universal library concurrently.
while ! mkdir "$out/.build-lock" 2>/dev/null; do sleep 1; done
trap 'rmdir "$out/.build-lock"' EXIT
libraries=()
for target in "${targets[@]}"; do
 rustup target add "$target"
 cargo build --lib --locked --release --target "$target"
 libraries+=("$root/engine/target/$target/release/libneptype_engine.a")
done
if [ "${#libraries[@]}" = 1 ]; then cp "${libraries[0]}" "$out/libneptype_engine.a.staging"; else xcrun lipo -create "${libraries[@]}" -output "$out/libneptype_engine.a.staging"; fi
mv "$out/libneptype_engine.a.staging" "$out/libneptype_engine.a"
