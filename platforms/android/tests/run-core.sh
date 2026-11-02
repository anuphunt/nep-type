#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
JDK_BIN=${JDK_BIN:-/opt/homebrew/opt/openjdk/bin}
out="${TMPDIR:-/tmp}/neptype-android-core-test"
mkdir -p "$out"
"$JDK_BIN/javac" --release 8 -d "$out" "$root"/app/src/main/java/app/neptype/keyboard/core/*.java "$root"/tests/legacy/*.java "$root/tests/CoreTest.java" "$root/tests/PersistenceTest.java" "$root/tests/LatestLookupSchedulerTest.java"
"$JDK_BIN/java" -cp "$out" CoreTest
"$JDK_BIN/java" -cp "$out" PersistenceTest
"$JDK_BIN/java" -cp "$out" LatestLookupSchedulerTest
