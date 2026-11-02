#!/bin/bash
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export PATH="$HOME/.cargo/bin:$PATH"
if ! command -v cargo >/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o "${TMPDIR:-/tmp}/neptype-rustup.sh"
  sh "${TMPDIR:-/tmp}/neptype-rustup.sh" -y --profile minimal --no-modify-path
fi
cd "$root/engine"
rustup target add wasm32-unknown-unknown
if ! command -v wasm-bindgen >/dev/null || [ "$(wasm-bindgen --version)" != "wasm-bindgen 0.2.130" ]; then
  cargo install wasm-bindgen-cli --version 0.2.130 --locked
fi
python3 "$root/scripts/engine-data.py" check
cargo build --lib --locked --release --target wasm32-unknown-unknown
mkdir -p "$root/landing-page/engine-build"
wasm-bindgen --target web --out-dir "$root/landing-page/engine-build" --out-name neptype_engine target/wasm32-unknown-unknown/release/neptype_engine.wasm
