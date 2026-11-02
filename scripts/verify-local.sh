#!/bin/bash
# Developer verification only: no input source installation or settings changes.
set -uo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
results=0
run() {
  local title="$1"; shift
  printf '\n%s\n' "== $title =="
  if "$@"; then printf '%s\n' "PASS: $title"; else printf '%s\n' "FAIL: $title"; results=1; fi
}
scratch="${TMPDIR:-/tmp}/neptype-local-verification-${UID}"
mkdir -p "$scratch"
export CLANG_MODULE_CACHE_PATH="$scratch/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$scratch/clang-cache"
export PYTHONPYCACHEPREFIX="$scratch/python-cache"
export NEPTYPE_ALIAS_INDEX="$root/data/compiled/google-ne-aliases.tsv"
export NEPTYPE_AKSHARANTAR_INDEX="$root/data/compiled/aksharantar-indiccorp-v1.tsv"
# SwiftPM's own sandbox cannot be nested in some managed environments.
run "Rust host build" bash "$root/scripts/build-shared-engine.sh"
run "Rust core and exhaustive dictionary parity" "$HOME/.cargo/bin/cargo" test --release --locked --manifest-path "$root/engine/Cargo.toml"
run "Swift core tests" swift test --disable-sandbox --package-path "$root" --scratch-path "$scratch/swift" --cache-path "$scratch/cache" --config-path "$scratch/config" --security-path "$scratch/security"
run "Portable core build" swift build --disable-sandbox --package-path "$root/portable-core" --scratch-path "$scratch/portable" --cache-path "$scratch/portable-cache" --config-path "$scratch/portable-config" --security-path "$scratch/portable-security"
export NEPTYPE_TEST_CORE="$root/engine/target/release/neptype-conformance"
run "Portable protocol" python3 "$root/portable-core/tests/conformance.py" "$NEPTYPE_TEST_CORE"
run "Portable input preservation" python3 "$root/portable-core/tests/safety_corpus.py" "$NEPTYPE_TEST_CORE"
run "Legacy external files cannot override embedded data" python3 "$root/portable-core/tests/corrupt-index-check.py" "$NEPTYPE_TEST_CORE"
run "Bundled index shape" python3 "$root/scripts/audit-index-shape.py" "$NEPTYPE_ALIAS_INDEX" "$NEPTYPE_AKSHARANTAR_INDEX"
run "Linux mock IBus" bash -c 'cd "$1" && python3 -m unittest discover -s tests -q' _ "$root/platforms/linux"
run "Windows mock TSF" "$root/platforms/windows/tests/run.sh"
if [ -n "${JDK_BIN:-}" ] && [ -x "$JDK_BIN/javac" ]; then
  run "Android Java core" "$root/platforms/android/tests/run-core.sh"
else
  printf '\n%s\n' 'SKIP: Android Java core (set JDK_BIN to an installed JDK bin directory)'
fi
run "Canonical dictionary hashes" python3 "$root/scripts/engine-data.py" check
run "Shared engine binding parity" bash "$root/shared/tests/run.sh"
run "Website WebAssembly and SEO" npm --prefix "$root/landing-page" test
run "iOS shared-source consistency" "$root/platforms/ios/sync-core.sh" --check "$root"
printf '\n%s\n' 'Native host behavior, Android SDK build, Windows SDK build, real IBus and enabled iOS/macOS keyboards are not tested by this script.'
exit "$results"
