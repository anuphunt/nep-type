#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
root="${1:-$project_dir/../..}"
"$project_dir/sync-core.sh" --check "$root"
cache="${TMPDIR:-/tmp}/neptype-ios-core-test-cache"
mkdir -p "$cache"
xcrun swiftc -module-cache-path "$cache" "$project_dir"/NepTypeKeyboard/SharedCore/*.swift "$project_dir/Tests/main.swift" -o "$cache/test-core"
NEPTYPE_ALIAS_INDEX="$project_dir/NepTypeKeyboard/Resources/google-ne-aliases.tsv" NEPTYPE_AKSHARANTAR_INDEX="$project_dir/NepTypeKeyboard/Resources/aksharantar-indiccorp-v1.tsv" "$cache/test-core"
