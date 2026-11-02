#!/bin/bash
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export PATH="$HOME/.cargo/bin:$PATH"
python3 "$root/scripts/engine-data.py" check
cargo build --manifest-path "$root/engine/Cargo.toml" --locked --release
out="$root/build/shared-engine"
mkdir -p "$out/dictionaries"
cp "$root/engine/target/release/neptype-conformance" "$out/neptype-conformance"
case "$(uname -s)" in
 Darwin) cp "$root/engine/target/release/libneptype_engine.dylib" "$out/libNepTypeEngine.dylib"; install_name_tool -id @rpath/libNepTypeEngine.dylib "$out/libNepTypeEngine.dylib"; codesign --force --sign - "$out/libNepTypeEngine.dylib";;
 Linux) cp "$root/engine/target/release/libneptype_engine.so" "$out/libNepTypeEngine.so";;
 *) echo 'Use the Rust MSVC target on Windows.' >&2; exit 1;;
esac
python3 "$root/scripts/engine-data.py" stage "$out/dictionaries"
