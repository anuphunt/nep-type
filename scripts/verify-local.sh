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
scratch="${TMPDIR:-/tmp}/lekha-local-verification-${UID}"
mkdir -p "$scratch"
export CLANG_MODULE_CACHE_PATH="$scratch/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$scratch/clang-cache"
export PYTHONPYCACHEPREFIX="$scratch/python-cache"
export LEKHA_ALIAS_INDEX="$root/data/compiled/google-ne-aliases.tsv"
export LEKHA_AKSHARANTAR_INDEX="$root/data/compiled/aksharantar-indiccorp-v1.tsv"
# SwiftPM's own sandbox cannot be nested in some managed environments.
run "Swift core tests" swift test --disable-sandbox --package-path "$root" --scratch-path "$scratch/swift" --cache-path "$scratch/cache" --config-path "$scratch/config" --security-path "$scratch/security"
run "Portable core build" swift build --disable-sandbox --package-path "$root/portable-core" --scratch-path "$scratch/portable" --cache-path "$scratch/portable-cache" --config-path "$scratch/portable-config" --security-path "$scratch/portable-security"
export LEKHA_TEST_CORE="$scratch/portable/debug/lekha-conformance"
run "Portable protocol" python3 "$root/portable-core/tests/conformance.py" "$LEKHA_TEST_CORE"
run "Portable input preservation" python3 "$root/portable-core/tests/safety_corpus.py" "$LEKHA_TEST_CORE"
run "Malformed-index fallback" python3 "$root/portable-core/tests/corrupt-index-check.py" "$LEKHA_TEST_CORE"
run "Bundled index shape" python3 "$root/scripts/audit-index-shape.py" "$LEKHA_ALIAS_INDEX" "$LEKHA_AKSHARANTAR_INDEX"
run "Linux mock IBus" bash -c 'cd "$1" && python3 -m unittest discover -s tests -q' _ "$root/platforms/linux"
run "Windows mock TSF" "$root/platforms/windows/tests/run.sh"
if [ -n "${JDK_BIN:-}" ] && [ -x "$JDK_BIN/javac" ]; then
  run "Android Java core" "$root/platforms/android/tests/run-core.sh"
else
  printf '\n%s\n' 'SKIP: Android Java core (set JDK_BIN to an installed JDK bin directory)'
fi
run "iOS shared-source consistency" "$root/platforms/ios/sync-core.sh" --check "$root"
printf '\n%s\n' 'Native host behavior, Android SDK build, Windows SDK build, real IBus and enabled iOS/macOS keyboards are not tested by this script.'
exit "$results"
