#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
JDK_BIN=${JDK_BIN:-/opt/homebrew/opt/openjdk/bin}
out="${TMPDIR:-/tmp}/lekha-android-core-test"
mkdir -p "$out"
"$JDK_BIN/javac" --release 8 -d "$out" "$root"/app/src/main/java/app/lekha/keyboard/core/*.java "$root/tests/CoreTest.java" "$root/tests/PersistenceTest.java" "$root/tests/LatestLookupSchedulerTest.java"
"$JDK_BIN/java" -cp "$out" CoreTest
"$JDK_BIN/java" -cp "$out" PersistenceTest
"$JDK_BIN/java" -cp "$out" LatestLookupSchedulerTest
"$JDK_BIN/javac" --release 8 -cp "$out" -d "$out" "$root/tests/RealIndexTest.java"
"$JDK_BIN/java" -cp "$out" RealIndexTest "$root/app/src/main/assets/aksharantar-indiccorp-v1.tsv" "$root/app/src/main/assets/google-ne-aliases.tsv" "$root/app/src/main/assets/nepali-authored-v1.tsv"
