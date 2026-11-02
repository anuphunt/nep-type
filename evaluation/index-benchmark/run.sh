#!/bin/bash
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
study="$root/evaluation/index-benchmark"
index="$root/data/compiled/aksharantar-indiccorp-v1.tsv"
jdk=${JDK_BIN:-/opt/homebrew/opt/openjdk/bin}
[ -x "$jdk/java" ] && [ -x "$jdk/javac" ] || { echo 'Set JDK_BIN to an installed JDK bin directory.' >&2; exit 1; }
scratch=$(mktemp -d "${TMPDIR:-/tmp}/neptype-index-varied.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
python3 "$study/generate.py" "$index" "$scratch/workload.json"
python3 "$study/to-tsv.py" "$scratch/workload.json" "$scratch/workload.tsv"
mkdir -p "$scratch/classes"
"$jdk/javac" --release 8 -d "$scratch/classes" "$root/platforms/android/app/src/main/java/app/neptype/keyboard/core/SortedCandidateIndex.java" "$study/IndexBench.java"
cp "$study/main.swift" "$scratch/main.swift"
swiftc -O -module-cache-path "$scratch/cache" "$root/Sources/NepaliCore/GeneratedAliasIndex.swift" "$scratch/main.swift" -o "$scratch/swift-index"
NEPTYPE_AKSHARANTAR_INDEX="$index" "$scratch/swift-index" "$scratch/workload.json" 3
"$jdk/java" -cp "$scratch/classes" IndexBench "$index" "$scratch/workload.tsv" 3
