#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
root="${1:-$project_dir/../..}"
"$project_dir/sync-core.sh" --check "$root"
cache="${TMPDIR:-/tmp}/neptype-ios-core-test-cache"
mkdir -p "$cache"
bash "$root/scripts/build-shared-engine.sh"
xcrun swiftc -I "$root/shared/include" "$root/engine/target/release/libneptype_engine.a" -module-cache-path "$cache" "$root"/Sources/NepaliCore/*.swift "$project_dir/Tests/main.swift" -o "$cache/test-core"
NEPTYPE_ALIAS_INDEX="$root/data/compiled/google-ne-aliases.tsv" NEPTYPE_AKSHARANTAR_INDEX="$root/data/compiled/aksharantar-indiccorp-v1.tsv" "$cache/test-core"
