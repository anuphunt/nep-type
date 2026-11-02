#!/bin/bash
# Offline comparison. It does not install software or touch a platform keyboard.
set -euo pipefail
if [ "$#" -ne 5 ]; then
  echo "Usage: $0 PROJECT_ROOT CANDIDATE_ANDROID_DIR FIXTURE_JSON JAVA_BIN NEW_OUTPUT_DIR" >&2; exit 2
fi
root=$1
candidate=$2
fixture=$3
jdk=$4
output=$5
if [ -e "$output" ] || [ -L "$output" ]; then echo "Output exists; refusing to overwrite." >&2; exit 2; fi
mkdir "$output"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/neptype-platform-compare.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
baseline="$root/platforms/android"
baselineCore="$baseline/app/src/main/java/app/neptype/keyboard/core"
candidateCore="$candidate/app/src/main/java/app/neptype/keyboard/core"
authored="$baseline/app/src/main/assets/nepali-authored-v1.tsv"
mined="$root/data/compiled/aksharantar-indiccorp-v1.tsv"
google="$root/data/compiled/google-ne-aliases.tsv"
for name in nepali-authored-v1.tsv aksharantar-indiccorp-v1.tsv google-ne-aliases.tsv; do
  if ! cmp -s "$baseline/app/src/main/assets/$name" "$candidate/app/src/main/assets/$name"; then
    echo "Baseline/candidate assets differ: $name" >&2; exit 1
  fi
done
cmp -s "$baseline/app/src/main/assets/aksharantar-indiccorp-v1.tsv" "$mined"
cmp -s "$baseline/app/src/main/assets/google-ne-aliases.tsv" "$google"
# Freeze exactly the fixture, evaluator, both Java lookup implementations and
# the unchanged Swift core/indexes before scoring. Never hide a mismatch.
shasum -a 256 "$fixture" "$here/run.sh" "$here/SwiftEvaluator.swift" "$here/ServiceLookup.java" "$here/compare.py" \
  "$baselineCore/SortedCandidateIndex.java" "$baselineCore/CandidateMerger.java" \
  "$candidateCore/SortedCandidateIndex.java" "$candidateCore/CandidateMerger.java" "$candidateCore/PhoneticCandidates.java" \
  "$baseline/app/src/main/java/app/neptype/keyboard/NepTypeKeyboardService.java" \
  "$candidate/app/src/main/java/app/neptype/keyboard/NepTypeKeyboardService.java" \
  "$root/Sources/NepaliCore/Transliterator.swift" "$root/Sources/NepaliCore/Composer.swift" \
  "$root/Sources/NepaliCore/GeneratedIndexes.swift" "$root/Sources/NepaliCore/GeneratedAliasIndex.swift" \
  "$authored" "$mined" "$google" > "$output/pre-evaluation-hashes.txt"
mkdir -p "$scratch/baseline" "$scratch/candidate"
"$jdk/javac" --release 8 -d "$scratch/baseline" "$baselineCore/SortedCandidateIndex.java" "$baselineCore/CandidateMerger.java" "$here/ServiceLookup.java"
"$jdk/javac" --release 8 -d "$scratch/candidate" "$candidateCore/SortedCandidateIndex.java" "$candidateCore/CandidateMerger.java" "$candidateCore/PhoneticCandidates.java" "$here/ServiceLookup.java"
cp "$here/SwiftEvaluator.swift" "$scratch/main.swift"
xcrun swiftc -O -module-cache-path "$scratch/cache" "$root/Sources/NepaliCore/Transliterator.swift" "$root/Sources/NepaliCore/Composer.swift" \
  "$root/Sources/NepaliCore/GeneratedIndexes.swift" "$root/Sources/NepaliCore/GeneratedAliasIndex.swift" "$scratch/main.swift" -o "$scratch/swift-evaluator"
export NEPTYPE_ALIAS_INDEX="$google" NEPTYPE_AKSHARANTAR_INDEX="$mined"
"$scratch/swift-evaluator" "$fixture" > "$output/swift.json"
python3 "$here/compare.py" "$fixture" "$output/swift.json" "$jdk/java" "$scratch/baseline" "$scratch/candidate" "$authored" "$mined" "$google" > "$output/comparison.json"
cp "$fixture" "$output/corpus.json"
printf 'Wrote frozen comparison to %s\n' "$output"
