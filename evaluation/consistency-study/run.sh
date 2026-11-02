#!/bin/bash
# Offline development-only comparison; does not install or enable a keyboard.
set -euo pipefail
project=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
jdk=${JDK_BIN:-/opt/homebrew/opt/openjdk/bin}
if [ ! -x "$jdk/javac" ] || [ ! -x "$jdk/java" ]; then
  echo 'Set JDK_BIN to the bin directory of an installed JDK.' >&2; exit 1
fi
scratch=$(mktemp -d "${TMPDIR:-/tmp}/neptype-consistency.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
export CLANG_MODULE_CACHE_PATH="$scratch/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$scratch/clang-cache"
swift build --disable-sandbox --package-path "$project/portable-core" --scratch-path "$scratch/swift" --cache-path "$scratch/cache" --config-path "$scratch/config" --security-path "$scratch/security" >/dev/null
"$jdk/javac" --release 8 -d "$scratch/classes" \
  "$project/platforms/android/app/src/main/java/app/neptype/keyboard/core/SortedCandidateIndex.java" \
  "$project/platforms/android/app/src/main/java/app/neptype/keyboard/core/CandidateMerger.java" \
  "$project/evaluation/consistency-study/ServiceLookup.java"
authored="$project/platforms/android/app/src/main/assets/nepali-authored-v1.tsv"
mined="$project/data/compiled/aksharantar-indiccorp-v1.tsv"
google="$project/data/compiled/google-ne-aliases.tsv"
python3 "$project/evaluation/consistency-study/compare.py" "$scratch/swift/debug/neptype-conformance" "$jdk/java" "$scratch/classes" "$authored" "$mined" "$google" "$project/data/sources/nepali-authored-v1.json" > "$scratch/authored.json"
python3 "$project/evaluation/consistency-study/sample_index.py" "$mined" 400 > "$scratch/sample.json"
python3 "$project/evaluation/consistency-study/compare_sample.py" "$scratch/swift/debug/neptype-conformance" "$jdk/java" "$scratch/classes" "$authored" "$mined" "$google" "$scratch/sample.json" > "$scratch/sample-results.json"
python3 "$project/evaluation/consistency-study/fallback.py" "$scratch/swift/debug/neptype-conformance" "$jdk/java" "$scratch/classes"
python3 - "$scratch/authored.json" "$scratch/sample-results.json" <<'PY'
import json, sys
a=json.load(open(sys.argv[1])); b=json.load(open(sys.argv[2]))
print('Authored data consistency:',a['summary'])
print('Index-derived sample:',b['summary'])
summary=a['summary']; total=summary['authored_keys']
for name in ('swift_authored_any','android_authored_any','swift_authored_all','android_authored_all','original_retained'):
    if summary[name]!=total: raise SystemExit('Authored consistency invariant failed: '+name)
if b['summary']['swift_original']!=b['summary']['total']:
    raise SystemExit('Swift original-availability invariant failed')
print('PASS: authored candidate presence and Swift original availability')
print('Not an accuracy test; does not build Android or exercise any native input method.')
PY
